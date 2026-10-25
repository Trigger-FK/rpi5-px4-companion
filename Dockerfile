FROM ros:humble-ros-base

# ホストユーザー(yamamotolab, uid/gid 1002)と揃える。値は docker-compose.yaml の build.args から渡す。
ARG USERNAME=rosuser
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# 1. ユーザー作成、sudo NOPASSWD、シリアル(/dev/ttyAMA0)用に dialout
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && usermod -aG dialout $USERNAME

# 2. ビルド依存
RUN apt-get update && apt-get install -y \
    git cmake build-essential \
    python3-colcon-common-extensions \
    python3-ament-package \
    python3-rosdep \
    libboost-all-dev \
    && rm -rf /var/lib/apt/lists/*

# 3. Micro-XRCE-DDS-Agent をソースビルド(/usr/local/bin/MicroXRCEAgent)
#    master を追わずタグで固定する。v3.0.1 = Fast DDS 3 系(研究室がこれまで運用してきた版)。
#    PX4 公式ドキュメントが Humble 向けに示すのは v2.4.2。FC 接続時に ros2 topic echo が通らなければ
#    docker-compose.yaml の XRCE_AGENT_VERSION を v2.4.2 にして up -d --build(詳細は CLAUDE.md)。
#    ここは root なので sudo 不要。Pi 5 では -j$(nproc) でも数十分かかる。
ARG XRCE_AGENT_VERSION=v3.0.1
WORKDIR /tmp
RUN git clone --depth 1 -b "$XRCE_AGENT_VERSION" https://github.com/eProsima/Micro-XRCE-DDS-Agent.git \
    && cd Micro-XRCE-DDS-Agent && mkdir build && cd build \
    && cmake .. && make -j"$(nproc)" && make install && ldconfig \
    && cd /tmp && rm -rf Micro-XRCE-DDS-Agent

# 4. 以降は rosuser
USER $USERNAME
WORKDIR /home/$USERNAME/ros2_ws

# 5. 対話シェル用の環境(docker exec -it px4_agent bash で読まれる)
#    heredoc なので \e や \[ がビルド時のシェル(dash)に解釈されず、そのまま .bashrc に入る
RUN cat >> ~/.bashrc <<'EOF'
source /opt/ros/humble/setup.bash
if [ -f ~/ros2_ws/install/setup.bash ]; then source ~/ros2_ws/install/setup.bash; fi
export PS1='\[\e[1;32m\][ros2-container] \[\e[m\]\w\$ '
EOF

COPY --chown=$USER_UID:$USER_GID entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# PID 1 = MicroXRCEAgent(entrypoint.sh が exec する)。Agent が落ちればコンテナが止まり restart: always で上がる。
# 対話シェルは docker exec で入るので CMD bash は無い。compose の command: は Agent への追加引数になる。
ENTRYPOINT ["/entrypoint.sh"]
