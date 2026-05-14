# Troubleshooting

本文件记录可复用排障线索。先以当前源码、launch 和 YAML 为准，再使用这里的经验。

## 容器与路径

- 如果 VS Code attached workspace 打开的是 `/root/Combat_Sentry2026/sentry_nav_ws/src`，执行 `colcon` 时通常需要到父目录 `/root/Combat_Sentry2026/sentry_nav_ws`。
- 宿主机路径和容器路径不要混用：
  - 宿主机：`/Users/muzjili/Desktop/Combat_Sentry/sentry_nav_ws`
  - 容器内源码挂载：`/root/Combat_Sentry2026/sentry_nav_ws/src`
  - 容器内 colcon 工作区：`/root/Combat_Sentry2026/sentry_nav_ws`
- 如果某个路径在容器内找不到，先确认 Docker 挂载和 VS Code 打开的目录，不要直接改 launch。

## Git 边界

- `/Users/muzjili/Desktop/Combat_Sentry` 不是当前 ROS 工作区的 git 根。
- 常见 git root：
  - `sentry_nav_ws`
  - `sentry_nav_ws/combat_sentry_nav`
  - `sentry_nav_ws/combat_sentry_behavior/combat_sentry_behavior`
  - `sentry_nav_ws/combat_rm_interfaces`
  - `sentry_nav_ws/standard_robot_pp_ros2`
- 提交、diff、status、push 前先用 `git -C <path> rev-parse --show-toplevel` 确认真实仓库。
- 外层 `sentry_nav_ws` 记录子仓库指针；子仓库提交并 push 后，外层仓库通常还需要提交新的 submodule/subproject 指针。

## Humble 编译差异

- `RCLCPP_*_THROTTLE` 宏可能因为 const 成员函数中的 clock 调用触发编译错误；先检查失败 helper 是否不该是 `const`。
- 多个包开启 `-Wall -Werror`，新增未使用变量、隐式转换、签名不匹配都会直接变成编译失败。
- arm64 容器内不要沿用 x86_64 专用库路径或预编译二进制；看到 `/usr/lib/x86_64-linux-gnu/...` 一类路径时要核对架构。

## 时间源与 TF

- 若节点启动时报 `parameter 'use_sim_time' has already been declared`，优先检查该节点是否手动 `declare_parameter("use_sim_time", ...)`；在 Humble 中自定义节点通常不要重复声明它。
- 若运行时报 `can't subtract times with different time sources [1 != 2]`，优先检查是否把默认构造的 `rclcpp::Time` 与节点 clock 的 `now()` 相减。
- 同一节点内优先使用 `this->get_clock()->now()` 或节点注入的 clock，避免混用临时 `rclcpp::Clock().now()`。
- Nav2 / SLAM / 点云链路异常时优先检查：
  - `use_sim_time` 是否一致。
  - `map -> odom -> base_footprint/base_yaw/base_yaw_odom` TF 是否连通。
  - 点云 header stamp 与 TF buffer 时间是否匹配。
  - message filter 是否因 TF 超时或 QoS 不匹配丢消息。
- 如果 Odin 重定位未定上导致 `map -> odom` 缺失，可临时用 `publish_static_map_to_odom_tf:=True` 启动静态兜底 TF；Odin 正常重定位后应关闭该开关。
- 同一条 TF 边不能同时由 Odin 和 static publisher 长期发布，否则 RViz/Nav2 看到的 TF 可能抖动或不确定。

## 地图、world 与 PCD

- `world:=<name>` 通常会拼出 `map/reality/<name>.yaml`，并可能关联同名先验 PCD。
- 当前实车默认 `world:=rmuc2026`，但 UC 2026 地图尚未建立；RMUL 2026 地图应使用 `world:=rmul2026`。
- 报 map 找不到时，先检查：
  - `pb2025_nav_bringup/map/reality/<world>.yaml`
  - YAML 内 `image:` 指向的 PGM 是否存在。
  - `map_server` 的 `yaml_filename` 是否被 launch 正确改写。
- 报 PCD 找不到时，先检查 `pb2025_nav_bringup/pcd/reality/`，当前该目录只有占位文件。
- `slam:=True` 时定位链路与 `slam:=False` 不同，不要把建图模式的问题直接归因到重定位或 `map_server`。
- 纯 YAML / launch / map 文件改动在 `--symlink-install` 下通常重启 launch 即可生效；非 symlink 安装或安装空间旧文件残留时需要重建或清理。

## 点云与 QoS

- `point_cloud_deskew` 连续打印 `Drop cloud: ... outside the odometry cache` 时，先确认 `odin1/odometry_highfreq` 正在发布且时间戳覆盖 Livox 点云时间段。
- 实车高频里程计可能轻微滞后，`max_extrapolation_sec` 和 `max_odom_gap_sec` 不能设得过窄。
- RViz 或下游节点报 `/registered_scan` / `/livox/lidar_deskewed` 的 `RELIABILITY_QOS_POLICY` 不兼容时，说明发布端/订阅端可靠性策略不匹配。
- 面向导航和 RViz 的处理后点云输出应使用 reliable QoS；原始传感器输入可继续使用 `SensorDataQoS`。

## 地形分析与代价地图

- 如果坡面全部被当成障碍，优先检查 `terrain_analysis` 的 `useSorting`、`quantileZ`、`considerDrop`、`disRatioZ`、`vehicleHeight`。
- 如果低矮障碍漏检，检查输出点云的 `intensity` 高度编码，以及 `IntensityVoxelLayer` 的 `min_obstacle_intensity` / `max_obstacle_intensity`。
- 如果动态物体走过后留下不可通行区域，检查 `clearDyObs`、decay time、clearing distance 和 costmap rolling window。
- 如果隧道、飞坡、起伏路段表现不稳定，不要只调全局 planner；这些地形可能需要限速、局部行为或 BT 专用节点。
- `semantic_terrain_layer_test_launch.py` 报 `pb_nav2_plugins/costmap_plugins.xml has no Root Element`，并且 `combat_nav2_plugins` 加载时指向旧 `install/pb_nav2_plugins/lib/liblayers.so` 的 `undefined symbol`，通常是旧安装残留污染插件索引和 `LD_LIBRARY_PATH`。删除 `build/pb_nav2_plugins install/pb_nav2_plugins`，再重建 `combat_nav2_plugins pb2025_nav_bringup`。
- `semantic_terrain_layer_test_launch.py` 在 Ctrl-C 退出时报 `class_loader.ClassLoader: SEVERE WARNING`、`terminate called without an active exception`、`exit code -6`，通常不是语义 layer 加载失败，而是 standalone active costmap 未先走 lifecycle `deactivate/cleanup` 就析构插件。
