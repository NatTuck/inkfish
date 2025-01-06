#!/bin/bash

export MIX_ENV=test
mix ecto.reset
mix test

cd assets
npm install
npm test
