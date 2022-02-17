#! /bin/bash
#
# Copyright (c) 2022 Bego Mario Garde
# License: MIT
#
# Creates a new wordpress site
# in a local test environment.
#
# ----
# DON`T USE ON THIS ON A PRODUCTION SERVER!
# ----
#
# Checks if run by user root,
# needs a site name,
# creates subdirectory in /var/www,
# creates SSL certificates,
# adds virtual host file,
# restarts server,
# creates MySQL database,
# downloads and installs WordPress

# Exit on first error
set -e

# Variables
SITE=${1,,}                # wp.test
NAME=${SITE%.*}            # wp
DIR=/var/www/"${SITE}"     # /var/wp/wp.test
WWWP="sudo -u www-data wp" # sudo -u www-data wp

# Use database `wordpress` for `wp.test`
# and `wp_...` for everything else.
# DB user `wordpress` has permission for all.
if [[ "$SITE" == 'wp.test' ]]; then
  DATABASE='wordpress'
else
  DATABASE="wp_${NAME}"
fi

# Execute as root, only
if [[ "$(whoami)" != 'root' ]]; then
  echo "❌ You have to execute this script as root user. Aborting script."
  exit 1
fi

# Exit, if no site name was provided
if [[ -z "$1" ]]; then
  echo "❌ No sitename provided. Aborting script."
  exit 1
fi

# Exit, if directory already exists
if [[ -d "${DIR}" ]]; then
  # Take action if $DIR exists. #
  echo "Directory ${DIR} already exist. Aborting script."
  exit 1
fi

# Create directory
mkdir -p "${DIR}"
chown www-data:www-data "${DIR}"
chmod 755 "${DIR}"
echo "Successfully created directory ${DIR}"

# Create selfsigned SSL certificate
mkcert \
  -cert-file /etc/ssl/certs/"${SITE}".pem \
  -key-file /etc/ssl/private/"${SITE}".key \
  "${SITE}" "*.${SITE}"

# Create virtual hosts and restart server
echo "<VirtualHost *:80>
    ServerAdmin wp@${SITE}
    ServerName ${SITE}
    ServerAlias www.${SITE}
    RewriteEngine On
    RewriteRule ^(.*)$ https://%{HTTP_HOST}\$1 [R=301,L]
    DocumentRoot ${DIR}
</VirtualHost>" >/etc/apache2/sites-available/"${SITE}".conf

echo "<VirtualHost *:443>
    ServerAdmin wp@${SITE}
    ServerName ${SITE}
    ServerAlias www.${SITE}
    DocumentRoot ${DIR}
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/${SITE}.pem
    SSLCertificateKeyFile /etc/ssl/private/${SITE}.key
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>" >/etc/apache2/sites-available/"${SITE}".ssl.conf

a2ensite "${SITE}"
a2ensite "${SITE}".ssl

systemctl restart apache2.service

# I'm using a Pihole as a local DNS server.
# Add domain to DNS list on pihole.
# shellcheck disable=SC2029
ssh pi@pihole "echo 192.168.178.99 ${SITE} >> /home/pi/.pihole/custom.list"
echo "Added ${SITE} to local DNS server, takes 15 min."

# Install WordPress
cd "${DIR}" || exit

# Add rules to `.htaccess`.
echo "<IfModule mod_deflate.c>
  # compress text, html, javascript, css, xml:
  AddOutputFilterByType DEFLATE text/plain
  AddOutputFilterByType DEFLATE text/html
  AddOutputFilterByType DEFLATE text/xml
  AddOutputFilterByType DEFLATE text/css
  AddOutputFilterByType DEFLATE application/xml
  AddOutputFilterByType DEFLATE application/xhtml+xml
  AddOutputFilterByType DEFLATE application/rss+xml
  AddOutputFilterByType DEFLATE application/javascript
  AddOutputFilterByType DEFLATE application/x-javascript
  AddOutputFilterByType DEFLATE image/x-icon
</IfModule>

<IfModule mod_expires.c>
ExpiresActive on
ExpiresByType image/gif \"access plus 1 months\"
ExpiresByType image/jpeg \"access plus 1 months\"
ExpiresByType image/png \"access plus 1 months\"
ExpiresByType application/x-font-woff \"access plus 1 months\"
ExpiresByType application/javascript \"access plus 1 months\"
ExpiresByType text/css \"access plus 1 months\"
</IfModule>" >"${DIR}"/.htaccess

chown www-data:www-data "${DIR}"/.htaccess

# Download WordPress, German locale
$WWWP core download --locale=de_DE

# Create WordPress configuration file
$WWWP config create --dbname="${DATABASE}" --dbuser=wordpress --dbpass=wordpress --extra-php <<PHP
  define( 'WP_ENVIRONMENT_TYPE', 'development' );
PHP

# Create MySQL database
if [[ $DATABASE != 'wordpress' ]]; then
  $WWWP db create
fi

# Install WordPress
$WWWP core install --title="${NAME}" --url=https://"${SITE}" --admin_user=admin --admin_password=password --admin_email=wp@"${SITE}" --skip-email
$WWWP option update permalink_structure "/%postname%"

# Add some settings to localize
$WWWP option update blogdescription "WordPress Testumgebung"
$WWWP option update timezone_string "Europe/Berlin"
$WWWP option update date_format "j. F Y"
$WWWP option update time_format "G:i"
$WWWP option update permalink_structure "/%postname%/"

# Create two nav menus
$WWWP menu create "Main"
$WWWP menu create "Legal"

# Add pages and create nav menu items for main menu
function main() {
  pages=(
    Startseite
    Blog
  )
  for i in "${pages[@]}"; do
    menuitem=$($WWWP post create \
      --post_author=admin \
      --post_titel="$i" \
      --post_status=publish \
      --post_type=page \
      --comment_status=closed \
      --porcelain)
    $WWWP menu item add-post main "$menuitem"
  done

  echo Created some web pages and added them to nav menu.
}
main

# Add imprint and create nav menu item for legal menu
# shellcheck disable=SC2046
$WWWP menu item add-post legal $(${WWWP} post create \
  --post_author=admin \
  --post_title=\"Impressum\" \
  --post_status=publish \
  --post_type=page \
  --comment_status=closed \
  --porcelain)

echo "Create imprint page and added it to legal menu."

# Install and activate some frequently use plugins.
PLUGINS="code-snippets customizer-search display-environment-type flying-pages"
$WWWP plugin install --activate "${PLUGINS}"

d=$(date "+%d.%m.%Y")
t=$(date "+%H:%M")
echo "Website ${SITE} created on ${d} at ${t}" >created
echo "Added timestamp to WordPress installation."

sudo -R chown www-data www-data "${DIR}"
echo "Changed owner of all files to www-data:www-data."

echo "That's it! Have a great day. 🌻"
