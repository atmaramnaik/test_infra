#!/bin/bash

function shutdown {
  kill -s SIGTERM $NODE_PID
  wait $NODE_PID
}

rm -f /tmp/.X*lock

export GEOMETRY="$SCREEN_WIDTH""x""$SCREEN_HEIGHT""x""$SCREEN_DEPTH"

Xvfb :99 -screen 0 $GEOMETRY &
NODE_PID=$!

./docker-entrypoint.sh

trap shutdown SIGTERM SIGINT
wait $NODE_PID
