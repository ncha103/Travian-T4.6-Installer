# Travian Server Installer - Dockerfile
# Based on Ubuntu 22.04 with PHP 7.4 and required dependencies

FROM ubuntu:22.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Set working directory
WORKDIR /installer

# Install system dependencies and PHP
RUN apt-get update && apt-get install -y \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    curl \
    wget \
    git \
    unzip \
    gnupg \
    lsb-release \
    && add-apt-repository -y ppa:ondrej/php \
    && apt-get update \
    && apt-get install -y \
    php7.4 \
    php7.4-cli \
    php7.4-fpm \
    php7.4-mysql \
    php7.4-pdo \
    php7.4-sqlite3 \
    php7.4-gd \
    php7.4-mbstring \
    php7.4-xml \
    php7.4-curl \
    php7.4-zip \
    php7.4-intl \
    php7.4-bcmath \
    php7.4-posix \
    nginx \
    mysql-server \
    mysql-client \
    redis-server \
    memcached \
    ufw \
    openssl \
    certbot \
    python3-certbot-nginx \
    sudo \
    dos2unix \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/sbin/php-fpm7.4 /usr/sbin/php-fpm

# Configure PHP
RUN echo "max_execution_time = 300" >> /etc/php/7.4/cli/php.ini \
    && echo "memory_limit = 256M" >> /etc/php/7.4/cli/php.ini \
    && echo "post_max_size = 50M" >> /etc/php/7.4/cli/php.ini \
    && echo "upload_max_filesize = 50M" >> /etc/php/7.4/cli/php.ini

# Create necessary directories
RUN mkdir -p /tmp/travian_installer \
    && mkdir -p /var/log/travian_installer \
    && mkdir -p /travian \
    && chmod -R 755 /tmp/travian_installer \
    && chmod -R 755 /var/log/travian_installer

# Copy installer files
COPY . /installer/

# Set proper permissions
RUN chmod +x /installer/launch.php \
    && chmod +x /installer/setup.sh \
    && chmod -R 755 /installer

# Expose port for web installer
EXPOSE 8080

# Set up entrypoint
COPY docker-entrypoint.sh /usr/local/bin/
RUN dos2unix /usr/local/bin/docker-entrypoint.sh \
    && chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

# Default command: start the installer web server
CMD ["php", "-S", "0.0.0.0:8080", "-t", "/installer"]
