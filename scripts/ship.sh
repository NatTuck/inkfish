#!/bin/bash

USER="inkfish"
HOST="gargoyle"

(cd .. && rsync -avz --delete --exclude inkfish/deps --exclude inkfish/assets/node_modules --exclude inkfish/_build inkfish $USER@$HOST:~/)

ssh $USER@$HOST bash -c "'(cd inkfish && scripts/deploy-user.sh)'"
