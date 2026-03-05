# 基础镜像
FROM ubuntu:22.04

# 环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
ENV NVM_DIR=/root/.nvm
ENV SSH_USER=ubuntu

# 解决 Kaniko / rootless apt sandbox 问题
RUN echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/no-sandbox

# 复制文件
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

# 安装基础依赖
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
    && rm -rf /var/lib/apt/lists/*

# 配置时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
 && echo $TZ > /etc/timezone

# 创建 sshd 目录
RUN mkdir -p /run/sshd

# 设置执行权限
RUN chmod +x /entrypoint.sh \
 && chmod +x /usr/local/sbin/reboot \
 && chmod +x /index.js \
 && chmod +x /app.js \
 && chmod +x /app.py \
 && chmod +x /app.sh \
 && chmod +x /agent \
 && chmod +x /start.sh

# 安装 nvm + Node.js
RUN curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
 && . "$NVM_DIR/nvm.sh" \
 && nvm install 24.13.0 \
 && nvm alias default 24.13.0 \
 && nvm use default \
 && node -v \
 && npm -v

# 让 node/npm 在所有 shell 中可用
ENV PATH=$NVM_DIR/versions/node/v24.13.0/bin:$PATH

# 安装 node 依赖
RUN npm install

# 安装 python 依赖
RUN pip3 install --no-cache-dir -r /requirements.txt

# 再次验证 node/npm
RUN node -v && npm -v

# 暴露端口
EXPOSE 22

# 启动入口
ENTRYPOINT ["/entrypoint.sh"]

# 启动 supervisor
CMD ["/usr/bin/supervisord","-n","-c","/etc/supervisor/supervisord.conf"]
