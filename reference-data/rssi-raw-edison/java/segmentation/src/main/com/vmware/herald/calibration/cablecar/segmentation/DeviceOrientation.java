//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.segmentation;

public class DeviceOrientation {
	public final Orientation orientation;
	public final Rotation rotation;

	// Orientation of physical device where horizontal means parallel with the
	// ground, and vertical means perpendicular to the ground.
	public enum Orientation {
		// Unknown orientation
		UNKNOWN,
		// Face up on a flat surface, e.g. desk (z = 9)
		HORIZONTAL_FACE_UP,
		// Face down on a flat surface, e.g. desk (z = -9)
		HORIZONTAL_FACE_DOWN,
		// Standing vertically, left edge towards ground, right edge towards sky (x = 9)
		VERTICAL_LEFT_EDGE,
		// Standing vertically, right edge towards ground, left edge towards sky (x =
		// -9)
		VERTICAL_RIGHT_EDGE,
		// Standing vertically, bottom edge towards ground, top edge towards sky (y = 9)
		VERTICAL,
		// Standing vertically, top edge towards ground, bottom edge towards sky (y =
		// -9)
		VERTICAL_INVERTED
	}

	// Rotation about cable where 0 degrees is towards Edison robot.
	// When horizontal, 0 degrees means top edge is pointing towards robot.
	// When vertical, 0 degrees means face of phone is facing towards robot.
	public enum Rotation {
		UNKNOWN, ROTATION_0, ROTATION_90, ROTATION_180, ROTATION_270,
	}

	public final static DeviceOrientation unknown = new DeviceOrientation(Orientation.UNKNOWN, Rotation.UNKNOWN);

	public DeviceOrientation(final Orientation orientation, final Rotation rotation) {
		this.orientation = orientation;
		this.rotation = rotation;
	}

	@Override
	public String toString() {
		return "DeviceOrientation [orientation=" + orientation + ", rotation=" + rotation + "]";
	}
}
