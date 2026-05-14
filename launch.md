# Nav 启动命令

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

## 常用构建

```bash
colcon build --symlink-install --packages-select pb2025_nav_bringup
source install/setup.bash
```

纯 launch、YAML、地图改动在 symlink install 下通常重启 launch 即可。

## 启动下位机串口

```bash
ros2 launch standard_robot_pp_ros2 standard_robot_pp_ros2.launch.py
```

## 启动 Odin1

```bash
ros2 launch pb2025_nav_bringup odin1_ros2.launch.py
```

## 启动实车导航

```bash
ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py
```

当前默认 `world:=rmuc2026`，但 UC 2026 地图尚未建立。

## 启动 RMUL 2026 地图导航

```bash
ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py \
  world:=rmul2026 \
  slam:=False
```

## 指定地图导航

```bash
ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py \
  world:=<地图名> \
  slam:=False
```

`world:=<地图名>` 会查找 `pb2025_nav_bringup/map/reality/<地图名>.yaml`。

## Odin 重定位未定上时启用静态 map -> odom 兜底

```bash
ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py \
  publish_static_map_to_odom_tf:=True
```

Odin 正常重定位时不要开启这个开关，避免重复发布同一条 `map -> odom`。

## 建图模式

```bash
ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py \
  slam:=True \
  use_robot_state_pub:=True
```

## 不开 RViz

```bash
ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py \
  use_rviz:=False
```

## 点云去畸变 / 融合链路单独测试

```bash
ros2 launch pb2025_nav_bringup point_cloud_deskew_launch.py
```

## 语义地形层单独测试

```bash
ros2 launch pb2025_nav_bringup semantic_terrain_layer_test_launch.py
```
