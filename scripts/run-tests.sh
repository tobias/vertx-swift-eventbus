#!/bin/bash

semaphore=test-server/target/semaphore

rm -f $semaphore
java -jar test-server/target/test-server.jar 7001 $semaphore &
server_pid=$!

echo "Waiting for test server to start..."
while [ ! -f $semaphore ]; do
    sleep 1
done

swift test
retval=$?

kill -9 $server_pid

exit $retval



