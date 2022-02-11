#! /bin/bash
# Exit on first error
set -e

: '
Creates archive of existing WordPress site

----
DON`T USE ON PUBLIC SERVER!
----

Checks if run by user root,
check if site name provided,
check if directory exists,
create temporary files with
list of themes and plugins,
export database as sql file,
create tar with
- `wp-config.php`
- `.htaccess`
- `wp-content/uploads`
- temporary file with list of active plugins
- temporary file with list of active themes
- sql file of database
- SSL certificates (both!),
- virtual host files
Delete temporary files after storage.
'

# Variables
SITE=${1,,} # wp.test
NAME=${SITE%.*} # wp
DIR=/var/www/${SITE} # /var/wp/wp.test
TMP=${DIR}/.tmp
wwwp="sudo -u www-data wp"
cwd=$(pwd)

# Execute as root, only
if [ "$(whoami)" != 'root' ]; then
echo "❌ You have to execute this script as root user. Aborting script."
exit 1;
fi

# Exit, if no site name was provided
if [ $# -eq 0 ] ; then
	echo '❌ No sitename provided. Aborting script.'
	exit 0
fi

# Exit, if directory already exists
if [ ! -d "$DIR" ]; then
  echo "❌ Directory ${DIR} doesn't exist. No website? Aborting script."
  exit 0
fi

# temporary hidden folder in website directory
sudo -u www-data mkdir -p ${TMP}

# export MySQL database and store in tmp-directory
$wwwp db export ${TMP}/wp-database.sql --dbuser=wordpress --dbpass=wordpress --path=$DIR

# Store list of themes and plugins in tmp-folder
$wwwp theme list --field=name --status=active --skip-update-check --path=${DIR} > ${TMP}/wp-theme.txt
$wwwp plugin list --field=name --status=active --skip-update-check --path=${DIR} > ${TMP}/wp-plugins.txt

# Create archive from files in tmp-directory
tar -C ${TMP} -cf /var/archive/${SITE}.tar \
  wp-database.sql \
  wp-plugins.txt \
  wp-theme.txt

# tmp-directory is no longer needed
rm -rf ${TMP}

# Add `wp-config.php`, `.htaccess` and uploads-directory to archive
tar -C ${DIR} -rf /var/archive/${SITE}.tar \
  wp-config.php \
  .htaccess \
  wp-content/uploads


# Add SSL-Certificates and Virtual Hosts to archive
tar -C /etc -rf /var/archive/${SITE}.tar \
  ssl/certs/${SITE}.pem \
  ssl/private/${SITE}.key \
  apache2/sites-available/${SITE}.conf \
  apache2/sites-available/${SITE}.ssl.conf

 /var/archive/${SITE}.tar.lz4

chmod 600 /var/archive/${SITlz4 /var/archive/${SITE}.tarE}.tar.lz4

echo "✅ Compressed archive stored at /var/archive/${SITE}.tgz"