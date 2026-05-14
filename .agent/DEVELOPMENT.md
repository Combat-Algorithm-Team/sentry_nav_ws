# Development Notes

本文件记录稳定开发流程。若这里与源码、launch、YAML 或 Docker 配置冲突，以当前仓库文件为准。

## 运行环境

- ROS 环境：Ubuntu 22.04 + ROS 2 Humble。
- 宿主机：Apple Silicon macOS；不要默认在 macOS 原生环境运行 ROS。
- 默认容器：`Combat_Sentry2026`。
- 默认镜像族：`combat_sentry2026`，优先使用本地最新可用 tag。
- 宿主机工作区：`/Users/muzjili/Desktop/Combat_Sentry/sentry_nav_ws`。
- 容器源码挂载通常是 `/root/Combat_Sentry2026/sentry_nav_ws/src`。
- 容器内 colcon 工作区通常是 `/root/Combat_Sentry2026/sentry_nav_ws`。

## 进入容器

```bash
docker start Combat_Sentry2026
docker exec -it Combat_Sentry2026 bash
```

```bash
source /opt/ros/humble/setup.bash
cd /root/Combat_Sentry2026/sentry_nav_ws
source install/setup.bash
```

## 仓库边界

- 外层仓库：`/Users/muzjili/Desktop/Combat_Sentry/sentry_nav_ws`。
- 导航子仓库：`sentry_nav_ws/combat_sentry_nav`。
- 行为树子仓库：`sentry_nav_ws/combat_sentry_behavior/combat_sentry_behavior`。
- 消息接口子仓库：`sentry_nav_ws/combat_rm_interfaces`。
- 下位机通信子仓库：`sentry_nav_ws/standard_robot_pp_ros2`。
- 执行 `git status`、`commit`、`push` 前先确认真实 git root，不要把外层状态和子仓库状态混在一起。

## 当前包清单

导航主仓库 `combat_sentry_nav` 当前包含：

- `pb2025_nav_bringup`：实车/SLAM/Nav2/地图/机器人描述启动入口。
- `sentry_fusion`：Livox 去畸变、Odin/Livox 点云融合、里程计适配。
- `terrain_analysis`、`terrain_analysis_ext`：地形点云分析，输出 `terrain_map`、`terrain_map_ext`。
- `pointcloud_to_laserscan`：SLAM 链路中把地形点云转为 scan。
- `small_gicp_relocalization`：基于先验 PCD 的重定位。
- `small_point_lio`：轻量点云里程计实验包。
- `odin_ros_driver`、`livox_ros_driver2`：Odin1 和 Livox 输入。
- `combat_nav2_plugins`：自定义 Nav2 costmap layer、terrain monitor 等插件。
- `pb_omni_pid_pursuit_controller`、`goal_approach_controller`：控制器。
- `cmd_vel_transform`：Nav2 输出速度转换。

## 构建原则

- 优先按包增量构建，不默认全工作区重编。
- 纯 launch / YAML / 地图改动在 `--symlink-install` 下通常只需重启 launch；若安装空间不是 symlink 或旧文件残留，再重建相关包。
- 新增依赖时同步检查 `package.xml`、`CMakeLists.txt`、头文件、链接和 plugin XML。
- 遇到 `ament_cmake_auto` 风格包，沿用现有写法。
- 不随意提升 C++ 标准；导航相关包里仍有 C++14 约束。

常用构建命令：

```bash
source /opt/ros/humble/setup.bash
cd /root/Combat_Sentry2026/sentry_nav_ws
colcon build --symlink-install --packages-select <package_name>
source install/setup.bash
```

常用目标：

- `pb2025_nav_bringup`
- `sentry_fusion`
- `terrain_analysis terrain_analysis_ext`
- `combat_nav2_plugins`
- `cmd_vel_transform`
- `combat_sentry_behavior`
- `combat_rm_interfaces`
- `standard_robot_pp_ros2`

## 常用启动

启动下位机串口：

```bash
ros2 launch standard_robot_pp_ros2 standard_robot_pp_ros2.launch.py
```

启动 Odin1：

```bash
ros2 launch pb2025_nav_bringup odin1_ros2.launch.py
```

启动实车导航主入口：

```bash
ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py
```

当前默认 `world:=rmuc2026`，但 UC 2026 地图尚未建立。运行 RMUL 2026 地图：

```bash
ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py \
  world:=rmul2026 \
  slam:=False
```

Odin 重定位未定上时临时启用静态 `map -> odom` 兜底：

```bash
ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py \
  publish_static_map_to_odom_tf:=True
```

该开关默认关闭。Odin 正常发布 `map -> odom` 时不要同时开启，避免同一 TF 边有两个发布源。

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

独立测试点云去畸变和里程计适配：

```bash
ros2 launch pb2025_nav_bringup point_cloud_deskew_launch.py
```

## 静态验证清单

- launch 引用的包、可执行文件、参数文件、地图、PCD、URDF/xacro 路径是否真实存在。
- `world:=<name>` 是否能找到对应 `map/reality/<name>.yaml` 和需要的先验 PCD。
- YAML 中 topic、frame、namespace 占位符和 remap 是否与 launch 一致。
- Nav2 配置中 `global_frame`、`robot_base_frame`、`map -> odom -> base_*` TF 链是否合理。
- 点云链路是否保持 `registered_scan`、`lidar_odometry`、`odometry`、`terrain_map`、`terrain_map_ext` 的 topic 约定。
- 行为树 XML 使用的 plugin、端口名和 C++ `providedPorts()` 是否一致。
- 时间相关改动要检查 `use_sim_time`、节点 clock、消息 header stamp 和不同 time source 混用。

## 命名与作者信息

- 保留仓库和用户现有命名，不主动改包名、topic、frame、节点名、class、函数、文件名、容器名或镜像名。
- 新建 ROS 包或需要作者/维护者信息时默认使用：
  - `Jieliang Li`
  - `lijieliang@njust.edu.cn`
- 不批量修改第三方或上游代码作者信息。
