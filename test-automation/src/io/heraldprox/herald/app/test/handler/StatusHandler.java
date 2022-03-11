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
 * Get current status of all devices. <br>
 * URL: /status
 */
public class StatusHandler extends AbstractHttpHandler {
	private final static Logger logger = Logger.getLogger(StatusHandler.class.getName());

	public StatusHandler(final AutomatedTestServer automatedTestServer) {
		super(automatedTestServer);
	}

	@Override
	public void handle(HttpExchange httpExchange) throws IOException {
		logger.log(Level.INFO, "status (remote=" + httpExchange.getRemoteAddress() + ",uri="
				+ httpExchange.getRequestURI().toString() + ")");
		final Map<String, String> parameters = parseRequestParameters(httpExchange);
		String response = "";
		if (parameters.containsKey("csv")) {
			response = automatedTestServer.statusCsv();
		} else {
			response = automatedTestServer.status();
		}
		sendResponse(httpExchange, 200, response);
		logger.log(Level.INFO, "status, complete (remote=" + httpExchange.getRemoteAddress() + ")");
	}

}
