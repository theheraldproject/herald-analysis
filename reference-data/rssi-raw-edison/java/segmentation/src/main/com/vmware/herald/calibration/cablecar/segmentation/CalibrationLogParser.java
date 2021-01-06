//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.segmentation;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.logging.Level;
import java.util.logging.Logger;

public class CalibrationLogParser {
	private final static Logger logger = Logger.getLogger(CalibrationLogParser.class.getName());
	private final static SimpleDateFormat dateFormatter = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");

	public final static void apply(final File logFile, final CalibrationLogConsumer consumer) throws Exception {
		final FileReader fileReader = new FileReader(logFile);
		final BufferedReader bufferedReader = new BufferedReader(fileReader);
		apply(bufferedReader, consumer);
		bufferedReader.close();
		fileReader.close();
	}

	public final static void apply(final BufferedReader bufferedReader, final CalibrationLogConsumer consumer)
			throws IOException {
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
				final String[] fields = line.split(",", 6);
				if (fields == null || fields.length != 6) {
					logger.log(Level.WARNING, "Invalid line " + lineNumber + ", missing fields : " + line);
					continue;
				}
				final Date time = dateFormatter.parse(fields[0]);
				if (!fields[1].isEmpty() && !fields[2].isEmpty()) {
					final String target = fields[1];
					final double rssi = Double.parseDouble(fields[2]);
					keepWorking = consumer.rssi(time, target, rssi);
				} else if (!fields[3].isEmpty() && !fields[4].isEmpty() && !fields[5].isEmpty()) {
					final double x = Double.parseDouble(fields[3]);
					final double y = Double.parseDouble(fields[4]);
					final double z = Double.parseDouble(fields[5]);
					keepWorking = consumer.inertia(time, x, y, z);
				} else {
					logger.log(Level.WARNING, "Invalid line " + lineNumber + ", unknown type : " + line);
				}
			} catch (Throwable e) {
				logger.log(Level.WARNING, "Invalid line " + lineNumber + ", parse error : " + line, e);
			}
		}
		consumer.close();
	}

}
