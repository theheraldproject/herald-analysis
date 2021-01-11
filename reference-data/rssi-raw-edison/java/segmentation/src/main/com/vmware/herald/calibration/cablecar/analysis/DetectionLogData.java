//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.analysis;

import java.io.File;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;

/// Parser for detection.csv log file
public class DetectionLogData {
	public final String deviceName;
	public final String operatingSystem;
	public final String operatingSystemVersion;
	public final String payloadShortName;
	public final List<String> detectedPayloadShortNames = new ArrayList<>();

	public DetectionLogData(final String detectionLogContent) {
		final String[] fields = detectionLogContent.split(",");
		deviceName = fields[0];
		operatingSystem = fields[1];
		operatingSystemVersion = fields[2];
		payloadShortName = fields[3];
		for (int i = 4; i < fields.length; i++) {
			detectedPayloadShortNames.add(fields[4]);
		}
	}

	public final static DetectionLogData parse(final File detectionLogFile) {
		try {
			final String content = new String(Files.readAllBytes(detectionLogFile.toPath()));
			final DetectionLogData detectionLogData = new DetectionLogData(content);
			return detectionLogData;
		} catch (Throwable e) {
			return null;
		}
	}
}
