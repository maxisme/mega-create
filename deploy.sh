#!/bin/bash
export $(grep -v '^#' .env | xargs)
docker-compose up -d
docker stack deploy -c mega-create.yml mega