#! /bin/bash
: '
Creates a new wordpress site.

Needs a site name,
creates directory in /var/www,
adds virtual host file,
restarts server,
creates database,
'


SITE=$1.test
DIR=/var/www/${SITE}

# Execute as root, only
if [ "$(whoami)" != 'root' ]; then
echo "You have to execute this script as root user"
exit 1;
fi

# Exit, if no site name was provided
if [[ $# -eq 0 ]] ; then
	echo 'No sitename provided'
	exit 0
fi

# Exit, if directory already exists
if [ -d "$DIR" ]; then
  # Take action if $DIR exists. #
  echo "Directory ${DIR} already exits. Stopping script."
  exit 0
else
  sudo mkdir -p ${DIR}
  sudo chown www-data:www-data ${DIR}
  sudo chmod 755 ${DIR}
  echo "Successfully created directory ${DIR}"
fi

# Create selfsigned SSL certificate
 mkcert \
 -cert-file /etc/ssl/certs/${SITE}.pem \
 -key-file /etc/ssl/private/${SITE}.key \
 ${SITE} "*.${SITE}"

echo "<VirtualHost *:80>
    ServerAdmin wp@${SITE}
    ServerName ${SITE}
    ServerAlias www.${SITE}
    RewriteEngine On
    RewriteRule ^(.*)$ https://%{HTTP_HOST}\$1 [R=301,L]
    DocumentRoot ${DIR}
</VirtualHost>" > /etc/apache2/sites-available/${SITE}.conf

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
</VirtualHost>" > /etc/apache2/sites-available/${SITE}.ssl.conf

if ! echo -e /etc/apache2/sites-available/${SITE}.conf; then
echo "I have a problem to create the virtual host."
else
  echo "Virtual host created !"
fi

if ! echo -e /etc/apache2/sites-available/${SITE}.ssl.conf; then
echo "I have a problem to create the virtual host (SSL)."
else
  echo "Virtual host (SSL) created !"
fi

sudo a2ensite ${SITE}
sudo a2ensite ${SITE}.ssl

echo "CREATE DATABASE \`wp_$1\`" | mysql -uroot -proot

cd ${DIR}

# Download WordPress, German locale
sudo -u www-data wp core download --locale=de_DE

# Create WordPress configuration file
sudo -u www-data wp config create --dbname=wp_$1 --dbuser=wordpress --dbpass=wordpress --extra-php <<PHP
  define( 'WP_ENVIRONMENT_TYPE', 'development' );
PHP

# Install WordPress
sudo -u www-data wp core install --title=$1 --url=https://${SITE} --admin_user=admin --admin_password=password --admin_email=wp@${SITE} --skip-email

echo "That's it! Have a great day. 🌻"
