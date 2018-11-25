#!/bin/bash

###################
# argument parser #
###################
domain=$1
db_name=$MAIL_DB_NAME
db_user=$MAIL_DB_USER
db_pass=$MAIL_DB_PASS

if [[ "$domain" == "" ]]
then
    echo "You must specify the email domain"
    exit 1
fi

if [[ "$db_name" == "" ]]
then
    echo "You must specify the database name as an environment variable MAIL_DB_NAME"
    exit 1
fi

if [[ "$db_user" == "" ]]
then
    echo "You must specify the database username as an environment variable MAIL_DB_USER"
    exit 1
fi

if [[ "$db_pass" == "" ]]
then
    echo "You must specify the database password as an environment variable MAIL_DB_PASS"
    exit 1
fi

mysql --user="$db_user" --password="$db_pass" -e "INSERT INTO `$db_name`.`virtual_domains` (`name`) VALUES ('$domain');"