#!/bin/bash

################################################################################
# Travian Server Installation Script
# Tự động cài đặt và cấu hình Travian Server trên Ubuntu/Debian
################################################################################

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Hàm in log với màu sắc
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Hàm thực thi lệnh với log
execute_command() {
    local description="$1"
    local command="$2"
    
    log_info "$description"
    
    if eval "$command" > /tmp/travian_install_cmd.log 2>&1; then
        log_success "$description - Hoàn thành"
        return 0
    else
        log_error "$description - Thất bại"
        cat /tmp/travian_install_cmd.log
        return 1
    fi
}

################################################################################
# BƯỚC 0: Kiểm tra quyền root và nhập thông tin cấu hình
################################################################################

log_info "==================================================================="
log_info "      TRAVIAN SERVER INSTALLATION SCRIPT - Ubuntu/Debian"
log_info "==================================================================="
echo ""

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
    log_error "Script này phải chạy với quyền root"
    log_info "Vui lòng chạy: sudo bash $0"
    exit 1
fi

log_success "Đang chạy với quyền root"

# Nhập thông tin cấu hình từ người dùng
echo ""
log_info "=== NHẬP THÔNG TIN CẤU HÌNH ==="
echo ""

# Database configuration
read -p "MySQL Root Password (mới): " DB_ROOT_PASS
read -p "MySQL Database Host [localhost]: " DB_HOST
DB_HOST=${DB_HOST:-localhost}
read -p "MySQL Database Port [3306]: " DB_PORT
DB_PORT=${DB_PORT:-3306}
read -p "MySQL Travian User [travian_user]: " DB_USER
DB_USER=${DB_USER:-travian_user}
read -p "MySQL Travian User Password: " DB_PASS

echo ""

# Server configuration
read -p "Server Name/Domain (vd: game.example.com): " SERVER_NAME
read -p "Admin Email: " ADMIN_EMAIL
read -p "Default Language [en]: " DEFAULT_LANG
DEFAULT_LANG=${DEFAULT_LANG:-en}
read -p "Timezone [UTC]: " TIMEZONE
TIMEZONE=${TIMEZONE:-UTC}
read -p "Discord Webhook URL (optional, enter để bỏ qua): " DISCORD_WEBHOOK

echo ""
log_info "Bắt đầu cài đặt với các thông tin sau:"
log_info "- Server Name: $SERVER_NAME"
log_info "- Admin Email: $ADMIN_EMAIL"
log_info "- Database Host: $DB_HOST:$DB_PORT"
log_info "- Database User: $DB_USER"
echo ""

read -p "Xác nhận bắt đầu cài đặt? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    log_warning "Hủy cài đặt"
    exit 0
fi

# Tạo tên server không có ký tự đặc biệt (cho database và directory names)
SERVER_NAME_SAFE=$(echo "$SERVER_NAME" | sed 's/[.-]/_/g')

################################################################################
# BƯỚC 1: Thiết lập quyền installer
################################################################################

log_info ""
log_info "=== BƯỚC 0 (6%): Thiết lập quyền installer ==="

execute_command "Thiết lập quyền cho installer scripts" \
    "chmod +x /installer/setup.sh 2>/dev/null || true"

execute_command "Thiết lập quyền cho thư mục installer" \
    "chmod -R 755 /installer 2>/dev/null || true"

################################################################################
# BƯỚC 2: Tải mã nguồn Travian từ GitHub
################################################################################

log_info ""
log_info "=== BƯỚC 1 (8%): Tải mã nguồn Travian từ GitHub ==="

# Xóa thư mục travian cũ nếu tồn tại
execute_command "Xóa thư mục /travian cũ (nếu có)" \
    "rm -rf /travian"

# Clone từ GitHub
if execute_command "Clone TravianT4.6 từ GitHub" \
    "git clone https://github.com/ncha103/TravianT4.6.git /travian"; then
    log_success "Tải mã nguồn thành công"
else
    log_warning "Git clone thất bại, thử phương pháp backup với wget"
    
    execute_command "Tải file ZIP từ GitHub" \
        "wget -O /tmp/travian.zip https://github.com/ncha103/TravianT4.6/archive/refs/heads/main.zip"
    
    execute_command "Giải nén mã nguồn" \
        "unzip -q /tmp/travian.zip -d /tmp/"
    
    execute_command "Di chuyển file đến /travian" \
        "mv /tmp/TravianT4.6-main /travian"
    
    execute_command "Xóa file ZIP tạm" \
        "rm /tmp/travian.zip"
fi

# Kiểm tra thư mục tồn tại
if [ ! -d "/travian" ]; then
    log_error "Không thể tải mã nguồn Travian"
    exit 1
fi

# Thiết lập quyền
execute_command "Thiết lập ownership cho /travian" \
    "chown -R root:root /travian"

execute_command "Thiết lập permissions cho /travian" \
    "chmod -R 755 /travian"

