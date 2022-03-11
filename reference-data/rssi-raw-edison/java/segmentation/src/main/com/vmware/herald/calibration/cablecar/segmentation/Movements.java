//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.segmentation;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.List;

import com.vmware.herald.calibration.cablecar.util.Sample;

/// Movements along cable axis over time quantised to unit time (e.g. 1 second)
public class Movements {
	private final long resolutionMillis;
	private final Sample sample = new Sample();
	public final List<Movement> data = new ArrayList<>();
	private Long currentTime = null;

	public Movements(final long resolutionMillis) {
		this.resolutionMillis = Math.abs(resolutionMillis);
	}

	/// Add movement data
	public void add(final Date time, final Double inertia) {
		if (time == null || inertia == null) {
			return;
		}
		// Round new time to given resolution
		final long newTime = (time.getTime() / resolutionMillis) * resolutionMillis;
		// First entry
		if (currentTime == null) {
			currentTime = newTime;
			sample.clear();
			sample.add(Math.abs(inertia));
			return;
		}
		// Collect entry
		if (currentTime != newTime && sample.count() > 0) {
			final Movement movement = new Movement(currentTime, sample.max());
			data.add(movement);
			sample.clear();
		}
		// Collate data
		currentTime = newTime;
		sample.add(Math.abs(inertia));
	}

	/// End collection of movement data
	public void close() {
		if (currentTime == null) {
			return;
		}
		if (sample.count() == 0) {
			return;
		}
		data.add(new Movement(currentTime, sample.max()));
		Collections.sort(data, new Comparator<Movement>() {
			@Override
			public int compare(Movement o1, Movement o2) {
				return Long.compare(o1.time, o2.time);
			}
		});
	}
}
