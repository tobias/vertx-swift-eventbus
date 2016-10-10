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

import com.fasterxml.jackson.databind.util.JSONPObject;
import io.vertx.core.AsyncResult;
import io.vertx.core.AsyncResultHandler;
import io.vertx.core.Handler;
import io.vertx.core.Vertx;
import io.vertx.core.eventbus.EventBus;
import io.vertx.core.eventbus.Message;
import io.vertx.core.json.Json;
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
                        .addOutboundPermitted(new PermittedOptions().setAddressRegex("test.*"))
                .addInboundPermitted(new PermittedOptions().setAddressRegex("test.*")));

        final int port = Integer.parseInt(args[0]);

        bridge.listen(port, "127.0.0.1", res -> {
            System.out.println("Vert.x bridge started on " + port);
            vertx.setPeriodic(100, timer -> {
                //System.out.println("Sending the time...");
                eb.publish("test.time", new JsonObject().put("now", System.currentTimeMillis()));
            });

            vertx.eventBus().consumer("test.echo",  m -> {
                //System.out.println("echo: " + m.body());
                JsonObject reply = new JsonObject();
                JsonObject headers = new JsonObject();
                m.headers().forEach(e -> headers.put(e.getKey(), e.getValue()));

                reply.put("original-body", m.body())
                        .put("original-headers", headers);
                System.out.println("REPLY: " + m.headers() + " | " + reply);
                m.reply(reply);
                // send a copy to another address as well to test non-replyable messages
                eb.publish("test.echo.responses", reply);
            });

            vertx.eventBus().consumer("test.ping-pong", Main::pingPong);
        });
    }

    static final AsyncResultHandler<Message<JsonObject>> pingPongReply = event -> pingPong(event.result());

    static void pingPong(final Message<JsonObject> m) {
        final int counter = m.body().getInteger("counter");
        System.out.println("ping-pong: count is " + counter);
        final JsonObject reply = new JsonObject();
        reply.put("counter", counter + 1);
        m.reply(reply, pingPongReply);
    }
}
