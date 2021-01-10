package com.vmware.herald.calibration.cablecar.analysis.weka;

import java.util.Date;
import java.util.LinkedList;

import com.vmware.herald.calibration.cablecar.analysis.ReferenceDataLogConsumer;
import com.vmware.herald.calibration.cablecar.util.Sample;
import com.vmware.herald.calibration.cablecar.util.TextFile;

/// Convert reference data log in CSV format to ARFF format for use with WEKA
public class ConvertCSVToARFF extends ReferenceDataLogConsumer {
	private final static class Row {
		public final Date time;
		public final double rssi;
		public final int distance;

		public Row(Date time, double rssi, int distance) {
			super();
			this.time = time;
			this.rssi = rssi;
			this.distance = distance;
		}
	}

	private final int historySeconds;
	private final int distanceResolution;
	private final TextFile output;
	private final LinkedList<Row> buffer = new LinkedList<>();
	private final Sample[] samples;
	private final double[] features;
	private int currentDistance = -1;

	public ConvertCSVToARFF(final int historySeconds, final int distanceResolution, final TextFile output) {
		this.historySeconds = historySeconds + 1;
		this.distanceResolution = distanceResolution;
		this.output = output;
		this.samples = new Sample[historySeconds];
		this.features = new double[historySeconds];
		for (int i = samples.length; i-- > 0;) {
			this.samples[i] = new Sample();
		}

		// Write header
		output.write("@RELATION rssi_distance");
		for (int i = samples.length; i-- > 0;) {
			output.write("@ATTRIBUTE rssi_" + i + " NUMERIC");
		}
		output.write("@ATTRIBUTE rssi_now NUMERIC");
		output.write("@ATTRIBUTE distance_now INTEGER");
		output.write("@DATA");
	}

	@Override
	public boolean apply(Date time, double rssi, int distance) {
		if (rssi > 0) {
			return true;
		}
		final int quantizedDistance = (distance / distanceResolution) * distanceResolution;
		if (currentDistance != quantizedDistance) {
			buffer.clear();
		}
		currentDistance = quantizedDistance;
		final double normalisedRssi = (rssi < -100 ? 1 : (rssi / -100d));
		final Row row = new Row(time, normalisedRssi, currentDistance);
		final String features = features(row);
		output.write(features);
		buffer.add(row);
		return true;
	}

	@Override
	public void close() {
		output.close();
		super.close();
	}

	private String features(final Row row) {
		discardRedundantRows(row, historySeconds, buffer);
		for (int i = samples.length; i-- > 0;) {
			samples[i].clear();
		}
		for (final Row r : buffer) {
			final int i = (int) ((row.time.getTime() - r.time.getTime()) / 1000);
			samples[i].add(r.rssi);
		}
		double recentValue = row.rssi;
		for (int i = 0; i < samples.length; i++) {
			if (samples[i].count() > 0) {
				recentValue = samples[i].mean();
			}
			features[i] = recentValue;
		}
		final StringBuilder featuresCSV = new StringBuilder();
		for (int i = features.length; i-- > 0;) {
			featuresCSV.append(Math.round(features[i] * 100d) / 100d);
			featuresCSV.append(',');
		}
		featuresCSV.append(Math.round(row.rssi * 100d) / 100d);
		featuresCSV.append(',');
		featuresCSV.append(row.distance);
		return featuresCSV.toString();
	}

	private final static void discardRedundantRows(final Row row, final int historySeconds,
			final LinkedList<Row> buffer) {
		final long threshold = (row.time.getTime() / 1000 - historySeconds + 1) * 1000;
		Row first = null;
		while ((first = buffer.peek()) != null && first.time.getTime() <= threshold) {
			buffer.poll();
		}
	}

}
