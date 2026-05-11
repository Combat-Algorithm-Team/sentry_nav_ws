# Troubleshooting

本文件记录 `sentry_nav_ws` 中可复用的排障线索。遇到新问题后，如果解决方案稳定，请追加同步。

## 容器与路径

- 如果 VS Code attached workspace 打开的是 `/root/Combat_Sentry2026/sentry_nav_ws/src`，执行 `colcon` 时通常需要到父目录 `/root/Combat_Sentry2026/sentry_nav_ws`。
- 宿主机路径和容器路径不要混用：
  - 宿主机：`/Users/muzjili/Desktop/Combat_Sentry/sentry_nav_ws`
  - 容器内源码挂载：`/root/Combat_Sentry2026/sentry_nav_ws/src`
  - 容器内 colcon 工作区：`/root/Combat_Sentry2026/sentry_nav_ws`
- 如果某个路径在容器内找不到，先确认 Docker 挂载和 VS Code 打开的目录，而不是直接改 launch。

## Humble 编译差异

- `RCLCPP_*_THROTTLE` 宏可能因为 const 成员函数中的 clock 调用触发编译错误；先检查失败 helper 是否不该是 `const`。
- 多个包开启 `-Wall -Werror`，新增未使用变量、隐式转换、签名不匹配都会直接变成编译失败。
- arm64 容器内不要沿用 x86_64 专用库路径或预编译二进制；看到 `/usr/lib/x86_64-linux-gnu/...` 一类路径时要特别核对架构。

## 时间源与 TF

- 若节点启动时报 `parameter 'use_sim_time' has already been declared`，优先检查该节点是否显式 `declare_parameter("use_sim_time", ...)`；在 Humble 中 `use_sim_time` 会被节点时间源/launch 参数机制处理，自定义节点通常不要再手动声明它。
- 若运行时报 `can't subtract times with different time sources [1 != 2]`，优先检查是否把默认构造的 `rclcpp::Time` 与节点 clock 的 `now()` 相减。
- 同一节点内优先使用 `this->get_clock()->now()` 或节点注入的 clock，避免混用临时 `rclcpp::Clock().now()`。
- Nav2 / SLAM / 点云链路异常时优先检查：
  - `use_sim_time` 是否一致。
  - `map -> odom -> base_footprint/base_yaw/base_yaw_odom` TF 是否连通。
  - 点云 header stamp 与 TF buffer 时间是否匹配。
  - message filter 是否因 TF 超时或 QoS 不匹配丢消息。
- `point_cloud_deskew` 连续打印 `Drop cloud: ... outside the odometry cache` 时，先确认 `odin1/odometry_highfreq` 正在发布且时间戳覆盖 Livox 点云时间段；实车高频里程计可能轻微滞后，`max_extrapolation_sec` 和 `max_odom_gap_sec` 不能设得过窄。
- RViz 或下游节点报 `/registered_scan` / `/livox/lidar_deskewed` 的 `RELIABILITY_QOS_POLICY` 不兼容时，说明发布端/订阅端可靠性策略不匹配；面向导航和 RViz 的处理后点云输出应使用 reliable QoS，原始传感器输入可继续用 `SensorDataQoS`。

## 地图与 PCD

- `world:=<name>` 通常会拼出地图 YAML 和 prior PCD 路径；报 map/pcd 找不到时，先检查 `pb2025_nav_bringup/map/*` 与 `pcd/*` 是否真的有对应文件。
- `slam:=True` 时定位链路与 `slam:=False` 不同，不要把建图模式的问题直接归因到重定位或 map_server。
- 纯 YAML/launch/map 文件改动在 `--symlink-install` 下通常重启 launch 即可生效，但安装空间旧文件或非 symlink 情况仍需重新构建/清理。

## 地形分析与代价地图

- 如果坡面全部被当成障碍，优先检查 `terrain_analysis` 的 `useSorting`、`quantileZ`、`considerDrop`、`disRatioZ`、`vehicleHeight`。
- 如果低矮障碍漏检，检查输出点云的 `intensity` 高度编码，以及 `IntensityVoxelLayer` 的 `min_obstacle_intensity` / `max_obstacle_intensity`。
- 如果动态物体走过后留下不可通行区域，检查 `clearDyObs`、decay time、clearing distance 和 costmap rolling window。
- 如果隧道/飞坡/起伏路段表现不稳定，不要只调全局 planner；这些地形可能需要限速、局部行为或 BT 专用节点。
- `semantic_terrain_layer_test_launch.py` 报 `pb_nav2_plugins/costmap_plugins.xml has no Root Element`，并且 `combat_nav2_plugins` 加载时指向 `install/pb_nav2_plugins/lib/liblayers.so` 的 `undefined symbol`，通常是旧 `pb_nav2_plugins` 安装残留污染了插件索引和 `LD_LIBRARY_PATH`。删除 `build/pb_nav2_plugins install/pb_nav2_plugins`，再重建 `combat_nav2_plugins pb2025_nav_bringup`。
- `semantic_terrain_layer_test_launch.py` 在 Ctrl-C 退出时报 `class_loader.ClassLoader: SEVERE WARNING`、`terminate called without an active exception`、`exit code -6`，通常不是语义 layer 加载失败，而是 standalone active costmap 直接收到终端 SIGINT，未先走 lifecycle `deactivate/cleanup` 就析构插件。测试 launch 应让 costmap 避免直接吃终端 SIGINT，并在 shutdown handler 中先调用 `/costmap/costmap/change_state` 的 `deactivate -> cleanup -> shutdown`，再结束进程。

## Git 边界

- `/Users/muzjili/Desktop/Combat_Sentry` 可能不是 git 仓库。
- 常见嵌套仓库包括：
  - `sentry_nav_ws/combat_sentry_nav`
  - `sentry_nav_ws/combat_sentry_behavior/combat_sentry_behavior`
  - `sentry_nav_ws/combat_rm_interfaces`
  - `sentry_nav_ws/standard_robot_pp_ros2`
- 提交、diff、status、push 前先用 `git -C <path> rev-parse --show-toplevel` 确认真实仓库。
