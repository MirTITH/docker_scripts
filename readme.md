# docker_scripts

本项目用于管理和运行与 Docker 相关的脚本，方便容器的构建、部署与维护。

## 目录结构

- `common_files`：存放 build_image.sh 时被复制到 image 中的文件
- `mount`：存放 create_container.py 时被挂载到 container 中的文件
- `mirrors`: ubuntu 的镜像源
- `common_rc`：通用脚本文件。在使用 create_container.py 创建容器时，这些文件会被挂载到容器内，并在容器启动 bash 或 zsh 时自动 source，实现环境初始化和配置。

## 使用方法

1. 克隆或下载本仓库到本地。
2. 根据需要修改或添加脚本。
3. 运行脚本前，请确保已安装 Docker，并具有相应权限。

查看创建 image 的方法：
```bash
./build_image.sh
```

查看创建 container 的方法：
```bash
./create_container.py --help
```

## 贡献

欢迎提交 issue 或 pull request 以完善本项目。
