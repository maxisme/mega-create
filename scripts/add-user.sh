#!/bin/bash

###################
# argument parser #
###################
email=$1
db_name=$MAIL_DB_NAME
db_user=$MAIL_DB_USER
db_pass=$MAIL_DB_PASS

if [[ "$email" == "" ]]
then
    echo "You must specify the email (foo@bar.com)"
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

password=$(date +%s | sha256sum | base64 | head -c 32 ; echo) # generate random string

mysql --user="$db_user" --password="$db_pass" -e "USE $db_name; INSERT INTO virtual_users (domain_id, password , email) VALUES ('1', ENCRYPT('$password', CONCAT('\$6\$', SUBSTRING(SHA(RAND()), -16))), '$email');"

exit "$password"