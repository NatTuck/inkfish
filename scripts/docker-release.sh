#!/bin/bash

(cd rel/container && docker build . -t inkfish:build)

docker run -w /home/inkfish/inkfish \
       -v $(pwd):/home/inkfish/inkfish \
       inkfish:build \
       su - inkfish -c '(cd ~/inkfish && bash scripts/build.sh)'
