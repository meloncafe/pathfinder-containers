FROM meloncafe/alpine-nginx-php:7-latest

RUN apk update && apk add --no-cache composer busybox-suid sudo bash php7-redis php7-pdo php7-pdo_mysql \
    php7-fileinfo php7-event shadow gettext bash apache2-utils logrotate ca-certificates

# fix expired DST Cert
RUN sed -i '/^mozilla\/DST_Root_CA_X3.crt$/ s/^/!/' /etc/ca-certificates.conf \
    && update-ca-certificates

# symlink nginx logs to stdout/stderr for supervisord
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log

COPY static/logrotate/pathfinder /etc/logrotate.d/pathfinder
COPY static/nginx/nginx.conf /etc/nginx/templateNginx.conf
# we need to create sites_enabled directory in order for entrypoint.sh being able to copy file after envsubst
RUN mkdir -p /etc/nginx/sites_enabled/
COPY static/nginx/site.conf  /etc/nginx/templateSite.conf

# Configure PHP-FPM
COPY static/php/fpm-pool.conf /etc/php7/php-fpm.d/www.conf

COPY static/php/php.ini /etc/zzz_custom.ini
# configure cron
COPY static/crontab.txt /var/crontab.txt
# Configure supervisord
COPY static/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY static/entrypoint.sh   /

WORKDIR /var/www/html/pathfinder
COPY pathfinder /var/www/html/pathfinder

RUN composer self-update 2.1.8
RUN composer install
#COPY  --chown=nobody --from=build /app  pathfinder

WORKDIR /var/www/html

RUN chmod 0766 pathfinder/logs pathfinder/tmp/ && touch /etc/nginx/.setup_pass &&  chmod +x /entrypoint.sh
COPY static/pathfinder/routes.ini /var/www/html/pathfinder/app/
COPY static/pathfinder/environment.ini /var/www/html/pathfinder/app/templateEnvironment.ini

RUN chown -R nobody:nobody /var/www/html/pathfinder

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
