#!/bin/bash

semaphore=test-server/target/semaphore

rm -f $semaphore
java -jar test-server/target/test-server.jar 7001 $semaphore &
server_pid=$!

function cleanup {
    kill -9 $server_pid
}
trap cleanup EXIT

echo "Waiting for test server to start..."
while [ ! -f $semaphore ]; do
    sleep 1
done

swift test
