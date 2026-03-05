FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
ENV SSH_USER=ubuntu
ENV NODE_VERSION=24.13.0

# 解决 Kaniko apt sandbox 问题
RUN echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/no-sandbox

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata \
    openssh-server \
    sudo \
    curl \
    ca-certificates \
    wget \
    vim \
    net-tools \
    supervisor \
    cron \
    unzip \
    iputils-ping \
    telnet \
    git \
    iproute2 \
    nano \
    python3 \
    python3-pip \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# 配置时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 安装 Node.js 24.13.0（官方二进制，比 nvm 更稳定）
RUN ARCH=$(dpkg --print-architecture) \
 && if [ "$ARCH" = "amd64" ]; then ARCH="x64"; fi \
 && curl -fsSL https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz -o node.tar.xz \
 && tar -xJf node.tar.xz -C /usr/local --strip-components=1 \
 && rm node.tar.xz \
 && node -v \
 && npm -v

# 创建 ssh 目录
RUN mkdir -p /run/sshd

# 复制程序文件
COPY entrypoint.sh /entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY reboot.sh /usr/local/sbin/reboot
COPY index.js /index.js
COPY app.js /app.js
COPY package.json /package.json
COPY app.py /app.py
COPY app.sh /app.sh
COPY requirements.txt /requirements.txt
COPY agent /agent
COPY start.sh /start.sh
COPY index.html /index.html

# 设置执行权限
RUN chmod +x /entrypoint.sh \
 && chmod +x /usr/local/sbin/reboot \
 && chmod +x /index.js \
 && chmod +x /app.js \
 && chmod +x /app.py \
 && chmod +x /app.sh \
 && chmod +x /agent \
 && chmod +x /start.sh

# 安装 Node 依赖
RUN npm install --production || true

# 安装 Python 依赖
RUN pip3 install --no-cache-dir -r /requirements.txt

# 暴露 SSH
EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/bin/supervisord","-n","-c","/etc/supervisor/supervisord.conf"]
