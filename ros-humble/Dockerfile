FROM osrf/ros:humble-desktop-full

ARG DOCKER_FILE_FOLDER

# Create a non-root user
ARG USERNAME=docker_user
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Change Ubuntu source list
COPY mirrors/ubuntu_22.04_ustc.list /etc/apt/sources.list
# COPY mirrors/ubuntu_22.04_tuna.list /etc/apt/sources.list
# COPY mirrors/ubuntu_22.04_osa.list /etc/apt/sources.list


# Change ROS 2 source list
# ARG ROS2_MIRROR_URL=https://mirrors.tuna.tsinghua.edu.cn/ros2/ubuntu
ARG ROS2_MIRROR_URL=https://mirrors.ustc.edu.cn/ros2/ubuntu
# ARG ROS2_MIRROR_URL=https://mirrors.osa.moe/ros2/ubuntu

RUN rm /etc/apt/sources.list.d/ros2-latest.list
RUN apt-get update && apt-get install -y curl gnupg2 \ 
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] $ROS2_MIRROR_URL $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null
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

# Install some dependencies packages
RUN sudo apt-get update && sudo apt-get upgrade -y \
    && sudo apt-get install -y \
    git net-tools vim bash-completion psmisc pulseaudio gdb \
    iputils-ping zsh breeze qt5ct fonts-noto-cjk wget \
    python3-colcon-common-extensions python3-colcon-mixin software-properties-common python3-pip

# Install Gazebo
RUN sudo apt-get update && sudo apt-get install -y ros-humble-gazebo-ros-pkgs

# Get rid of EasyInstallDeprecationWarning. 
# (This warning seems to have been fixed.)
# RUN pip install setuptools==58.2.0

RUN colcon mixin add default https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml && colcon mixin update default

# Add user to video group to allow access to webcam
RUN sudo usermod --append --groups video $USERNAME

RUN rosdep update

# zsh
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k \
    && git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

COPY --chown=$USERNAME:$USERNAME $DOCKER_FILE_FOLDER/.zshrc /home/$USERNAME/
COPY --chown=$USERNAME:$USERNAME $DOCKER_FILE_FOLDER/.bash_aliases /home/$USERNAME/
COPY --chown=$USERNAME:$USERNAME common_files/.p10k.zsh /home/$USERNAME/

RUN git config --global core.quotepath false

# Create some directories to avoid permission issues
# For example, when creating container with `-v /path/to/host_file:/home/$USERNAME/.config/file`,
# the `.config` directory will be created with root permission, and the user will not be able to write to it.
RUN mkdir -p /home/$USERNAME/.config
RUN mkdir -p /home/$USERNAME/.local

ENTRYPOINT []
CMD ["/bin/zsh"]