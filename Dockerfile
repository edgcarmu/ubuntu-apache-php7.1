FROM ubuntu:18.04

LABEL Maintainer="Fabian Carvajal <inbox@edgcarmu.me>" \
      Description=""

# Set Apache environment variables (can be changed on docker run with -e)
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data

ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid
ENV APACHE_RUN_DIR /var/run/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2

ENV APACHE_SERVER_ADMIN admin@localhost
ENV APACHE_SERVER_NAME  localhost
#ENV APACHE_SERVER_ALIAS docker.localhost
ENV APACHE_DOCUMENT_ROOT /var/www/html

#ENV APACHE_WORKER_START_SERVERS             2
#ENV APACHE_WORKER_MIN_SPARE_THREADS         2
#ENV APACHE_WORKER_MAX_SPARE_THREADS         10
#ENV APACHE_WORKER_THREAD_LIMIT              64
#ENV APACHE_WORKER_THREADS_PER_CHILD         25
#ENV APACHE_WORKER_MAX_REQUEST_WORKERS       4
#ENV APACHE_WORKER_MAX_CONNECTIONS_PER_CHILD 0

# System
ENV TIMEZONE Etc/UTC
ARG DEBIAN_FRONTEND=noninteractive

# Locale specific
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# Update the package repository
RUN apt update
RUN apt upgrade -y
RUN apt install -y software-properties-common

# add php7.1 repository
RUN add-apt-repository ppa:ondrej/php && apt update

# install apache and php modules
RUN apt install -y locales wget curl nano vim apache2 apache2-utils \
    php7.1 php7.1-bcmath php7.1-curl php7.1-gd php7.1-imagick php7.1-intl php7.1-cli \
    php7.1-mbstring php7.1-mcrypt php7.1-memcached php7.1-mysql php7.1-pgsql php7.1-sqlite \
    php7.1-redis php7.1-soap php7.1-xml php7.1-common php7.1-zip php7.1-imap php7.1-gmp composer

# Configure timezone and locale
RUN locale-gen $LANGUAGE && \
    dpkg-reconfigure locales && \
    echo "$TIMEZONE" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

# clean install
RUN apt clean

# Update the default apache site with the config we created.
COPY config/apache/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY config/apache/conf-available/application-env.conf /etc/apache2/conf-available/application-env.conf
COPY config/apache/mods-available/deflate.conf /etc/apache2/mods-available/deflate.conf

# Configure PHP
COPY config/php/php.ini /etc/php/7.1/apache2/conf.d/custom.ini

# ENTRYPOINT
ADD docker-entrypoint.sh /

## Make sure files/folders needed by the processes are accessable when they run under the www-data user
RUN chown -R $APACHE_RUN_USER:$APACHE_RUN_GROUP var/www/html && \
    chown -R $APACHE_RUN_USER:$APACHE_RUN_GROUP /var/log/apache2 && \
    chown -R $APACHE_RUN_USER:$APACHE_RUN_GROUP /var/lib/apache2 && \
    chown -R $APACHE_RUN_USER:$APACHE_RUN_GROUP /run && \
    chown -R $APACHE_RUN_USER:$APACHE_RUN_GROUP docker-entrypoint.sh

# Activate modules & configurations
RUN a2enmod php7.1
RUN a2enmod rewrite
RUN a2enmod deflate
RUN a2enconf application-env

# Switch to use a non-root user from here on
USER $APACHE_RUN_USER

# Add application
RUN rm -rf /var/www/html/*
WORKDIR /var/www/html
COPY --chown=www-data src/ /var/www/html/

# Expose apache
EXPOSE 80

# By default start up apache in the foreground
ENTRYPOINT ["sh","/docker-entrypoint.sh"]