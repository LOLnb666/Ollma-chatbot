#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_NAME="${WP_DB_NAME:-FURNITURE}"
DB_USER="${WP_DB_USER:-furniture_wp}"
DB_PASSWORD="${WP_DB_PASSWORD:-$(openssl rand -hex 24)}"
ADMIN_USER="${WP_ADMIN_USER:-furniture_admin}"
ADMIN_PASSWORD="${WP_ADMIN_PASSWORD:-$(openssl rand -hex 16)}"
ADMIN_EMAIL="${WP_ADMIN_EMAIL:-admin@furniture.local}"
SITE_URL="${WP_URL:-http://localhost}"
SITE_TITLE="${WP_TITLE:-家具官网}"
CREDENTIALS_FILE="$PROJECT_DIR/.wordpress-credentials"

if [[ $EUID -ne 0 ]]; then
  echo "请使用 root 运行：sudo $0" >&2
  exit 1
fi

for value in "$DB_NAME" "$DB_USER"; do
  if [[ ! "$value" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "数据库名和用户名只能包含字母、数字和下划线。" >&2
    exit 1
  fi
done
if [[ ! "$DB_PASSWORD" =~ ^[A-Za-z0-9._~-]+$ ]]; then
  echo "数据库密码只能包含字母、数字及 . _ ~ - 字符。" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y software-properties-common ca-certificates curl apache2 mysql-server
if ! apt-cache show php8.2-cli >/dev/null 2>&1; then
  add-apt-repository -y ppa:ondrej/php
  apt-get update
fi
apt-get install -y php8.2 php8.2-cli libapache2-mod-php8.2 php8.2-curl php8.2-gd \
  php8.2-intl php8.2-mbstring php8.2-mysql php8.2-xml php8.2-zip

a2dismod php8.3 >/dev/null 2>&1 || true
a2enmod php8.2 rewrite
systemctl enable --now mysql apache2

mysql --protocol=socket -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL

if ! command -v wp >/dev/null 2>&1; then
  curl --fail --location --retry 3 \
    https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    --output /usr/local/bin/wp
  chmod 0755 /usr/local/bin/wp
fi

if [[ ! -f "$PROJECT_DIR/wp-load.php" ]]; then
  wp core download --path="$PROJECT_DIR" --locale=zh_CN --force --allow-root
fi

if [[ ! -f "$PROJECT_DIR/wp-config.php" ]]; then
  wp config create --path="$PROJECT_DIR" --dbname="$DB_NAME" --dbuser="$DB_USER" \
    --dbpass="$DB_PASSWORD" --dbhost=localhost --dbcharset=utf8mb4 \
    --skip-check --allow-root
  chmod 0640 "$PROJECT_DIR/wp-config.php"
fi

cat >/etc/apache2/sites-available/furniture-wordpress.conf <<APACHE
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot "$PROJECT_DIR"
    DirectoryIndex index.php
    <Directory "$PROJECT_DIR">
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/furniture-wordpress-error.log
    CustomLog \${APACHE_LOG_DIR}/furniture-wordpress-access.log combined
</VirtualHost>
APACHE
a2dissite 000-default >/dev/null 2>&1 || true
a2ensite furniture-wordpress
apache2ctl configtest
systemctl restart apache2

if ! wp core is-installed --path="$PROJECT_DIR" --allow-root 2>/dev/null; then
  wp core install --path="$PROJECT_DIR" --url="$SITE_URL" --title="$SITE_TITLE" \
    --admin_user="$ADMIN_USER" --admin_password="$ADMIN_PASSWORD" \
    --admin_email="$ADMIN_EMAIL" --skip-email --allow-root
fi

umask 077
cat >"$CREDENTIALS_FILE" <<CREDS
后台地址: ${SITE_URL%/}/wp-admin/
管理员账号: $ADMIN_USER
管理员密码: $ADMIN_PASSWORD
数据库: $DB_NAME
数据库用户: $DB_USER
数据库密码: $DB_PASSWORD
CREDS
chmod 0600 "$CREDENTIALS_FILE"

echo "WordPress 安装完成。登录信息保存在 $CREDENTIALS_FILE"
cat "$CREDENTIALS_FILE"