################################################################################
# BƯỚC 3: Cập nhật hệ thống và cài đặt gói thiết yếu
################################################################################

log_info ""
log_info "=== BƯỚC 2 (10%): Cập nhật hệ thống ==="

execute_command "Cập nhật package list" \
    "DEBIAN_FRONTEND=noninteractive apt-get update"

execute_command "Nâng cấp các gói hệ thống" \
    "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"

log_info ""
log_info "=== BƯỚC 2 (15%): Cài đặt các gói thiết yếu ==="

# Danh sách các gói cần cài
ESSENTIAL_PACKAGES=(
    "software-properties-common"
    "git"
    "curl"
    "wget"
    "unzip"
    "apt-transport-https"
)

for package in "${ESSENTIAL_PACKAGES[@]}"; do
    execute_command "Cài đặt $package" \
        "DEBIAN_FRONTEND=noninteractive apt-get install -y $package"
done

################################################################################
# BƯỚC 4: Tạo user travian và cấu trúc thư mục
################################################################################

log_info ""
log_info "=== BƯỚC 3 (20%): Tạo user và thư mục ==="

# Tạo user travian
execute_command "Tạo user travian" \
    "useradd -r -s /bin/bash -d /home/travian -m travian 2>/dev/null || true"

execute_command "Thêm travian vào nhóm sudo" \
    "usermod -aG sudo travian 2>/dev/null || true"

# Tạo sudoers entry cho travian
execute_command "Cấu hình sudo cho user travian" \
    "echo 'travian ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/travian"

execute_command "Thiết lập quyền cho sudoers file" \
    "chmod 440 /etc/sudoers.d/travian"

# Tạo cấu trúc thư mục
log_info "Tạo cấu trúc thư mục cho Travian..."

DIRECTORIES=(
    "/home/travian/gpack"
    "/home/travian/servers/ts3/public"
    "/home/travian/servers/ts3/include"
    "/home/travian/servers/ts2/public"
    "/home/travian/servers/ts2/include"
    "/home/travian/logs"
    "/home/travian/backups"
    "/home/travian/tmp"
)

for dir in "${DIRECTORIES[@]}"; do
    execute_command "Tạo thư mục: $dir" \
        "mkdir -p $dir"
done

# Thiết lập ownership
execute_command "Thiết lập ownership cho /home/travian" \
    "chown -R travian:travian /home/travian"

execute_command "Thiết lập permissions cho /home/travian" \
    "chmod -R 755 /home/travian"

################################################################################
# BƯỚC 5: Cài đặt và cấu hình Nginx
################################################################################

log_info ""
log_info "=== BƯỚC 4 (25%): Cài đặt Nginx ==="

execute_command "Cài đặt Nginx" \
    "DEBIAN_FRONTEND=noninteractive apt-get install -y nginx"

# Tạo nginx user nếu chưa tồn tại
execute_command "Tạo nginx user" \
    "useradd -r -s /bin/false nginx 2>/dev/null || true"

# Thiết lập ownership cho các thư mục nginx
execute_command "Thiết lập ownership cho nginx logs" \
    "chown -R travian:travian /var/log/nginx"

execute_command "Thiết lập ownership cho nginx config" \
    "chown -R travian:travian /etc/nginx"

execute_command "Thiết lập ownership cho nginx cache" \
    "chown -R travian:travian /var/cache/nginx 2>/dev/null || true"

execute_command "Thiết lập ownership cho nginx lib" \
    "chown -R travian:travian /var/lib/nginx 2>/dev/null || true"

# Khởi động Nginx
execute_command "Khởi động Nginx" \
    "systemctl start nginx"

execute_command "Kích hoạt Nginx auto-start" \
    "systemctl enable nginx"

################################################################################
# BƯỚC 6: Cài đặt và cấu hình MySQL
################################################################################

log_info ""
log_info "=== BƯỚC 5 (30%): Cài đặt MySQL 8.0 ==="

execute_command "Cài đặt MySQL Server và Client" \
    "DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server mysql-client"

execute_command "Khởi động MySQL" \
    "systemctl start mysql"

execute_command "Kích hoạt MySQL auto-start" \
    "systemctl enable mysql"

log_info ""
log_info "=== BƯỚC 6 (35%): Cấu hình MySQL ==="

# Tạo file cấu hình MySQL
log_info "Tạo file cấu hình MySQL..."

cat >> /etc/mysql/mysql.conf.d/travian.cnf << EOF
# Travian Server MySQL Configuration
[mysqld]
default_authentication_plugin = mysql_native_password
bind-address = 0.0.0.0
port = 3306
max_connections = 200
max_allowed_packet = 64M
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
tmp_table_size = 32M
max_heap_table_size = 32M
slow_query_log = 1
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 2

[client]
user=root
password=$DB_ROOT_PASS
host=localhost
port=3306
EOF

