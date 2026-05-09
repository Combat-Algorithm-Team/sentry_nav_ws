# AGENTS.md

This file gives coding agents workspace-specific guidance for `sentry_nav_ws`.

**最高优先级指令**
`AGENTS.md` 只定义稳定规则与信息入口。可变的项目知识、比赛场地语义、构建命令、排障经验统一维护在 `.agent/`、源码、README、launch、YAML、package.xml 和 CMakeLists.txt 中。

---

## 阶段一：握手与加载 (Pre-task)

在处理 `sentry_nav_ws` 内任何开发、排障、重构、规则分析或导航调参任务前，优先按以下顺序获取上下文：

1. `cat .agent/TODO.md`
   了解当前工作区状态、待办项、已知缺口和最近同步状态。
2. `cat .agent/DEVELOPMENT.md`
   加载 Ubuntu 22.04 / ROS 2 Humble 运行环境、构建方式、命名约束、验证方式和容器路径约定。
3. 按需读取 `.agent/KNOWLEDGE.md`
   当任务涉及 Nav2、SLAM、点云地形分析、BehaviorTree、裁判系统接口、RoboMaster 2026 场地/地形/增益/禁区语义时使用。
4. 按需读取 `.agent/TROUBLESHOOTING.md`
   当任务涉及 colcon 编译失败、Humble API 差异、时间源错误、TF/QoS/message filter、地图/PCD、容器路径或传感器联调问题时使用。
5. 以当前仓库事实校验文档
   启动流程看 `launch.md` 与各包 `launch/`，参数看 `config/**/*.yaml`，构建依赖看 `package.xml` / `CMakeLists.txt`，实现细节看对应源码和 README。

## 阶段二：执行约束 (Execution)

- 默认与用户使用中文交流，除非用户明确要求英文。
- 运行环境按 `Ubuntu 22.04 + ROS 2 Humble` 处理；不要默认在 macOS 原生环境运行 ROS。
- 用户主机是 Apple Silicon MacBook，常见真实执行路径是 Docker 容器；涉及二进制、ABI、设备、OpenVINO、libusb、驱动或镜像时要注意 `arm64` / `aarch64`。
- 默认容器名为 `Combat_Sentry2026`，默认镜像族为 `combat_sentry2026`；不要擅自改名。
- 保留用户和仓库现有命名，不要擅自“规范化”包名、topic、frame、节点、类、函数、文件、容器或镜像名。
- 做改动前先定位落在哪个 ROS 包或子仓库；优先按包小改、按包增量编译。
- `sentry_nav_ws` 下存在多个嵌套 git 仓库；执行 git 操作前必须确认真实 git root。
- 除任务明确要求外，不要修改外部/vendor 项目或相邻工作区，例如 `BehaviorTree.CPP`、`small_gicp`、`sp_vision_25`、`groot2_web`。
- 不凭记忆猜测 launch 参数、YAML 路径、topic、frame、行为树 XML 或地图文件名；必须回到当前文件核实。
- 当 `.agent/` 文档与源码/配置不一致时，以当前源码和配置为准，再决定是否同步 `.agent/`。
- 读取遵循最小充分原则：先加载必要入口，再按任务扩展，避免无关上下文污染。

## 阶段三：收尾与状态同步 (Post-task)

完成任务后，检查是否需要同步 `.agent/`：

1. 进度、缺口、待验证项变化，更新 `.agent/TODO.md`。
2. 构建、运行、调试或验证流程变化，更新 `.agent/DEVELOPMENT.md`。
3. 形成稳定架构知识、场地语义、规则理解或导航策略，更新 `.agent/KNOWLEDGE.md`。
4. 沉淀新的报错特征或解决办法，更新 `.agent/TROUBLESHOOTING.md`。

除以上入口与路由说明外，不要继续扩写本文件。
