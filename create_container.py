#!/usr/bin/python3

import os
import sys
import subprocess
import argparse
from typing import List, Optional

# 定义颜色代码
RED = "\033[31m"
GREEN = "\033[32m"
BLUE = "\033[34m"
YELLOW = "\033[33m"
YELLOW_BACKGROUND = "\033[43m"
BOLD = "\033[1m"
RESET = "\033[0m"  # 重置为默认样式


def ask_user_to_continue(prompt: str = "Continue?") -> bool:
    """Ask the user if they want to continue

    Returns:
        bool: True if the user wants to continue
    """

    print(prompt + " [Y/n] ", end="")
    return input().lower() in ["y", ""]


def format_cmd(cmd: List[str]):
    result = ""
    for arg in cmd:
        if arg.startswith("-"):
            result += f"\n    {arg}"
        else:
            result += f" {arg}"
    return result


class DockerCmdGenerator:
    def __init__(self, args):
        self.image_name: str = getattr(args, "image-name")
        self.container_name: str = getattr(args, "container-name")
        self.container_user_name: str = getattr(args, "user_name")
        # self.user_data_dir: str = self.__get_arg_abs_path(getattr(args, "user_data", None), path_type="dir", create_if_not_exist=True)
        self.no_nv: bool = getattr(args, "no_nv", False)

        self.rc_file: Optional[str] = self.__get_arg_abs_path(getattr(args, "rc_file", None), path_type="file", create_if_not_exist=True)

        self.volumes: List[str] = getattr(args, "volume")
        if not self.volumes:
            self.volumes = []

        self.clangd_path: Optional[str] = self.__get_arg_abs_path(getattr(args, "clangd_path", None), path_type="dir", create_if_not_exist=False)

        self.dotfiles_path: Optional[str] = self.__get_arg_abs_path(getattr(args, "dotfiles", None), path_type="dir", create_if_not_exist=False)

        # Resolve default user from image when --user-name is empty
        self.use_image_default_user = False
        if not self.container_user_name:
            self.container_user_name = self.__get_image_default_user(self.image_name)
            self.use_image_default_user = True

        # -d: Run the container in the background
        # --name: Name of the container
        # --user: User to run the container as (omit to use image default)
        if self.use_image_default_user:
            self.cmd_prefix = ["docker", "run", "-d", "--name", self.container_name]
        else:
            self.cmd_prefix = ["docker", "run", "-d", "--name", self.container_name, "--user", self.container_user_name]
        self.cmd_postfix = [self.image_name, "sleep", "infinity"]

        no_privileged = getattr(args, "no_privileged", False)
        self.privileged = not no_privileged

        print(f"Image name: {BLUE}{self.image_name}{RESET}")
        print(f"Container name: {BLUE}{self.container_name}{RESET}")
        print(f"Container user name: {BLUE}{self.container_user_name}{RESET}")
        # print(f"User data directory: {BLUE}{self.user_data_dir}{RESET}")
        print(f"Do not enable NVIDIA GPU: {BLUE}{self.no_nv}{RESET}")
        print(f"RC file: {BLUE}{self.rc_file}{RESET}")
        print(f"Volumes: {BLUE}{self.volumes}{RESET}")
        print(f"Clangd path: {BLUE}{self.clangd_path}{RESET}")
        print(f"Dotfiles path: {BLUE}{self.dotfiles_path}{RESET}")
        print()

    def __get_arg_abs_path(self, path: Optional[str], path_type: str = "", create_if_not_exist=False) -> Optional[str]:
        if path == "":
            return None

        if path is None:
            return None

        if not path_type:
            if path.endswith("/"):
                path_type = "dir"
            else:
                path_type = "file"

        abs_path = self.__to_host_abs_path(path)

        # Create the directory or file if it does not exist
        if create_if_not_exist:
            if path_type == "dir":
                self.__check_and_create_directory(abs_path)
            elif path_type == "file":
                self.__check_and_create_file(abs_path)
            else:
                raise ValueError(f"Invalid path type: {path_type}")

        if not os.path.exists(abs_path):
            print(f"{YELLOW}Warning: {abs_path} does not exist. Ignoring...{RESET}")
            return None

        return abs_path

    def generate_cmd(self) -> List[str]:
        cmd_args = self.__get_cmd_args()
        cmd = self.cmd_prefix + cmd_args + self.cmd_postfix
        return cmd

    def run_cmd(self):
        cmd = self.generate_cmd()

        print(f"Running command:\n {format_cmd(cmd)}")

        if ask_user_to_continue():
            print("Creating container...")
            result = subprocess.run(cmd)
            if result.returncode != 0:
                print("Failed to create container")
                sys.exit(1)
            print("Container created successfully.")
            
            # Install dotfiles if provided
            if self.dotfiles_path:
                self.__install_dotfiles()
            
            print("\nDone.\n\nYou can attach to the container using vscode or by running one of the following command:")
            print(f"    docker exec -it {self.container_name} bash")
            print(f"    docker exec -it {self.container_name} zsh\n")
            print("To remove the container, run the following command:")
            print(f"    docker rm -f {self.container_name}")
        else:
            print("Aborted")

    def __get_home_dir(self, user_name):
        if user_name in ["root", "0"]:
            return "/root"
        else:
            return f"/home/{user_name}"

    def __get_image_default_user(self, image_name: str) -> str:
        try:
            result = subprocess.run(
                ["docker", "image", "inspect", "--format", "{{.Config.User}}", image_name],
                capture_output=True,
                text=True,
            )
        except FileNotFoundError:
            raise RuntimeError("docker not found. Please install Docker or ensure it is in PATH.")

        if result.returncode != 0:
            error_message = result.stderr.strip() or "unknown error"
            raise RuntimeError(f"failed to inspect image '{image_name}': {error_message}")

        user = result.stdout.strip()
        if not user:
            return "root"

        if ":" in user:
            user = user.split(":", 1)[0] or "root"

        return user

    def __install_dotfiles(self):
        """Copy dotfiles to container and run install.sh"""
        if not self.dotfiles_path:
            return
        
        print(f"\n{GREEN}Installing dotfiles from {self.dotfiles_path}...{RESET}")
        
        # Create a temporary directory in the container
        temp_dir = "/tmp/dotfiles_install"
        
        # Copy dotfiles to container
        print(f"Copying dotfiles to container...")
        copy_cmd = ["docker", "cp", self.dotfiles_path, f"{self.container_name}:{temp_dir}"]
        result = subprocess.run(copy_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"{RED}Failed to copy dotfiles to container: {result.stderr}{RESET}")
            return
        
        # Check if install.sh exists
        check_cmd = ["docker", "exec", self.container_name, "test", "-f", f"{temp_dir}/install.sh"]
        result = subprocess.run(check_cmd, capture_output=True)
        if result.returncode != 0:
            print(f"{YELLOW}Warning: install.sh not found in {self.dotfiles_path}, skipping installation.{RESET}")
        else:
            # Run install.sh
            print(f"Running install.sh...")
            install_cmd = ["docker", "exec", self.container_name, "bash", "-c", f"cd {temp_dir} && bash install.sh"]
            result = subprocess.run(install_cmd)
            if result.returncode != 0:
                print(f"{RED}Warning: install.sh exited with code {result.returncode}{RESET}")
            else:
                print(f"{GREEN}Dotfiles installed successfully.{RESET}")
        
        # Clean up temporary directory
        print(f"Cleaning up temporary directory...")
        cleanup_cmd = ["docker", "exec", self.container_name, "rm", "-rf", temp_dir]
        subprocess.run(cleanup_cmd, capture_output=True)

    def __to_host_abs_path(self, path):
        return os.path.abspath(os.path.expanduser(path))

    def __to_container_abs_path(self, path):
        if os.path.isabs(path):
            return path
        else:
            return os.path.join(self.__get_home_dir(self.container_user_name), path)

    def __check_and_create_directory(self, dir_path, ask=True):
        if not os.path.exists(dir_path):
            if ask:
                if not ask_user_to_continue(f"Directory '{dir_path}' does not exist. Create? "):
                    return

            print(f"Creating directory '{dir_path}'")
            os.makedirs(dir_path)

    def __check_and_create_file(self, file_path, ask=True):
        if not os.path.exists(file_path):
            if ask:
                if not ask_user_to_continue(f"File '{file_path}' does not exist. Create? "):
                    return

            print(f"Creating file '{file_path}'")
            with open(file_path, "w") as f:
                f.write("")

    def __get_mount_args(self, host_path: str, container_path: str, path_type: str = "", options: str = "") -> List[str]:
        """Get the arguments to mount a directory or file from the host to the container

        Args:
            host_path (str): Host path
            container_path (str): Container path
            path_type (str, optional): "dir" or "file". If not specified, the function will deduce the type by checking if the path ends with "/"
            options (str, optional): Mount options

        Returns:
            List[str]: List of arguments to mount the directory or file
        """

        if not path_type:
            if host_path.endswith("/"):
                path_type = "dir"
            else:
                path_type = "file"

        host_abs_path = self.__to_host_abs_path(host_path)
        container_abs_path = self.__to_container_abs_path(container_path)

        # Create the directory or file if it does not exist
        if path_type == "dir":
            self.__check_and_create_directory(host_abs_path)
        elif path_type == "file":
            self.__check_and_create_file(host_abs_path)
        else:
            if not os.path.exists(host_abs_path):
                print(f"{YELLOW}Warning: {host_abs_path} does not exist{RESET}")

        if options:
            print(f"Mounting {BLUE}{host_abs_path}{RESET} -> {GREEN}{container_abs_path}{RESET} with options: {options}")
            return ["-v", f"{host_abs_path}:{container_abs_path}:{options}"]
        else:
            print(f"Mounting {BLUE}{host_abs_path}{RESET} -> {GREEN}{container_abs_path}{RESET}")
            return ["-v", f"{host_abs_path}:{container_abs_path}"]

    def __get_volumes_mount_args(self) -> List[str]:
        result = []
        for volume in self.volumes:
            paths = volume.split(":")
            if len(paths) <= 1:
                raise ValueError(f"Invalid volume: {volume}")
            options = paths[2] if len(paths) > 2 else ""
            result.extend(self.__get_mount_args(paths[0], paths[1], options=options))
        return result

    def __get_cmd_args(self):
        CONTAINER_HOME = self.__get_home_dir(self.container_user_name)

        XDG_RUNTIME_DIR = os.getenv("XDG_RUNTIME_DIR")
        HOME = os.getenv("HOME")
        # SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))

        cmd_args = []

        cmd_args.extend(
            [
                "--init",  # Use the Docker init process to handle reaping zombies and forwarding signals
                "--network=host",  # Enable host networking
                "--ipc=host",  # 使用 host 的 IPC 命名空间，以便容器内的进程可以使用共享内存（避免 /dev/shm 空间不足的问题）
            ]
        )

        cmd_args.extend(["--ulimit", "memlock=-1"])  # Disable memory lock limit
        cmd_args.extend(["--ulimit", "stack=67108864"])  # Increase stack size limit
        cmd_args.extend(["--ulimit", "nofile=1048576:1048576"])  # Increase open file limit

        if self.privileged:
            cmd_args.extend(["--privileged"])  # Allow access to all devices

        # Enable X11 GUI
        cmd_args.extend(self.__get_mount_args("/tmp/.X11-unix", "/tmp/.X11-unix", path_type="dir", options="rw"))
        env_DISPLAY = os.getenv("DISPLAY")
        if env_DISPLAY != ":0":
            print(
                f"{YELLOW}"
                f"Warning: $DISPLAY is set to {env_DISPLAY}\n"
                f"  Normally, $DISPLAY should be ':0', indicating the first local display.\n"
                f"  This may occur if you are running the script in a non-GUI environment, a VNC session, or via VSCode Remote-SSH.\n"
                f"  In such cases, GUI applications inside the container may not function properly.\n"
                f"  However, there are scenarios where $DISPLAY is set to values like ':1' or ':2', which can be valid.\n"
                f"  To verify if the current $DISPLAY is valid, exit this script and try running a GUI application (e.g., gedit, xclock, firefox) in the same terminal.\n"
                f"  If the application launches successfully, you can proceed with the current $DISPLAY.\n"
                f"  If not, you may set $DISPLAY to ':0' by running:\n\n"
                f"    export DISPLAY=:0\n"
                f"{RESET}"
            )
            if ask_user_to_continue(f"Continue with $DISPLAY={env_DISPLAY}?") == False:
                sys.exit(1)
        cmd_args.extend(["--env", "DISPLAY"])
        cmd_args.extend(["--env", "QT_X11_NO_MITSHM=1"])

        # Enable NVIDIA GPU
        if not self.no_nv:
            cmd_args.extend(["--runtime=nvidia", "--gpus", "all", "--env", "NVIDIA_DRIVER_CAPABILITIES=all"])

        # Enable sound
        cmd_args.extend(self.__get_mount_args(f"{XDG_RUNTIME_DIR}/pulse", "/tmp/pulse", "dir"))
        cmd_args.extend(self.__get_mount_args(f"{HOME}/.config/pulse/cookie", f"{CONTAINER_HOME}/.config/pulse/cookie", "file"))
        cmd_args.extend(["--env", "PULSE_SERVER=unix:/tmp/pulse/native"])

        # Mount .ssh directory
        cmd_args.extend(self.__get_mount_args(f"{HOME}/.ssh", f"{CONTAINER_HOME}/.ssh", "dir"))

        # Mount .gitconfig
        cmd_args.extend(self.__get_mount_args(f"{HOME}/.gitconfig", f"{CONTAINER_HOME}/.gitconfig", "file"))

        # Mount rc_file
        if self.rc_file:
            cmd_args.extend(self.__get_mount_args(f"{self.rc_file}", f"{CONTAINER_HOME}/.local/common_rc", "file"))

        # Mount user data directory
        # if self.user_data_dir:
        #     cmd_args.extend(self.__get_mount_args(self.user_data_dir, f"{CONTAINER_HOME}/user_data", "dir"))

        # Mount volumes
        cmd_args.extend(self.__get_volumes_mount_args())

        # Mount clangd
        if self.clangd_path:
            cmd_args.extend(self.__get_mount_args(self.clangd_path, f"{CONTAINER_HOME}/.local/clangd", "dir"))

        return cmd_args


