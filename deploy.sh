#!/bin/bash
export $(grep -v '^#' .env | xargs)
rm -rf "mail/$DOMAIN/"
echo '1@|{SHA512-CRYPT}$6$ie22FSkEZyEYY8vz$CD8OY2SWbJfgzYJ5BIiPk/YXS4cc4cyhEFrYRTNCA2tmUlQ.Zw1iywX5GBpG6Y93rIyL.Wf1ZOi1BOY1cw.UR.'>config/postfix-accounts.cf
docker-compose up -d
docker stack deploy -c stack.yml mega
