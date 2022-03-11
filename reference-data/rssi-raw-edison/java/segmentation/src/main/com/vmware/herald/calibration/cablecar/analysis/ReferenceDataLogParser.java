//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.analysis;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.logging.Level;
import java.util.logging.Logger;

public class ReferenceDataLogParser {
	private final static Logger logger = Logger.getLogger(ReferenceDataLogParser.class.getName());

	public final static void apply(final File logFile, final ReferenceDataLogConsumer consumer) throws Exception {
		final FileReader fileReader = new FileReader(logFile);
		final BufferedReader bufferedReader = new BufferedReader(fileReader);
		apply(bufferedReader, consumer);
		bufferedReader.close();
		fileReader.close();
	}

	public final static void apply(final BufferedReader bufferedReader, final ReferenceDataLogConsumer consumer)
			throws IOException {
		final SimpleDateFormat dateFormatter = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
		String line;
		long lineNumber = 0;
		boolean keepWorking = true;
		while (keepWorking && (line = bufferedReader.readLine()) != null) {
			lineNumber++;
			// Detect and skip header
			if (line.startsWith("time,")) {
				continue;
			}
			// Parse CSV
			try {
				final String[] fields = line.split(",", 3);
				if (fields == null || fields.length != 3) {
					logger.log(Level.WARNING, "Invalid line " + lineNumber + ", missing fields : " + line);
					continue;
				}
				final Date time = dateFormatter.parse(fields[0]);
				if (!fields[1].isEmpty() && !fields[2].isEmpty()) {
					final double rssi = Double.parseDouble(fields[1]);
					final int distance = Integer.parseInt(fields[2]);
					keepWorking = consumer.apply(time, rssi, distance);
				} else {
					logger.log(Level.WARNING, "Invalid line " + lineNumber + ", unknown type : " + line);
				}
			} catch (Throwable e) {
				logger.log(Level.WARNING, "Invalid line " + lineNumber + ", processing error : " + line, e);
				e.printStackTrace();
			}
		}
		consumer.close();
	}

}
