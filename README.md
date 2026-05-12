# Docker 项目自动化创建工具

这是一个用于快速创建 Docker 部署目录和部署脚本的小工具。

你只需要运行 `create_project.sh`，按提示输入项目名称、选择需要的服务、填写端口，脚本就会自动在 `/apps` 目录下创建项目结构，并生成对应的部署脚本。

## 这个工具能做什么

- 创建项目目录，例如 `/apps/my-project`
- 根据选择生成 API 部署脚本、Web 部署脚本，或两个都生成
- 自动创建日志目录
- 部署时自动停止并删除旧容器
- 解压新的项目包
- 重新构建 Docker 镜像
- 启动新的 Docker 容器

## 目录说明

运行创建脚本后，会生成类似这样的目录：

```text
/apps/项目名称/
├── api/       # API 服务代码解压后放在这里
├── web/       # Web 前端代码解压后放在这里
├── logs/      # 部署日志
└── scripts/   # 自动生成的部署脚本
```

如果选择了 API，会生成：

```text
/apps/项目名称/scripts/deploy_api.sh
```

如果选择了 Web，会生成：

```text
/apps/项目名称/scripts/deploy_web.sh
```

## 使用前准备

服务器需要提前安装好：

- Bash
- Docker
- tar

同时要确保当前用户有权限写入 `/apps` 目录，并且有权限执行 Docker 命令。

如果 `/apps` 不存在或没有权限，可以先创建并授权：

```bash
sudo mkdir -p /apps
sudo chown -R $USER /apps
```

## 如何创建项目

进入本工具所在目录：

```bash
cd /Users/simon/workplace/scripts/create_project
```

运行创建脚本：

```bash
bash create_project.sh
```

然后按提示输入：

1. 项目名称
2. 需要的服务类型
3. API 端口或 Web 外部端口

服务类型有三种：

```text
1) 仅 API
2) 仅 Web
3) API + Web 全部
```

示例：

```text
请输入项目名称：demo
请选择需要的服务：3
请输入 API 运行端口：8080
请输入 Web 外部端口：8081
```

执行完成后，项目会创建在：

```text
/apps/demo
```

## 如何部署 API

API 部署脚本默认读取这个文件：

```text
/apps/项目名称/app.tar.gz
```

所以部署前，需要先把 API 项目打包成 `app.tar.gz`，并放到项目根目录下。

API 压缩包解压后，根目录里应该包含 `Dockerfile`。

示例：

```bash
cp app.tar.gz /apps/demo/
/apps/demo/scripts/deploy_api.sh
```

部署完成后，容器名称是：

```text
demo-api
```

镜像名称也是：

```text
demo-api
```

## 如何部署 Web

Web 部署脚本默认读取这个文件：

```text
/apps/项目名称/web.tar.gz
```

所以部署前，需要先把 Web 项目打包成 `web.tar.gz`，并放到项目根目录下。

Web 压缩包解压后，需要包含：

```text
dist/      # 前端构建产物
Docker/    # Docker 构建目录，里面需要有 Dockerfile
```

部署时脚本会把 `dist` 移动到 `Docker/` 目录下，然后在 `Docker/` 目录中构建镜像。

示例：

```bash
cp web.tar.gz /apps/demo/
/apps/demo/scripts/deploy_web.sh
```

部署完成后，容器名称是：

```text
demo-web
```

镜像名称也是：

```text
demo-web
```

## 查看日志

API 部署日志：

```text
/apps/项目名称/logs/deployment_api_log.txt
```

Web 部署日志：

```text
/apps/项目名称/logs/deployment_web_log.txt
```

也可以查看容器日志：

```bash
docker logs 项目名称-api
docker logs 项目名称-web
```

例如：

```bash
docker logs demo-api
docker logs demo-web
```

## 注意事项

- 项目名称不能为空。
- 端口必须填写数字。
- 如果端口已经被占用，容器会启动失败。
- 每次部署都会清空 `/apps/项目名称/api` 或 `/apps/项目名称/web` 目录里的旧文件。
- 不要把需要长期保存的重要文件直接放在 `api/` 或 `web/` 目录下。
- API 压缩包必须命名为 `app.tar.gz`。
- Web 压缩包必须命名为 `web.tar.gz`。
- Web 压缩包里必须有 `dist/` 目录，否则部署会失败。

## 常用命令

查看容器是否启动：

```bash
docker ps
```

停止 API 容器：

```bash
docker stop demo-api
```

停止 Web 容器：

```bash
docker stop demo-web
```

删除 API 容器：

```bash
docker rm demo-api
```

删除 Web 容器：

```bash
docker rm demo-web
```

重新部署时，一般不需要手动停止和删除容器，部署脚本会自动处理。
