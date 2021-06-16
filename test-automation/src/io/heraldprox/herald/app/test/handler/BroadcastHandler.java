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
 * Set pending commands for broadcasting to all devices. Omit commands
 * parameters to clear all pending commands. <br>
 * URL: /broadcast?commands=[pendingCommands]
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
		final String commands = parameters.get("commands");
		final String inSeconds = parameters.get("in");
		if (null == inSeconds) {
			final String response = automatedTestServer.broadcast(commands);
			sendResponse(httpExchange, 200, response);
			logger.log(Level.INFO,
					"broadcast, complete (remote=" + httpExchange.getRemoteAddress() + ",commands=" + commands + ")");
		} else {
			final String response = automatedTestServer.broadcast(commands, Long.parseLong(inSeconds));
			sendResponse(httpExchange, 200, response);
			logger.log(Level.INFO, "broadcast, complete (remote=" + httpExchange.getRemoteAddress() + ",commands="
					+ commands + ",inSeconds=" + inSeconds + ")");
		}
	}

}
