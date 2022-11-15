#!/bin/bash
#
# Copyright (c) 2022 Bego Mario Garde
# License: MIT
#
# Creates a new wordpress site
# in a local test environment.
#
# ----
# ! DON`T USE ON THIS ON A PRODUCTION SERVER !
# ----
#
# Needs a site name,
# creates subdirectory in /var/www,
# creates SSL certificates,
# adds virtual host file,
# restarts server,
# creates MySQL database,
# downloads and installs WordPress

# Exit on first error
set -e

# Variables
SITE=${1,,} # wp.test
# make sure, domain ends with '.test'
if [[ ! 'test' == "${SITE##*.}" ]]; then
	if [[ ! "${SITE}" == *\. ]]; then
		SITE+="."
	fi
	SITE+="test"
fi

NAME=${SITE%.*}          # wp
DIR=/var/www/"${SITE}"   # /var/wp/wp.test
RASPIIP="192.168.178.99" # IP address Pihole

declare -A user # Array of users
user["editor"]=Redakteur
user["author"]=Autor
user["contributor"]=Mitarbeiter
user["subscriber"]=Abonnent

GREEN='\033[32;1m'                   # Color for success message
REGULAR='\033[0m'                    # Reset to normal
SUCCESS="${GREEN}Success:${REGULAR}" # Success message (beginning)

# Use database `wordpress` for `wp.test`
# and `wp_...` for everything else.
# DB user `wordpress` has permission for all.
if [[ "$SITE" == 'wp.test' ]]; then
	DATABASE='wordpress'
else
	DATABASE="wp_${NAME}"
fi

# Exit, if no site name was provided
if [[ -z "$1" ]]; then
	echo "❌ No sitename provided. Aborting script."
	exit 1
fi

# Exit, if directory already exists
if [[ -d "${DIR}" ]]; then
	# Take action if $DIR exists. #
	echo "❌ Directory ${DIR} already exist. Aborting script."
	exit 1
fi

# Create directory
sudo mkdir -p "${DIR}"
sudo chown pi:pi "${DIR}"
sudo chmod 755 "${DIR}"
echo -e "${SUCCESS} Created directory ${DIR}"

# I'm using a Pihole as a local DNS server.
# Add domain to DNS list on pihole.
# shellcheck disable=SC2029
ssh pi@pihole.local "echo ${RASPIIP} ${SITE} > /home/pi/.pihole/newdns"
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

sudo systemctl restart apache2.service

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

# Download WordPress, German locale
wp core download --locale=de_DE

# Create WordPress configuration file
wp config create --dbname="${DATABASE}" --dbuser=wordpress --dbpass=wordpress
wp config set WP_ENVIRONMENT_TYPE development

# Create MySQL database
if [[ $DATABASE != 'wordpress' ]]; then
	wp db create
fi

# Install WordPress
wp core install --title="${NAME}" --url=https://"${SITE}" --admin_user=admin --admin_password=password --admin_email=wp@"${SITE}" --skip-email
wp option update permalink_structure "/%postname%"

# Add some site settings
wp option update blogdescription "WordPress Testumgebung"
wp option update permalink_structure "/%postname%/"

# Create two nav menus
wp menu create "Main"
wp menu create "Legal"

# Add pages and create nav menu items for main menu

PAGES=(
	"Startseite"
	"Über mich"
	"Blog"
)
for i in "${PAGES[@]}"; do
	menuitem=$(wp post create \
		--post_author=1 \
		--post_title="${i}" \
		--post_status=publish \
		--post_type=page \
		--comment_status=closed \
		--porcelain)
	wp menu item add-post main "$menuitem"
	if [[ 'Startseite' == "${i}" ]]; then
		wp option update page_on_front $menuitem
	fi
	if [[ 'Blog' == "${i}" ]]; then
		wp option update page_for_posts $menuitem
	fi
done

wp option update show_on_front page

echo -e "${SUCCESS} Created some web pages and added them to nav menu."

# Add imprint and create nav menu item for legal menu
# shellcheck disable=SC2046
wp menu item add-post legal $(wp post create \
	--post_author=1 \
	--post_title=Impressum \
	--post_status=publish \
	--post_type=page \
	--comment_status=closed \
	--porcelain)

echo -e "${SUCCESS}  Created imprint page and added it to legal menu."

# Create some posts with blindtext

curl -N http://loripsum.net/api/3/short/prude/plaintext > lorem.txt && cat lorem.txt | wp post generate \
	--count=3 \
	--post_author=1 \
	--post_date="$(date '+%Y-%m-%d-%H-%M-%S')" \
	--post_title="Beitrag ${i}" \
	--post_content \
  && rm lorem.txt

echo -e "${SUCCESS}  Created 3 random posts."

for key in "${!user[@]}"; do
	wp user create ${user[${key}]} ${user[${key}],,}@wp.test \
		--role=${key} \
		--user_pass=password
done

# Install and activate plugin display-environment-type
wp plugin install display-environment-type --activate

d=$(date "+%d.%m.%Y")
t=$(date "+%H:%M")
echo "Website ${SITE} created on ${d} at ${t}" >created
echo -e "${SUCCESS} Added timestamp to WordPress installation."

sudo chown -R pi:pi "${DIR}"
echo -e "${SUCCESS} Changed owner/group of all files to pi:pi."

echo -e "\nThat's it! Have a great day. 🌻\n"
