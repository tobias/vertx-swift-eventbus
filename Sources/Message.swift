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

public class Message {
    let basis: JSON
    let eventBus: EventBus
    
    var body: JSON {
        return basis["body"]
    }

    var headers: [String: String] {
        return (basis["headers"].dictionaryObject as! [String: String]?) ?? [String: String]()
    }
    
    init(basis: JSON, eventBus: EventBus) {
        self.basis = basis
        self.eventBus = eventBus
    }

    public func reply(_ body: [String: Any]) throws {
        try reply(body: body)
    }
    
    public func reply(body: [String: Any], headers: [String: String]? = nil, callback: ((Message) -> ())? = nil) throws {
        if let replyAddress = self.basis["replyAddress"].string {
            try self.eventBus.send(to: replyAddress, body: body, headers: headers, callback: callback)
        }

    }
    
}
