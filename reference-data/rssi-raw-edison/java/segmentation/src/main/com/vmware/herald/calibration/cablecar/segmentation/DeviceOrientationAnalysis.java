//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.segmentation;

import java.util.Arrays;
import java.util.Comparator;
import java.util.Date;

import com.vmware.herald.calibration.cablecar.segmentation.DeviceOrientation.Orientation;
import com.vmware.herald.calibration.cablecar.segmentation.DeviceOrientation.Rotation;

/// Determine device orientation from distribution of x, y, z values.
/// Assumes device is aligned to one of the axis. Heuristics assumes
/// greatest value is caused by gravity, and the next greatest value
/// is caused by movement along cable.
public class DeviceOrientationAnalysis extends CalibrationLogConsumer {
	public final Sample xDistribution = new Sample();
	public final Sample yDistribution = new Sample();
	public final Sample zDistribution = new Sample();

	@Override
	public boolean inertia(Date time, double x, double y, double z) {
		xDistribution.add(x);
		yDistribution.add(y);
		zDistribution.add(z);
		return true;
	}

	public DeviceOrientation orientation() {
		if (xDistribution.count() == 0 || yDistribution.count() == 0 || zDistribution.count() == 0) {
			return DeviceOrientation.unknown;
		}
		// Sort distributions by mean value to identify the most dominant orientation
		final Sample[] distributions = new Sample[] { xDistribution, yDistribution, zDistribution };
		Arrays.parallelSort(distributions, new Comparator<Sample>() {
			@Override
			public int compare(Sample a, Sample b) {
				return Double.compare(b.mean(), a.mean());
			}
		});
		// Establish orientation by gravity
		if (distributions[0].mean() < 9) {
			return DeviceOrientation.unknown;
		}
		Orientation orientation = Orientation.UNKNOWN;
		if (distributions[0] == zDistribution) {
			orientation = (distributions[0].mean() > 0 ? Orientation.HORIZONTAL_FACE_UP
					: Orientation.HORIZONTAL_FACE_DOWN);
		} else if (distributions[0] == xDistribution) {
			orientation = (distributions[0].mean() > 0 ? Orientation.VERTICAL_LEFT_EDGE
					: Orientation.VERTICAL_RIGHT_EDGE);
		} else {
			orientation = (distributions[0].mean() > 0 ? Orientation.VERTICAL : Orientation.VERTICAL_INVERTED);
		}
		// Establish rotation by cable car movements
		// This may be inaccurate, best to rely on manual data logging
		Rotation rotation = Rotation.UNKNOWN;
		if (distributions[1] == yDistribution) {
			rotation = (distributions[1].mean() > 0 ? Rotation.ROTATION_0 : Rotation.ROTATION_180);
		} else if (distributions[1] == xDistribution) {
			rotation = (distributions[1].mean() > 0 ? Rotation.ROTATION_90 : Rotation.ROTATION_270);
		} else {
			rotation = (distributions[1].mean() > 0 ? Rotation.ROTATION_0 : Rotation.ROTATION_180);
		}
		return new DeviceOrientation(orientation, rotation);
	}
}
