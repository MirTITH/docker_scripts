if [[ -f ~/.local/common_rc ]]; then
    source ~/.local/common_rc
fi

if [ -f $HOME/.local/ros_rc ]; then
    source $HOME/.local/ros_rc
fi
