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
 * Upload file from client to server.<br>
 * URL:
 * /upload?model=[modelName]&os=[operatingSystem]&version=[operatingSystemVersion]&payload=[payloadShortName]&status=[sensorArrayOn|Off]&filename=[filename]
 */
public class UploadHandler extends AbstractHttpHandler {
	private final static Logger logger = Logger.getLogger(UploadHandler.class.getName());

	public UploadHandler(final AutomatedTestServer automatedTestServer) {
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
		final String filename = parameters.get("filename");
		if (null == model || null == operatingSystem || null == operatingSystemVersion || null == payload
				|| null == status || null == filename) {
			// On parse error, return "error" as response
			logger.log(Level.WARNING,
					"upload, request missing parameter (remote=" + httpExchange.getRemoteAddress() + ")");
			sendResponse(httpExchange, 400, "error");
			return;
		}
		// Upload file to server
		try {
			final long bytesRead = automatedTestServer.upload(
					new TestDevice(model, operatingSystem, operatingSystemVersion, payload, status), filename,
					httpExchange.getRequestBody());
			final String response = "ok," + bytesRead;
			sendResponse(httpExchange, 200, response);
			logger.log(Level.INFO,
					"upload, complete (remote=" + httpExchange.getRemoteAddress() + ",response=" + response + ")");
		} catch (Throwable e) {
			final String response = "error";
			sendResponse(httpExchange, 400, response);
			logger.log(Level.WARNING, "upload, failed due to exception (remote=" + httpExchange.getRemoteAddress()
					+ ",response=" + response + ")", e);
		}
	}

}
