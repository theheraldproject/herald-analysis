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
import io.heraldprox.herald.app.test.TestDevice;

/**
 * Send heartbeat to server to register device characteristics and current
 * status. <br>
 * URL:
 * /heartbeat?model=[modelName]&os=[operatingSystem]&version=[operatingSystemVersion]&payload=[payloadShortName]&status=[sensorArrayOn|Off]
 */
public class HeartbeatHandler extends AbstractHttpHandler {
	private final static Logger logger = Logger.getLogger(HeartbeatHandler.class.getName());

	public HeartbeatHandler(final AutomatedTestServer automatedTestServer) {
		super(automatedTestServer);
	}

	@Override
	public void handle(HttpExchange httpExchange) throws IOException {
		logger.log(Level.INFO, "heartbeat (remote=" + httpExchange.getRemoteAddress() + ",uri="
				+ httpExchange.getRequestURI().toString() + ")");
		// Parse parameters
		final Map<String, String> parameters = parseRequestParameters(httpExchange);
		final String model = parameters.get("model");
		final String operatingSystem = parameters.get("os");
		final String operatingSystemVersion = parameters.get("version");
		final String payload = parameters.get("payload");
		final String status = parameters.get("status");
		if (null == model || null == operatingSystem || null == operatingSystemVersion || null == payload
				|| null == status) {
			// On parse error, return "error" as response
			logger.log(Level.WARNING,
					"heartbeat, request missing parameter (remote=" + httpExchange.getRemoteAddress() + ")");
			sendResponse(httpExchange, 400, "error");
			return;
		}
		// Register heartbeat with server and get pending commands for client
		final TestDevice testDevice = automatedTestServer
				.heartbeat(new TestDevice(model, operatingSystem, operatingSystemVersion, payload, status));
		final String testDeviceCommands = automatedTestServer.getAndClearCommands(testDevice);
		// Build CSV response starting with "ok"
		final StringBuilder responseBuilder = new StringBuilder();
		responseBuilder.append("ok");
		if (null != testDeviceCommands && !testDeviceCommands.isEmpty()) {
			responseBuilder.append(",");
			responseBuilder.append(testDeviceCommands);
		}
		sendResponse(httpExchange, 200, responseBuilder);
		logger.log(Level.INFO, "heartbeat, complete (remote=" + httpExchange.getRemoteAddress() + ",response="
				+ responseBuilder.toString() + ")");
	}

}
