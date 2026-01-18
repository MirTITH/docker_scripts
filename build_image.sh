#!/bin/bash
set -euo pipefail

script_path=$(readlink -f "$0")      # 脚本文件的绝对路径
script_dir=$(dirname "$script_path") # 脚本文件的目录
dockerfile_path=$script_dir/docker_files/ros.dockerfile

UBUNTU_VERSION=""
DOCKER_IMAGE_NAME=""


# Docker 构建参数
DOCKER_ARG_ROS_TARGET="ros2"
DOCKER_ARG_LOCALE="C.UTF-8"
DOCKER_ARG_TZ=""       # 如果为空则自动检测
DOCKER_ARG_USERNAME="" # 如果为空则自动检测
DOCKER_ARG_UID=""      # 如果为空则自动检测
DOCKER_ARG_GID=""      # 如果为空则自动检测

# 镜像源
# DOCKER_ARG_UBUNTU_MIRROR="http://mirrors.osa.moe/ubuntu"
# DOCKER_ARG_ROS2_MIRROR_URL="http://mirrors.osa.moe/ros2/ubuntu"
DOCKER_ARG_UBUNTU_MIRROR="http://mirrors.ustc.edu.cn/ubuntu"
DOCKER_ARG_ROS2_MIRROR_URL="http://mirrors.ustc.edu.cn/ros2/ubuntu"
DOCKER_ARG_ROS1_MIRROR_URL="http://mirrors.ustc.edu.cn/ros/ubuntu"

print_usage() {
    echo "用法: $0 <ubuntu_version> <docker_image_name> [选项]"
    echo ""
    echo "位置参数:"
    echo "  ubuntu_version         Ubuntu 版本 (例如: 20.04, 22.04, 24.04)"
    echo "  docker_image_name      要构建的 Docker 镜像名称"
    echo ""
    echo "选项:"
    echo "  --ros-target ROS_TARGET        设置 ros 构建目标 (默认: ${DOCKER_ARG_ROS_TARGET})"
    echo "  --locale LOCALE                设置语言环境 (默认: ${DOCKER_ARG_LOCALE})"
    echo "  --timezone TIMEZONE            设置时区 (默认: 自动检测, 例如: Asia/Shanghai)"
    echo "  --username USERNAME            设置用户名 (默认: 当前用户)"
    echo "  --uid UID                      设置用户 ID (默认: 当前用户的 UID)"
    echo "  --gid GID                      设置组 ID (默认: 当前用户的 GID)"
    echo "  --ubuntu-mirror URL            设置 Ubuntu 镜像源 URL (默认: ${DOCKER_ARG_UBUNTU_MIRROR})"
    echo "  --ros2-mirror URL              设置 ROS2 镜像源 URL (默认: ${DOCKER_ARG_ROS2_MIRROR_URL})"
    echo "  --ros1-mirror URL              设置 ROS1 镜像源 URL (仅当构建 ROS1 目标时有效)"
    echo "  --help, -h                     显示此帮助信息并退出"
    echo ""
    echo "示例:"
    echo "  $0 22.04 my-ros2-image --locale zh_CN.UTF-8"
}

get_timezone() {
    local tz=""

    # 优先尝试 timedatectl (现代 systemd 系统)
    if command -v timedatectl >/dev/null 2>&1; then
        tz=$(timedatectl | grep "Time zone" | awk '{print $3}')
    fi

    # 如果 timedatectl 失败或不存在，尝试读取 /etc/timezone (Debian/Ubuntu)
    if [ -z "$tz" ] && [ -f /etc/timezone ]; then
        tz=$(cat /etc/timezone)
    fi

    # 最后手段：解析 /etc/localtime 符号链接 (通用方法)
    if [ -z "$tz" ] && [ -L /etc/localtime ]; then
        # 将路径中 /usr/share/zoneinfo/ 之后的部分提取出来
        tz=$(readlink /etc/localtime | sed 's#.*/zoneinfo/##')
    fi

    # 如果仍然无法确定时区，则报错
    if [ -z "$tz" ]; then
        echo "Error: 无法检测系统时区，请手动指定 --timezone 参数"
        exit 1
    fi

    echo "$tz"
}

get_ros2_version() {
    local ros_version=""
    local ubuntu_version="$1"
    case "$ubuntu_version" in
    "20.04")
        ros_version="foxy"
        ;;
    "22.04")
        ros_version="humble"
        ;;
    "24.04")
        ros_version="jazzy"
        ;;
    *)
        echo "Error: 不支持的 Ubuntu 版本: $ubuntu_version"
        exit 1
        ;;
    esac
    echo "$ros_version"
}

get_ros1_version() {
    local ros_version=""
    local ubuntu_version="$1"
    case "$ubuntu_version" in
    "18.04")
        ros_version="melodic"
        ;;
    "20.04")
        ros_version="noetic"
        ;;
    *)
        echo "Error: 不支持的 Ubuntu 版本: $ubuntu_version"
        exit 1
        ;;
    esac
    echo "$ros_version"
}

positional_arg_count=0

