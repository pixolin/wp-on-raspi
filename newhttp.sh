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

# Create virtual hosts and restart server
echo "<VirtualHost *:80>
    ServerAdmin wp@${SITE}
    ServerName ${SITE}
    ServerAlias www.${SITE}
    DocumentRoot ${DIR}
</VirtualHost>" | sudo tee -a /etc/apache2/sites-available/"${SITE}".conf >/dev/null

sudo a2ensite "${SITE}"

sudo systemctl restart apache2.service

# Install WordPress
cd "${DIR}" || exit

touch .htaccess

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
wp core install --title=jessica.test --url=http://jessica.test --admin_user=admin --admin_password=password --admin_email=wp@jessica.test --skip-email
wp option update permalink_structure "/%postname%"

d=$(date "+%d.%m.%Y")
t=$(date "+%H:%M")
echo "Website ${SITE} created on ${d} at ${t}" >created
echo -e "${SUCCESS} Added timestamp to WordPress installation."

sudo chown -R pi:pi "${DIR}"
echo -e "${SUCCESS} Changed owner/group of all files to pi:pi."

echo -e "\nThat's it! Have a great day. 🌻\n"
