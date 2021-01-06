//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.segmentation;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.stream.Collectors;

/// Determine device orientation from distribution of x, y, z values.
/// Assumes device is aligned to one of the axis. Heuristics assumes
/// greatest value is caused by gravity, and the next greatest value
/// is caused by movement along cable.
public class MovementAnalysis extends CalibrationLogConsumer {
	private final static Logger logger = Logger.getLogger(MovementAnalysis.class.getName());
	public final Movements movements;
	private CalibrationLogConsumer consumer = null;
	private final CalibrationLogConsumer xConsumer = new CalibrationLogConsumer() {
		@Override
		public boolean inertia(Date time, double x, double y, double z) {
			movements.add(time, x);
			return true;
		}
	};
	private final CalibrationLogConsumer yConsumer = new CalibrationLogConsumer() {
		@Override
		public boolean inertia(Date time, double x, double y, double z) {
			movements.add(time, y);
			return true;
		}
	};
	private final CalibrationLogConsumer zConsumer = new CalibrationLogConsumer() {
		@Override
		public boolean inertia(Date time, double x, double y, double z) {
			movements.add(time, z);
			return true;
		}
	};

	public MovementAnalysis(final DeviceOrientation deviceOrientation) {
		// Quantise movement data to one second
		this.movements = new Movements(1000);
		switch (deviceOrientation.orientation) {
		case HORIZONTAL_FACE_UP:
		case HORIZONTAL_FACE_DOWN:
		case VERTICAL_LEFT_EDGE:
		case VERTICAL_RIGHT_EDGE:
			switch (deviceOrientation.rotation) {
			case ROTATION_0:
			case ROTATION_180:
				consumer = yConsumer;
				break;
			case ROTATION_90:
			case ROTATION_270:
				consumer = xConsumer;
				break;
			default:
				break;
			}
			break;
		case VERTICAL:
		case VERTICAL_INVERTED:
			switch (deviceOrientation.rotation) {
			case ROTATION_0:
			case ROTATION_180:
				consumer = zConsumer;
				break;
			case ROTATION_90:
			case ROTATION_270:
				consumer = xConsumer;
				break;
			default:
				break;
			}
			break;
		default:
			break;
		}
		if (consumer == null) {
			logger.log(Level.WARNING, "Unknown device orientation, assuming travel along y-axis");
			consumer = yConsumer;
		}
	}

	@Override
	public boolean inertia(Date time, double x, double y, double z) {
		consumer.inertia(time, x, y, z);
		return true;
	}

	@Override
	public void close() {
		movements.close();
	}

	/// Remove noise data caused by general vibrations
	protected final static List<Movement> denoise(final List<Movement> movements) {
		final Sample distribution = new Sample();
		movements.forEach(movement -> distribution.add(movement.inertia));
		// Remove values below mean to discard noise data
		final double threshold = distribution.mean();
		return movements.parallelStream().filter(movement -> movement.inertia >= threshold)
				.collect(Collectors.toList());
	}

	/// Find time when cable car was moved by searching for peaks separated by at
	/// least 1/2 sample duration
	protected final static List<Movement> peaks(final List<Movement> movements, final long sampleDurationMillis) {
		final List<Movement> candidates = denoise(movements);
		// Sort by inertia in descending order
		candidates.sort((a, b) -> Double.compare(b.inertia, a.inertia));
		// Discard candidates that are too close to existing peaks
		final List<Movement> peaks = new ArrayList<>();
		final long windowMillis = sampleDurationMillis / 4 * 3;
		for (final Movement candidate : candidates) {
			boolean isLocalMaxima = true;
			for (final Movement peak : peaks) {
				// Discard entries close to existing maxima
				if (Math.abs(peak.time - candidate.time) <= windowMillis) {
					isLocalMaxima = false;
					break;
				}
			}
			if (isLocalMaxima) {
				peaks.add(candidate);
			}
		}
		peaks.sort((a, b) -> Long.compare(a.time, b.time));
		return peaks;
	}

	public List<Movement> movedAt(final long sampleDurationMillis) {
		return peaks(movements.data, sampleDurationMillis);
	}
}
