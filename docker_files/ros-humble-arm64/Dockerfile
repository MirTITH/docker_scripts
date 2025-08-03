FROM ubuntu:22.04

# Create a non-root user
ARG USERNAME=ubuntu
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Update ca-certificates to avoid "Certificate verification failed" error
RUN apt-get update && apt-get install -y ca-certificates

# Change Ubuntu source list
COPY mirrors/ubuntu_20.04_tuna_ports.list /etc/apt/sources.list
# COPY mirrors/ubuntu_22.04_osa_ports.list /etc/apt/sources.list

# 设置时区环境变量
ENV TZ=Asia/Shanghai

# 安装 tzdata 并设置时区
RUN apt-get update && apt-get install -y tzdata && \
    ln -fs /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata


# Change ROS 2 source list
# ROS 2 在 2025 年 6 月左右更换了软件源的签名，并改用 ros2-apt-source.deb 来配置源。
# ros2-apt-source.deb 会创建 /etc/apt/sources.list.d/ros2.sources 文件，并在自身更新时自动更新软件源的配置，但默认情况下会使用官方源。
# 如需使用镜像源，需要删除 ros2-apt-source.deb 包，并手动添加 ROS 2 的软件源。（测试过直接修改 /etc/apt/sources.list.d/ros2.sources 文件中的 URL会报错(2025-06-07)。可能镜像站暂不支持这种格式）
ARG ROS2_MIRROR_URL=https://mirrors.ustc.edu.cn/ros2/ubuntu
# ARG ROS2_MIRROR_URL=https://mirrors.tuna.tsinghua.edu.cn/ros2/ubuntu
# ARG ROS2_MIRROR_URL=https://mirrors.osa.moe/ros2/ubuntu

# If ROS2_MIRROR_URL is set, replace the ROS 2 source URL
RUN if [ -n "$ROS2_MIRROR_URL" ]; then \
    apt purge -y ros2-apt-source; \
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] $ROS2_MIRROR_URL $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null; \
    fi

# Remove docker-clean to enable auto-completion for apt
RUN rm /etc/apt/apt.conf.d/docker-clean

# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

# Install ROS2
RUN sudo apt-get update && sudo apt-get install -y locales \
    && sudo locale-gen en_US en_US.UTF-8 \
    && sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
RUN sudo apt-get update && sudo apt-get install -y software-properties-common \
    && sudo add-apt-repository universe -y \
    && sudo apt-get upgrade -y \
    && sudo apt-get install -y ros-humble-desktop ros-dev-tools

# Install dependencies
RUN sudo apt-get update && sudo apt-get upgrade -y \
    && sudo apt-get install -y \
    git net-tools vim bash-completion psmisc pulseaudio gdb \
    iputils-ping zsh breeze qt5ct fonts-noto-cjk wget \
    python3-colcon-common-extensions python3-colcon-mixin software-properties-common python3-pip

# Install Gazebo (Arm64 doesn't have this package)
# RUN sudo apt-get update && sudo apt-get install -y ros-humble-gazebo-ros-pkgs

# Get rid of EasyInstallDeprecationWarning. 
# (This warning seems to have been fixed.)
# RUN pip install setuptools==58.2.0

RUN colcon mixin add default https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml && colcon mixin update default

# Add user to video group to allow access to webcam
RUN sudo usermod --append --groups video $USERNAME

RUN sudo rosdep init && rosdep update

# zsh
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k \
    && git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

COPY --chown=$USERNAME:$USERNAME copy_files/.zshrc /home/$USERNAME/
COPY --chown=$USERNAME:$USERNAME copy_files/.bash_aliases /home/$USERNAME/
COPY --chown=$USERNAME:$USERNAME copy_files/.p10k.zsh /home/$USERNAME/

RUN git config --global core.quotepath false

# Create some directories to avoid permission issues
# For example, when creating container with `-v /path/to/host_file:/home/$USERNAME/.config/file`,
# the `.config` directory will be created with root permission, and the user will not be able to write to it.
RUN mkdir -p /home/$USERNAME/.config
RUN mkdir -p /home/$USERNAME/.local
COPY --chown=$USERNAME:$USERNAME copy_files/ros_rc/humble /home/$USERNAME/.local/ros_rc

ENTRYPOINT []
CMD ["/bin/zsh"]