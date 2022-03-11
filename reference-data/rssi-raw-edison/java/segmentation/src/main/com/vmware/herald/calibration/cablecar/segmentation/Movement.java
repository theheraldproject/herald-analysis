//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.segmentation;

import java.text.SimpleDateFormat;
import java.util.Date;

/// Movement along cable axis at a point in time
public class Movement {
	private final static SimpleDateFormat dateFormatter = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
	public final long time;
	public final double inertia;

	public Movement(final long time, final double inertia) {
		this.time = time;
		this.inertia = inertia;
	}

	public Movement(final Date time, final double inertia) {
		this.time = (time == null ? 0 : time.getTime());
		this.inertia = inertia;
	}

	@Override
	public String toString() {
		return dateFormatter.format(new Date(time)) + "," + inertia;
	}

}
