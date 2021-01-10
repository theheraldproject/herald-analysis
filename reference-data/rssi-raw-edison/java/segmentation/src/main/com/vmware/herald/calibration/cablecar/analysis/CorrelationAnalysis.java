//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.analysis;

import java.util.Date;
import java.util.List;

import com.vmware.herald.calibration.cablecar.analysis.StatisticalAnalysis.RSSIDistribution;
import com.vmware.herald.calibration.cablecar.util.Sample;

/// Correlation analysis
public class CorrelationAnalysis extends ReferenceDataLogConsumer {
	private final Sample x = new Sample(), y = new Sample();
	private final double xMean, yMean;
	private double dividend = 0, xDivisor = 0, yDivisor = 0;

	public CorrelationAnalysis(final List<RSSIDistribution> rssiDistributions) {
		rssiDistributions.forEach(d -> {
			x.add(d);
			y.add(d.distance, d.count());
		});
		xMean = x.mean();
		yMean = y.mean();
	}

	@Override
	public boolean apply(Date time, double rssi, int distance) {
		dividend += ((rssi - xMean) * (distance - yMean));
		xDivisor += ((rssi - xMean) * (rssi - xMean));
		yDivisor += ((distance - yMean) * (distance - yMean));
		return true;
	}

	public double pearsonCorrelationCoefficient() {
		return dividend / Math.sqrt(xDivisor * yDivisor);

	}
}
