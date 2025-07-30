#!/bin/bash

ASG_ID=123

curl -s -X GET -H "x-auth: $INKFISH_KEY" http://localhost:4000/api/v1/subs?assignment_id=$ASG_ID | jq
