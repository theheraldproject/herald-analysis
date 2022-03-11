//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.segmentation;

import java.text.SimpleDateFormat;
import java.util.Date;

public class Annotation {
	private final static SimpleDateFormat dateFormatter = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
	public Date startTime;
	public Date endTime;
	public final int distance;
	public final double inertia;

	public Annotation(Date startTime, Date endTime, int distance, double inertia) {
		super();
		this.startTime = startTime;
		this.endTime = endTime;
		this.distance = distance;
		this.inertia = inertia;
	}

	@Override
	public String toString() {
		final int minutesSinceLastMovement = (int) ((endTime.getTime() - startTime.getTime()) / 60000);
		return dateFormatter.format(startTime) + "," + dateFormatter.format(endTime) + "," + minutesSinceLastMovement
				+ "," + distance + "," + inertia;
	}
}
