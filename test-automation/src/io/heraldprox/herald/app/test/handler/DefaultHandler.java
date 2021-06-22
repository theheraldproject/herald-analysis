//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.herald.app.test.handler;

import java.io.IOException;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.sun.net.httpserver.HttpExchange;

import io.heraldprox.herald.app.test.AutomatedTestServer;

/**
 * Get help on usage of server. <br>
 * URL: / or /help
 */
public class DefaultHandler extends AbstractHttpHandler {
	private final static Logger logger = Logger.getLogger(DefaultHandler.class.getName());
	// @formatter:off
	private final static String[] helpText = new String[] {
			"Herald - Automated Test Server",
			"",
			"GET:  /",
			"  Print this help",
			"",
			"GET:  /help",
			"  Print this help",
			"",
			"GET:  /status",
			"  Get status of all connected devices in JSON format",
			"",
			"POST: /broadcast?commands=[A]",
			"  Broadcast command separated commands [A] to all connected devices as soon as possible. Supported commands are:",
			"  - start : Start sensor array",
			"  - stop  : Stop sensor array",
			"  - clear : Clear all in-memory and stored data and reset user interface",
			"  - upload(filename) : Get file from device",
			"  Server will respond with the list of all scheduled commands in JSON format.",
			"",
			"POST: /broadcast?commands=[A]&hours=[B]&minutes=[C]&seconds=[D]",
			"  Schedule broadcast of commands [A] to all connected devices after [B] hours, [C] minutes, and [D] seconds.",
			"  Parameters [B-D] are all optional and defaults to 0.",
			"  Server will respond with the list of all scheduled commands in JSON format.",
			"",
			"POST: /broadcast?clear",
			"  Clear all pending commands for all devices and also scheduled commands.",
			"  Server will respond with the list of all scheduled commands in JSON format. Should be empty.",
			"",
			"POST: /heartbeat?model=[A]&os=[B]&version=[C]&payload=[D]&status=[E]",
			"  Register device information [A-C], payload shortname [D], and current sensor array status [E] for the connected device.",
			"  Server will respond with the list of all scheduled commands in CSV format with prefix 'ok' on success, or 'error' otherwise.",
			"  This is used by the AutomatedTestClient on the connected device.",
			"",
			"POST: /upload?model=[A]&os=[B]&version=[C]&payload=[D]&status=[E]&filename=[F]",
			"  Upload a plain text file [F] from device to server and also report current status (see /heartbeat) for a connected device.",
			"  The body of the post request contains UTF8 encoded file content.",
			"  Server will respond with 'status,N' in CSV format where status 'ok' means success, or 'error' otherwise. N is the number of bytes received.",
			"  This is used by the AutomatedTestClient on the connected device.",
			"",
			"POST: /macro?script=reset",
			"  Script to stop and clear data on all connected devices, e.g. to prepare for test.",
			"  Server will respond with status of all connected devices and scheduled commands in JSON format",
			"",
			"POST: /macro?script=test&in=[A]&for=[B]",
			"  Script to start sensor array on all connected devices in [A] minutes (default 0) and run the test for [B] hours.",
			"  Parameter [B] can be decimal (e.g. 0.5 for 30 minutes). After [B] hours, the script will stop sensor array on all",
			"  connected devices, and then request upload of all log files. The uploaded files shall be found in the upload folder",
			"  under a subfolder named by the date/time of when this script was started",
			"  Server will respond with status of all connected devices and scheduled commands in JSON format",
			"",
			"POST: /macro?script=upload&scope=[efficacy|all]",
			"  Script to request upload of log files from all connected devices. The scope of upload is 'efficacy' logs only by default.",
			"  Specify 'all' to include 'log.txt' file that can be > 500MB. The uploaded files shall be found in the upload folder" + 
			"  under a subfolder named by the date/time of when this script was started",
			"  Server will respond with status of all connected devices and scheduled commands in JSON format",
	};
	// @formatter:on

	public DefaultHandler(final AutomatedTestServer automatedTestServer) {
		super(automatedTestServer);
	}

	@Override
	public void handle(HttpExchange httpExchange) throws IOException {
		logger.log(Level.INFO, "help (remote=" + httpExchange.getRemoteAddress() + ",uri="
				+ httpExchange.getRequestURI().toString() + ")");
		final String response = String.join("\n", helpText);
		sendResponse(httpExchange, 200, response);
		logger.log(Level.INFO, "help, complete (remote=" + httpExchange.getRemoteAddress() + ")");
	}

}
