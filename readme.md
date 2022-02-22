# Raspberry Pi as WordPress test environment

> :warning: **Never use this script on a publicly accessible web server!**
> This script is intended for a local test environment only and *intentionally* uses extremely weak credentials (e.g. admin:password).

All scripts must be run as root.
wp-cli commands are executed as user `www-data:www-data`.

---
`newsite.sh <sitename>`
Creates a new wordpress site by adding a new directory in `/var/www`, adding a virtual hosts file, downloading WordPress, creating `wp-config.php`, creating a MySQL database and installing WordPress with some default settings.

---
`destroysite.sh <sitename>`
Destroys an existing website by reverting the steps from `newsite.sh`.

---
`archive.sh`
Creates an archive of an existing website, storing `wp-confi.php`, `.htaccess`, directory `wp-content` and a database dump.

---
`restore.sh``
Restore archive created with `archive.sh` by installing WordPress and restoring the content of an archive file.
