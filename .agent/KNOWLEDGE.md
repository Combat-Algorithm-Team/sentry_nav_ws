# Workspace Knowledge

本文件记录稳定项目知识。若与当前源码、配置或官方规则文件冲突，以当前源码、配置和规则 PDF 为准。

## 工作区结构

- `combat_sentry_nav/`：Nav2、SLAM、点云融合、重定位、地图、地形分析和 bringup 主仓库。
- `combat_sentry_behavior/combat_sentry_behavior/`：哨兵行为树主包，包含 BT 插件、XML、行为服务与客户端。
- `combat_rm_interfaces/`：自定义 ROS2 msg/srv/action 接口。
- `standard_robot_pp_ros2/`：下位机、裁判系统、串口通信和部分 TF 相关数据。

## 实车导航入口

- 主入口：`combat_sentry_nav/pb2025_nav_bringup/launch/rm_navigation_reality_launch.py`。
- 通用 Nav2 入口：`pb2025_nav_bringup/launch/bringup_launch.py`、`navigation_launch.py`。
- 地图发布入口：`localization_launch.py`，加载 `map_server` 与 `lifecycle_manager_localization`。
- SLAM 入口：`slam_launch.py`，启动 `map_saver_server`、`pointcloud_to_laserscan`、`slam_toolbox`。
- 实车参数优先看：
  - `pb2025_nav_bringup/config/reality/nav2_params_mppi.yaml`
  - `pb2025_nav_bringup/config/reality/nav2_params.yaml`
- 仿真参数看 `pb2025_nav_bringup/config/simulation/nav2_params.yaml`。

## 地图与 world

- 实车默认 `world:=rmuc2026`，但 UC 2026 地图尚未建立。
- RMUL 2026 地图文件是 `pb2025_nav_bringup/map/reality/rmul2026.pgm/.yaml`。
- 运行 RMUL 2026 地图时显式传 `world:=rmul2026`。
- `rmul2026.yaml` 当前 `origin` 暂为 `[0.0, 0.0, 0.0]`，需要结合实车重定位、先验 PCD 和 RViz 对齐确认。
- 旧的 `map/reality/rmul_2026_r.xcf` 已删除，不再作为仓库内地图源文件恢复。
- `pcd/reality/` 目前只有占位文件；若重定位需要先验点云，必须补齐与 `world` 对应的 PCD 或显式配置。

## 点云与 TF 链路

- `odin_ros_driver` 和 `livox_ros_driver2` 提供 Odin1 与 Livox 输入。
- `sentry_fusion/point_cloud_deskew` 负责 Livox 点云去畸变、Odin/Livox 点云融合，并发布 `registered_scan`。
- `sentry_fusion/odom_adapter` 负责里程计适配，并发布 `lidar_odometry`、`odometry`，维护导航侧所需的 odom/base 关系。
- `terrain_analysis` 订阅 `registered_scan`，发布近场 `terrain_map`。
- `terrain_analysis_ext` 订阅 `registered_scan` 与 `terrain_map`，发布更大范围 `terrain_map_ext`。
- `pointcloud_to_laserscan` 在 SLAM 链路中把 `terrain_map_ext` 转成 `obstacle_scan`，服务 scan-based consumer；它不是 Nav2 3D 语义代价层的替代品。
- `publish_static_map_to_odom_tf` 是从 `rm_navigation_reality_launch.py` 传到 `bringup_launch.py` 再传到 `slam_launch.py` / `localization_launch.py` 的静态 `map -> odom` 兜底开关，默认 `False`。
- 只有 Odin 重定位未定上、需要临时连通 TF 树时才启用 `publish_static_map_to_odom_tf:=True`；Odin 正常发布 `map -> odom` 时不要开启。

## Nav2 与代价地图

- `navigation_launch.py` 启动：
  - `terrain_analysis`
  - `terrain_analysis_ext`
  - 可选 `combat_nav2_plugins/terrain_zone_monitor`
  - controller / planner / smoother / behavior / bt_navigator / waypoint_follower / velocity_smoother
