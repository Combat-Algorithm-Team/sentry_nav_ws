# Workspace Knowledge

本文件记录 `sentry_nav_ws` 的稳定项目知识、导航链路和 RoboMaster 2026 场地语义。若与当前源码、配置或官方规则文件冲突，以当前源码/配置/规则 PDF 为准。

## 工作区结构

- `combat_sentry_nav/`
  - Nav2、SLAM、点云、定位、bringup、地图、地形分析相关主仓库。
- `combat_sentry_behavior/combat_sentry_behavior/`
  - 哨兵行为树主包，包含 BT 插件、行为树 XML、launch、params、行为服务器与客户端。
- `combat_rm_interfaces/`
  - 自定义 ROS2 msg/srv/action 接口。
- `standard_robot_pp_ros2/`
  - 与 StandardRobot++ 下位机通信，发布控制、裁判系统和 TF 相关数据。

## 导航主链路

- 实车入口优先看 `combat_sentry_nav/pb2025_nav_bringup/launch/rm_navigation_reality_launch.py`。
- 通用 Nav2 bringup 入口看 `combat_sentry_nav/pb2025_nav_bringup/launch/bringup_launch.py` 和 `navigation_launch.py`。
- 实车参数优先看：
  - `combat_sentry_nav/pb2025_nav_bringup/config/reality/nav2_params_mppi.yaml`
  - `combat_sentry_nav/pb2025_nav_bringup/config/reality/nav2_params.yaml`
- 仿真参数看 `combat_sentry_nav/pb2025_nav_bringup/config/simulation/nav2_params.yaml`。
- 地图和 PCD 目录：
  - `combat_sentry_nav/pb2025_nav_bringup/map/reality/`
  - `combat_sentry_nav/pb2025_nav_bringup/map/simulation/`
  - `combat_sentry_nav/pb2025_nav_bringup/pcd/reality/`
  - `combat_sentry_nav/pb2025_nav_bringup/pcd/simulation/`

## 哨兵底盘特性

- 当前哨兵机器人是舵轮底盘，具备全向平动能力；Nav2/MPPI 配置应按全向底盘理解，而不是差速或 Ackermann 车辆。
- 全向能力不代表复杂地形可高速通过。堡垒、梯形高地、飞坡、起伏路段等区域应重点限制平动速度、角速度、加速度/减速度，尤其要约束下坡时的急转、横移和急刹。
- 判断坡面风险时不要只看机器人 yaw，应结合 odom 中真实速度方向和 footprint 与语义区域的相交关系。
- 固定危险地形优先用地图语义层长期表达，再由上位机规划/限速和下位机保护共同执行。

## 点云与地形分析

- `livox_ros_driver2` 发布 LiDAR 数据。
- `point_lio` 提供里程计和注册点云。
- `loam_interface` 将 Point-LIO 输出转成导航链路需要的 `registered_scan` 和 `lidar_odometry`。
- `terrain_analysis` 处理近场地形，发布 `terrain_map`。
- `terrain_analysis_ext` 处理更大范围地形，发布 `terrain_map_ext`。
- `terrain_map` 通常进入 local costmap，`terrain_map_ext` 通常进入 global costmap。
- `PointCloud2.intensity` 在地形分析输出中不是普通反射强度，而是障碍物相对局部地面的高度编码。
- `pb_nav2_costmap_2d::IntensityVoxelLayer` 读取点云的 z 与 intensity 区间，将障碍写入 Nav2 costmap。
- `pointcloud_to_laserscan` 在 SLAM 模式中把 `terrain_map_ext` 转成 `obstacle_scan`，用于 scan-based consumer；它不是 Nav2 3D 语义代价层的替代品。
- 坡面通过性强依赖 `useSorting`、`quantileZ`、`considerDrop`、`disRatioZ`、`vehicleHeight`、`min/max obstacle intensity` 等参数，调参时要结合实车点云验证。

## BehaviorTree 边界

- 哨兵自身行为树 XML 位于 `combat_sentry_behavior/combat_sentry_behavior/behavior_trees/`。
- Nav2 使用的行为树 XML 位于 `combat_sentry_nav/pb2025_nav_bringup/behavior_trees/`。
- 新增或修改 BT 插件时同步检查：
  - 源文件和头文件是否成对存在。
  - `CMakeLists.txt` 是否加入对应 library。
  - 是否加入 `plugin_libs`。
  - 是否带 `BT_PLUGIN_EXPORT`。
  - 是否通过 `CreateRosNodePlugin(...)` 注册。
  - `providedPorts()` 与 XML 使用保持一致。

## RoboMaster 2026 场地语义

