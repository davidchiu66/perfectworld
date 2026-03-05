############################
# Stage 1: builder
############################
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_VERSION=24.13.0

# 解决 Kaniko apt sandbox 问题
RUN echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/no-sandbox

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    python3 \
    python3-pip \
    xz-utils \
    git \
    && rm -rf /var/lib/apt/lists/*

# 安装 Node.js
RUN ARCH=$(dpkg --print-architecture) \
 && if [ "$ARCH" = "amd64" ]; then ARCH="x64"; fi \
 && curl -fsSL https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz -o node.tar.xz \
 && tar -xJf node.tar.xz -C /usr/local --strip-components=1 \
 && rm node.tar.xz

WORKDIR /build

COPY package.json /build/package.json

RUN npm install --production

COPY requirements.txt /build/requirements.txt

RUN pip3 install --no-cache-dir -r requirements.txt --prefix=/python

############################
# Stage 2: runtime
############################
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
ENV SSH_USER=ubuntu

# 解决 Kaniko apt sandbox 问题
RUN echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/no-sandbox

RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata \
    openssh-server \
    sudo \
    supervisor \
    curl \
    ca-certificates \
    python3 \
    iputils-ping \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# 时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# SSH
RUN mkdir -p /run/sshd

# Node runtime
COPY --from=builder /usr/local /usr/local

# npm modules
COPY --from=builder /build/node_modules /node_modules

# python modules
COPY --from=builder /python /usr/local

# 应用文件
COPY entrypoint.sh /entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY reboot.sh /usr/local/sbin/reboot
COPY index.js /index.js
COPY app.js /app.js
COPY app.py /app.py
COPY app.sh /app.sh
COPY agent /agent
COPY start.sh /start.sh
COPY index.html /index.html

RUN chmod +x /entrypoint.sh \
 && chmod +x /usr/local/sbin/reboot \
 && chmod +x /agent \
 && chmod +x /start.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/bin/supervisord","-n"]
