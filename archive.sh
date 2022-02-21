#!/bin/bash
#
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
DIR="/var/www/${SITE}"            # /var/wp/wp.test
TAR="/var/archive/${SITE}.tar.gz" # /var/archive/wp.test.gz
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
if [[ ! -d "$DIR" ]]; then
  echo "❌ Directory ${DIR} doesn't exist. No website? Aborting script."
  exit 1
fi

# export MySQL database and store in tmp-directory
$WWWP db export "${DIR}"/database.sql --dbuser=wordpress --dbpass=wordpress --path="${DIR}"

# Create archive from files in tmp-directory
tar -czf "${TAR}" -C "${DIR}" \
  database.sql \
  wp-config.php \
  .htaccess \
  wp-content

rm "${DIR}"/database.sql

echo "✅ Compressed archive stored at ${TAR}"
