# --- 阶段 1: 构建前端 ---
FROM node:20-alpine AS frontend-build
WORKDIR /app/emby-actor-ui

# 先复制package文件以利用Docker层缓存
COPY emby-actor-ui/package*.json ./
RUN npm cache clean --force && \
    npm install --no-fund --verbose

# 再复制源码并构建
COPY emby-actor-ui/ ./
RUN npm run build

# --- 阶段 2: 构建最终的生产镜像 ---
FROM python:3.11-slim

# 设置环境变量
ENV LANG="C.UTF-8" \
    TZ="Asia/Shanghai" \
    HOME="/embyactor" \
    CONFIG_DIR="/config" \
    APP_DATA_DIR="/config" \
    TERM="xterm" \
    PUID=0 \
    PGID=0 \
    UMASK=000

WORKDIR /app

# 安装必要的系统依赖和 Node.js
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        nodejs \
        gettext-base \
        locales \
        procps \
        gosu \
        bash \
        wget \
        curl \
        dumb-init && \
    apt-get clean && \
    rm -rf \
        /tmp/* \
        /var/lib/apt/lists/* \
        /var/tmp/*

# 先复制requirements.txt以利用pip缓存
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 复制入口脚本并设置权限
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 创建用户和目录
RUN mkdir -p ${HOME} && \
    groupadd -r embyactor -g 918 && \
    useradd -r embyactor -g embyactor -d ${HOME} -s /bin/bash -u 918

# 复制应用源码（这些文件变化频繁，放在最后以最大化缓存利用）
COPY web_app.py \
     core_processor.py \
     douban.py \
     tmdb_handler.py \
     emby_handler.py \
     utils.py \
     logger_setup.py \
     constants.py \
     web_parser.py \
     ai_translator.py \
     watchlist_processor.py \
     actor_sync_handler.py \
     actor_utils.py \
     actor_subscription_processor.py \
     moviepilot_handler.py \
     config_manager.py \
     task_manager.py \
     db_handler.py \
     extensions.py \
     ./

COPY routes/ ./routes/
COPY templates/ ./templates/

# 从前端构建阶段拷贝编译好的静态文件
COPY --from=frontend-build /app/emby-actor-ui/dist/. /app/static/

# 声明 /config 目录为数据卷
VOLUME [ "${CONFIG_DIR}" ]

EXPOSE 5257

# 设置容器入口点
ENTRYPOINT [ "/entrypoint.sh" ]