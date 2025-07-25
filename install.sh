#!/bin/bash
# 作者: [菜芽]
# 描述: 该脚本用于安装 Docker 环境、下载 docker-compose.yml 文件，并根据用户选择安装和配置服务。
# 项目地址：https://github.com/e5sub/docker-images

# 安装 Docker 环境
docker_install(){
    echo -e "\033[1;34m正在检查依赖工具...\033[0m"
    if ! type wget >/dev/null 2>&1; then
        echo -e "\033[1;33mwget 未安装，正在安装中...\033[0m"
        apt install wget -y || yum install wget -y
    else
        echo -e "\033[1;32mwget 已安装，继续操作\033[0m"
    fi
    
    if ! type curl >/dev/null 2>&1; then
        echo -e "\033[1;33mcurl 未安装，正在安装中...\033[0m"
        apt install curl -y || yum install curl -y
    else
        echo -e "\033[1;32mcurl 已安装，继续操作\033[0m"
    fi

    if ! type git >/dev/null 2>&1; then
        echo -e "\033[1;33mgit 未安装，正在安装中...\033[0m"
        apt install git -y || yum install git -y
    else
        echo -e "\033[1;32mgit 已安装，继续操作\033[0m"
    fi   
     
    if ! type docker >/dev/null 2>&1; then
        echo -e "\033[1;33mdocker 未安装，正在安装中...\033[0m"
        curl -fsSL https://fastly.jsdelivr.net/gh/e5sub/docker-install@master/install.sh | bash -s docker --mirror Aliyun
        systemctl enable docker
        echo -e "\033[1;34m正在配置 Docker...\033[0m"
        cat >/etc/docker/daemon.json<<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "20m",
    "max-file": "2"
  },
  "registry-mirrors": [
    "https://docker.071717.xyz"
  ]
}
EOF
        systemctl daemon-reload
        systemctl restart docker
    else 
        echo -e "\033[1;32mdocker 已安装，继续操作\033[0m"
    fi
}
docker_install

# 定义配置文件路径和下载地址
compose_file="./docker-compose.yml"
compose_url="https://fastly.jsdelivr.net/gh/e5sub/docker-images@master/docker-compose.yml"

# 检查文件是否存在
if [ -f "$compose_file" ]; then
    echo -e "\033[1;33m检测到已有 docker-compose.yml 文件，跳过下载\033[0m"
else
    # 下载文件
    echo -e "\033[1;34m正在下载 docker-compose.yml 文件...\033[0m"
    wget -q -N --no-cache "$compose_url" -O "$compose_file"
    
    # 检查下载结果
    if [ $? -ne 0 ]; then
        echo -e "\033[1;31m下载失败，请检查网络或 URL 地址\033[0m"
        exit 1
    else
        echo -e "\033[1;32m下载成功\033[0m"
    fi
fi

# 创建临时文件用于后续处理
temp_compose_file="./docker-compose.temp.yml"
cp "$compose_file" "$temp_compose_file"
echo -e "\033[1;34m已创建临时配置文件\033[0m"

# 提取服务描述
service_descriptions=()
services=()
prev_line=""

while IFS= read -r line; do
    if [[ "$line" =~ ^\ \ [a-zA-Z0-9_-]+: ]]; then
        service=$(echo "$line" | awk '{print $1}' | tr -d ':')
        description=$(echo "$prev_line" | sed 's/^[[:space:]]*#[[:space:]]*//')
        
        services+=("$service")
        service_descriptions+=("$description")
    fi
    prev_line="$line"
done < "$compose_file"

# 颜色定义
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m' # 恢复默认颜色

