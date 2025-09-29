#!/bin/bash
# Rebuilds the docker container for PostgreSQL
docker-compose rm -sf && docker-compose up

