#!/bin/bash

USER="inkfish"
HOST="homework.quest"

rsync -avz --delete ../inkfish $USER@$HOST:~/

ssh $USER@$HOST bash -c "'(cd inkfish && scripts/deploy.sh)'"
