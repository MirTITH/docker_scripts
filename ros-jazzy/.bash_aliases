if [ -f $HOME/.local/common_rc ]; then
    source $HOME/.local/common_rc
fi

rr() {
    # For bash, ros-jazzy
    source /opt/ros/jazzy/setup.bash
    source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash
    source /usr/share/colcon_cd/function/colcon_cd.sh
    export _colcon_cd_root=/opt/ros/jazzy/
}

rr
