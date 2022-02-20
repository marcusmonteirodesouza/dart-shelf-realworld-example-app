#!/usr/bin/env bash

docker compose down && docker compose run --publish 5432:5432 --detach db && dart bin/server.dart && docker compose down
