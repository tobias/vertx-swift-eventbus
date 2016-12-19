/**
 * Copyright Red Hat, Inc 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import SwiftyJSON

/// Represents an EventBus message with metadata.
public class Message {
    let basis: JSON
    let eventBus: EventBus

    var headers: [String: String] {
        return (basis["headers"].dictionaryObject as! [String: String]?) ?? [String: String]()
    }

    init(basis: JSON, eventBus: EventBus) {
        self.basis = basis
        self.eventBus = eventBus
    }

    /// The body (content) of the message.
    public var body: JSON {
        return basis["body"]
    }

    /// True if this message was the result of a send (vs. publish)
    public var isSend: Bool {
        if let s = basis["send"].bool {

            return s
        }

        return false
    }
    
    /// Sends back a reply to this message
    ///
    /// - parameters:
    ///   - <#body#>: the content of the message
    ///   - <#headers#>: headers to send with the message (default: `[String: String]()`)
    ///   - <#replyTimeout#>: the timeout (in ms) to wait for a reply if a reply callback is provided (default: `30000`)
    ///   - <#callback#>: the callback to handle the reply or timeout `Response` (default: `nil`)
    /// - throws: `EventBus.Error.invalidData(data:)` if the given `body` can't be converted to JSON
    /// - throws: `EventBus.Error.disconnected(cause:)` if not connected to the remote bridge
    public func reply(body: [String: Any],
                      headers: [String: String]? = nil,
                      replyTimeout: Int = 30000, // 30 seconds
                      callback: ((Response) -> ())? = nil) throws {
        if let replyAddress = self.basis["replyAddress"].string {
            try self.eventBus.send(to: replyAddress, body: body, headers: headers, replyTimeout: replyTimeout, callback: callback)
        }

    }
    
}
