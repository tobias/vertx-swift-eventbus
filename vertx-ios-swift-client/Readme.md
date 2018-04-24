# Vert.x EventBus bridge iOS client app

This app demonstrates the Swift EventBus bridge library inside an iOS app. 

## Running the example

Install cocoapod dependencies

```console
$ pod install
```

Open the **vertx-ios-swift-client.xcworkspace**  
(you'll need XCode installed)

Open up Terminal and start up the EventBus bridge,  
which is a Java application  
(you'll need [Maven](https://maven.apache.org) and Java installed):

```console
$ cd bridge-server
$ mvn package
$ java -jar target/bridge-server.jar
```

Go back to XCode and run the app (⌘R)
