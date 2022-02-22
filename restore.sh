#! /bin/bash
#
# Copyright (c) 2022 Bego Mario Garde
# License: MIT
#
# Restores archived WordPress site
#
# ----
# ! DON`T USE ON THIS ON A PRODUCTION SERVER !
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
SITE=${1,,}                       # wp.test
DIR=/var/www/"${SITE}"            # /var/wp/wp.test
TAR=/var/archive/"${SITE}".tar.gz # /var/archive/wp.test.tar.gz
WWWP="sudo -u www-data wp"        # sudo -u www-data wp

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
if [[ -d "${DIR}" ]]; then
  echo "❌ Directory ${DIR} already exist. Aborting script."
  exit 1
fi

# Exit, if directory already exists
if [[ ! -f "${TAR}" ]]; then
  echo "❌ Archive ${TAR##*/} not found. Aborting script."
  exit 1
fi

# Create directory
mkdir -p "${DIR}"
chown www-data:www-data "${DIR}"
chmod 755 "${DIR}"
echo "Success: created directory ${DIR}"

# I'm using a Pihole as a local DNS server.
# Add domain to DNS list on pihole.
# shellcheck disable=SC2029
ssh pi@pihole "echo 192.168.178.99 ${SITE} > /home/pi/.pihole/newdns"
echo "Added ${SITE} to local DNS server, change needs 10 minutes."

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

# Install WordPress
cd "${DIR}" || exit

# Download WordPress, skipping wp-content, German locale
$WWWP core download --skip-content --locale=de_DE

# extract  database.sql, wp-config.php, .htaccess, wp-content
tar -zxf "${TAR}" -C "${DIR}"
chown -R www-data:www-data "${DIR}"

# import sql file and remove afterwards
${WWWP} db import "${DIR}/database.sql" && rm "${DIR}/database.sql"

echo ""
echo "✅ Archive ${TAR##*/} has been restored successfully."
echo ""