log_success "File cấu hình MySQL đã được tạo"

# Tạo thư mục log
execute_command "Tạo thư mục MySQL log" \
    "mkdir -p /var/log/mysql"

execute_command "Thiết lập ownership cho MySQL logs" \
    "chown mysql:mysql /var/log/mysql"

# Restart MySQL với cấu hình mới
execute_command "Restart MySQL với cấu hình mới" \
    "systemctl restart mysql"

# Đợi MySQL khởi động
log_info "Đợi MySQL khởi động..."
sleep 5

# Secure MySQL installation
log_info "Thực hiện MySQL secure installation..."

# Tạo script để secure MySQL
cat > /tmp/mysql_secure.sh << EOF
#!/bin/bash
# Thiết lập password cho root
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_ROOT_PASS';"

# Xóa anonymous users
mysql -u root -p'$DB_ROOT_PASS' -e "DELETE FROM mysql.user WHERE User='';"

# Chỉ cho phép root login từ localhost
mysql -u root -p'$DB_ROOT_PASS' -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"

# Xóa test database
mysql -u root -p'$DB_ROOT_PASS' -e "DROP DATABASE IF EXISTS test;"
mysql -u root -p'$DB_ROOT_PASS' -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"

# Reload privileges
mysql -u root -p'$DB_ROOT_PASS' -e "FLUSH PRIVILEGES;"
EOF

execute_command "Thiết lập quyền cho MySQL secure script" \
    "chmod +x /tmp/mysql_secure.sh"

execute_command "Chạy MySQL secure installation" \
    "/tmp/mysql_secure.sh"

execute_command "Xóa MySQL secure script" \
    "rm /tmp/mysql_secure.sh"

################################################################################
# BƯỚC 7: Cài đặt và cấu hình PHP 7.4
################################################################################

log_info ""
log_info "=== BƯỚC 7 (40%): Cài đặt PHP 7.4 ==="

execute_command "Thêm PHP PPA repository" \
    "add-apt-repository -y ppa:ondrej/php"

execute_command "Cập nhật package list" \
    "apt-get update"

# Danh sách PHP packages
PHP_PACKAGES="php7.4 php7.4-fpm php7.4-mysql php7.4-pdo php7.4-sqlite3 php7.4-memcache php7.4-redis php7.4-gd php7.4-mbstring php7.4-xml php7.4-curl php7.4-zip php7.4-intl php7.4-bcmath"

execute_command "Cài đặt PHP và các extension" \
    "DEBIAN_FRONTEND=noninteractive apt-get install -y $PHP_PACKAGES"

log_info ""
log_info "=== BƯỚC 7 (45%): Cấu hình PHP ==="

# Cấu hình PHP cơ bản
log_info "Cấu hình PHP settings..."

cat >> /etc/php/7.4/fpm/php.ini << EOF

; Travian Server Configuration
max_execution_time = 300
max_input_time = 60
memory_limit = 256M
zlib.output_compression = Off
post_max_size = 50M
upload_max_filesize = 50M
max_file_uploads = 20
EOF

# Cấu hình OPcache
cat >> /etc/php/7.4/fpm/php.ini << EOF

; OPcache Configuration
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
opcache.save_comments=1
EOF

log_success "PHP configuration đã được tạo"

# Cấu hình PHP-FPM pool
log_info "Cấu hình PHP-FPM pool..."

cat > /etc/php/7.4/fpm/pool.d/www.conf << EOF
[www]
user = travian
group = travian
listen = 127.0.0.1:9000
listen.owner = travian
listen.group = travian
listen.mode = 0660
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500
pm.process_idle_timeout = 10s
pm.max_requests = 1000
php_admin_value[error_log] = /var/log/php7.4-fpm/www-error.log
php_admin_flag[log_errors] = on
php_value[session.save_handler] = files
php_value[session.save_path] = /var/lib/php/sessions
php_value[soap.wsdl_cache_dir] = /var/lib/php/wsdlcache
EOF

log_success "PHP-FPM pool configuration đã được tạo"

# Tạo thư mục session
execute_command "Tạo thư mục PHP sessions" \
    "mkdir -p /var/lib/php/sessions"

execute_command "Thiết lập ownership cho PHP lib" \
    "chown -R travian:travian /var/lib/php"

# Restart PHP-FPM
execute_command "Restart PHP-FPM" \
    "systemctl restart php7.4-fpm"

execute_command "Kích hoạt PHP-FPM auto-start" \
    "systemctl enable php7.4-fpm"

################################################################################
# BƯỚC 8: Cài đặt Redis và Memcached (tùy chọn)
################################################################################

log_info ""
log_info "=== BƯỚC 8 (47%): Cài đặt Redis ==="

if execute_command "Cài đặt Redis Server" \
    "DEBIAN_FRONTEND=noninteractive apt-get install -y redis-server"; then
    
    log_info "Cấu hình Redis..."
    
    cat >> /etc/redis/redis.conf << EOF

