import Foundation

let eb = try EventBus(host: "localhost", port: 7000)

try eb.register(address: "out") {
    msg in
    print("HANDLER \(msg)")
    print(msg["body"]["now"].int)
}

print("Started")

// poor man's blocking
var foo = NSString(data:NSFileHandle.fileHandleWithStandardInput().availableData, encoding:NSUTF8StringEncoding)
