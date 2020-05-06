#!/bin/bash
domain="$DOMAINNAME"

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
email="$username@$domain"
/usr/bin/local/add-user.sh "$email" "$password"

# remove all inbox
email_dir="/var/mail/$domain/$username/new/"
rm -rf "$email_dir*"

# account creation with same password generated for email
reg=$(megareg --register --email "$email" --name "John Doe" --password "$password")

# get verify code part 1
part1=$(echo "${reg}" | sed -n 3p)

# wait for email...
sleep 10

# look for verify email in inbox with verify code part2
for i in "$email_dir"*; do
  # get line number of https://mega.nz/#confirm
  lineN=$(awk '/https:\/\/mega\.nz\/\#confirm/{ print NR; exit }' "$i")
  # extract part2 of verification code
  part2=$(sh -c "sed '$lineN!d' $i")

  # use different domain
  part2=${part2/mega.nz/mega.co.nz}
  if [[ $part2 != *"mega"* ]]; then
    # failed to receive email in time so try again with new account
    bash "$0"
    exit
  fi
done

# run verifying code
verifyCODE=$(eval "${part1/@LINK@/$part2}")

if [[ $verifyCODE == *"Account registered successfully!"* ]]; then
  # increment counter
  if [[ "$cnt" != "" ]]; then
    echo "$cnt" >"$cntfile"
  fi

  echo "{\"email\": \"$email\", \"password\": \"$password\"}"

  rm -rf "/var/mail/$DOMAINNAME/*"
else
  echo "failed registration: $verifyCODE"
fi