规则来源：本工作区内文件 `.agent/rules/RoboMaster 2026 机甲大师超级对抗赛比赛规则手册V1.4.2（20260430）.pdf`。以下内容用于导航语义建模，不替代官方规则原文。

### 战场整体

- 战场约 28m x 15m，中心对称布局。
- 场地为木质结构，表面主要铺设 2mm PVC 地胶；地形跨越增益点较低处和起伏路段铺设 2mm PVC 夹线地胶。
- 部分结构有金属保护层，可能影响点云、视觉和定位。
- 战场外围为黑色钢制围挡，上边沿距离战场地面约 2.4m。
- 实际战场不是严格水平面，以战场中轴线为轴向长边两侧倾斜约 1°-2°。
- 部分木制结构与地面的交线可能存在约 50mm 开槽，用于弹丸回收；低矮开槽不应简单当成普通平面。

### 基地区

基地区包含：

- 启动区：基地周围六边形区域，地面机器人赛前放置区。
- 基地：攻防核心，位于启动区中央基地底座上，是静态障碍、战术目标和禁区边界。
- 飞镖发射站：飞镖系统唯一放置区，含主体、滑台和闸门；对地面机器人按静态障碍/禁入附近区域处理。
- 停机坪：空中机器人初始平台，关联停机坪禁区。
- 雷达基座：高平台结构，约 3.4m x 1.16m，高约 2.5m，四周约 1.1m 围栏；对视觉/雷达遮挡和静态地图有影响。
- 补给区：包括资源站、补给区增益点、无线充电装置放置区、飞镖传递窗口，是己方重要导航目标，对方相关区域需按规则禁入。
- 资源站：含能量单元，主要影响工程机器人，也可能形成动态/半动态障碍。
- 堡垒：关键防守区域，存在约 20° 坡；步兵/哨兵可占领堡垒增益点。

### 高地区

- 高地区高于战场地面，将战场分割成立体空间。
- 梯形高地：红蓝半场各 1 个，靠近停机坪，相对战场地面约 200-400mm，含约 43° 坡和 23° 坡。43° 对普通导航应视作高风险或不可通行，23° 也需实车验证。
- 中央高地：位于战场中部，两端通过坡道连接公路区，图示约 10.5° 坡，是关键跨区通道和增益区域。
- 装配区：位于能量机关下方，分红蓝双方，图示含约 14°、12°、45°、15° 坡。45° 通常应视为结构边界或不可通行。
- 能量机关：位于装配区正上方，主要影响视觉、射击和规则机制，不是地面可通行地形。
- 前哨站：靠近公路飞坡，带底座和装甲模块；是静态障碍、战术目标和增益点关联区域。

### 公路区

公路区包含公路、飞坡、隧道、起伏路段。

- 公路：图示存在约 11°、15° 坡，是主要跨区通道。
- 起伏路段：表面按间距排布凸起；对底盘震动、速度控制和地面估计影响大，宜建成高代价/限速可通行区域。
- 凸起：不应一概当作致命障碍，需要结合底盘能力和 `terrain_analysis` 输出判断。
- 飞坡：公路区 17° 坡，可飞跃沟壑快速抵达对方半场。建议作为专门行为/特殊通过动作处理，而不是普通 Nav2 低速路径段。
- 公路隧道：存在地形跨越增益点（隧道），交互卡面积显著小于其他增益区。通过时规则建议速度保持在 0.5m/s 以下以保证检测稳定。

### 飞行区与其它道具

- 飞行区包括停机坪及上方空域、与梯形高地连接的公路上方空域。
- 空中机器人连接安全绳，安全绳长度约 2.4m。对地面导航主要体现为停机坪禁区、坠落/回收风险和空间遮挡。
- 能量单元是可移动道具，约 400±50g，可抓取携带；掉落或被移动后应按动态障碍处理。
- 弹丸会受场地倾斜影响向长边两侧滚动；低矮散乱弹丸可能造成点云和底盘扰动。

### 增益点与禁区

- 场地增益点均铺设场地交互模块卡，可能存在死区和检测延迟。
- 地形跨越增益点类型包括：高地、公路、飞坡、隧道。
- 中央高地有 2 处地形跨越增益点（高地）。
- 双方公路区各有 2 处地形跨越增益点（公路）、2 处地形跨越增益点（飞坡）、6 处地形跨越增益点（隧道）。
- 地形跨越增益（公路/高地）要求先检测较低处，再检测较高处。
- 地形跨越增益（隧道）要求按顺序检测一端、中间、另一端。
- 触发时间窗口：公路 3s、隧道 3s、高地 5s、飞坡 10s。
- 禁区包括补给禁区、装配禁区、公路禁区、基地禁区、停机坪禁区。
- 公路禁区、基地禁区是双方禁区；补给禁区、装配禁区、停机坪禁区是单方禁区。
- 导航地图不能只建二维障碍，还应有语义层表达禁区、己方/对方区域、增益点、限速区和特殊动作区域。