# Redis Configuration for Travian
bind 127.0.0.1
port 6379
timeout 300
tcp-keepalive 60
maxmemory 256mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
EOF
    
    execute_command "Khởi động Redis" \
        "systemctl start redis"
    
    execute_command "Kích hoạt Redis auto-start" \
        "systemctl enable redis"
else
    log_warning "Redis installation thất bại, tiếp tục mà không có Redis"
fi

log_info ""
log_info "=== BƯỚC 8 (48%): Cài đặt Memcached ==="

if execute_command "Cài đặt Memcached" \
    "DEBIAN_FRONTEND=noninteractive apt-get install -y memcached"; then
    
    log_info "Cấu hình Memcached..."
    
    cat > /etc/memcached.conf << EOF
# Memcached Configuration for Travian
-p 11211
-u memcached
-m 256
-c 1024
-l 127.0.0.1
EOF
    
    execute_command "Khởi động Memcached" \
        "systemctl start memcached"
    
    execute_command "Kích hoạt Memcached auto-start" \
        "systemctl enable memcached"
else
    log_warning "Memcached installation thất bại, tiếp tục mà không có Memcached"
fi

################################################################################
# BƯỚC 9: Thiết lập databases
################################################################################

log_info ""
log_info "=== BƯỚC 9 (50%): Thiết lập databases ==="

# Tạo script để setup databases
cat > /tmp/setup_databases.sh << EOF
#!/bin/bash
mysql -u root -p'$DB_ROOT_PASS' << 'MYSQL_EOF'
CREATE DATABASE IF NOT EXISTS main;
CREATE DATABASE IF NOT EXISTS ${SERVER_NAME_SAFE}_ts2;
CREATE DATABASE IF NOT EXISTS ${SERVER_NAME_SAFE}_ts3;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
# Cập nhật password nếu user đã tồn tại (cho trường hợp chạy lại script)
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON main.* TO '$DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON ${SERVER_NAME_SAFE}_ts2.* TO '$DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON ${SERVER_NAME_SAFE}_ts3.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_EOF
EOF

execute_command "Thiết lập quyền cho database setup script" \
    "chmod +x /tmp/setup_databases.sh"

execute_command "Tạo databases và user" \
    "/tmp/setup_databases.sh"

execute_command "Xóa database setup script" \
    "rm /tmp/setup_databases.sh"

# Import main.sql nếu tồn tại
if [ -f "/travian/main.sql" ]; then
    execute_command "Import main database schema" \
        "mysql -u root -p'$DB_ROOT_PASS' main < /travian/main.sql"
fi

################################################################################
# BƯỚC 10: Thiết lập các file ứng dụng
################################################################################

log_info ""
log_info "=== BƯỚC 10 (52%): Thiết lập application files ==="

# Tạo các thư mục bổ sung
ADDITIONAL_DIRS=(
    "/travian/tmp"
    "/travian/logs"
    "/travian/backups"
    "/travian/cache"
)

for dir in "${ADDITIONAL_DIRS[@]}"; do
    execute_command "Tạo thư mục: $dir" \
        "mkdir -p $dir"
done

# Thiết lập permissions
execute_command "Thiết lập ownership cho /travian" \
    "chown -R travian:travian /travian"

execute_command "Thiết lập permissions cho /travian" \
    "chmod -R 755 /travian"

# Thiết lập quyền cho các file nhạy cảm
if [ -f "/travian/main.sql" ]; then
    execute_command "Thiết lập permissions cho main.sql" \
        "chmod 600 /travian/main.sql"
fi

if [ -f "/travian/dbbackup.php" ]; then
    execute_command "Thiết lập permissions cho dbbackup.php" \
        "chmod 644 /travian/dbbackup.php"
fi

# Tạo gpack symlink nếu tồn tại
if [ -d "/travian/sections/gpack" ]; then
    execute_command "Tạo gpack symlink" \
        "ln -sf /travian/sections/gpack /travian/gpack"
    log_success "Gpack symlink đã được tạo"
else
    log_warning "Thư mục gpack không tìm thấy trong sections"
fi

# Tạo thư mục cache cho gpack
execute_command "Tạo gpack cache directory" \
    "mkdir -p /travian/cache/gpack"

execute_command "Thiết lập ownership cho cache" \
    "chown -R travian:travian /travian/cache"

################################################################################
# BƯỚC 11: Tạo thư mục application với tên server
################################################################################

log_info ""
log_info "=== BƯỚC 11 (55%): Tạo application directories ==="

SERVER_DIR="/home/travian/${SERVER_NAME_SAFE}/servers/ts3"

execute_command "Tạo public directory" \
    "mkdir -p ${SERVER_DIR}/public"

execute_command "Tạo include directory" \
    "mkdir -p ${SERVER_DIR}/include"

