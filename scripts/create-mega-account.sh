#!/bin/bash
###################
# argument parser #
###################
while getopts "hd:e:" opt; do
  case ${opt} in
    h )
      echo "Usage:"
      echo "    -h                Display this help message."
      echo "    -d                Domain for Mega account"
      echo "    -e                Username to generate Mega account"
      exit 0
      ;;
    d )
      domain=$OPTARG
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
    cnt=$(<"$user_cntfile")
    cnt=$(( cnt + 1 ))
    username="$user_cnt"
fi

# create email
/usr/local/bin/addmailuser "$username@$domain"


# remove all inbox
email_dir="/var/mail/$domain/$username/new/"
rm -rf "$email_dir*"

# account creation with same password generated for email
reg=$(megareg --register --email "$email" --name "John Doe" --password "$password")

# get verify code part 1
code1=$(echo "${reg}" | sed -n 3p)

if [[ "$code1" == "" ]]
then
	echo "Already registered the email: $email."
    if [[ "$user_cnt" != "" ]]
    then
        # increment the counter
        echo "$user_cnt" > "$user_cntfile"
        echo "Incremented account counter $user_cnt"
    fi
	exit
fi

#check if email containing code is there
check_cnt=1
function checkforcode {
	sleep 2 # wait for email to arrive in inbox.

    if (("$check_cnt" < "20"))
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
                echo "attempt" $check_cnt
                check_cnt=$(( check_cnt + 1 ))
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
# cmd "${code1/@LINK@/$code2}" > /tmp/createMegaVerification
# verifyCODE=$(</tmp/createMegaVerification)
# rm /tmp/createMegaVerification
verifyCODE=$(cmd "${code1/@LINK@/$code2}")

if [[ $verifyCODE == *"Account registered successfully!"* ]]
then
    # increment counter
	if [[ "$user_cnt" != "" ]]
    then
        echo "$user_cnt" > "$user_cntfile"
    fi

	echo "{'email': $email, 'password': $password}\n" >> /var/log/mega-accounts.log
	echo "{'email': $email, 'password': $password}"
else
	echo "failed registration: $verifyCODE"
fi

#finished running
rm -f $LOCKFILE