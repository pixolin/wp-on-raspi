#! /bin/bash
: '
Destroys an existing wordpress site.

Needs a site name,
deletes subdirectory in /var/www,
deletes SSL certificates,
removes virtual host file,
restarts server,
drops MySQL database.
'

# Variables
SITE=${1,,} # wp.test
NAME=${SITE%.*} # wp
DIR=/var/www/${SITE}

if [ $SITE == 'wp.test' ]; then
  DATABASE='wordpress'
else
  DATABASE='wp_${NAME}'
fi

# Execute as root, only
if [ "$(whoami)" != 'root' ]; then
echo "You have to execute this script as root user. Aborting script."
exit 1;
fi

# Exit, if no site name was provided
if [[ $# -eq 0 ]] ; then
	echo 'No sitename provided. Aborting script.'
	exit 0
fi

# Check if website directory exists
if [[ ! -d "$DIR" ]]; then
  # Take action if $DIR exists. #
  echo "Directory ${DIR} doesn't exist. Aborting script."
  exit 0
fi

# Delete the directory
rm -rf ${DIR}
echo Deleted director ${SITE}

# Delete selfsigned SSL certificates
rm /etc/ssl/certs/${SITE}.pem
rm /etc/ssl/private/${SITE}.key
echo Deleted SSL certificates

# Disable virtual hosts and restart server
a2dissite ${SITE}
a2dissite ${SITE}.ssl
echo Virtual hosts disabled

# Delete virtual hosts
rm /etc/apache2/sites-available/${SITE}.conf
rm /etc/apache2/sites-available/${SITE}.ssl.conf
systemctl restart apache2.service
echo Restarting Apache2 server.

# Delete MySQL-Database
echo "DROP DATABASE \`${DATABASE}\`" | mysql -uroot -proot

echo "Site ${SITE} destroyed. Create something new. 🪴"
