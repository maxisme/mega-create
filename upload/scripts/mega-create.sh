#!/bin/bash
DOMAIN="$DOMAINNAME"
RETRIES=5

##########
# SCRIPT #
##########
password=$(
  strings /dev/urandom | grep -o '[[:alnum:]]' | head -n 50 | tr -d '\n'
  echo
)

username="$1"
if [[ "$username" == "" ]]; then
  username=$(date +%s%N)
fi

# create email
email="$username@$DOMAIN"
/usr/bin/local/add-user.sh "$email" "$password"

# remove all inbox
email_dir="/var/mail/$DOMAIN/$username/new/"
rm -rf "$email_dir*"

sleep 1

# account creation with same password generated for email
reg=$(megareg --register --email "$email" --name "John Doe" --password "$password")

# get verify code part 1
part1=$(echo "${reg}" | sed -n 3p)

sleep 10

c=1
while [[ $c -le $RETRIES ]]
do
  du "$email_dir"
  if [ -d "$email_dir" ]; then
    echo "in!!!"
    # look for verify email in inbox with verify code part2
    for i in "$email_dir"*; do
      # get line number of https://mega.nz/#confirm
      lineN=$(awk '/https:\/\/mega\.nz\/\#confirm/{ print NR; exit }' "$i")
      # extract part2 of verification code
      part2=$(sh -c "sed '$lineN!d' $i")

      # use new domain
      part2=${part2/mega.nz/mega.co.nz}
      if [[ $part2 != *"mega"* ]]; then
        exit 1
      fi
    done
    break
  fi
  sleep 1
  let c=c+1
done

if [ -z "$part2" ]
then
  echo "Did not receive confirmation email in time"
  exit 1
fi

# run verifying code
verifyCODE=$(eval "${part1/@LINK@/$part2}")

if [[ $verifyCODE == *"Account registered successfully!"* ]]; then
  echo "{\"email\": \"$email\", \"password\": \"$password\"}"
else
  echo "failed registration: $verifyCODE"
  exit 1
fi
