/*
 * Copyright 2016 Red Hat, Inc, and individual contributors.
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
 */
package eventbusbridge;

import java.util.Collections;
import java.util.List;

import com.google.common.primitives.Chars;
import io.vertx.core.Vertx;
import io.vertx.core.eventbus.EventBus;
import io.vertx.core.eventbus.Message;
import io.vertx.core.json.JsonObject;
import io.vertx.ext.bridge.BridgeOptions;
import io.vertx.ext.bridge.PermittedOptions;
import io.vertx.ext.eventbus.bridge.tcp.TcpEventBusBridge;

public class Main {

    public static void main(String[] args) {
        final Vertx vertx = Vertx.vertx();
        final EventBus eb = vertx.eventBus();
        TcpEventBusBridge bridge = TcpEventBusBridge.create(
                vertx,
                new BridgeOptions()
                        .addOutboundPermitted(new PermittedOptions().setAddressRegex("word.*"))
                        .addInboundPermitted(new PermittedOptions().setAddressRegex("word.*")));

        bridge.listen(7001, res -> {
            System.out.println("Vert.x bridge started on 7001");

            vertx.eventBus().consumer("word.scramble", (Message<JsonObject> m) -> {
                String word = m.body().getString("word");

                List<Character> chars = Chars.asList(word.toCharArray());
                Collections.shuffle(chars);
                String scrambled = new String(Chars.toArray(chars));

                JsonObject reply = new JsonObject();
                reply.put("word", word);
                reply.put("scrambled", scrambled);
                m.reply(reply);
            });
        });
    }

}