# 计算最大序号宽度
max_width=${#services[@]}
max_width=${#max_width}

# 打印美化标题
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                         ${WHITE}Docker 服务安装菜单${CYAN}                          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"

echo -e "${GREEN}请选择要安装的服务（用空格分隔多个选项，输入 all 选择所有服务）：${NC}"
echo -e "${YELLOW}--------------------------------------------------------------------------------${NC}"

# 按原始顺序打印服务列表
for ((i = 0; i < ${#services[@]}; i++)); do
    printf "${GREEN}%${max_width}d.${NC} ${BLUE}%-25s${NC} ${WHITE}%s${NC}\n" "$((i + 1))" "${services[$i]}" "${service_descriptions[$i]}"
done

echo -e "${YELLOW}--------------------------------------------------------------------------------${NC}"
read -e -p "选择: " choices

# 处理用户选择
echo -e "\n${CYAN}正在处理你的选择...${NC}"
if [ "$choices" == "all" ]; then
    selected_services=("${services[@]}")
    echo -e "${GREEN}已选择安装所有服务${NC}"
else
    selected_services=()
    valid_choice=false
    for choice in $choices; do
        index=$((choice - 1))
        if [ $index -ge 0 ] && [ $index -lt ${#services[@]} ]; then
            selected_services+=("${services[$index]}")
            valid_choice=true
        else
            echo -e "${RED}无效的选择: $choice${NC}"
        fi
    done
    
    if ! $valid_choice; then
        echo -e "${RED}没有选择任何有效服务，退出安装${NC}"
        exit 1
    fi
fi

# 显示用户选择的服务
echo -e "\n${CYAN}你选择安装的服务：${NC}"
for ((i = 0; i < ${#selected_services[@]}; i++)); do
    service="${selected_services[$i]}"
    for ((j = 0; j < ${#services[@]}; j++)); do
        if [[ "${services[$j]}" == "$service" ]]; then
            printf "${GREEN}%${max_width}d.${NC} ${BLUE}%-25s${NC} ${WHITE}%s${NC}\n" "$((j + 1))" "$service" "${service_descriptions[$j]}"
            break
        fi
    done
done

# 处理 tailscaled 配置文件
echo -e "\n${CYAN}正在配置所选服务...${NC}"
if [[ " ${selected_services[@]} " =~ " tailscaled " ]]; then
    read -e -p "请输入你的 Tailscale Auth Key: " ts_authkey
    sed -i "s/TS_AUTHKEY=.*# 替换为你的 Tailscale Auth Key/TS_AUTHKEY=$ts_authkey/" "$temp_compose_file"
    echo -e "${GREEN}Tailscale Auth Key 已配置${NC}"
    # 获取网卡 IP 段
    ip_segment=$(ip -o -f inet addr show | awk '/scope global/ {split($4, a, "/"); print a[1]"/"a[2]}' | head -n 1)
    if [ -n "$ip_segment" ]; then
        # 安装 ipcalc 工具（如果未安装）
        if ! type ipcalc >/dev/null 2>&1; then
            apt install ipcalc -y || yum install ipcalc -y
        fi
        # 使用 ipcalc 计算网络地址
        network_address=$(ipcalc $ip_segment | grep 'Network' | awk '{print $2}')
        if [ -n "$network_address" ]; then
            sed -i "s|--advertise-routes=192.168.0.0/24|--advertise-routes=$network_address|" "$temp_compose_file"
            echo -e "${GREEN}Tailscale 广告路由已更新为 $network_address${NC}"
        else
            echo -e "${RED}无法计算网络地址，使用默认配置${NC}"
        fi
    else
        echo -e "${RED}无法获取网卡 IP 段，使用默认配置${NC}"
    fi
fi

# 处理 rustdesk-server 配置文件
if [[ " ${selected_services[@]} " =~ " rustdesk-server " ]]; then
    read -e -p "请输入你的中继服务器地址: " relay_server
    read -e -p "请输入你的 ID 服务器地址: " id_server
    read -e -p "请输入你的 API 服务器地址: " api_server    
    sed -i "s/RELAY=.*# 替换为你的中继服务器地址（21117端口）/RELAY=$relay_server/" "$temp_compose_file"
    sed -i "s/RUSTDESK_API_RUSTDESK_ID_SERVER=.*# 替换为你的ID服务器地址（21116端口）/RUSTDESK_API_RUSTDESK_ID_SERVER=$id_server/" "$temp_compose_file"
    sed -i "s/RUSTDESK_API_RUSTDESK_RELAY_SERVER=.*# 替换为你的中继服务器地址（21117端口）/RUSTDESK_API_RUSTDESK_RELAY_SERVER=$relay_server/" "$temp_compose_file"
    sed -i "s/RUSTDESK_API_RUSTDESK_API_SERVER=.*# 替换为你的API服务器地址/RUSTDESK_API_RUSTDESK_API_SERVER=$api_server/" "$temp_compose_file"    
    echo -e "${GREEN}RustDesk 服务器地址已配置${NC}"
fi

# 处理 portainer 或者 portainer_agent 的 AGENT_SECRET 配置
if [[ " ${selected_services[@]} " =~ " portainer " ]] && [[ " ${selected_services[@]} " =~ " portainer_agent " ]]; then
    read -e -p "请输入 Portainer 或者 Portainer Agent 的 AGENT_SECRET 密码: " agent_secret
    sed -i "s/AGENT_SECRET=.*$/AGENT_SECRET=$agent_secret/" "$temp_compose_file"
    echo -e "${GREEN}Portainer 或者 Portainer Agent 的 AGENT_SECRET 已配置${NC}"
fi

# 处理nginx目录映射问题
if [[ " ${selected_services[@]} " =~ " nginx " ]]; then
    echo -e "${CYAN}配置 Nginx 服务...${NC}"
    # 拉取最新 nginx 镜像
    echo -e "${CYAN}拉取 nginx:latest 镜像...${NC}"
    docker pull nginx:latest
    # 创建临时容器提取配置
    container_id=$(docker create nginx:latest)
    echo -e "${CYAN}创建临时容器: $container_id${NC}"
    temp_dir=$(mktemp -d)
    echo -e "${CYAN}使用临时目录: $temp_dir${NC}"
    # 提取配置文件
    docker cp "$container_id:/etc/nginx" "$temp_dir/"
    docker cp "$container_id:/usr/share/nginx/html" "$temp_dir/"
    docker rm "$container_id" >/dev/null
    # 定义挂载映射
    declare -A mount_map=(
        ["/usr/share/nginx/html"]="/opt/nginx/html"
        ["/etc/nginx"]="/opt/nginx/conf"
        ["/var/log/nginx"]="/opt/nginx/log"
    )
    for container_path in "${!mount_map[@]}"; do
        host_path="${mount_map[$container_path]}"
        echo -e "${CYAN}处理挂载: ${host_path} -> ${container_path}${NC}"
        mkdir -p "$host_path"
        case "$container_path" in
            "/usr/share/nginx/html")
                if [ -z "$(ls -A "$host_path")" ]; then
                    echo -e "${CYAN}复制默认网页内容...${NC}"
                    cp -r "$temp_dir/html/." "$host_path/"
                    echo -e "${GREEN}网页内容复制完成${NC}"
                else
                    echo -e "${GREEN}网页目录非空，跳过复制${NC}"
                fi
                ;;
            "/etc/nginx")
                missing_main_conf=0
                [ ! -f "$host_path/nginx.conf" ] && missing_main_conf=1
                [ ! -d "$host_path/conf.d" ] && missing_main_conf=1

                if [ -z "$(ls -A "$host_path")" ] || [ "$missing_main_conf" -eq 1 ]; then
                    echo -e "${YELLOW}配置目录为空或缺失关键文件，初始化默认配置...${NC}"
                    cp -r "$temp_dir/nginx/." "$host_path/"
                    # 检查并生成 default.conf
                    if [ ! -f "$host_path/conf.d/default.conf" ]; then
                        echo -e "${YELLOW}default.conf 不存在，生成默认虚拟主机配置...${NC}"
                        mkdir -p "$host_path/conf.d"
                        cat > "$host_path/conf.d/default.conf" <<EOF
server {
    listen       80;
    server_name  localhost;
    return       301 https://\$host\$request_uri;
}

server {
    listen       443 ssl;
    server_name  localhost;

    ssl_certificate      /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key  /etc/nginx/ssl/nginx.key;

    ssl_protocols        TLSv1.2 TLSv1.3;
    ssl_ciphers          HIGH:!aNULL:!MD5;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF
                    echo -e "${GREEN}default.conf 已生成${NC}"
                fi
                    echo -e "${GREEN}Nginx 配置初始化完成${NC}"
                else
                    echo -e "${GREEN}配置目录存在且完整，跳过复制${NC}"
                fi
                ;;
            "/var/log/nginx")
                echo -e "${GREEN}日志目录已准备好${NC}"
                ;;
            *)
                echo -e "${YELLOW}未知路径 $container_path，跳过${NC}"
                ;;
        esac
    done

    # 清理临时目录
    echo -e "${CYAN}清理临时目录...${NC}"
    rm -rf "$temp_dir"
    echo -e "${GREEN}Nginx 配置完成${NC}"
fi

# 处理 n8n 文件夹权限设置
if [[ " ${selected_services[@]} " =~ " n8n " ]]; then
    n8n_dir="/opt/n8n"
    mkdir -p "$n8n_dir"
    chown -R 1000:1000 "$n8n_dir"
    chmod -R 777 "$n8n_dir"
    echo -e "${GREEN}已创建并设置 $n8n_dir 文件夹权限${NC}"
fi

# 处理 Redis 配置文件
if [[ " ${selected_services[@]} " =~ " redis " ]]; then
    redis_conf_url="https://gh-proxy.com/https://raw.githubusercontent.com/redis/redis/8.0/redis.conf"
    redis_conf_dir="/opt/redis/conf"
    mkdir -p "$redis_conf_dir"
    echo -e "${CYAN}正在下载 Redis 配置文件...${NC}"
    wget -q -N --no-cache "$redis_conf_url" -O "$redis_conf_dir/redis.conf"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Redis 配置文件下载失败，请检查网络或 URL 地址${NC}"
    else
        echo -e "${GREEN}Redis 配置文件下载成功${NC}"
    fi
fi

# 处理 MinIO 配置文件
if [[ " ${selected_services[@]} " =~ " minio " ]]; then
    minio_conf_file="/opt/minio/minio"
    mkdir -p "$(dirname "$minio_conf_file")"
    cat > "$minio_conf_file" <<EOF
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=minioadmin
MINIO_VOLUMES="/mnt/data"
MINIO_OPTS="--console-address :9001"
EOF
    echo -e "${GREEN}MinIO 配置文件已生成${NC}"
fi

# 处理 MoneyPrinterTurbo 配置文件
if [[ " ${selected_services[@]} " =~ " moneyprinterturbo " ]]; then
    moneyprinterturbo_dir="/opt/MoneyPrinterTurbo"
    mkdir -p "$moneyprinterturbo_dir"
    git_repo="https://gh-proxy.com/https://github.com/harry0703/MoneyPrinterTurbo.git"
    echo -e "${CYAN}正在下载 MoneyPrinterTurbo 代码...${NC}"
    git clone "$git_repo" "$moneyprinterturbo_dir"
    if [ $? -ne 0 ]; then
        echo -e "${RED}代码下载失败，请检查网络或 URL 地址${NC}"
        exit 1
    else
        echo -e "${GREEN}代码下载成功${NC}"
    fi
fi

# 处理 mysql 配置
if [[ " ${selected_services[@]} " =~ " mysql " ]]; then
    read -e -p "请输入 MySQL root 密码: " mysql_root_password
    read -e -p "请输入 MySQL 数据库名称: " mysql_database
    sed -i "s/MYSQL_ROOT_PASSWORD=.*# 替换为你的 MySQL root 密码/MYSQL_ROOT_PASSWORD=$mysql_root_password/" "$temp_compose_file"
    sed -i "s/MYSQL_DATABASE=.*# 替换为你的数据库名称/MYSQL_DATABASE=$mysql_database/" "$temp_compose_file"
    echo -e "${GREEN}MySQL 配置已完成${NC}"
fi

# 处理 MongoDB 配置
if [[ " ${selected_services[@]} " =~ " mongodb " ]]; then
    read -e -p "请输入 MongoDB root 用户名: " mongo_root_username
    read -e -p "请输入 MongoDB root 密码: " mongo_root_password
    sed -i "s/MONGO_INITDB_ROOT_USERNAME=.*# 替换为你的 MongoDB root 用户名/MONGO_INITDB_ROOT_USERNAME=$mongo_root_username/" "$temp_compose_file"
    sed -i "s/MONGO_INITDB_ROOT_PASSWORD=.*# 替换为你的 MongoDB root 密码/MONGO_INITDB_ROOT_PASSWORD=$mongo_root_password/" "$temp_compose_file"
    echo -e "${GREEN}MongoDB 配置已完成${NC}"
fi

# 处理 PostgreSQL 配置
if [[ " ${selected_services[@]} " =~ " postgresql " ]]; then
    read -e -p "请输入 PostgreSQL 用户名: " postgres_user
    read -e -p "请输入 PostgreSQL 密码: " postgres_password
    read -e -p "请输入 PostgreSQL 数据库名称: " postgres_database
    sed -i "s/POSTGRES_USER=.*# 替换为你的 PostgreSQL 用户名/POSTGRES_USER=$postgres_user/" "$temp_compose_file"
    sed -i "s/POSTGRES_PASSWORD=.*# 替换为你的 PostgreSQL 密码/POSTGRES_PASSWORD=$postgres_password/" "$temp_compose_file"
    sed -i "s/POSTGRES_DB=.*# 替换为你的数据库名称/POSTGRES_DB=$postgres_database/" "$temp_compose_file"
    echo -e "${GREEN}PostgreSQL 配置已完成${NC}"
fi

# 处理 Dockerhub 配置
if [[ " ${selected_services[@]} " =~ " dockerhub " ]]; then
    echo -e "${CYAN}正在下载 Docker-Proxy 代码...${NC}"
    git clone https://gh-proxy.com/https://github.com/dqzboy/Docker-Proxy.git /opt/Docker-Proxy
    if [ $? -ne 0 ]; then
        echo -e "${RED}代码下载失败，请检查网络或 URL 地址${NC}"
        exit 1
    else
        echo -e "${GREEN}代码下载成功${NC}"
    fi
fi

# 处理 frpp-master 配置文件
if [[ " ${selected_services[@]} " =~ " frpp-master " ]]; then
    # 随机生成 APP_GLOBAL_SECRET
    app_global_secret=$(openssl rand -hex 16)
    echo -e "${CYAN}生成的 APP_GLOBAL_SECRET: $app_global_secret${NC}"
    # 保存 APP_GLOBAL_SECRET 到 /opt/frpp
    mkdir -p /opt/frpp
    echo "$app_global_secret" > /opt/frpp/app_global_secret.txt
    echo -e "${GREEN}APP_GLOBAL_SECRET 已保存到 /opt/frpp/app_global_secret.txt${NC}"
    # 替换 docker-compose.yml 中的 APP_GLOBAL_SECRET
    sed -i "s/APP_GLOBAL_SECRET=.*# APP_GLOBAL_SECRET注意不要泄漏，客户端和服务端的是通过Master生成的/APP_GLOBAL_SECRET=$app_global_secret/" "$temp_compose_file"
    # 提示用户输入 MASTER_RPC_HOST 和 MASTER_API_HOST
    while true; do
    read -e -p "请输入服务器的外部 IP 或 域名: " host
    if [ -n "$host" ]; then
        break
    else
        echo -e "${RED}输入不能为空，请重新输入。${NC}"
    fi
done
    sed -i "s/MASTER_RPC_HOST=.*#服务器的外部IP或域名/MASTER_RPC_HOST=$host/" "$temp_compose_file"
    sed -i "s/MASTER_API_HOST=.*#服务器的外部IP或域名/MASTER_API_HOST=$host/" "$temp_compose_file"
    echo -e "${GREEN}frpp-master 配置已完成${NC}"
fi

# 处理 frp-panel-server 配置文件
if [[ " ${selected_services[@]} " =~ " frp-panel-server " ]]; then
    while true; do
    read -e -p "请输入frp-panel面板服务器的外部 IP 或 域名: " host
    if [ -n "$host" ]; then
        break
    else
        echo -e "${RED}输入不能为空，请重新输入。${NC}"
    fi
done
    while true; do
    read -e -p "请输入frp-panel服务端面板生成的密钥: " secret
    if [ -n "$secret" ]; then
        break
    else
        echo -e "${RED}输入不能为空，请重新输入。${NC}"
    fi
done
    while true; do
    read -e -p "请输入frp-panel服务端面板的ID: " id
    if [ -n "$id" ]; then
        break
    else
        echo -e "${RED}输入不能为空，请重新输入。${NC}"
    fi
done
    sed -i "s/frpp.example.com/$host/g" "$temp_compose_file"
    sed -i "s/frpp-rpc.example.com/$host/g" "$temp_compose_file"
    sed -i "s/abcdef/$secret/g" "$temp_compose_file"
    sed -i "s/default/$id/g" "$temp_compose_file"
    echo -e "${GREEN}frp-panel-server 配置已完成${NC}"
fi

# 启动所选服务
echo -e "\n${CYAN}正在启动所选服务...${NC}"
docker compose -f "$temp_compose_file" up -d ${selected_services[@]}

rm "$temp_compose_file"

# 显示安装结果
echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                          ${GREEN}服务安装完成${CYAN}                           ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"

echo -e "${GREEN}已成功安装以下服务：${NC}"
echo -e "${YELLOW}--------------------------------------------------------------------------------${NC}"
for service in "${selected_services[@]}"; do
    for ((i = 0; i < ${#services[@]}; i++)); do
        if [[ "${services[$i]}" == "$service" ]]; then
            printf "${GREEN}%${max_width}d.${NC} ${BLUE}%-25s${NC} ${WHITE}%s${NC}\n" "$((i + 1))" "$service" "${service_descriptions[$i]}"
            break
        fi
    done
done
echo -e "${YELLOW}--------------------------------------------------------------------------------${NC}"