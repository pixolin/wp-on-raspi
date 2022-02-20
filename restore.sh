i#! /bin/bash
#
# Copyright (c) 2022 Bego Mario Garde
# License: MIT
#
# Restores archived WordPress site
#
# ----
# DON`T USE ON THIS ON A PRODUCTION SERVER!
# ----
#
# Checks if run by user root,
# check if site name provided,
# creates
#
# dump MySQL database
# create tar with
# - `database.sql`
# - `wp-config.php`
# - `.htaccess`
# - `wp-content`
# store under /var/archive
#

# Exit on first error
set -e

# Variables
SITE=${1,,}            # wp.test
DIR=/var/www/"${SITE}" # /var/wp/wp.test
TAR=/var/archive/"${SITE}".tar
WWWP="sudo -u www-data wp"

# Execute as root, only
if [[ "$(whoami)" != 'root' ]]; then
  echo "❌ You have to execute this script as root user. Aborting script."
  exit 1
fi

# Exit, if no site name was provided
if [[ -z "$1" ]]; then
  echo '❌ No sitename provided. Aborting script.'
  exit 1
fi

# Exit, if directory already exists
if [[ -d "$DIR" ]]; then
  echo "❌ Directory ${DIR} already exist. Aborting script."
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
echo "Success: created directory ${DIR}"

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