def main():
    parser = argparse.ArgumentParser(
        description="Create a container",
        epilog=f"Example:\n  {sys.argv[0]} my-ros-humble my-project-name -v ~/Documents/:Documents -v ~/Downloads/:Downloads",
        formatter_class=argparse.RawTextHelpFormatter,
    )

    script_dir = os.path.dirname(os.path.realpath(__file__))
    default_rc_file = os.path.join(script_dir, "mount/common_rc")
    default_clangd_path = os.path.join(script_dir, "mount/clangd")
    default_dotfiles_path = "./dotfiles"

    parser.add_argument("image-name", help="The name of the image to create the container from")
    parser.add_argument("container-name", help="The name of the container to create")
    parser.add_argument(
        "--rc-file",
        help=f'The rc file to source in the container, which will be mounted to /home/<user_name>/.local/common_rc.\nThe default value is {BLUE}{default_rc_file}{RESET}. Give "" to not mount any rc file.',
        default=default_rc_file,
    )
    parser.add_argument("--user-name", help="The user to run the container as. Leave empty to use default user in the image", default="")
    # parser.add_argument("--user-data", help="The directory to store user data. It will be mounted to /home/<user_name>/user_data")
    parser.add_argument("--no-nv", help="Do not enable NVIDIA GPU", action="store_true")
    parser.add_argument("--volume", "-v", help="Mount a volume from the host to the container", action="append")
    parser.add_argument(
        "--clangd-path",
        help=f'Path to clangd. The default value is {BLUE}{default_clangd_path}{RESET}. Give "" to not mount clangd.',
        default=default_clangd_path,
    )
    parser.add_argument(
        "--dotfiles",
        help=f'Path to dotfiles directory. After container creation, this directory will be copied to a temp location in the container, install.sh will be executed, and then the temp directory will be removed. The default value is {BLUE}{default_dotfiles_path}{RESET}. Give "" to skip dotfiles installation.',
        default=default_dotfiles_path,
    )
    parser.add_argument("--no-privileged", action="store_true")
    args = parser.parse_args()

    docker_cmd_generator = DockerCmdGenerator(args)
    docker_cmd_generator.run_cmd()


if __name__ == "__main__":
    main()
