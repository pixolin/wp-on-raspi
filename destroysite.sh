#! /bin/bash
# Copyright (c) 2022 Bego Mario Garde
# License: MIT
# ----
# Destroys an existing WordPress site.
# ----
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


# Execute as root, only
if [[ "$(whoami)" != 'root' ]];
then
echo You have to execute this script as root user. Aborting script.
exit 1;
fi

# Exit, if no site name was provided
if [[ -z "$1" ]] ;
then
	echo No sitename provided. Aborting script.
	exit 1
fi

# Check if website directory exists
if [[ ! -d "$DIR" ]]; then
  # Take action if $DIR exists. #
  echo "Directory ${DIR} doesn't exist. Aborting script."
  exit 1
fi

# Delete MySQL-Database
if [[ $SITE == 'wp.test' ]];
then
  sudo -u www-data wp db reset --yes --path="${DIR}"
else
  sudo -u www-data wp db drop --yes --path="${DIR}"
fi

# Delete the directory
rm -rf "${DIR}"
echo "✅ Deleted directory ${SITE}"

# Delete selfsigned SSL certificates
rm /etc/ssl/certs/"${SITE}".pem
rm /etc/ssl/private/"${SITE}".key
echo ✅ Deleted SSL certificates

# Disable virtual hosts and restart server
a2dissite "${SITE}" "${SITE}".ssl
echo ✅ Virtual hosts disabled

# Delete virtual hosts
rm /etc/apache2/sites-available/"${SITE}".conf
rm /etc/apache2/sites-available/"${SITE}".ssl.conf
systemctl restart apache2.service
echo ✅ Restarted Apache2 server.

echo "
🪦 Site ${SITE} has been destroyed.
🪴 Build something new.
"
