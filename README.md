## nfranke fork

Fixes these issues:
- Losing connection with the server would cause a stack overflow
- Upon re-connecting, previous registrations would not successfully be reregistered
- Util.intToBytes crash was fixed (may be a Swift 4.0-related issue)

## Description

This provides a Swift client for talking to [Vert.x](http://vertx.io)
via the
[vertx-tcp-eventbus-bridge](https://github.com/vert-x3/vertx-tcp-eventbus-bridge).

The original version has been tested with [Swift 3.1](https://swift.org/download/)
on macOS X and Ubuntu.

This fork has been tested on macOS with Swift 4.0 and Xcode 9.2

A simple example application is available in [example-project](https://github.com/nfranke/vertx-swift-eventbus/tree/master/example-project).

The API docs are (still) available at http://tobias.github.io/vertx-swift-eventbus/.

## Usage

The latest release is `0.2.1`. To use it with Swift Package Manager,
add the following to your dependencies in `Package.swift`:

```swift
.Package(url: "https://github.com/nfranke/vertx-swift-eventbus.git", "0.2.1")
```

## Running the tests

`make test`

The tests build a Vert.x server and launch it, so you'll need Java (8
or higher) and maven installed.

## Generating docs

To generate documentation, you'll need to have
[`sourcekitten`](https://github.com/jpsim/SourceKitten) and
[`jazzy`](https://github.com/realm/jazzy) installed. The easiest way
to do that (on MacOS) is with:

```
brew install sourcekitten
sudo gem install jazzy
```

Then, build the docs with:

`make docs`

The generated docs will be available in `docs/`.

## License

vertx-swift-eventbus is licensed under the Apache License, v2. See
[LICENSE](https://github.com/nfranke/vertx-swift-eventbus/blob/master/LICENSE) for details.

