# Nav 启动命令

## 进入容器

```bash
docker start -ai Combat_Sentry2026
docker exec -it Combat_Sentry2026 bash
```

```bash
source /opt/ros/humble/setup.bash
cd /root/Combat_Sentry2026/sentry_nav_ws
source install/setup.bash
```

## 启动串口

```bash
ros2 launch standard_robot_pp_ros2 standard_robot_pp_ros2.launch.py
```

## 启动 Odin1

```bash
ros2 launch pb2025_nav_bringup odin1_ros2.launch.py
```

## 启动导航

```bash
ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py
```

## 指定地图导航

```bash
ros2 launch pb2025_nav_bringup rm_navigation_reality_launch.py \
  world:=<地图名> \
  slam:=False
```

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


colcon build --symlink-install
source install/setup.bash
