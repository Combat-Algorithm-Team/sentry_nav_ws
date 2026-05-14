# TODO / Current State

本文件只记录当前工作区状态、真实缺口和下一步优先事项。稳定流程放在 `DEVELOPMENT.md`，长期架构知识放在 `KNOWLEDGE.md`，排障经验放在 `TROUBLESHOOTING.md`。

## 当前事实

- 运行环境按 Ubuntu 22.04 + ROS 2 Humble 处理；宿主机是 Apple Silicon macOS，ROS 构建和运行优先在 Docker 容器里完成。
- 默认容器名为 `Combat_Sentry2026`，宿主机 `sentry_nav_ws` 通常挂载到容器内 `/root/Combat_Sentry2026/sentry_nav_ws/src`。
- `sentry_nav_ws` 是外层工作区和 git 仓库，内部包含多个嵌套 git 仓库；提交或 push 前必须先确认真实 git root。
- 当前导航主仓库是 `combat_sentry_nav`，主要链路围绕 `pb2025_nav_bringup`、`sentry_fusion`、`terrain_analysis`、`terrain_analysis_ext`、`pointcloud_to_laserscan`、`combat_nav2_plugins`、`cmd_vel_transform`、`pb_omni_pid_pursuit_controller` 等包。
- 实车入口是 `combat_sentry_nav/pb2025_nav_bringup/launch/rm_navigation_reality_launch.py`。
- `rm_navigation_reality_launch.py` 默认 `world:=rmuc2026`，但 UC 2026 地图尚未建立；运行 RMUL 2026 地图时需要显式传 `world:=rmul2026`。
- RMUL 2026 栅格地图为 `combat_sentry_nav/pb2025_nav_bringup/map/reality/rmul2026.pgm/.yaml`；旧的 `rmul_2026_r.xcf` 已删除，不要恢复。
- `rmul2026.yaml` 当前 `origin` 暂为 `[0.0, 0.0, 0.0]`，需要结合实车重定位、先验 PCD 和 RViz 对齐后再定稿。
- Odin 重定位可能定不上时，可用 `publish_static_map_to_odom_tf:=True` 临时发布静态 `map -> odom` 兜底；默认关闭，避免 Odin 正常重定位时重复发布同一条 TF。
- 静态语义地形层已经接入实车 Nav2 参数，区域配置在 `pb2025_nav_bringup/config/reality/terrain_semantic_zones.yaml`。

## 当前已知缺口

- UC 2026 的 `rmuc2026.pgm/.yaml` 尚未建立，默认 `world:=rmuc2026` 不能视为可直接运行的地图导航路径。
- RMUL 2026 地图的 `origin`、先验 PCD、Odin 重定位坐标系之间的关系还没有完成实车标定。
- `pcd/reality/` 目前没有可用先验 PCD，重定位相关运行需要现场补齐或显式配置。
- 语义地形多边形仍需要用 RViz 对齐真实地图，不能只凭模板坐标投入下位机限速。
- 飞坡、隧道、起伏路段、43 度坡等区域仍需要沉淀为可维护的语义地图、限速策略或专门行为。
- 真机联调还需要重点验证 TF 连通、点云时间戳、Livox/Odin 点云融合质量、Nav2 costmap 更新和下位机速度保护。

## 下一步优先事项

- 建立并验证 `rmuc2026.pgm/.yaml`，让默认 `world:=rmuc2026` 成为可运行路径。
- 标定 `rmul2026.yaml` 的 `origin`，并与先验 PCD / Odin 重定位输出统一。
- 补齐 `pcd/reality/` 中与 `world` 对应的先验 PCD 或明确当前运行不依赖 PCD 的模式。
- 用 RViz 校准 `terrain_semantic_zones.yaml`，确保堡垒、高地、43 度坡、禁区和限速区贴合实际地图。
- 实测 `publish_static_map_to_odom_tf:=True` 只作为 Odin 重定位失败时的临时兜底，不进入默认启动参数。
- 梳理飞坡、隧道、起伏路段为行为树动作、速度限制或 Nav2 语义层规则。

## 已完成但需保持一致

- `sentry_fusion` 负责 Livox 点云去畸变、Odin/Livox 点云融合和里程计适配，并发布 `registered_scan`、`lidar_odometry`、`odometry`。
- `terrain_analysis` / `terrain_analysis_ext` 消费 `registered_scan`，发布 `terrain_map` / `terrain_map_ext`。
- `pointcloud_to_laserscan` 在 SLAM 链路中把 `terrain_map_ext` 转成 `obstacle_scan`。
- `navigation_launch.py` 启动 `terrain_analysis`、`terrain_analysis_ext`，并可选启动 `terrain_zone_monitor`。
- `localization_launch.py` 加载 `map_server` 和 `lifecycle_manager_localization`，并支持同一个静态 `map -> odom` 兜底开关。
- `slam_launch.py` 中原来的静态 `map -> odom` 发布已改为受 `publish_static_map_to_odom_tf` 控制。
