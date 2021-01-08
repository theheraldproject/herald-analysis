//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.analysis;

import java.util.Date;

/// Consumer for reference data log data
public abstract class ReferenceDataLogConsumer {

	/// Consume rssi and distance data, returning true to continue or false to stop
	/// consumption
	public boolean apply(Date time, double rssi, int distance) {
		return true;
	}

	/// Consume end of file
	public void close() {
	}
}
