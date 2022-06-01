#!/bin/bash

PROJECT=$1
REPOSITORY=$2

gcloud builds submit ../../.. --project "$PROJECT" --tag "$REPOSITORY/conduit-server"
