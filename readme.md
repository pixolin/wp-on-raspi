# Raspberry Pi as WordPress test environment

> :warning: **Never use this script on a publicly accessible web server!**
> This script is intended for a local test environment only and intentionally uses extremely weak passwords.

`newsite.sh <sitename>`
Creates a new wordpress site by adding a new directory in `/var/www`, adding a virtual hosts file, downloading WordPress, creating `wp-config.php`, creating a MySQL database and installing WordPress with default settings. Must be run as root.

`destroysite.sh <sitename>`
Destroys an existing website by reverting the steps from `newsite.sh`. Must be run as `root`.
