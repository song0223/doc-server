FROM swift:5.9-jammy

# 安装 MySQL 客户端库
RUN apt-get update && apt-get install -y \
    libmysqlclient-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制 Package 文件
COPY Package.swift ./
COPY Sources ./Sources

# 编译
RUN swift build -c release

# 运行
EXPOSE 8088

CMD ["swift", "run", "-c", "release"]
