ARG BASE_IMAGE=ubuntu:22.04

FROM ${BASE_IMAGE} AS base

# Avoid interactive prompts during package installation
ARG DEBIAN_FRONTEND=noninteractive

# 删除默认的 ubuntu 用户（目前发现 ubuntu 24.04 镜像中存在该用户，22.04 及更早版本不存在）
RUN userdel -r ubuntu 2>/dev/null || true

# Ubuntu 换源
# 配置语言和时区
# 安装基础工具
ARG UBUNTU_MIRROR=http://mirrors.ustc.edu.cn/ubuntu
ARG LOCALE=en_US.UTF-8
ENV LANG=${LOCALE}
ENV LC_ALL=${LOCALE}
ENV TZ=Asia/Shanghai
COPY docker_files/nros-change-mirror /tmp/
RUN /tmp/nros-change-mirror ${UBUNTU_MIRROR} --no-update && rm /tmp/nros-change-mirror \
  \
  && apt-get update && apt-get install -y tzdata locales \
  && sed -i "s/# ${LOCALE}/${LOCALE}/g" /etc/locale.gen \
  && locale-gen && update-locale LC_ALL=${LOCALE} LANG=${LOCALE} \
  && ln -fs /usr/share/zoneinfo/$TZ /etc/localtime \
  && echo $TZ > /etc/timezone \
  && dpkg-reconfigure --frontend noninteractive tzdata \
  \
  && apt-get install -y \
  sudo vim curl wget git bash-completion psmisc pulseaudio build-essential cmake \
  pkg-config ninja-build gdb strace ltrace python3 python3-pip python3-venv \
  net-tools iproute2 iputils-ping openssh-client ca-certificates unzip zip \
  tar bzip2 xz-utils p7zip-full htop procps rsync software-properties-common \
  fonts-noto-cjk tree nano zsh breeze qt5ct \
  && rm -rf /var/lib/apt/lists/*

# 使用 sudo 时保留代理环境变量
# 参考 https://wiki.archlinux.org/title/Proxy_server#Keep_proxy_through_sudo
COPY docker_files/nros-add-sudo-proxy /tmp/
RUN bash /tmp/nros-add-sudo-proxy && rm /tmp/nros-add-sudo-proxy

# 创建非root用户
ARG USERNAME=ubuntu
ARG UID=1000
ARG GID=1000
RUN groupadd --gid ${GID} $USERNAME \
  && useradd -m -s /bin/bash --uid ${UID} --gid ${GID} ${USERNAME} \
  && echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} \
  && chmod 0440 /etc/sudoers.d/${USERNAME}
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Create some directories to avoid permission issues
# For example, when creating container with `-v /path/to/host_file:/home/$USERNAME/.config/file`,
# the `.config` directory will be created with root permission, and the user will not be able to write to it.
RUN mkdir -p /home/$USERNAME/.config \
  && mkdir -p /home/$USERNAME/.local/share \
  && mkdir -p /home/$USERNAME/.local/bin \
  && mkdir -p /home/$USERNAME/.cache

ENTRYPOINT []
CMD ["/bin/zsh"]


#-------------------------------------------------------------
# ROS 2
#-------------------------------------------------------------
FROM base AS ros2

# Avoid interactive prompts during package installation
ARG DEBIAN_FRONTEND=noninteractive

ARG ROS2_VERSION=humble
ARG ROS2_MIRROR_URL=https://mirrors.ustc.edu.cn/ros2/ubuntu
ARG INSTALL_GAZEBO=false
ARG INSTALL_COLCON_MIXIN=true
ARG ROSDEP_UPDATE=true
COPY docker_files/nros-install-ros2 /tmp/
RUN bash /tmp/nros-install-ros2 \
  --ros2-version ${ROS2_VERSION} \
  --mirror ${ROS2_MIRROR_URL} \
  --install-gazebo ${INSTALL_GAZEBO} \
  --install-colcon-mixin ${INSTALL_COLCON_MIXIN} \
  --rosdep-update ${ROSDEP_UPDATE} \ 
  && sudo rm /tmp/nros-install-ros2

# 防止 git 输出中文路径时出现乱码
# Remove docker-clean to enable auto-completion for apt
RUN git config --global core.quotepath false \
  && sudo rm /etc/apt/apt.conf.d/docker-clean || true

# 添加 ros2_rc 实用脚本
COPY docker_files/ros2_rc/${ROS2_VERSION} /home/${USERNAME}/.local/ros2_rc

#-------------------------------------------------------------
# ROS 1
#-------------------------------------------------------------
FROM base AS ros1

# Avoid interactive prompts during package installation
ARG DEBIAN_FRONTEND=noninteractive

ARG ROS1_VERSION=noetic
ARG ROS1_MIRROR_URL=https://mirrors.ustc.edu.cn/ros/ubuntu
COPY docker_files/nros-install-ros1 /tmp/
RUN bash /tmp/nros-install-ros1 \
  --ros1-version ${ROS1_VERSION} \
  --mirror ${ROS1_MIRROR_URL} \
  --install-gazebo ${INSTALL_GAZEBO} \
  --rosdep-update ${ROSDEP_UPDATE} \ 
  && sudo rm /tmp/nros-install-ros1

# 防止 git 输出中文路径时出现乱码
# Remove docker-clean to enable auto-completion for apt
RUN git config --global core.quotepath false \
  && sudo rm /etc/apt/apt.conf.d/docker-clean || true
