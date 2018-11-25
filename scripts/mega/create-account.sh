#!/bin/bash
###################
# argument parser #
###################
while getopts "hd:n:u:p:e:" opt; do
  case ${opt} in
    h )
      echo "Usage:"
      echo "    -h                Display this help message."
      echo "    -d                Email domain for Mega account"
      echo "    -n                Database name"
      echo "    -u                Database username"
      echo "    -p                Database password"
      echo "    -e                Email username to generate Mega account"
      exit 0
      ;;
    d )
      domain=$OPTARG
      ;;
    n )
      db_name=$OPTARG
      ;;
    u )
      db_user=$OPTARG
      ;;
    p )
      db_pass=$OPTARG
      ;;
    e )
      username=$OPTARG
      ;;
    \? )
      echo "Invalid Option: -$OPTARG" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))


if [[ "$domain" == "" ]]
then
    echo "You must specify the email domain [-d]"
    exit 1
fi

if [[ "$db_name" == "" ]]
then
    echo "You must specify the database name [-n]"
    exit 1
fi

if [[ "$db_user" == "" ]]
then
    echo "You must specify the database username [-u]"
    exit 1
fi

if [[ "$db_pass" == "" ]]
then
    echo "You must specify the database password [-p]"
    exit 1
fi


###############
# lock script #
###############
LOCKFILE="/tmp/creatingmega"
if [ -f $LOCKFILE ]; then
	echo "createNewMega already running"
	exit 1
else
	touch $LOCKFILE
fi
trap $(rm -f $LOCKFILE)


##########
# SCRIPT #
##########
cntfile="/root/mega/cnt_$domain"

if [[ "$username" == "" ]]
then
    # use incremental counter if no username specified
    cnt=$(<"$cntfile")
    cnt=$(( cnt + 1 ))
    username="$cnt"
fi

# email account details
email="$username@$domain"

# create email account
password=$(bash ../add-user.sh -u "$db_user" -p "$db_pass" -n "$db_name" -e "$email")

# remove all inbox
email_dir="/var/mail/vhosts/$domain/$username/new/"
rm -rf "$email_dir*"

# account creation with same password generated for email
reg=$(megareg --register --email "$email" --name "Foo" --password "$password")

# get verify code part 1
code1=$(echo "${reg}" | sed -n 3p)

if [[ "$code1" == "" ]]
then
	echo "Already registered this email $email."
    if [[ "$cnt" != "" ]]
    then
        # increment the counter
        echo "$cnt" > "$cntfile"
        echo "Incremented account counter $cnt"
    fi
	exit
fi

#check if email containing code is there
X=1
function checkforcode {
	sleep 5 # wait for email to arrive in inbox.

    if (("$X" < "20"))
    then
        # look for verify email in inbox with verify code part 2
        for i in "$email_dir"*
        do
            #get line number of https://mega.nz/#confirm
            lineN=$(awk '/https:\/\/mega\.nz\/\#confirm/{ print NR; exit }' "$i")
            code2=$(sudo sh -c "sed '$lineN!d' $i")

            #add .co to domain
            code2=${code2/mega.nz/mega.co.nz}
            if [[ $code2 != *"mega"* ]]
            then
                echo "attempt" $X
                X=$(( X + 1 ))
                checkforcode
            fi
        done
    else
        echo "No email received from mega!"
        exit
    fi
}
checkforcode

# run verifying code
cmd "${code1/@LINK@/$code2}" > /tmp/createMegaVerification
verifyCODE=$(</tmp/createMegaVerification)
rm /tmp/createMegaVerification

if [[ $verifyCODE == *"Account registered successfully!"* ]]
then
    # increment counter
	if [[ "$cnt" != "" ]]
    then
        echo "$cnt" > "$cntfile"
    fi

    # insert account details into db
	mysql --user="$db_user" --password="$db_pass" -e "USE $db_name; INSERT INTO mega_account (username, password) VALUES ('$email', '$password')"

	echo "{'email': $email, 'password': $password}"
else
	echo "failed registration: $verifyCODE"
fi

#finished running
rm -f $LOCKFILE