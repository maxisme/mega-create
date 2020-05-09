#!/bin/bash
export $(cat .env | xargs) && rails c
docker-compose up -d
docker stack deploy -c mega-create.yml mega