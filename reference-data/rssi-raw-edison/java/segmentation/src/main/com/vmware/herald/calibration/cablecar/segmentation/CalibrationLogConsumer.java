//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.segmentation;

import java.util.Date;

/// Consumer for calibration log data
public abstract class CalibrationLogConsumer {

	/// Consume rssi data, returning true to continue or false to stop consumption
	public boolean rssi(Date time, String target, double rssi) {
		return true;
	}

	/// Consume accelerometer data, returning true to continue or false to stop
	/// consumption
	public boolean inertia(Date time, double x, double y, double z) {
		return true;
	}

	/// Consume end of file
	public void close() {
	}
}
