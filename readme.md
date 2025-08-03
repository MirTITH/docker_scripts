# docker_scripts

本项目用于管理和运行与 Docker 相关的脚本，方便容器的构建、部署与维护。

## 目录结构

- `common_files`：存放 build_image.sh 时被复制到 image 中的文件
- `mount`：存放 create_container.py 时被挂载到 container 中的文件
- `mirrors`: ubuntu 的镜像源
- `common_rc`：通用脚本文件。在使用 create_container.py 创建容器时，这些文件会被挂载到容器内，并在容器启动 bash 或 zsh 时自动 source，实现环境初始化和配置。

## 使用说明

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

## 使用示例

### 创建容器

```shell
./create_container.py my-ros-humble my-project-name --rc-file common_rc -v ~/Documents/:Documents -v ~/Downloads/:Downloads --user-data /path/to/project
```

### 使用 VSCode 附加到容器

1. 安装 `Dev Containers` 插件  
2. 附加到 `my-project-name`

### 测试 GUI 应用是否可用

在主机上运行：

```shell
xhost +local:docker
```

然后在容器内运行：

```shell
rviz2
```

## （可选）自定义设置

### 使用 zsh

在 VSCode 中将默认终端切换为 zsh

### 更改 Qt 应用程序样式

#### 作用：

- 改变 rviz2 等应用的界面风格  
- 解决部分应用图标缺失的问题

#### 方法：

运行 GUI 工具：

```shell
qt5ct
```

推荐设置：  
- 在“外观”标签页，将样式设置为 `Breeze`  
- 在“图标主题”标签页，选择 Breeze 并点击 OK  


## 贡献

欢迎提交 issue 或 pull request 以完善本项目。
