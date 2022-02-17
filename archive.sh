#! /bin/bash
# Copyright (c) 2022 Bego Mario Garde
# License: MIT
#
# Creates archive of existing WordPress site
#
# ----
# DON`T USE ON THIS ON A PRODUCTION SERVER!
# ----
#
# Checks if run by user root,
# check if site name provided,
# check if directory exists,
#
# create temporary files with
# list of themes and plugins,
# export database as sql file,
#
# create tar with
# - `wp-config.php`
# - `.htaccess`
# - `wp-content/uploads`
# - temporary file with list of active plugins
# - temporary file with list of active themes
# - sql file of database
# - SSL certificates (both!),
# - virtual host files
#
# Delete temporary files after storage.

# Exit on first error
set -e

# Variables
SITE=${1,,} # wp.test
DIR=/var/www/"${SITE}" # /var/wp/wp.test
TMP="${DIR}"/.tmp
TAR=/var/archive/"${SITE}".tar
wwwp="sudo -u www-data wp"


# Execute as root, only
if [[ "$(whoami)" != 'root' ]];
then
echo "❌ You have to execute this script as root user. Aborting script."
exit 1;
fi

# Exit, if no site name was provided
if [[ -z "$1" ]] ;
then
	echo '❌ No sitename provided. Aborting script.'
	exit 1
fi

# Exit, if directory already exists
if [[ ! -d "$DIR" ]];
then
  echo "❌ Directory ${DIR} doesn't exist. No website? Aborting script."
  exit 1
fi

# temporary hidden folder in website directory
sudo -u www-data mkdir -p "${TMP}"

# export MySQL database and store in tmp-directory
$wwwp db export "${TMP}"/wp-database.sql --dbuser=wordpress --dbpass=wordpress --path="${DIR}"

# Store list of themes and plugins in tmp-folder
$wwwp theme list --field=name --status=active --skip-update-check --path="${DIR}" > "${TMP}"/wp-theme.txt
$wwwp plugin list --field=name --status=active --skip-update-check --path="${DIR}" > "${TMP}"/wp-plugins.txt

# Create archive from files in tmp-directory
tar -C "${TMP}" -cf "${TAR}" \
  wp-database.sql \
  wp-plugins.txt \
  wp-theme.txt

# tmp-directory is no longer needed
rm -rf "${TMP}"

# Add `wp-config.php`, `.htaccess` and uploads-directory to archive
tar -C "${DIR}" -rf "${TAR}" \
  wp-config.php \
  .htaccess \
  wp-content/uploads

# Add SSL-Certificates and Virtual Hosts to archive
tar -C /etc -rf "${TAR}" \
  ssl/certs/"${SITE}".pem \
  ssl/private/"${SITE}".key \
  apache2/sites-available/"${SITE}".conf \
  apache2/sites-available/"${SITE}".ssl.conf

# Compress archive with gzip, remove original file
gzip "${TAR}"

# Change permissions of archive
chmod 600 "${TAR}".gz

echo "✅ Compressed archive stored at /var/archive/${SITE}.gz"
