#!/bin/bash
export $(grep -v '^#' .env | xargs)
rm -rf "mail/$DOMAIN/"
> config/postfix-accounts.cf
docker-compose up -d
docker stack deploy -c stack.yml mega
