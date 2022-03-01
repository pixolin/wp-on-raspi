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
# Check if site name provided,
# creates
#
# Restore tar with
# - `database.sql`
# - `wp-config.php`
# - `.htaccess`
# - `wp-content`
#

# Exit on first error
set -e

# Variables
SITE=${1,,}                       # wp.test
DIR=/var/www/"${SITE}"            # /var/wp/wp.test
TAR=/var/archive/"${SITE}".tar.gz # /var/archive/wp.test.tar.gz
RASPIIP="192.168.178.99"

GREEN='\033[32;1m'
REGULAR='\033[0m'
SUCCESS="${GREEN}Success: $REGULAR"

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
echo -e "${SUCCESS} created directory ${DIR}"

# I'm using a Pihole as a local DNS server.
# Add domain to DNS list on pihole.
# shellcheck disable=SC2029
ssh pi@pihole "echo ${RASPIIP} ${SITE} > /home/pi/.pihole/newdns"
echo -e "${SUCCESS} Added ${SITE} to local DNS server, change needs 10 minutes."

# Create selfsigned SSL certificate
sudo mkcert \
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
</VirtualHost>" | sudo tee -a /etc/apache2/sites-available/"${SITE}".conf >/dev/null

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
</VirtualHost>" | sudo tee -a /etc/apache2/sites-available/"${SITE}".ssl.conf >/dev/null

sudo a2ensite "${SITE}"
sudo a2ensite "${SITE}".ssl

systemctl restart apache2.service

# Install WordPress
cd "${DIR}" || exit

# Download WordPress, skipping wp-content, German locale
wp core download --skip-content --locale=de_DE

# extract  database.sql, wp-config.php, .htaccess, wp-content
sudo tar -zxf "${TAR}" -C "${DIR}"
sudo chown -R pi:pi "${DIR}"

# import sql file and remove afterwards
wp db import "${DIR}/database.sql" && rm "${DIR}/database.sql"

d=$(date "+%d.%m.%Y")
t=$(date "+%H:%M")
echo "Website ${SITE} restored on ${d} at ${t}" >>created

echo ""
echo -e "${SUCCESS} Archive ${TAR##*/} has been restored successfully."
echo ""