while [[ $# -gt 0 ]]; do
    case "$1" in
    --ros-target)
        DOCKER_ARG_ROS_TARGET="$2"
        shift 2
        ;;
    --locale)
        DOCKER_ARG_LOCALE="$2"
        shift 2
        ;;
    --timezone)
        DOCKER_ARG_TZ="$2"
        shift 2
        ;;
    --username)
        DOCKER_ARG_USERNAME="$2"
        shift 2
        ;;
    --uid)
        DOCKER_ARG_UID="$2"
        shift 2
        ;;
    --gid)
        DOCKER_ARG_GID="$2"
        shift 2
        ;;
    --ubuntu-mirror)
        DOCKER_ARG_UBUNTU_MIRROR="$2"
        shift 2
        ;;
    --ros2-mirror)
        DOCKER_ARG_ROS2_MIRROR_URL="$2"
        shift 2
        ;;
    --ros1-mirror)
        DOCKER_ARG_ROS1_MIRROR_URL="$2"
        shift 2
        ;;
    --help | -h)
        print_usage
        exit 0
        ;;
    -*)
        echo "未知选项: $1"
        print_usage
        exit 1
        ;;
    *)
        case $positional_arg_count in
        0)
            UBUNTU_VERSION="$1"
            ;;
        1)
            DOCKER_IMAGE_NAME="$1"
            ;;
        *)
            echo "Error: 多余的位置参数: $1"
            print_usage
            exit 1
            ;;
        esac
        positional_arg_count=$((positional_arg_count + 1))
        shift
        ;;
    esac
done

# 验证必须的参数
if [ -z "$UBUNTU_VERSION" ] || [ -z "$DOCKER_IMAGE_NAME" ]; then
    echo "Error: 缺少必须的参数"
    print_usage
    exit 1
fi

# 如果未设置 TIMEZONE，则尝试自动检测
if [ -z "$DOCKER_ARG_TZ" ]; then
    DOCKER_ARG_TZ=$(get_timezone)
    echo "检测到的时区: $DOCKER_ARG_TZ"
fi

# 如果未设置 USERNAME，则使用当前用户
if [ -z "$DOCKER_ARG_USERNAME" ]; then
    DOCKER_ARG_USERNAME=$(whoami)
    echo "使用当前用户名: $DOCKER_ARG_USERNAME"
fi

# 如果未设置 UID，则使用当前用户的 DOCKER_ARG_UID
if [ -z "$DOCKER_ARG_UID" ]; then
    DOCKER_ARG_UID=$(id -u "$DOCKER_ARG_USERNAME")
    echo "使用当前用户的 uid: $DOCKER_ARG_UID"
fi

# 如果未设置 GID，则使用当前用户的 DOCKER_ARG_GID
if [ -z "$DOCKER_ARG_GID" ]; then
    DOCKER_ARG_GID=$(id -g "$DOCKER_ARG_USERNAME")
    echo "使用当前用户的 gid: $DOCKER_ARG_GID"
fi

DOCKER_BUILD_EXTRA_ARGS=()

case "${DOCKER_ARG_ROS_TARGET}" in
"ros2")
    ROS2_VERSION=$(get_ros2_version "$UBUNTU_VERSION")
    DOCKER_BUILD_EXTRA_ARGS+=(
        --build-arg "ROS_TARGET=${DOCKER_ARG_ROS_TARGET}"
        --build-arg "ROS2_VERSION=${ROS2_VERSION}"
        --build-arg "ROS2_MIRROR_URL=${DOCKER_ARG_ROS2_MIRROR_URL}"
    )
    ;;
"ros1")
    ROS1_VERSION=$(get_ros1_version "$UBUNTU_VERSION")
    DOCKER_BUILD_EXTRA_ARGS+=(
        --build-arg "ROS_TARGET=${DOCKER_ARG_ROS_TARGET}"
        --build-arg "ROS1_VERSION=${ROS1_VERSION}"
        --build-arg "ROS1_MIRROR_URL=${DOCKER_ARG_ROS1_MIRROR_URL}"
    )
    ;;
*)
    echo "Error: 不支持的 TARGET: ${DOCKER_ARG_ROS_TARGET}"
    exit 1
    ;;
esac

# Build the image
DOCKER_ARGS=(
    build -f "$dockerfile_path" -t "$DOCKER_IMAGE_NAME" "$script_dir"
    --target final
    --build-arg "BASE_IMAGE=ubuntu:${UBUNTU_VERSION}"
    --build-arg "UBUNTU_MIRROR=${DOCKER_ARG_UBUNTU_MIRROR}"
    --build-arg "LOCALE=${DOCKER_ARG_LOCALE}"
    --build-arg "TZ=${DOCKER_ARG_TZ}"
    --build-arg "USERNAME=${DOCKER_ARG_USERNAME}"
    --build-arg "UID=${DOCKER_ARG_UID}"
    --build-arg "GID=${DOCKER_ARG_GID}"
    "${DOCKER_BUILD_EXTRA_ARGS[@]}"
    # --no-cache
    # --build-arg "http_proxy=http://localhost:7890"
    # --build-arg "https_proxy=http://localhost:7890"
    # --build-arg "all_proxy=socks5://localhost:7890"
    # --network host
)

# echo "即将执行以下 docker 命令构建镜像:"
# echo "docker ${DOCKER_ARGS[@]}"
# read -p "按回车键继续，或按 Ctrl+C 取消..."

docker "${DOCKER_ARGS[@]}"
