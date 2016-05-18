This provides a Swift client for talking to [Vert.x](http://vertx.io)
via the
[vertx-tcp-eventbus-bridge](https://github.com/vert-x3/vertx-tcp-eventbus-bridge).

It has only been tested with the
[2016-05-09 snapshot](https://swift.org/download/#snapshots) of Swift,
and only on Ubuntu 15.10.

To build on Ubuntu, you'll need to install the Swift snapshot, plus
[libdispatch](https://github.com/apple/swift-corelibs-libdispatch):

`sudo apt-get install autoconf libtool libkqueue-dev libkqueue0 libcurl4-openssl-dev libbsd-dev libblocksruntime-dev`

`git clone -b experimental/foundation https://github.com/apple/swift-corelibs-libdispatch.git && cd swift-corelibs-libdispatch && git submodule init && git submodule update && sh ./autogen.sh && ./configure --with-swift-toolchain=<path-to-swift>/usr --prefix=<path-to-swift>/usr && make && make install`

## License

vertx-swift-eventbus is licensed under the Apache License, v2. See
[LICENSE](LICENSE) for details.

