#!/bin/bash
set -e

echo "🚀 Starting Travian Server Installer Container"
echo "=============================================="
echo ""

# Start MySQL service
echo "📦 Starting MySQL service..."
service mysql start

# Wait for MySQL to be ready
echo "⏳ Waiting for MySQL to be ready..."
until mysqladmin ping -h localhost --silent; do
    sleep 1
done
echo "✅ MySQL is ready"

# Start Redis service
echo "📦 Starting Redis service..."
service redis-server start

# Start Memcached service
echo "📦 Starting Memcached service..."
service memcached start

# Start PHP-FPM service
echo "📦 Starting PHP-FPM service..."
mkdir -p /run/php
if [ -x /etc/init.d/php7.4-fpm ]; then
    /etc/init.d/php7.4-fpm start
else
    echo "⚠️ PHP-FPM init script not found, skipping..."
fi

echo ""
echo "✅ All services started successfully!"
echo ""
echo "🌐 Travian Server Installer is now available at:"
echo "   http://localhost:8080"
echo ""
echo "📝 To access from your host machine:"
echo "   http://localhost:8080"
echo ""
echo "⚠️  Note: This container runs the web installer interface."
echo "   The actual Travian server installation will configure"
echo "   the host system as specified in the installer."
echo ""

# Execute the main command
exec "$@"
