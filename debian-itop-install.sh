#!/usr/bin/env bash

# mkdir testing && cd testing && nano debian-itop-install.sh && chmod +x debian-itop-install.sh && ./debian-itop-install.sh

show_time ()
{
    echo -n "$(date +%r) -- "
}

check_root_privilieges ()
{
    show_time
    echo -n "Checking root privilieges..."
    if [ $(id -u) -ne 0 ]; then
        echo -e "failed\n\nPlease run the script with root privilieges.\n"
        exit 1
    else
        echo "done"
    fi
}

check_file_presence ()
{
    show_time
    echo -n "Checking file presence..."
    if [ "$(ls -A)" != "debian-itop-install.sh" ]; then
        echo -e "failed\n\nPlease run the script in an empty or a in new directory\n"
        exit 1
    else
        echo "done"
    fi
}

# check dns + wan access
check_internet_access ()
{
    show_time
    echo -n "Checking internet access..."
    ping -c 1 debian.org &> $log_file
    check_status
}

log_file=$(mktemp /tmp/itop-install.XXXXXX)

check_status ()
{
    if [ $? -eq 0 ]; then
        echo "done"
    else
        cat /dev/null
        echo -e "failed\n\nAn error occured, see the action above\nI made the program quit\n\nIf you want to bypass errors, comment line 41\nLog file $log_file\n"
        exit 1
    fi
}

hidden_check_status ()
{
    if [ $? -ne 0 ]; then
        cat /dev/null
        echo -e "failed\n\nAn error occured during the installation - see the action above\nI made the program quit\n\nIf you want to bypass errors, comment line 50\nlog file $log_file\n"
        exit 1
    fi
}

cleaning_up ()
{
    show_time
    echo -n "Cleaning up..."
    ls -A | grep -v debian-itop-install.sh | xargs rm -rf
    check_status
}

update ()
{
    show_time
    echo -n "Running apt-get update..."
    apt-get update &> $log_file
    check_status
}

install_prerequires ()
{
    show_time
    echo -n "Installing prerequires (take some time)..."
    apt-get install -y apache2 mariadb-server php php-{mysql,ldap,cli,soap,json,mbstring,xml,gd,zip,curl} libapache2-mod-php graphviz unzip &> $log_file
    check_status
    apt-get install -y php-mcrypt &> $log_file
}

update_php_config ()
{
    show_time
    echo -n "Updating php.ini file..."
    sed -i "/file_uploads = /c\file_uploads = On" /etc/php/*/apache2/php.ini &> $log_file
    sed -i "/upload_max_filesize = /c\upload_max_filesize = 20" /etc/php/*/apache2/php.ini &> $log_file
    sed -i "/max_execution_time = /c\max_execution_time = 300" /etc/php/*/apache2/php.ini &> $log_file
    sed -i "/memory_limit = /c\memory_limit = 256M" /etc/php/*/apache2/php.ini &> $log_file
    sed -i "/post_max_size = /c\post_max_size = 32M" /etc/php/*/apache2/php.ini &> $log_file
    sed -i "/max_input_time = /c\max_input_time = 90" /etc/php/*/apache2/php.ini &> $log_file
    sed -i "/max_input_vars = /c\max_input_vars = 5000" /etc/php/*/apache2/php.ini &> $log_file
    sed -i "/;date.timezone =/c\date.timezone = Europe/Paris" /etc/php/*/apache2/php.ini &> $log_file
    check_status
}

download_itop ()
{
    show_time
    echo -n "Downloading latest iTop from source..."
    wget https://sourceforge.net/projects/itop/files/itop/3.1.0-1/iTop-3.1.0-1-11836.zip &> $log_file
    check_status
}

install_itop ()
{
    show_time
    echo -n "Installing iTop..."
    unzip iTop-*.zip -d /var/www/html/ &> $log_file
    hidden_check_status
    # mv /var/www/html/web /var/www/html/itop  /!\ changing dir
    mv /var/www/html/web/* /var/www/html/
    hidden_check_status
    # chown -R www-data:www-data /var/www/html/itop/  /!\ changing dir
    chown -R www-data:www-data /var/www/html
    # hidden_check_status
    # chmod -R 755 /var/www/html/itop/
    hidden_check_status
    cp /var/www/html/index.html /var/www/html/index.html.old #  /!\ changing dir
    rm /var/www/html/index.html #  /!\ changing dir
    rm iTop-*.zip
    check_status
}

update_apache_config ()
{
    show_time
    echo -n "Updating apache config..."
    # echo -e "<Directory /var/www/html/itop>\nOptions Indexes FollowSymLinks\nAllowOverride All\nRequire all granted\n</Directory>" >> /etc/apache2/apache2.conf  /!\ changing dir
    echo -e "<Directory /var/www/html>\nOptions Indexes FollowSymLinks\nAllowOverride All\nRequire all granted\n</Directory>" >> /etc/apache2/apache2.conf
    check_status
}

restart_services ()
{
    show_time
    echo -n "Restarting services..."
    systemctl restart apache2 &> $log_file
    hidden_check_status
    systemctl restart mysql &> $log_file
    check_status
}

install_done ()
{
    host_ip=$(ip r get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
    echo -e "\nInstallation of iTop is done\nContinue the installation: http://$host_ip\nLog file: $log_file\n"
}

main ()
{
    clear
    check_root_privilieges
    check_file_presence
    check_internet_access
    update
    install_prerequires
    update_php_config
    download_itop
    install_itop
    update_apache_config
    restart_services
    cleaning_up
    install_done
}

main