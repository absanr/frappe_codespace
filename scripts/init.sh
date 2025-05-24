#!bin/bash

set -e

if [[ -f "/workspaces/frappe_codespace/frappe-bench/apps/frappe" ]]
then
    echo "Bench already exists, skipping init"
    exit 0
fi

rm -rf /workspaces/frappe_codespace/.git

# Set permissions for the current script
SCRIPT_PATH="$(realpath "$0")"
chmod +x "$SCRIPT_PATH"
echo "Permissions set for: $SCRIPT_PATH"

source /home/frappe/.nvm/nvm.sh
nvm alias default 18
nvm use 18

echo "nvm use 18" >> ~/.bashrc
cd /workspace

bench init \
--ignore-exist \
--skip-redis-config-generation \
frappe-bench

cd frappe-bench

# Use containers instead of localhost
bench set-mariadb-host mariadb
bench set-redis-cache-host redis-cache:6379
bench set-redis-queue-host redis-queue:6379
bench set-redis-socketio-host redis-socketio:6379

# Ensuring Redis URLs are properly configured in common_site_config.json...
CONFIG_FILE="/workspace/frappe-bench/sites/common_site_config.json"
sed -i 's/redis-cache:6379/redis:\/\/redis-cache:6379/' "$CONFIG_FILE"
sed -i 's/redis-queue:6379/redis:\/\/redis-queue:6379/' "$CONFIG_FILE"
sed -i 's/redis-socketio:6379/redis:\/\/redis-socketio:6379/' "$CONFIG_FILE"
echo "Redis URLs verified and correctly set."

# Remove redis from Procfile
sed -i '/redis/d' ./Procfile

# ---------------------------------------------------------------------------------------
# Check MariaDB availability
# ---------------------------------------------------------------------------------------
echo "Checking MariaDB availability..."
until mysql -hmariadb -uroot -p123 -e "SELECT 1;" >/dev/null 2>&1; do
  echo "Waiting for MariaDB to be available..."
  sleep 3
done
echo "MariaDB is available."

# ---------------------------------------------------------------------------------------
# Create site using root
# ---------------------------------------------------------------------------------------
create_site_with_root() {
  echo "Trying to create site with root user..."
  if ! bench new-site dev.localhost \
    --mariadb-root-username root \
    --mariadb-root-password 123 \
    --admin-password admin \
    --db-host mariadb \
    --mariadb-user-host-login-scope=%; then
    echo "Critical error: Failed to create site using root."
    exit 1
  else
    echo "Site created successfully."
  fi
}

create_site_with_root               

# ---------------------------------------------------------------------------------------
# Additional site configuration
# ---------------------------------------------------------------------------------------
bench --site dev.localhost set-config developer_mode 1
bench --site dev.localhost clear-cache
bench use dev.localhost