execute_command "Thiết lập ownership cho server directories" \
    "chown -R travian:travian /home/travian/"

################################################################################
# BƯỚC 12: Cấu hình Nginx
################################################################################

log_info ""
log_info "=== BƯỚC 12 (60%): Cấu hình Nginx ==="

# Xóa cấu hình Nginx cũ
execute_command "Xóa cấu hình Nginx cũ" \
    "rm -rf /etc/nginx/conf.d/* /etc/nginx/sites-enabled/* /etc/nginx/partial.d"

# Tạo nginx main configuration
log_info "Tạo Nginx main configuration..."

cat > /etc/nginx/nginx.conf << 'EOF'
user travian;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 50M;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Gzip Configuration
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    include /etc/nginx/conf.d/*.conf;
}
EOF

log_success "Nginx main configuration đã được tạo"

# Tạo thư mục partials
execute_command "Tạo nginx partials directory" \
    "mkdir -p /etc/nginx/partial.d"

# Tạo default server configuration
# log_info "Tạo default server configuration..."
# 
# cat > /etc/nginx/conf.d/default.conf << 'EOF'
# # Default server configuration
# server {
#     listen 80 default_server;
#     listen [::]:80 default_server;
#     server_name _;
#     root /var/www/html;
#     index index.html index.htm;
# 
#     location / {
#         try_files $uri $uri/ =404;
#     }
# 
#     error_page 404 /404.html;
#     location = /404.html {
#     }
# 
#     error_page 500 502 503 504 /50x.html;
#     location = /50x.html {
#     }
# }
# EOF
# 
# log_success "Default server configuration đã được tạo"

# Tạo Travian defaults partial
log_info "Tạo Travian defaults partial..."

cat > /etc/nginx/partial.d/travian_defaults.conf << 'EOF'
# Travian Server Defaults
# Include this in your server blocks

# Security headers
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";

# Main location block
location / {
    try_files $uri $uri/ /index.php?$query_string;
}

# PHP processing
location ~ \.php$ {
    fastcgi_pass 127.0.0.1:9000;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
    fastcgi_read_timeout 300;
    fastcgi_connect_timeout 300;
    fastcgi_send_timeout 300;
}

# Static files caching
location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    access_log off;
}

# Deny access to sensitive files
location ~ /\. {
    deny all;
    access_log off;
    log_not_found off;
}

location ~ \.(sql|log|conf)$ {
    deny all;
    access_log off;
    log_not_found off;
}
EOF

log_success "Travian defaults partial đã được tạo"

# Tạo server-specific configuration
log_info "Tạo server-specific configuration..."

cat > /etc/nginx/conf.d/${SERVER_NAME_SAFE}_ts3.conf << EOF
# HTTP server
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    #server_name $SERVER_NAME;
    server_name _;
    root /travian/main_script/public;
    index index.php index.html;

    # Include Travian defaults
    include /etc/nginx/partial.d/travian_defaults.conf;
}
EOF

log_success "Server-specific configuration đã được tạo"

# Thiết lập ownership
execute_command "Thiết lập ownership cho nginx config" \
    "chown -R travian:travian /etc/nginx"

execute_command "Thiết lập ownership cho nginx logs" \
    "chown -R travian:travian /var/log/nginx"

# Test và restart Nginx
execute_command "Test Nginx configuration" \
    "nginx -t"

execute_command "Restart Nginx" \
    "systemctl restart nginx"

################################################################################
# BƯỚC 14: Tạo các file cấu hình
################################################################################

log_info ""
log_info "=== BƯỚC 14 (70%): Tạo configuration files ==="

# Global config
log_info "Tạo global configuration..."

cat > /home/travian/${SERVER_NAME_SAFE}/globalConfig.php << EOF
<?php
global \$globalConfig;
\$globalConfig = [];

// Static Parameters
\$globalConfig['staticParameters'] = [];
\$globalConfig['staticParameters']['default_language'] = '$DEFAULT_LANG';
\$globalConfig['staticParameters']['default_timezone'] = '$TIMEZONE';
\$globalConfig['staticParameters']['indexUrl'] = 'http://$SERVER_NAME/';
\$globalConfig['staticParameters']['adminEmail'] = '$ADMIN_EMAIL';
\$globalConfig['staticParameters']['recaptcha_public_key'] = '';
\$globalConfig['staticParameters']['recaptcha_private_key'] = '';

// Database Configuration
\$globalConfig['dataSources'] = [];
\$globalConfig['dataSources']['globalDB'] = [];
\$globalConfig['dataSources']['globalDB']['hostname'] = '$DB_HOST';
\$globalConfig['dataSources']['globalDB']['username'] = '$DB_USER';
\$globalConfig['dataSources']['globalDB']['password'] = '$DB_PASS';
\$globalConfig['dataSources']['globalDB']['database'] = 'main';
\$globalConfig['dataSources']['globalDB']['charset'] = 'utf8mb4';
\$globalConfig['dataSources']['globalDB']['port'] = $DB_PORT;

// Server Configuration
\$globalConfig['server'] = [];
\$globalConfig['server']['name'] = '$SERVER_NAME';
\$globalConfig['server']['domain'] = '$SERVER_NAME';
\$globalConfig['server']['admin_email'] = '$ADMIN_EMAIL';
\$globalConfig['server']['timezone'] = '$TIMEZONE';
\$globalConfig['server']['language'] = '$DEFAULT_LANG';

// Paths
\$globalConfig['paths'] = [];
\$globalConfig['paths']['travian_root'] = '/travian/';
\$globalConfig['paths']['main_script'] = '/travian/main_script/';
\$globalConfig['paths']['gpack'] = '/travian/gpack/';
\$globalConfig['paths']['cache'] = '/travian/cache/';
\$globalConfig['paths']['logs'] = '/travian/logs/';
\$globalConfig['paths']['backups'] = '/travian/backups/';
EOF

execute_command "Thiết lập quyền cho global config" \
    "chown travian:travian /home/travian/${SERVER_NAME_SAFE}/globalConfig.php"

log_success "Global configuration đã được tạo"

# Server environment config
log_info "Tạo environment configuration..."

cat > ${SERVER_DIR}/include/env.php << 'EOF'
<?php
define("IS_DEV", false);
define("PUBLIC_PATH", dirname(__DIR__) . "/public/");
define("INCLUDE_PATH", dirname(__DIR__) . "/include/");
define("GPACK_PATH", "/travian/gpack/");
define("MAIN_SCRIPT_PATH", "/travian/main_script/");
define("TRAVIAN_ROOT", "/travian/");
EOF

execute_command "Thiết lập quyền cho env config" \
    "chown travian:travian ${SERVER_DIR}/include/env.php"

log_success "Environment configuration đã được tạo"

# Server-specific config
log_info "Tạo server-specific configuration..."

cat > ${SERVER_DIR}/include/config.php << EOF
<?php
// Server Configuration for $SERVER_NAME
\$serverConfig = [];
\$serverConfig['name'] = '$SERVER_NAME';
\$serverConfig['admin_email'] = '$ADMIN_EMAIL';
\$serverConfig['default_language'] = '$DEFAULT_LANG';
\$serverConfig['timezone'] = '$TIMEZONE';
\$serverConfig['database'] = [
    'host' => '$DB_HOST',
    'port' => '$DB_PORT',
    'user' => '$DB_USER',
    'pass' => '$DB_PASS',
    'name' => '${SERVER_NAME_SAFE}_ts3'
];
\$serverConfig['paths'] = [
    'travian_root' => '/travian/',
    'main_script' => '/travian/main_script/',
    'gpack' => '/travian/gpack/',
    'cache' => '/travian/cache/',
    'logs' => '/travian/logs/',
    'backups' => '/travian/backups/'
];
EOF

execute_command "Thiết lập quyền cho server config" \
    "chown travian:travian ${SERVER_DIR}/include/config.php"

log_success "Server-specific configuration đã được tạo"

# Gpack config
if [ -d "/travian/gpack" ]; then
    log_info "Tạo gpack configuration..."
    
    cat > /travian/gpack/config.php << 'EOF'
<?php
// Gpack Configuration
$gpackConfig = [];
$gpackConfig['path'] = '/travian/gpack/';
$gpackConfig['enabled'] = true;
$gpackConfig['cache_enabled'] = true;
$gpackConfig['cache_path'] = '/travian/cache/gpack/';
EOF
    
    execute_command "Thiết lập quyền cho gpack config" \
        "chown travian:travian /travian/gpack/config.php"
    
    log_success "Gpack configuration đã được tạo"
fi

# TaskWorker config
if [ -d "/travian/TaskWorker" ]; then
    log_info "Tạo TaskWorker configuration..."
    
    cat > /travian/TaskWorker/config.php << EOF
<?php
// TaskWorker Configuration for $SERVER_NAME
\$taskWorkerConfig = [];
\$taskWorkerConfig['users'] = [];
\$taskWorkerConfig['users']['$SERVER_NAME_SAFE'] = [];
\$taskWorkerConfig['users']['$SERVER_NAME_SAFE']['main_domain'] = '$SERVER_NAME';
\$taskWorkerConfig['users']['$SERVER_NAME_SAFE']['type'] = 'cloudflare';
\$taskWorkerConfig['users']['$SERVER_NAME_SAFE']['zone_id'] = ''; // User needs to set this
\$taskWorkerConfig['users']['$SERVER_NAME_SAFE']['email'] = '$ADMIN_EMAIL';
\$taskWorkerConfig['users']['$SERVER_NAME_SAFE']['api_key'] = ''; // User needs to set this
\$taskWorkerConfig['users']['$SERVER_NAME_SAFE']['ip'] = ''; // Auto-detected
EOF
    
    execute_command "Thiết lập quyền cho TaskWorker config" \
        "chown travian:travian /travian/TaskWorker/config.php"
    
    log_success "TaskWorker configuration đã được tạo"
fi

# Discord webhook
if [ -n "$DISCORD_WEBHOOK" ]; then
    log_info "Lưu Discord webhook..."
    echo "$DISCORD_WEBHOOK" > /travian/discord_webhook.url
    execute_command "Thiết lập quyền cho webhook file" \
        "chmod 600 /travian/discord_webhook.url"
    execute_command "Thiết lập ownership cho webhook file" \
        "chown travian:travian /travian/discord_webhook.url"
fi

################################################################################
# BƯỚC 15: Tạo systemd service
################################################################################

log_info ""
log_info "=== BƯỚC 15 (75%): Tạo systemd service ==="

SERVICE_NAME="${SERVER_NAME_SAFE}_ts3"

# Tạo systemd service file
log_info "Tạo systemd service file..."

cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Travian game engine (ts3) - $SERVER_NAME
After=network.target mysql.service

[Service]
Type=simple
User=travian
Group=travian
WorkingDirectory=${SERVER_DIR}/include
ExecStart=/usr/bin/php ${SERVER_DIR}/include/${SERVICE_NAME}.service.php
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

log_success "Systemd service file đã được tạo"

# Tạo service script
log_info "Tạo service script..."

cat > ${SERVER_DIR}/include/${SERVICE_NAME}.service.php << 'EOF'
#!/usr/bin/php -q
<?php
require __DIR__ . "/env.php";
if(IS_DEV){
    require("/travian/main_script_dev/include/AutomationEngine.php");
} else {
    require("/travian/main_script/include/AutomationEngine.php");
}
EOF

execute_command "Thiết lập quyền executable cho service script" \
    "chmod +x ${SERVER_DIR}/include/${SERVICE_NAME}.service.php"

log_success "Service script đã được tạo"

################################################################################
# BƯỚC 16: Cập nhật sync.sh và cài đặt services
################################################################################

log_info ""
log_info "=== BƯỚC 16 (80%): Cấu hình sync.sh ==="

if [ -f "/travian/Manager/sync.sh" ]; then
    # Backup file gốc
    execute_command "Backup sync.sh gốc" \
        "cp /travian/Manager/sync.sh /travian/Manager/sync.sh.bak"
    
    # Cập nhật sync.sh với server name
    log_info "Cập nhật sync.sh với server name..."
    sed -i "s/supported_users=(\"\"\)/supported_users=(\"$SERVER_NAME_SAFE\")/" /travian/Manager/sync.sh
    
    execute_command "Thiết lập quyền executable cho sync.sh" \
        "chmod +x /travian/Manager/sync.sh"
    
    execute_command "Thiết lập ownership cho sync.sh" \
        "chown travian:travian /travian/Manager/sync.sh"
    
    # Chạy install command
    execute_command "Chạy sync.sh install" \
        "cd /travian/Manager && ./sync.sh --install"
    
    log_success "sync.sh đã được cấu hình và chạy"
else
    log_warning "File sync.sh không tồn tại, bỏ qua bước này"
fi

################################################################################
# BƯỚC 17: Khởi động services
################################################################################

log_info ""
log_info "=== BƯỚC 17 (82%): Khởi động services ==="

execute_command "Reload systemd daemon" \
    "systemctl daemon-reload"

execute_command "Khởi động Travian service" \
    "systemctl start ${SERVICE_NAME}.service"

execute_command "Kích hoạt Travian service auto-start" \
    "systemctl enable ${SERVICE_NAME}.service"

################################################################################
# BƯỚC 18: Cấu hình firewall
################################################################################

log_info ""
log_info "=== BƯỚC 18 (85%): Cấu hình firewall ==="

execute_command "Cho phép HTTP (port 80)" \
    "ufw allow 80/tcp"

execute_command "Cho phép SSH (port 22)" \
    "ufw allow 22/tcp"

execute_command "Kích hoạt firewall" \
    "ufw --force enable"

################################################################################
# BƯỚC 19: Final setup và tạo admin credentials
################################################################################

log_info ""
log_info "=== BƯỚC 19 (90%): Final setup ==="

# Thiết lập Multihunter password
ADMIN_PASSWORD_HASH=$(echo -n "admin123" | sha1sum | awk '{print $1}')

execute_command "Thiết lập Multihunter password" \
    "mysql -u root -p'$DB_ROOT_PASS' -e \"UPDATE users SET password='$ADMIN_PASSWORD_HASH' WHERE id=2\" ${SERVER_NAME_SAFE}_ts3 2>/dev/null || true"

# Tạo admin token
ADMIN_TOKEN=$(openssl rand -hex 16)

execute_command "Tạo admin token" \
    "mysql -u root -p'$DB_ROOT_PASS' -e \"INSERT INTO paymentConfig (loginToken) VALUES ('$ADMIN_TOKEN') ON DUPLICATE KEY UPDATE loginToken='$ADMIN_TOKEN'\" main 2>/dev/null || true"

################################################################################
# BƯỚC 20: Tạo admin access URL
################################################################################

log_info ""
log_info "=== BƯỚC 20 (95%): Tạo admin access ==="

LOGIN_HASH=$(echo -n "$(echo -n 'admin123' | sha1sum | awk '{print $1}')" | sha1sum | awk '{print $1}')
ADMIN_URL="http://$SERVER_NAME/login.php?action=multiLogin&hash=$LOGIN_HASH&token=$ADMIN_TOKEN"

log_success "Admin URL đã được tạo"

################################################################################
# BƯỚC 21: Tạo installation summary
################################################################################

log_info ""
log_info "=== BƯỚC 21 (97%): Tạo installation summary ==="

cat > /home/travian/INSTALLATION_SUMMARY.txt << EOF
Travian Server Installation Summary
==================================

Server Information:
- Server Name: $SERVER_NAME
- Admin Email: $ADMIN_EMAIL
- Default Language: $DEFAULT_LANG
- Timezone: $TIMEZONE

Access Information:
- Server URL: http://$SERVER_NAME
- Admin URL: $ADMIN_URL
- Admin Username: admin
- Admin Password: admin123

File Structure:
- Travian Root: /travian/
- Main Script: /travian/main_script/
- Gpack Files: /travian/gpack/
- Server Config: ${SERVER_DIR}/
- Global Config: /home/travian/${SERVER_NAME_SAFE}/globalConfig.php
- Logs: /travian/logs/
- Backups: /travian/backups/
- Cache: /travian/cache/

Database Information:
- Host: $DB_HOST
- Port: $DB_PORT
- User: $DB_USER
- Databases: main, ${SERVER_NAME_SAFE}_ts2, ${SERVER_NAME_SAFE}_ts3

Services:
- Nginx: Web Server
- MySQL: Database Server
- PHP-FPM: PHP Process Manager
- Redis: Caching (if installed)
- Memcached: Caching (if installed)
- Travian Service: ${SERVICE_NAME}.service

Management Commands:
- systemctl status ${SERVICE_NAME}.service: Kiểm tra trạng thái service
- systemctl restart ${SERVICE_NAME}.service: Restart service
- systemctl start ${SERVICE_NAME}.service: Khởi động service
- systemctl stop ${SERVICE_NAME}.service: Dừng service

Installation completed on: $(date '+%Y-%m-%d %H:%M:%S')
EOF

execute_command "Thiết lập quyền cho summary file" \
    "chown travian:travian /home/travian/INSTALLATION_SUMMARY.txt"

log_success "Installation summary đã được tạo"

################################################################################
# HOÀN TẤT CÀI ĐẶT
################################################################################

log_info ""
log_info "==================================================================="
log_success "CÀI ĐẶT HOÀN TẤT (100%)"
log_info "==================================================================="
echo ""

log_success "Travian Server đã được cài đặt thành công!"
echo ""

log_info "📝 THÔNG TIN TRUY CẬP:"
echo ""
log_info "Server URL: http://$SERVER_NAME"
log_info "Admin URL: $ADMIN_URL"
log_info "Admin Username: admin"
log_info "Admin Password: admin123"
echo ""

log_info "📂 FILE VÀ THÔNG TIN QUAN TRỌNG:"
log_info "- Installation Summary: /home/travian/INSTALLATION_SUMMARY.txt"
log_info "- Travian Files: /travian/"
log_info "- Configuration: ${SERVER_DIR}/include/"
log_info "- Logs: /travian/logs/"
echo ""

log_info "🔧 QUẢN LÝ SERVICE:"
log_info "- Kiểm tra trạng thái: systemctl status ${SERVICE_NAME}.service"
log_info "- Khởi động: systemctl start ${SERVICE_NAME}.service"
log_info "- Dừng: systemctl stop ${SERVICE_NAME}.service"
log_info "- Restart: systemctl restart ${SERVICE_NAME}.service"
log_info "- Xem logs: journalctl -u ${SERVICE_NAME}.service -f"
echo ""

log_warning "⚠️  LƯU Ý:"
log_info "1. Đổi password admin ngay sau khi đăng nhập lần đầu"
log_info "2. Thay thế self-signed SSL certificate bằng Let's Encrypt cho production"
log_info "3. Cấu hình Cloudflare Zone ID và API Key trong TaskWorker config nếu cần"
log_info "4. Thiết lập backup định kỳ cho database và files"
echo ""

log_success "🎮 Chúc bạn vận hành server thành công!"
echo ""
