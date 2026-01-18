#!/bin/bash
set -euo pipefail

script_path=$(readlink -f "$0")      # 脚本文件的绝对路径
script_dir=$(dirname "$script_path") # 脚本文件的目录
build_image_sh="$script_dir/build_image.sh"

UBUNTU_MIRROR="http://mirrors.osa.moe/ubuntu"
ROS1_MIRROR_URL="http://mirrors.osa.moe/ros/ubuntu"
ROS2_MIRROR_URL="http://mirrors.osa.moe/ros2/ubuntu"

echo "-------------------------------------"
echo "正在构建 20.04 + ROS1 Noetic 镜像..."
"$build_image_sh" 20.04 ros1-noetic --ros-target ros1 --ubuntu-mirror "$UBUNTU_MIRROR" --ros1-mirror "$ROS1_MIRROR_URL" --ros2-mirror "$ROS2_MIRROR_URL"

echo "-------------------------------------"
echo "正在构建 18.04 + ROS1 Melodic 镜像..."
"$build_image_sh" 18.04 ros1-melodic --ros-target ros1 --ubuntu-mirror "$UBUNTU_MIRROR" --ros1-mirror "$ROS1_MIRROR_URL" --ros2-mirror "$ROS2_MIRROR_URL"

# echo "-------------------------------------"
# echo "正在构建 20.04 + ROS2 Foxy 镜像..."
# "$build_image_sh" 20.04 ros2-foxy --ubuntu-mirror "$UBUNTU_MIRROR" --ros1-mirror "$ROS1_MIRROR_URL" --ros2-mirror "$ROS2_MIRROR_URL"

echo "-------------------------------------"
echo "正在构建 22.04 + ROS2 Humble 镜像..."
"$build_image_sh" 22.04 ros2-humble --ubuntu-mirror "$UBUNTU_MIRROR" --ros1-mirror "$ROS1_MIRROR_URL" --ros2-mirror "$ROS2_MIRROR_URL"

echo "-------------------------------------"
echo "正在构建 24.04 + ROS2 Jazzy 镜像..."
"$build_image_sh" 24.04 ros2-jazzy --ubuntu-mirror "$UBUNTU_MIRROR" --ros1-mirror "$ROS1_MIRROR_URL" --ros2-mirror "$ROS2_MIRROR_URL"
