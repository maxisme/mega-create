#!/bin/bash
DOMAIN="$DOMAINNAME"
RETRIES=20

##########
# SCRIPT #
##########
password=$(
  strings /dev/urandom | grep -o '[[:alnum:]]' | head -n 50 | tr -d '\n'
  echo
)

username="$1"
if [[ -z "$username" ]]; then
  username=$(date +%s%N)
fi

# create email
email="$username@$DOMAIN"
/usr/bin/local/add-user.sh "$email" "$password"

# remove all inbox
rm -rf "/var/mail/$DOMAIN/$username/*"

sleep 3

# account creation with same password generated for email
reg=$(megareg --register --email "$email" --name "John Doe" --password "$password")

# get verify code part 1
part1=$(echo "${reg}" | sed -n 3p)
echo "$part1" >"/var/mail/${username}.txt"
echo "$password" >"/var/mail/${username}_pass.txt"

sleep 3

c=1
while [[ $c -le $RETRIES ]]; do
  # look for verify email in inbox with verify code part2
  for dir in "/var/mail/$DOMAIN/"*"/"; do
    if [ -d "${dir}new/" ]; then
      for i in "${dir}new/"*; do
        user=${dir/\/var\/mail\/$DOMAIN\//}
        user=${user/\//}
        part1_file="/var/mail/${user}.txt"
        if [ -f "$part1_file" ]; then
          part1=$(cat "$part1_file")
          pass=$(cat "/var/mail/${user}_pass.txt")

          # get line number of https://mega.nz/#confirm
          lineN=$(awk '/https:\/\/mega\.nz\/\#confirm/{ print NR; exit }' "$i")
          # extract part2 of verification code
          part2=$(sh -c "sed '$lineN!d' $i")

          # use new domain
          part2=${part2/mega.nz/mega.co.nz}
          if [[ $part2 != *"mega"* ]]; then
            exit 1
          fi

          email="$user@$DOMAIN"

          # clean up
          rm -rf "/var/mail/$DOMAIN/$user/" "$part1_file"
          sed -i "/$user/d" /email-config/postfix-accounts.cf # remove account

          # run verifying code
          verifyCODE=$(eval "${part1/@LINK@/$part2}")

          if [[ $verifyCODE == *"Account registered successfully!"* ]]; then
            echo "{\"email\": \"$email\", \"password\": \"$pass\"}"
            exit
          else
            echo "failed registration: $verifyCODE"
            exit 1
          fi
        fi
      done
    fi
  done
  sleep 0.5
  let c=c+1
done

echo "Did not receive any confirmation emails in time."
exit 1
