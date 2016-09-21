This provides a Swift client for talking to [Vert.x](http://vertx.io)
via the
[vertx-tcp-eventbus-bridge](https://github.com/vert-x3/vertx-tcp-eventbus-bridge).

It has only been tested with the
[2016-07-25 snapshot](https://swift.org/download/#snapshots) of Swift,
and only on MacOS X.

## Running the tests

`make test`

The tests build a Vert.x server and launch it, so you'll need Java (8 or higher) and maven installed.

## License

vertx-swift-eventbus is licensed under the Apache License, v2. See
[LICENSE](LICENSE) for details.

