#!/bin/bash

ASG_ID=22

curl -s -X GET -H "x-auth: $INKFISH_KEY" \
  http://localhost:4000/api/v1/staff/subs?assignment_id=$ASG_ID |
  jq
