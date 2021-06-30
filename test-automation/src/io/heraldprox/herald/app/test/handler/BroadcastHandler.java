//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.herald.app.test.handler;

import java.io.IOException;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.sun.net.httpserver.HttpExchange;

import io.heraldprox.herald.app.test.AutomatedTestServer;

/**
 * Set pending commands for broadcasting to all devices.<br>
 * URL: /broadcast?commands=[commands]<br>
 * URL: /broadcast?id=[id]&commands=[commands]<br>
 * URL:
 * /broadcast?commands=[commands]&hours=[hours]&minutes=[minutes]&seconds=[seconds]<br>
 * URL: /broadcast?clear URL: /broadcast?id=[id]&clear
 *
 */
public class BroadcastHandler extends AbstractHttpHandler {
	private final static Logger logger = Logger.getLogger(BroadcastHandler.class.getName());

	public BroadcastHandler(final AutomatedTestServer automatedTestServer) {
		super(automatedTestServer);
	}

	@Override
	public void handle(HttpExchange httpExchange) throws IOException {
		logger.log(Level.INFO, "broadcast (remote=" + httpExchange.getRemoteAddress() + ",uri="
				+ httpExchange.getRequestURI().toString() + ")");
		// Parse parameters
		final Map<String, String> parameters = parseRequestParameters(httpExchange);
		if (parameters.containsKey("id")) {
			final int id = Integer.parseInt(parameters.get("id"));
			if (parameters.containsKey("commands")) {
				final String commands = parameters.get("commands");
				automatedTestServer.broadcast(id, commands);
				logger.log(Level.INFO, "broadcast, scheduled commands (remote=" + httpExchange.getRemoteAddress()
						+ ",id=" + id + ",commands=" + commands + ")");
			} else if (parameters.containsKey("clear")) {
				automatedTestServer.broadcast(id, null);
				logger.log(Level.INFO,
						"broadcast, cleared commands (remote=" + httpExchange.getRemoteAddress() + ",id=" + id + ")");
			}
		} else {
			if (parameters.containsKey("commands")) {
				final String commands = parameters.get("commands");
				final String seconds = parameters.getOrDefault("seconds", "0");
				final String minutes = parameters.getOrDefault("minutes", "0");
				final String hours = parameters.getOrDefault("hours", "0");
				final long inSeconds = Long.parseLong(seconds) + 60 * Long.parseLong(minutes)
						+ 60 * 60 * Long.parseLong(hours);
				automatedTestServer.broadcast(commands, inSeconds);
				logger.log(Level.INFO,
						"broadcast, scheduled commands (remote=" + httpExchange.getRemoteAddress() + ",commands="
								+ commands + ",inSeconds=" + inSeconds + "[" + hours + ":" + minutes + ":" + seconds
								+ ")");
			} else if (parameters.containsKey("clear")) {
				automatedTestServer.broadcastClear();
				logger.log(Level.INFO, "broadcast, cleared commands (remote=" + httpExchange.getRemoteAddress() + ")");
			}
		}
		final String response = automatedTestServer.broadcastScheduled();
		sendResponse(httpExchange, 200, response);
		logger.log(Level.INFO, "broadcast, complete (remote=" + httpExchange.getRemoteAddress() + ")");
	}

}
