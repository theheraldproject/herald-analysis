//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.herald.app.test.handler;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.sun.net.httpserver.HttpExchange;

import io.heraldprox.herald.app.test.AutomatedTestServer;

/**
 * Short cut to command sets<br>
 * URL: /macro?script=reset<br>
 * URL: /macro?script=test&in=[minutes]&for=[hours]<br>
 * URL: /macro?script=upload&scope=[efficacy|all]<br>
 *
 */
public class MacroHandler extends AbstractHttpHandler {
	private final static Logger logger = Logger.getLogger(MacroHandler.class.getName());
	private final static String[] uploadFilesEfficacy = new String[] { "contacts.csv", "detection.csv",
			"statistics.csv", "battery.csv", "timeToConnectDevice.csv", "timeToProcessDevice.csv" };
	private final static String[] uploadFilesAll = new String[] { "contacts.csv", "detection.csv", "statistics.csv",
			"battery.csv", "timeToConnectDevice.csv", "timeToProcessDevice.csv", "log.txt" };

	public MacroHandler(final AutomatedTestServer automatedTestServer) {
		super(automatedTestServer);
	}

	@Override
	public void handle(HttpExchange httpExchange) throws IOException {
		logger.log(Level.INFO, "macro (remote=" + httpExchange.getRemoteAddress() + ",uri="
				+ httpExchange.getRequestURI().toString() + ")");
		// Parse parameters
		final Map<String, String> parameters = parseRequestParameters(httpExchange);
		final String script = parameters.get("script");
		if ("reset".equals(script)) {
			automatedTestServer.broadcastClear();
			automatedTestServer.broadcast(null);
			automatedTestServer.broadcast("stop,clear");
			logger.log(Level.INFO, "macro, reset devices (remote=" + httpExchange.getRemoteAddress() + ")");
		} else if ("upload".equals(script)) {
			final String scope = parameters.getOrDefault("scope", "efficacy");
			final List<String> commands = new ArrayList<>();
			for (final String file : ("efficacy".equals(scope) ? uploadFilesEfficacy : uploadFilesAll)) {
				commands.add("upload(" + file + ")");
			}
			automatedTestServer.uploadSubfolderNameNow();
			automatedTestServer.broadcast(String.join(",", commands));
			logger.log(Level.INFO,
					"macro, upload " + scope + " files (remote=" + httpExchange.getRemoteAddress() + ")");
		} else if ("test".equals(script)) {
			final String inMinutes = parameters.getOrDefault("in", "0");
			final String forHours = parameters.getOrDefault("for", "0");
			// Start in
			automatedTestServer.broadcast("start", 60 * Long.parseLong(inMinutes));
			// Stop,Upload after
			final List<String> commands = new ArrayList<>();
			commands.add("stop");
			for (final String file : uploadFilesAll) {
				commands.add("upload(" + file + ")");
			}
			automatedTestServer.uploadSubfolderNameNow();
			automatedTestServer.broadcast(String.join(",", commands),
					60 * Long.parseLong(inMinutes) + Math.round(60 * 60 * Double.parseDouble(forHours)));
			logger.log(Level.INFO, "macro, test in " + inMinutes + " minutes for " + forHours + " hours (remote="
					+ httpExchange.getRemoteAddress() + ")");
		}
		final String response = automatedTestServer.status();
		sendResponse(httpExchange, 200, response);
		logger.log(Level.INFO, "macro, complete (remote=" + httpExchange.getRemoteAddress() + ")");
	}

}
