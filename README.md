# Docker 项目自动化创建工具

这是一个用于快速创建 Docker 部署目录和部署脚本的小工具。

你可以交互式运行 `create_project.sh`，也可以通过命令行参数直接创建项目。脚本默认在 `/apps` 目录下创建项目结构，并生成对应的部署脚本；也可以通过 `BASE_DIR` 环境变量或 `--base-dir` 参数修改根目录。

## 这个工具能做什么

- 创建项目目录，例如 `/apps/my-project`
- 根据选择生成 API 部署脚本、Web 部署脚本，或两个都生成
- 自动创建日志目录
- 部署时自动停止并删除旧容器
- 部署前校验压缩包和 Docker 构建文件
- 先解压到临时目录，构建成功后再替换服务目录
- 重新构建 Docker 镜像
- 启动新的 Docker 容器
- 支持交互输入和命令行参数两种创建方式

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

同时要确保当前用户有权限写入项目根目录，并且有权限执行 Docker 命令。

如果 `/apps` 不存在或没有权限，可以先创建并授权：

```bash
sudo mkdir -p /apps
sudo chown -R $USER /apps
```

如果不想使用 `/apps`，可以指定其他绝对路径：

```bash
BASE_DIR=/data/apps bash create_project.sh
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

也可以使用非交互模式：

```bash
bash create_project.sh --name demo --type all --api-port 8080 --web-port 8081
```

常用参数：

```text
--name <项目名>          项目名称
--type <api|web|all>     服务类型
--api-port <端口>        API 服务端口
--web-port <端口>        Web 外部端口
--base-dir <目录>        项目根目录，默认 /apps
```

示例：创建到 `/data/apps/demo`

```bash
bash create_project.sh \
  --name demo \
  --type all \
  --api-port 8080 \
  --web-port 8081 \
  --base-dir /data/apps
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
- 项目名称只能包含小写字母、数字、中划线和下划线，并且必须以小写字母或数字开头。
- 端口必须是 `1-65535` 之间的数字。
- 如果端口已经被占用，容器会启动失败。
- 部署脚本会先解压到临时目录并完成镜像构建，成功后才替换 `/apps/项目名称/api` 或 `/apps/项目名称/web` 目录。
- 不要把需要长期保存的重要文件直接放在 `api/` 或 `web/` 目录下。
- API 压缩包必须命名为 `app.tar.gz`。
- API 压缩包根目录必须包含 `Dockerfile`。
- Web 压缩包必须命名为 `web.tar.gz`。
- Web 压缩包根目录必须包含 `dist/` 目录和 `Docker/Dockerfile`。

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
