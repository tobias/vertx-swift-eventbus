import Kitura
import KituraStencil
import VertxEventBus
import Darwin

print("Starting example app on http://localhost:8080...")

// create an eventBus, set a top-level error hander, and connect to the bridge server
let eventBus = EventBus(host: "localhost", port: 7001)
eventBus.register(errorHandler: { print($0) })
do {
   try eventBus.connect()
} catch let error {
    print("Failed to connect to the event bus bridge; is it running? \(error)")
    exit(1)
}

var words = [String: Word]()

func reverse(_ str: String) -> String {
    return String(str.characters.reversed())
}

// register a listener to reverse words, sending the result back on a different address
let _ = try eventBus.register(address: "word.reverse") {
    if let word = $0.body["word"].string {
        do {
            try eventBus.send(to: "word.reversed", body: ["word": word, "reversed": reverse(word)])
        } catch let error {
            print("Failed to send to the eventBus: \(error)")
        }
    }
}

// register a listener to store the reversed words
let _ = try eventBus.register(address: "word.reversed") {
    if let word = $0.body["word"].string,
       let reversed = $0.body["reversed"].string,
       let wordRecord = words[word] {
        wordRecord.reversed = reversed
    }
}

func respond(_ response: RouterResponse) throws {
    try response.render("index.stencil", context: ["words": Array(words.values)])
      .end()
}

let router = Router()
router.add(templateEngine: StencilTemplateEngine())
router
  .get("/") { _, response, _ in
      try respond(response)
  }
  .post("/") { request, response, _ in
      if let body = try request.readString() {
          let parts = body.components(separatedBy: "=")
          if parts.count > 1 {
              let wordStr = parts[1] 
              if strlen(wordStr) > 0 {
                  var word = words[wordStr] ?? Word(wordStr)
                  words[wordStr] = word
                  let msg = ["word": wordStr]

                  // send the word off to the reverser
                  try eventBus.send(to: "word.reverse", body: msg)

                  // send the word off to the scrambler (implemented in the Java bridge), and register
                  // a callback to handle the response, storing it
                  try eventBus.send(to: "word.scramble", body: msg) {
                      if let msg = $0.message,
                         let scrambled = msg.body["scrambled"].string {
                          word.scrambled = scrambled
                      } else {
                          print("reply timed out!")
                      }
                  }
              }
          }
      }
      try respond(response)
  }
 .error { request, response, next in
     response.headers["Content-Type"] = "text/plain"
     let errorDescription: String
     if let error = response.error {
         errorDescription = "\(error)"
     } else {
         errorDescription = "Unknown error"
     }
     try response.send("An error occurred: \(errorDescription)").end()
 }


Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()

