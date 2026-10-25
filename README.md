# rpi5-px4-companion

ROS 2 Humble environment for a Raspberry Pi 5 companion computer that talks to a PX4 flight controller over uXRCE-DDS.
ROS 2 and the Micro XRCE-DDS Agent run in a Docker container, so the host stays plain Ubuntu 24.04.
Once set up, powering on the Pi is enough: the bridge starts and the `/fmu/*` topics become available.

```
PX4 flight controller ──UART 921600 bps──> Raspberry Pi 5 (/dev/ttyAMA0)
  (TELEM port)                               └─ container "px4_agent"
                                                ├─ Micro XRCE-DDS Agent
                                                └─ ROS 2 Humble + px4_msgs
```

## Versions

| Component | Version |
| --- | --- |
| PX4 firmware | v1.15.x (tested on Pixracer Pro) |
| px4_msgs | `release/1.15` (git submodule) |
| Micro XRCE-DDS Agent | v3.0.1 |
| ROS 2 | Humble |

px4_msgs must match the PX4 firmware. If they differ, some topics are silently dropped or decoded with wrong values.

## Hardware

- Raspberry Pi 5 (8 GB recommended), microSD 32 GB or larger
- PX4 flight controller with a free TELEM port

| FC TELEM port | Raspberry Pi 5 |
| --- | --- |
| TX | GPIO15 / RXD (pin 10) |
| RX | GPIO14 / TXD (pin 8) |
| GND | GND (pin 6) |

PX4 parameters: set `UXRCE_DDS_CFG` to that TELEM port and `SER_TELx_BAUD` to 921600.

## Setup

### 1. Host (once per Pi)

Enable UART0 in `/boot/firmware/config.txt` and reboot:

```
enable_uart=1
dtparam=uart0=on
dtoverlay=uart0-pi5
```

- Remove `console=serial0,...` from `/boot/firmware/cmdline.txt` if present.
- Install Docker Engine with the Compose plugin and add your user to the `docker` group.
- Set `USER_UID` / `USER_GID` in `docker-compose.yaml` to your `id -u` / `id -g` (1002 here).

### 2. Build

```bash
git clone --recurse-submodules https://github.com/<org>/rpi5-px4-companion.git
cd rpi5-px4-companion
docker compose up -d --build   # about 16 min on a Pi 5
docker exec px4_agent bash -c 'source /opt/ros/humble/setup.bash && cd ~/ros2_ws && colcon build --symlink-install'   # about 10 min
```

The container uses `restart: always`, so it starts on every boot.

## Usage

```bash
docker exec -it px4_agent bash   # ROS 2 and the workspace are sourced automatically
ros2 topic list | grep fmu
ros2 topic echo /fmu/out/vehicle_status --once
```

Other machines on the same LAN can use the topics directly (host networking) if they run ROS 2 Humble
with `ROS_DOMAIN_ID=0` and the same px4_msgs version.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| No `session established` in `docker logs px4_agent` | `sudo cat /proc/tty/driver/ttyAMA`: if `rx:` stays 0, check the wiring (TX/RX crossed), `UXRCE_DDS_CFG`, and the baud rate |
| Topics are listed but `ros2 topic echo` prints nothing | px4_msgs does not match the firmware |
| Container keeps restarting | `/dev/ttyAMA0` is missing (`config.txt`) or used by a serial console (`cmdline.txt`) |
| Other PCs cannot see the topics | Same LAN and subnet, `ROS_DOMAIN_ID`, Fast DDS as the RMW |

## Updating px4_msgs

When the PX4 firmware changes, move the submodule to the matching px4_msgs, rebuild it from scratch,
and update the Versions table. The package collects `msg/*.msg` at configure time, so a normal rebuild
misses added or removed messages.

```bash
git -C ros2_ws/src/px4_msgs fetch
git -C ros2_ws/src/px4_msgs checkout <branch-or-commit>
docker exec px4_agent bash -c 'source /opt/ros/humble/setup.bash && cd ~/ros2_ws && rm -rf build/px4_msgs install/px4_msgs && colcon build --symlink-install'
git add ros2_ws/src/px4_msgs && git commit -m "Update px4_msgs to <version>"
```

## Optional: enter the container on SSH login

Append to `~/.bashrc` on the host:

```bash
if [ -n "$SSH_CONNECTION" ] && [ -z "$DOCKER_CONTAINER" ]; then
  if docker ps | grep -q px4_agent; then
    export DOCKER_CONTAINER=1
    exec docker exec -it px4_agent bash
  fi
fi
alias da='docker exec -it px4_agent bash'
```

To stay on the host instead: `ssh -t <user>@<pi> 'DOCKER_CONTAINER=1 exec bash -l'`

## Files

| Path | Purpose |
| --- | --- |
| `Dockerfile` | ROS 2 Humble image with the Micro XRCE-DDS Agent built from source |
| `docker-compose.yaml` | Container settings: host network, `/dev/ttyAMA0`, workspace mount, Agent version |
| `entrypoint.sh` | Runs `MicroXRCEAgent serial --dev /dev/ttyAMA0 -b 921600` |
| `ros2_ws/src/px4_msgs` | PX4 message definitions (submodule) |
| `CLAUDE.md` | Notes for Claude Code (Japanese) |

## License

TBD. Third-party components keep their own licenses: px4_msgs (BSD-3-Clause), Micro XRCE-DDS Agent (Apache-2.0).
