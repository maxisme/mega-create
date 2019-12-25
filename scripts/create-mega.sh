#!/bin/bash
. ../.env
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
trap rm -f $LOCKFILE

##########
# SCRIPT #
##########
password=$(strings /dev/urandom | grep -o '[[:alnum:]]' | head -n 50 | tr -d '\n'; echo)
cntfile="/root/mega/cnt_$domain"

mkdir -p /root/mega/

username="$1"
if [[ "$username" == "" ]]
then
    # use incremental counter if no username specified
    cnt=$(<"$cntfile")
    if [[ "$cnt" == "" ]]
    then
	    cnt=0
    fi
    cnt=$(( cnt + 1 ))
    username="$cnt"
fi

# create email
email="$username@$domain"
/usr/local/bin/addmailuser "$email" "$password"

# remove all inbox
email_dir="/var/mail/$domain/$username/new/"
rm -rf "$email_dir*"

# account creation with same password generated for email
reg=$(megareg --register --email "$email" --name "John Doe" --password "$password")

# get verify code part 1
part1=$(echo "${reg}" | sed -n 3p)

if [[ "$part1" == "" ]]
then
	echo "Already registered the email: $email."
    if [[ "$cnt" != "" ]]
    then
        # increment the counter
        echo "$cnt" > "$cntfile"

        echo "Incremented account counter $cnt"
    fi
	exit
fi

#check if email containing code is there
check_cnt=1
function checkforcode {
	sleep 5 # wait for email to arrive in inbox.

    if (("$check_cnt" < "20"))
    then
        # look for verify email in inbox with verify code part 2
        for i in "$email_dir"*
        do
            #get line number of https://mega.nz/#confirm
            lineN=$(awk '/https:\/\/mega\.nz\/\#confirm/{ print NR; exit }' "$i")
            part2=$(sh -c "sed '$lineN!d' $i")

            #add .co to domain
            part2=${part2/mega.nz/mega.co.nz}
            if [[ $part2 != *"mega"* ]]
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
echo "${part1/@LINK@/$part2}"
verifyCODE=$(eval "${part1/@LINK@/$part2}")

if [[ $verifyCODE == *"Account registered successfully!"* ]]
then
    # increment counter
	if [[ "$cnt" != "" ]]
    then
        echo "$cnt" > "$cntfile"
    fi

	echo "{'email': $email, 'password': $password}\n" >> /var/log/mega-accounts.log
	echo "{'email': $email, 'password': $password}"
else
	echo "failed registration: $verifyCODE"
fi

#finished running
rm -f $LOCKFILE