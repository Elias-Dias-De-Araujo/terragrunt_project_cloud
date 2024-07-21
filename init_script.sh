#!/bin/sh

cp /config/wp-config.php /var/www/html/wp-config.php

sed -i "s|WORDPRESS_DB_NAME|$WORDPRESS_DB_NAME|" /var/www/html/wp-config.php
sed -i "s|WORDPRESS_DB_USER|$WORDPRESS_DB_USER|" /var/www/html/wp-config.php
sed -i "s|WORDPRESS_DB_PASSWORD|$WORDPRESS_DB_PASSWORD|" /var/www/html/wp-config.php
sed -i "s|WORDPRESS_DB_HOST|$WORDPRESS_DB_HOST|" /var/www/html/wp-config.php

exec "$@"

