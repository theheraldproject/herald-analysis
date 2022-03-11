//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.analysis;

import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

import com.vmware.herald.calibration.cablecar.util.Sample;

/// Gather summary statistics for RSSI values measured at each distance
public class StatisticalAnalysis extends ReferenceDataLogConsumer {
	final Map<Integer, RSSIDistribution> rssiDistributions = new ConcurrentHashMap<>();

	public final static class RSSIDistribution extends Sample {
		public final int distance;

		public RSSIDistribution(final int distance) {
			this.distance = distance;
		}

		@Override
		public String toString() {
			return distance + "," + count() + "," + mean() + "," + standardDeviation() + "," + min() + "," + max() + ","
					+ skewness() + "," + kurtosis();
		}
	}

	@Override
	public boolean apply(Date time, double rssi, int distance) {
		RSSIDistribution rssiDistribution = rssiDistributions.get(distance);
		if (rssiDistribution == null) {
			rssiDistribution = new RSSIDistribution(distance);
			rssiDistributions.put(distance, rssiDistribution);
		}
		rssiDistribution.add(rssi);
		return true;
	}

	/// RSSI distributions sorted by distance
	public List<RSSIDistribution> distributions() {
		return rssiDistributions.values().stream().sorted((a, b) -> Integer.compare(a.distance, b.distance))
				.collect(Collectors.toList());
	}

	public double pearsonCorrelationCoefficient() {
		final Sample rssi = new Sample(), distance = new Sample();
		rssiDistributions.values().forEach(d -> {
			rssi.add(d.mean());
			distance.add(d.distance);
		});
		final double rssiMean = rssi.mean();
		final double distanceMean = distance.mean();
		double dividend = 0;
		double rssiDivisor = 0;
		double distanceDivisor = 0;
		for (RSSIDistribution d : rssiDistributions.values()) {
			dividend += ((d.mean() - rssiMean) * (d.distance - distanceMean));
			rssiDivisor += ((d.mean() - rssiMean) * (d.mean() - rssiMean));
			distanceDivisor += ((d.distance - distanceMean) * (d.distance - distanceMean));
		}
		return dividend / Math.sqrt(rssiDivisor * distanceDivisor);

	}
}
