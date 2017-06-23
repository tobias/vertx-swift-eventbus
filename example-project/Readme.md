# Vert.x EventBus bridge sample app

This simple app demonstrates the Swift EventBus bridge library. 

## Running the example

First, you'll need to start up the EventBus bridge, which is a Java
application (you'll need [Maven](https://maven.apache.org) and Java
installed):

```console
$ cd bridge-server
$ mvn package
$ java -jar target/bridge-server.jar
```

Then you'll need to build and start the Swift application:

```console
$ make
```

Finally, point a browser at http://localhost:8080.