## 建议的导航语义层

为 2026 场地做地图或策略时，优先拆成以下层：

- 静态障碍层：基地、前哨站、雷达基座、飞镖发射站、围挡、固定墙体。
- 坡度/通过代价层：10.5°、11°、12°、14°、15°、17°、20°、23°、43°、45°等坡面按底盘能力分级。
- 起伏/震动层：公路起伏路段和凸起，配置限速和更保守的局部规划。
- 禁区层：补给、装配、公路、基地、停机坪禁区，按红蓝方语义区分。
- 增益目标层：基地、中央高地、梯形高地、地形跨越、前哨站、装配区、补给区、堡垒增益点。
- 特殊行为层：飞坡、隧道、狭窄地形、跨坡触发增益点等不适合完全交给普通全局/局部规划器的区域。

## 固定危险地形的代价建模原则

- 堡垒、梯形高地等固定危险地形应作为长期静态语义层维护，不应依赖实时点云临时识别。
- 可通行但不希望普通路径经过的区域，用高但非致命代价表达，例如堡垒坡、梯形高地 23°坡、高地平台边缘过渡区。
- 绝对不允许通行的区域，用致命障碍表达，例如梯形高地 43°坡以及实车确认不可跨越的结构边界。
- 如果目标点可能设置在堡垒或高地上，目标所在平台和可达坡道不能设为 lethal，只能设为可通行高代价；否则全局规划器会认为目标不可达。
- 规划避让与目标可达的推荐结构是：静态障碍层表达不可走区域，语义代价层表达高风险但可走区域，速度限制/地形状态节点表达进入该区域后的慢速控制。
- 对舵轮底盘，下坡风险区最好同时限制线速度、横向速度、角速度、加速度和减速度；只改 costmap 代价不足以防止高速下坡翻车。

## 当前语义地形实现

- 区域配置文件：`combat_sentry_nav/pb2025_nav_bringup/config/reality/terrain_semantic_zones.yaml`。
- 代价层插件：`pb_nav2_costmap_2d::SemanticPolygonLayer`，位于 `combat_sentry_nav/pb_nav2_plugins`，已注册到 `costmap_plugins.xml`。
- 状态发布节点：`pb_nav2_plugins/terrain_zone_monitor`，实车 `rm_navigation_reality_launch.py` 默认通过 `use_terrain_zone_monitor:=True` 启动。
- `nav2_params_mppi.yaml` 和 `nav2_params.yaml` 的 global/local costmap 均已加入 `terrain_semantic_layer`，顺序为 `static_layer -> terrain_semantic_layer -> intensity_voxel_layer -> inflation_layer`。
- `terrain_semantic_zones.yaml` 中 `high_cost` 表示可通行但高代价，`slowdown` 表示可通行限速状态，`lethal` 表示不可通行障碍。
- 狭窄交线/边线不建议手写成大块 polygon，可用 `line` 或 `segments` + `line_width` 表达，解析器会自动膨胀成窄条高代价区。堡垒六个斜坡交线建议使用 `type: high_cost`、`cost: 220-240`、`line_width: 0.20-0.35`，让规划器尽量走坡面正中间。
- 43°坡应配置为 `type: lethal`、`cost: 254`、`state_id: 255`；堡垒/高地平台或可达坡道应配置为 `type: high_cost`，不能配置为 lethal。
- `terrain_zone_monitor` 通过 TF 查询机器人在语义区域 frame 下的位置，并用圆形 footprint 采样判断是否进入区域。
- 默认发布：
  - `/sentry_terrain_state`：`std_msgs/msg/UInt8`，0 正常，1 高代价地形，2 限速地形，255 禁行/危险地形。
  - `/sentry_terrain_zone_name`：`std_msgs/msg/String`，当前命中的区域名，正常为 `normal`。
  - `/sentry_terrain_speed_limit`：`std_msgs/msg/Float32`，当前区域建议速度上限，-1 表示无语义限速。
  - `/terrain_semantic_markers`：`visualization_msgs/msg/MarkerArray`，用于 RViz 检查多边形与 SLAM map 是否对齐。
- 在无先验建图模式中，语义多边形坐标依赖每次启动位姿一致；启动后必须先检查 `/terrain_semantic_markers` 是否贴合实际堡垒/高地，再允许下位机使用状态限速。
