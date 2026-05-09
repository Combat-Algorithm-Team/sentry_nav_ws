# TODO / Current State

本文件记录 `sentry_nav_ws` 的当前状态和待办。完成工作后如状态变化，请同步更新。

## 当前状态

- 运行环境按 Ubuntu 22.04 + ROS 2 Humble 处理。
- 常用容器为 `Combat_Sentry2026`，宿主机 `sentry_nav_ws` 通常挂载到容器内 `/root/Combat_Sentry2026/sentry_nav_ws/src`。
- `sentry_nav_ws` 是多包 ROS2 工作区，同时包含多个嵌套 git 仓库；提交前必须确认真实仓库边界。
- 当前导航主要围绕 `combat_sentry_nav/pb2025_nav_bringup`、`terrain_analysis`、`terrain_analysis_ext`、`loam_interface`、`sensor_scan_generation`、`cmd_vel_transform` 等包。
- RoboMaster 2026 规则 PDF 已复制到 `.agent/rules/`，场地/地形语义已整理到 `.agent/KNOWLEDGE.md`，后续应结合实际地图、点云和规则更新继续修正。

## 已知缺口

- 2026 规则语义目前是从本地 V1.4.2 PDF 梳理得到；若官方规则文件更新，需要重新核对。
- `pb2025_nav_bringup/map/reality/` 中已有 `rmul_2026_r.xcf`，但是否存在完整可运行的 2026 `.yaml/.pgm` 和对应 `.pcd` 需要在任务中实时确认。
- 飞坡、隧道、起伏路段、陡坡高地等地形建议继续沉淀为独立导航语义层或行为树动作，而不是只依赖二维占据栅格。
- 真机运行、RViz、TF、点云质量、增益点检测等仍需要结合容器和实车现场验证。

## 后续优先事项

- 将 2026 场地规则语义映射为可维护的地图/代价/禁区/增益点配置。
- 明确 `rmul_2026_r` 的栅格地图、先验 PCD、Nav2 `world` 参数和 launch 默认值之间的关系。
- 为飞坡、隧道、起伏路段建立专门通过策略或至少限速/高代价策略。
- 对 `terrain_analysis` 与 `IntensityVoxelLayer` 的参数做坡面、凸起、低矮障碍的实测标定。

## 当前实施任务：无先验建图模式下的静态语义地形层

目标：在 `slam:=True` 建图模式、每次启动位姿基本一致的前提下，用固定 `map` 坐标多边形表达堡垒、梯形高地等危险地形，使普通规划默认避开高代价区域，目标在堡垒/高地上时仍可到达，同时将 43°坡设为不可通行障碍，并向下位机发布当前地形状态用于限速保护。

### 任务拆分

- [x] 新增 `terrain_semantic_zones.yaml`，用 `map` frame 多边形描述固定危险区域；先提供可运行模板和清晰注释，实车坐标后续由 RViz 标定填充。
- [x] 在 `pb_nav2_plugins` 中实现 `SemanticPolygonLayer` costmap 插件：
  - [x] 读取 `terrain_semantic_zones.yaml`。
  - [x] 支持 `high_cost`、`lethal`、`slowdown` 等语义。
  - [x] 将高地/堡垒写成高但非致命代价。
  - [x] 将梯形高地 43°坡写成 `LETHAL_OBSTACLE`。
  - [x] 支持 global/local rolling costmap，默认全窗口更新，且在 frame 一致时可按区域 bounds 收敛更新范围。
- [x] 在 `pb_nav2_plugins` 中实现 `terrain_zone_monitor` 节点：
  - [x] 读取同一份区域 YAML。
  - [x] 通过 TF 查询机器人位置，结合圆形 footprint 采样判断所在区域。
  - [x] 发布 `/sentry_terrain_state` 给下位机或上层逻辑。
  - [x] 发布 RViz MarkerArray，用于检查语义区域是否与建图模式下的 `map` 坐标对齐。
- [x] 接入 `pb2025_nav_bringup`：
  - [x] 在 `nav2_params_mppi.yaml` 的 global/local costmap 加入 `terrain_semantic_layer`。
  - [x] 在实车 bringup 或 navigation launch 中可选启动 `terrain_zone_monitor`。
  - [x] 提供 launch 参数开关，避免影响不需要语义层的旧流程。
- [x] 验证：
  - [x] `colcon build --symlink-install --packages-select pb_nav2_plugins pb2025_nav_bringup`。
  - [x] 静态检查 YAML/launch 路径真实存在。
  - [x] 静态确认 43°坡使用 `lethal`，堡垒/高地使用 `high_cost`，避免目标在可达平台上时被 lethal 阻断。

### 注意事项

- 不修改 SLAM 生成的 `/map`；语义层作为额外 overlay 长期叠加。
- 由于没有先验地图，区域多边形坐标依赖启动位姿一致性；每次启动后必须用 RViz marker 检查对齐。
- 语义层只解决“规划偏好/可达性”，翻车保护仍需下位机或 `cmd_vel` limiter 使用 `/sentry_terrain_state` 限速、限加速度和限角速度。
- 本次实现不改动 `combat_sentry_behavior` 中已有未提交变更。