- local/global costmap 使用 `terrain_map` / `terrain_map_ext` 作为 `IntensityVoxelLayer` 输入。
- `PointCloud2.intensity` 在地形分析输出中不是普通反射强度，而是障碍物相对局部地面的高度编码。
- `pb_nav2_costmap_2d::IntensityVoxelLayer` 读取点云 z 与 intensity 区间，将障碍写入 Nav2 costmap。
- 全局路径规划与局部控制要按舵轮全向底盘理解，不要简化为差速或 Ackermann。

## 静态语义地形层

- 区域配置：`pb2025_nav_bringup/config/reality/terrain_semantic_zones.yaml`。
- 代价层插件：`combat_nav2_plugins` 中的 `pb_nav2_costmap_2d::SemanticPolygonLayer`。
- 状态节点：`combat_nav2_plugins/terrain_zone_monitor`。
- 实车入口默认通过 `use_terrain_zone_monitor:=True` 启动 `terrain_zone_monitor`。
- `high_cost` 表示可通行但高代价；`slowdown` 表示可通行限速状态；`lethal` 表示不可通行障碍。
- 43 度坡应配置为 `lethal`；堡垒/高地平台或可达坡道应配置为 `high_cost`，不能配置为 lethal，否则目标可能不可达。
- 默认发布：
  - `/sentry_terrain_state`：`std_msgs/msg/UInt8`，0 正常，1 高代价地形，2 限速地形，255 禁行/危险地形。
  - `/sentry_terrain_zone_name`：`std_msgs/msg/String`，当前命中的区域名，正常为 `normal`。
  - `/sentry_terrain_speed_limit`：`std_msgs/msg/Float32`，当前区域建议速度上限，-1 表示无语义限速。
  - `/terrain_semantic_markers`：`visualization_msgs/msg/MarkerArray`，用于 RViz 检查区域对齐。
- 若语义多边形依赖固定启动位姿，启动后必须先检查 markers 是否贴合实际地图，再允许下位机使用状态限速。

## BehaviorTree 边界

- 哨兵自身行为树 XML 位于 `combat_sentry_behavior/combat_sentry_behavior/behavior_trees/`。
- Nav2 使用的行为树 XML 位于 `combat_sentry_nav/pb2025_nav_bringup/behavior_trees/`。
- 新增或修改 BT 插件时同步检查：
  - 源文件和头文件是否成对存在。
  - `CMakeLists.txt` 是否加入对应 library。
  - 是否加入 `plugin_libs`。
  - 是否带 `BT_PLUGIN_EXPORT`。
  - 是否通过 `CreateRosNodePlugin(...)` 注册。
  - `providedPorts()` 与 XML 使用是否一致。

## RoboMaster 2026 场地语义

规则来源：`.agent/rules/RoboMaster 2026 机甲大师超级对抗赛比赛规则手册V1.4.2（20260430）.pdf`。以下内容用于导航建模，不替代官方规则原文。

- 战场约 28m x 15m，中心对称；实际地面存在 1-2 度倾斜。
- 基地区、飞镖发射站、雷达基座、前哨站、基地等固定结构应进入静态障碍或禁区语义。
- 梯形高地含约 43 度坡和 23 度坡；43 度坡通常按不可通行，23 度坡需实车验证。
- 堡垒约 20 度坡，哨兵可占领堡垒增益点，但应限速和高代价处理。
- 中央高地和公路坡道可作为跨区通道，但需要速度/加速度约束。
- 起伏路段和凸起不应一概设为致命障碍，应结合底盘能力和地形分析输出判断。
- 飞坡建议作为专门行为或特殊通过动作处理，不建议完全交给普通 Nav2 路径。
- 隧道通过时规则建议速度保持在 0.5m/s 以下，适合作为限速语义区。
- 禁区、增益点、飞坡、隧道、坡面和起伏路段应分层表达，不要只依赖二维占据栅格。

## 地形建模原则

- 静态障碍层表达不可走结构。
- 语义代价层表达高风险但可走区域。
- `terrain_zone_monitor` 和下位机限速表达进入区域后的速度约束。
- 对舵轮底盘，下坡风险区最好同时限制线速度、横向速度、角速度、加速度和减速度。
- 如果目标点可能设置在堡垒或高地上，目标所在平台和可达坡道不能设为 lethal。
