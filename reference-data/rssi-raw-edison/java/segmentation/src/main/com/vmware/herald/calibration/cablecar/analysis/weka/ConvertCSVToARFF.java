package com.vmware.herald.calibration.cablecar.analysis.weka;

import java.io.File;
import java.util.ArrayList;
import java.util.Date;
import java.util.LinkedList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.vmware.herald.calibration.cablecar.analysis.ReferenceDataLogConsumer;
import com.vmware.herald.calibration.cablecar.analysis.ReferenceDataLogParser;
import com.vmware.herald.calibration.cablecar.util.Sample;
import com.vmware.herald.calibration.cablecar.util.TextFile;

/// Convert reference data log in CSV format to ARFF format for use with WEKA
public class ConvertCSVToARFF extends ReferenceDataLogConsumer {
	private final static Logger logger = Logger.getLogger(ConvertCSVToARFF.class.getName());

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

		@Override
		public String toString() {
			return "Row [time=" + time + ", rssi=" + rssi + ", distance=" + distance + "]";
		}
	}

	private final int historySeconds;
	private final int distanceResolution;
	private final TextFile output;
	private final LinkedList<Row> buffer = new LinkedList<>();
	private final Sample[] samples;
	private final double[] features;
	private int currentDistance = -1;

	public ConvertCSVToARFF(final int historySeconds, final int distanceResolution, final int distanceRange,
			final TextFile output) {
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
		// Write attribute as nominal
		final StringBuilder distanceNominal = new StringBuilder();
		for (int i = 0; i <= distanceRange; i += distanceResolution) {
			if (distanceNominal.length() > 0) {
				distanceNominal.append(',');
			}
			distanceNominal.append(i);
		}
		output.write("@ATTRIBUTE distance_now NUMERIC");
		// Distance attribute as discrete classes
		// output.write("@ATTRIBUTE distance_now {" + distanceNominal.toString() + "}");
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
		final Row row = new Row(time, rssi, currentDistance);
		final String features = features(row);
		if (features != null) {
			output.write(features);
		}
		return true;
	}

	@Override
	public void close() {
		output.close();
		super.close();
	}

	private String features(final Row row) {
		try {
			discardRedundantRows(row, historySeconds, buffer);
			buffer.add(row);
			for (int i = samples.length; i-- > 0;) {
				samples[i].clear();
			}
			for (final Row r : buffer) {
				final int i = (int) ((row.time.getTime() - r.time.getTime()) / 1000);
				samples[i].add(r.rssi);
			}
			// RSSI measurements for time window from 0-N, rather than individual seconds.
//			for (int i = 1; i < samples.length; i++) {
//				samples[i].add(samples[i - 1]);
//			}
			double recentValue = row.rssi;
			for (int i = 0; i < samples.length; i++) {
				if (samples[i].count() > 0) {
					recentValue = samples[i].max();
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
		} catch (Throwable e) {
			logger.log(Level.WARNING, "Feature extraction failed : " + row);
			e.printStackTrace();
			System.exit(0);
			return null;
		}
	}

	private final static void discardRedundantRows(final Row row, final int historySeconds,
			final LinkedList<Row> buffer) {
		final long threshold = (row.time.getTime() / 1000 - historySeconds + 1) * 1000;
		Row first = null;
		while ((first = buffer.peek()) != null && first.time.getTime() <= threshold) {
			buffer.poll();
		}
	}

	public final static void main(String[] args) {
		final File folder = new File(args[0]);
		final String prefix = args[1];
		final int distanceResolution = (args.length > 2 ? Integer.parseInt(args[2]) : 10);
		final int distanceRange = (args.length > 3 ? Integer.parseInt(args[3]) : 300);
		final int historySeconds = (args.length > 4 ? Integer.parseInt(args[4]) : 30);

		// Get all CSV files
		final List<File> files = new ArrayList<>();
		for (final File file : folder.listFiles()) {
			if (file.getName().toLowerCase().endsWith(".csv")) {
				files.add(file);
			}
		}

		files.parallelStream().forEach(f -> {
			final String fileName = f.getName().substring(0, f.getName().length() - 4);
			final TextFile arffFile = new TextFile(f.getParentFile(), prefix + fileName + ".arff");
			try {
				ReferenceDataLogParser.apply(f,
						new ConvertCSVToARFF(historySeconds, distanceResolution, distanceRange, arffFile));
				System.out.println("Processed " + fileName + " -> " + arffFile.file);
			} catch (Throwable e) {
				System.err.println("Processing failed " + fileName);
				e.printStackTrace();
			}
		});
	}
}
