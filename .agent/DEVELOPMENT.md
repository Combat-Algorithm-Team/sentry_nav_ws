# Development Notes

本文件记录 `sentry_nav_ws` 的稳定开发流程。若与当前源码、launch、YAML 或 Docker 配置冲突，以当前仓库文件为准。

## 运行环境

- ROS 运行环境：Ubuntu 22.04 + ROS 2 Humble。
- 宿主机通常是 Apple Silicon macOS；ROS 构建、运行、调试优先在 Linux Docker 容器内完成。
- 默认容器名：`Combat_Sentry2026`。
- 默认镜像族：`combat_sentry2026`，优先使用本地最新可用 tag。
- 宿主机工作区路径：`/Users/muzjili/Desktop/Combat_Sentry/sentry_nav_ws`。
- 当前 Docker 示例将宿主机 `sentry_nav_ws` 挂载到容器内 `/root/Combat_Sentry2026/sentry_nav_ws/src`。
- 容器内执行 `colcon` 时，优先从父工作区 `/root/Combat_Sentry2026/sentry_nav_ws` 执行；VS Code attach 时可能打开的是其 `src` 子目录。

## 常用进入方式

```bash
docker start Combat_Sentry2026
docker exec -it Combat_Sentry2026 bash
```

```bash
source /opt/ros/humble/setup.bash
cd /root/Combat_Sentry2026/sentry_nav_ws
source install/setup.bash
```

## 构建原则

- 优先按包增量构建，不默认全工作区重编。
- 改 launch、YAML、地图或行为树时，若使用 `--symlink-install`，通常无需因纯配置改动反复重编，但仍需重启相关 launch。
- 增加依赖时同时检查 `package.xml`、`CMakeLists.txt`、头文件包含和链接设置。
- 遇到 `ament_cmake_auto` 风格包，沿用现有模式。
- 不要随意提升包的 C++ 标准；导航相关包里仍有 C++14 约束，行为包当前偏 C++17。

## 常用构建命令

```bash
source /opt/ros/humble/setup.bash
cd /root/Combat_Sentry2026/sentry_nav_ws
colcon build --symlink-install --packages-select <package_name>
source install/setup.bash
```

常用目标：

- 行为树插件/行为服务：`combat_sentry_behavior`
- 导航 bringup / 参数 / 地图：`pb2025_nav_bringup`
- 地形分析：`terrain_analysis`、`terrain_analysis_ext`
- 点云与里程计接口：`loam_interface`、`sensor_scan_generation`
- 底盘速度变换：`cmd_vel_transform`、`fake_vel_transform`
- 下位机串口通信：`standard_robot_pp_ros2`
- 自定义消息：`combat_rm_interfaces`

## 常用启动命令

启动下位机串口：

```bash
ros2 launch standard_robot_pp_ros2 standard_robot_pp_ros2.launch.py
```

启动 Odin1：

```bash
ros2 launch pb2025_nav_bringup odin1_ros2.launch.py
```

启动 Odin 链路建图：

```bash
ros2 launch pb2025_nav_bringup odin_slam_launch.py
```

启动实车导航：

```bash
ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py
```

指定地图导航：

```bash
ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py \
  world:=<地图名> \
  slam:=False
```

建图模式：

```bash
ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py \
  slam:=True \
  use_robot_state_pub:=True
```

关闭 RViz：

```bash
ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py \
  use_rviz:=False
```

## 静态验证清单

- 新增源文件是否被目标编译。
- `package.xml` 与 `CMakeLists.txt` 依赖是否一致。
- launch 引用的包名、可执行文件、参数文件、地图、PCD、URDF/xmacro 路径是否真实存在。
- YAML 中 topic、frame、namespace 占位符和 remap 是否与 launch 一致。
- Nav2 配置中 `global_frame`、`robot_base_frame`、`map -> odom -> base_*` TF 链是否合理。
- 行为树 XML 使用的 plugin、端口名、默认值和 C++ `providedPorts()` 是否一致。
- 任何涉及时间戳的改动都要检查 `use_sim_time`、节点 clock、消息 header stamp 和不同 time source 混用。

## 命名与作者信息

- 保留仓库和用户现有命名，不主动改包名、topic、frame、节点名、class、函数或文件名。
- 新建 ROS 包或需要作者/维护者信息时默认使用：
  - `Jieliang Li`
  - `lijieliang@njust.edu.cn`
- 不批量修改第三方或上游代码作者信息。
