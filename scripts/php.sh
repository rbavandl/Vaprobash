#!/usr/bin/env bash

export LANG=C.UTF-8

PHP_TIMEZONE=$1
HHVM=$2
PHP_VERSION=$3
PHP_PATH="/etc/php/$PHP_VERSION"

if [[ $HHVM == "true" ]]; then

    echo ">>> Installing HHVM"

    # Get key and add to sources
    wget --quiet -O - http://dl.hhvm.com/conf/hhvm.gpg.key | sudo apt-key add -
    echo deb http://dl.hhvm.com/ubuntu trusty main | sudo tee /etc/apt/sources.list.d/hhvm.list

    # Update
    sudo apt-get update

    # Install HHVM
    # -qq implies -y --force-yes
    sudo apt-get install -qq hhvm

    # Start on system boot
    sudo update-rc.d hhvm defaults

    # Replace PHP with HHVM via symlinking
    sudo /usr/bin/update-alternatives --install /usr/bin/php php /usr/bin/hhvm 60

    sudo service hhvm restart
else
    echo ">>> Installing PHP $PHP_VERSION"

    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C

    comp=$(awk 'BEGIN{ print "'$PHP_VERSION'">="'7.1.0'" }')

    if [ "$comp" -eq 1 ]; then
        # Fix potentially broken add-apt-repository locales
        sudo apt-get install -y language-pack-en-base
        # Add repo for PHP 5.5
        sudo LC_ALL=en_US.UTF-8 add-apt-repository -y ppa:ondrej/php
    else
        sudo add-apt-repository -y ppa:ondrej/php
    fi

    sudo apt-key update
    sudo apt-get update

    # Install PHP
    # -qq implies -y --force-yes
	sudo apt-get install -qq php$PHP_VERSION-cli php$PHP_VERSION-fpm php$PHP_VERSION-mysql php$PHP_VERSION-pgsql php$PHP_VERSION-sqlite php$PHP_VERSION-curl php$PHP_VERSION-gd php$PHP_VERSION-gmp php$PHP_VERSION-xml php$PHP_VERSION-memcached php$PHP_VERSION-redis php$PHP_VERSION-imagick php$PHP_VERSION-intl php$PHP_VERSION-xdebug php$PHP_VERSION-mailparse

    if [ $PHP_VERSION != "7.2" ]; then
		sudo apt-get install -qq php$PHP_VERSION-mcrypt
    fi

    # Set PHP FPM to listen on TCP instead of Socket
    sudo sed -i "s/listen =.*/listen = 127.0.0.1:9000/" "${PHP_PATH}"/fpm/pool.d/www.conf

    # Set PHP FPM allowed clients IP address
    sudo sed -i "s/;listen.allowed_clients/listen.allowed_clients/" "${PHP_PATH}"/fpm/pool.d/www.conf

    # Set run-as user for PHP-FPM processes to user/group "vagrant"
    # to avoid permission errors from apps writing to files
    sudo sed -i "s/user = www-data/user = vagrant/" "${PHP_PATH}"/fpm/pool.d/www.conf
    sudo sed -i "s/group = www-data/group = vagrant/" "${PHP_PATH}"/fpm/pool.d/www.conf

    sudo sed -i "s/listen\.owner.*/listen.owner = vagrant/" "${PHP_PATH}"/fpm/pool.d/www.conf
    sudo sed -i "s/listen\.group.*/listen.group = vagrant/" "${PHP_PATH}"/fpm/pool.d/www.conf
    sudo sed -i "s/listen\.mode.*/listen.mode = 0666/" "${PHP_PATH}"/fpm/pool.d/www.conf


    # xdebug Config if supported
    echo ">>> Checking for potential xdebug.ini file to configure"
    CAT_CMD="$(find "$PHP_PATH" -name xdebug.ini)"
    cat > "${CAT_CMD}" << EOF
zend_extension=xdebug.so
xdebug.remote_enable = 1
xdebug.remote_connect_back = 1
xdebug.remote_port = 9000
xdebug.scream=0
xdebug.cli_color=1
xdebug.show_local_vars=1

xdebug.profiler_enable_trigger = 1
xdebug.profiler_enable_trigger_value = 1
xdebug.profiler_output_dir = /vagrant/tmp

; var_dump display
xdebug.var_display_max_depth = 5
xdebug.var_display_max_children = 256
xdebug.var_display_max_data = 1024
EOF

    # PHP Error Reporting Config
    sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" "${PHP_PATH}"/fpm/php.ini
    sudo sed -i "s/display_errors = .*/display_errors = On/" "${PHP_PATH}"/fpm/php.ini

    # PHP Date Timezone
    sudo sed -i "s/;date.timezone =.*/date.timezone = ${PHP_TIMEZONE/\//\\/}/" "${PHP_PATH}"/fpm/php.ini
    sudo sed -i "s/;date.timezone =.*/date.timezone = ${PHP_TIMEZONE/\//\\/}/" "${PHP_PATH}"/cli/php.ini

    sudo service php$PHP_VERSION-fpm restart
fi
