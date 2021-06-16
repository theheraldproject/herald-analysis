//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.herald.app.test.handler;

import java.io.IOException;
import java.io.OutputStream;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import io.heraldprox.herald.app.test.AutomatedTestServer;

public abstract class AbstractHttpHandler implements HttpHandler {
	private final static Logger logger = Logger.getLogger(AbstractHttpHandler.class.getName());
	protected final AutomatedTestServer automatedTestServer;

	public AbstractHttpHandler(final AutomatedTestServer automatedTestServer) {
		this.automatedTestServer = automatedTestServer;
	}

	protected Map<String, String> parseRequestParameters(final HttpExchange httpExchange) {
		final Map<String, String> parameters = new HashMap<>();
		try {
			final String requestParameters = httpExchange.getRequestURI().toString().split("\\?")[1];
			for (final String requestParameter : requestParameters.split("&")) {
				final String[] keyValue = requestParameter.split("=");
				if (keyValue.length == 2) {
					final String key = URLDecoder.decode(keyValue[0], StandardCharsets.UTF_8.toString());
					final String value = URLDecoder.decode(keyValue[1], StandardCharsets.UTF_8.toString());
					parameters.put(key, value);
				}
			}
			logger.log(Level.INFO, "parseRequestParameters(requestParameters=" + requestParameters + ")");
		} catch (Throwable e) {
		}
		return parameters;
	}

	protected void sendResponse(final HttpExchange httpExchange, final int status, final StringBuilder responseBuilder)
			throws IOException {
		sendResponse(httpExchange, status, responseBuilder.toString());
	}

	protected void sendResponse(final HttpExchange httpExchange, final int status, final String responseString)
			throws IOException {
		sendResponse(httpExchange, status, responseString.getBytes(StandardCharsets.UTF_8));
	}

	protected void sendResponse(final HttpExchange httpExchange, final int status, final byte[] response)
			throws IOException {
		httpExchange.sendResponseHeaders(status, response.length);
		final OutputStream outputStream = httpExchange.getResponseBody();
		outputStream.write(response);
		outputStream.flush();
		outputStream.close();
	}
}
