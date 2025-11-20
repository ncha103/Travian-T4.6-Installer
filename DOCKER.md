# Docker Installation Guide

## 🐳 Running Travian Server Installer with Docker

This guide explains how to run the Travian Server Installer in a Docker container.

## Prerequisites

- Docker installed on your system ([Get Docker](https://docs.docker.com/get-docker/))
- Docker Compose installed ([Get Docker Compose](https://docs.docker.com/compose/install/))
- At least 4GB of available RAM
- At least 10GB of free disk space

## Quick Start

### Option 1: Using Docker Compose (Recommended)

```bash
# Clone the repository (if you haven't already)
git clone https://github.com/ncha103/Travian-T4.6-Installer.git
cd Travian-T4.6-Installer

# Build and start the container
docker-compose up -d

# View logs
docker-compose logs -f
```

Access the installer at: **http://localhost:8080**

### Option 2: Using Docker directly

```bash
# Build the Docker image
docker build -t travian-installer .

# Run the container
docker run -d \
  --name travian-installer \
  -p 8080:8080 \
  -v travian-data:/travian \
  -v installer-logs:/var/log/travian_installer \
  --privileged \
  travian-installer

# View logs
docker logs -f travian-installer
```

Access the installer at: **http://localhost:8080**

## Container Details

### What's Included

The Docker container includes:
- **Ubuntu 22.04** base system
- **PHP 7.4** with all required extensions
- **MySQL Server** for database
- **Nginx** web server
- **Redis** for caching
- **Memcached** for session management
- All system dependencies pre-installed

### Ports

- **8080** - Web installer interface

### Volumes

- **travian-data** - Travian server files and game data
- **installer-logs** - Installation logs and debugging information
- **mysql-data** - MySQL database files

## Usage

### Starting the Container

```bash
docker-compose up -d
```

### Stopping the Container

```bash
docker-compose down
```

### Restarting the Container

```bash
docker-compose restart
```

### Viewing Logs

```bash
# All logs
docker-compose logs -f

# Installer logs only
docker exec travian-installer tail -f /var/log/travian_installer/*.log
```

### Accessing the Container Shell

```bash
docker exec -it travian-installer bash
```

### Checking Service Status

```bash
docker exec travian-installer service mysql status
docker exec travian-installer service php7.4-fpm status
docker exec travian-installer service redis-server status
docker exec travian-installer service memcached status
```

## Installation Process

1. **Start the container** (see Quick Start above)
2. **Open your browser** to http://localhost:8080
3. **Follow the installation wizard**:
   - Step 1: System requirements check
   - Step 2: Database configuration
   - Step 3: Server configuration
   - Step 4: Installation progress
   - Step 5: Installation complete

## Important Notes

### Container vs. Host Installation

- The Docker container runs the **web installer interface**
- The actual Travian server installation configures services **inside the container**
- All data is persisted in Docker volumes

### Privileged Mode

The container runs in privileged mode to:
- Install and configure system services (MySQL, Nginx, PHP-FPM)
- Manage user accounts and permissions
- Configure firewall rules (UFW)
- Modify system files

### Data Persistence

All important data is stored in Docker volumes:
- Game files: `/travian`
- Databases: `/var/lib/mysql`
- Logs: `/var/log/travian_installer`

Even if you remove the container, your data is preserved in volumes.

## Troubleshooting

### Container won't start

```bash
# Check if port 8080 is already in use
netstat -an | grep 8080

# Use a different port
docker run -p 8081:8080 ...
```

### MySQL connection issues

```bash
# Check MySQL is running
docker exec travian-installer service mysql status

# Restart MySQL
docker exec travian-installer service mysql restart
```

### View container logs

```bash
# Real-time logs
docker logs -f travian-installer

# Last 100 lines
docker logs --tail 100 travian-installer
```

### Reset everything

```bash
# Stop and remove container
docker-compose down

# Remove all volumes (WARNING: deletes all data)
docker-compose down -v

# Rebuild and start fresh
docker-compose up -d --build
```

## Production Deployment

For production use:

1. **Use proper SSL certificates**:
   ```bash
   # Mount certificate directory
   docker run -v /path/to/certs:/etc/ssl/certs ...
   ```

2. **Use environment variables for secrets**:
   ```bash
   # Create .env file with database passwords
   docker run --env-file .env ...
   ```

3. **Set up regular backups**:
   ```bash
   # Backup volumes
   docker run --rm -v travian-data:/data -v $(pwd):/backup ubuntu tar czf /backup/travian-backup.tar.gz /data
   ```

4. **Monitor resources**:
   ```bash
   # Check resource usage
   docker stats travian-installer
   ```

## Advanced Configuration

### Custom PHP Settings

Edit `Dockerfile` and add custom PHP configuration:

```dockerfile
RUN echo "memory_limit = 512M" >> /etc/php/7.4/cli/php.ini
```

### Custom MySQL Settings

```bash
docker exec travian-installer bash -c "echo '[mysqld]' >> /etc/mysql/my.cnf"
docker exec travian-installer bash -c "echo 'max_connections = 500' >> /etc/mysql/my.cnf"
docker exec travian-installer service mysql restart
```

### Expose Additional Ports

Edit `docker-compose.yml`:

```yaml
ports:
  - "8080:8080"  # Installer
  - "80:80"      # HTTP
  - "443:443"    # HTTPS
  - "3306:3306"  # MySQL
```

## Cleaning Up

### Remove Container Only

```bash
docker-compose down
```

### Remove Container and Images

```bash
docker-compose down --rmi all
```

### Remove Everything (including data)

```bash
docker-compose down -v
docker system prune -a
```

## Support

For issues and questions:
- Check the main [README.md](README.md)
- Join our [Discord server](https://discord.gg/ZgmNK2cQjm)
- Open an issue on GitHub

## License

Same as the main project license.
