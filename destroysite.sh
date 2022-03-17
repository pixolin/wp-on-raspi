#!/bin/bash
#
# Copyright (c) 2022 Bego Mario Garde
# License: MIT
#
# ----
# ! DON`T USE ON THIS ON A PRODUCTION SERVER !
# ----
#
# Destroys an existing WordPress site.
#
# Needs a site name,
# deletes subdirectory in /var/www,
# deletes SSL certificates,
# removes virtual host file,
# restarts server,
# drops MySQL database.

# Exit on first error
set -e

# Variables
SITE=${1,,} # wp.test
DIR=/var/www/"${SITE}"

GREEN='\033[32;1m'
REGULAR='\033[0m'
SUCCESS="${GREEN}Success:$REGULAR"

# Exit, if no site name was provided
if [[ -z "$1" ]]; then
	echo "No sitename provided. Aborting script."
	exit 1
fi

# Check if website directory exists
if [[ ! -d "$DIR" ]]; then
	# Take action if $DIR exists. #
	echo "Directory ${DIR} doesn't exist. Aborting script."
	exit 1
fi

# Delete MySQL-Database
if [[ $SITE == 'wp.test' ]]; then
	wp db reset --yes --path="${DIR}"
else
	wp db drop --yes --path="${DIR}"
fi

# Check if directory exists and delete the directory
[[ -d "$DIR" ]] && rm -rf "${DIR}"
echo -e "${SUCCESS} Deleted directory ${SITE}"

# Delete selfsigned SSL certificates
sudo rm /etc/ssl/certs/"${SITE}".pem
sudo rm /etc/ssl/private/"${SITE}".key
echo -e "${SUCCESS} Deleted SSL certificates"

# Disable virtual hosts and restart server
sudo a2dissite "${SITE} ${SITE}.ssl"
echo -e "${SUCCESS} Virtual hosts disabled"

# Delete virtual hosts
sudo rm /etc/apache2/sites-available/"${SITE}".conf
sudo rm /etc/apache2/sites-available/"${SITE}".ssl.conf

# and restart Apache2 Webserver
sudo systemctl restart apache2.service
echo -e "${SUCCESS} Restarted Apache2 server."

echo "
🥲 Site ${SITE} has been destroyed.
🪴 Build something new.
"
