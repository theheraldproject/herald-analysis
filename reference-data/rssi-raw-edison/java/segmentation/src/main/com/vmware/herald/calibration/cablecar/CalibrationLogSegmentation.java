//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.vmware.herald.calibration.cablecar.analysis.CorrelationAnalysis;
import com.vmware.herald.calibration.cablecar.analysis.DetectionLogData;
import com.vmware.herald.calibration.cablecar.analysis.ReferenceDataLogParser;
import com.vmware.herald.calibration.cablecar.analysis.StatisticalAnalysis;
import com.vmware.herald.calibration.cablecar.segmentation.Annotation;
import com.vmware.herald.calibration.cablecar.segmentation.CalibrationLogConsumer;
import com.vmware.herald.calibration.cablecar.segmentation.CalibrationLogParser;
import com.vmware.herald.calibration.cablecar.segmentation.DeviceOrientation;
import com.vmware.herald.calibration.cablecar.segmentation.DeviceOrientation.Orientation;
import com.vmware.herald.calibration.cablecar.segmentation.DeviceOrientation.Rotation;
import com.vmware.herald.calibration.cablecar.segmentation.Movement;
import com.vmware.herald.calibration.cablecar.segmentation.MovementAnalysis;
import com.vmware.herald.calibration.cablecar.util.TextFile;

/// Automated process for extracting reference data from calibration log
/// 1. Create log folder for a test run (e.g. 20210102-0000)
/// 2. Copy raw phone logs into sub-folders with prefix "A" and "B" for phone A and B (e.g. 20210102-0000/A-Pixel2, 20210102-0000/B-J6)
/// 3. Run this tool to generate reference data
public class CalibrationLogSegmentation {
	private final static Logger logger = Logger.getLogger(CalibrationLogSegmentation.class.getName());
	private final static SimpleDateFormat fileNameDateFormatter = new SimpleDateFormat("yyyyMMdd-HHmm");
	private final static SimpleDateFormat dateFormatter = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");

	/// Parameters :
	/// logFolder - Log folder for the test run (e.g. 20210102-0000)
	/// duration - Sample duration in minutes (e.g. 30)
	/// distance - Distance moved per step in centimetres (e.g. 20)
	/// steps - Number of steps performed in test (e.g. 10)
	public static void main(String[] args) throws Exception {
		// Get parameters
		final File logFolder = new File(args[0]);
		final int sampleDurationMinutes = Integer.parseInt(args[1]);
		final int sampleDistanceCentimetres = Integer.parseInt(args[2]);
		final int sampleSteps = Integer.parseInt(args[3]);

		// Get calibration log files
		final File phoneALogFile = getCalibrationLogInSubFolder(logFolder, "A-");
		final File phoneBLogFile = getCalibrationLogInSubFolder(logFolder, "B-");
		if (phoneALogFile == null) {
			logger.log(Level.SEVERE, "Missing calibration.csv file for phone A");
			return;
		}
		if (phoneBLogFile == null) {
			logger.log(Level.SEVERE, "Missing calibration.csv file for phone B");
			return;
		}

		// Get phone data files
		final DetectionLogData phoneADetectionLog = DetectionLogData
				.parse(new File(phoneALogFile.getParentFile(), "detection.csv"));
		final DetectionLogData phoneBDetectionLog = DetectionLogData
				.parse(new File(phoneBLogFile.getParentFile(), "detection.csv"));
		if (phoneADetectionLog == null) {
			logger.log(Level.SEVERE, "Missing detection.csv file for phone A");
			return;
		}
		if (phoneBDetectionLog == null) {
			logger.log(Level.SEVERE, "Missing detection.csv file for phone B");
			return;
		}
		final TextFile phoneMetadataFile = new TextFile(logFolder, "phones.csv");
		phoneMetadataFile.write("phone,name,os,version,payload");
		phoneMetadataFile.write("A," + phoneADetectionLog.deviceName + "," + phoneADetectionLog.operatingSystem + ","
				+ phoneADetectionLog.operatingSystemVersion + "," + phoneADetectionLog.payloadShortName);
		phoneMetadataFile.write("B," + phoneBDetectionLog.deviceName + "," + phoneBDetectionLog.operatingSystem + ","
				+ phoneBDetectionLog.operatingSystemVersion + "," + phoneBDetectionLog.payloadShortName);
		phoneMetadataFile.close();

		// Analysis of phone B movements
		final DeviceOrientation deviceOrientation = new DeviceOrientation(Orientation.VERTICAL_RIGHT_EDGE,
				Rotation.ROTATION_0);
		final MovementAnalysis phoneBMovementAnalysis = new MovementAnalysis(deviceOrientation);
		CalibrationLogParser.apply(phoneBLogFile, phoneBMovementAnalysis);
		final TextFile phoneBMovementLogFile = new TextFile(logFolder, "movement.csv");
		phoneBMovementLogFile.write("time,inertia");
		MovementAnalysis.normalise(phoneBMovementAnalysis.movements.data, 5 * 60)
				.forEach(m -> phoneBMovementLogFile.write(m.toString()));
		phoneBMovementLogFile.close();
		final List<Movement> phoneBMovements = phoneBMovementAnalysis.movedAt(sampleDurationMinutes * 60 * 1000);
		if (sampleSteps > phoneBMovements.size()) {
			logger.log(Level.SEVERE, "Number of movements < samples steps (" + sampleSteps + ") : " + phoneBMovements);
			return;
		}

		// Show phone B movements for visual check
		final List<Annotation> annotations = annotations(phoneBMovements, sampleDurationMinutes,
				sampleDistanceCentimetres, sampleSteps);
		final TextFile segmentationFile = new TextFile(logFolder, "segmentation.csv", System.out);
		segmentationFile.write("startTime,endTime,duration,distance,inertia");
		annotations.forEach(annotation -> segmentationFile.write(annotation.toString()));
		segmentationFile.close();

		// Apply annotations to phone A and B logs
		final File phoneAReferenceDataFile = annotate(annotations, phoneBDetectionLog.payloadShortName, phoneALogFile,
				logFolder, "-A.csv");
		logger.log(Level.INFO, "Wrote segmented file for phone A : " + phoneAReferenceDataFile);
		final File phoneBReferenceDataFile = annotate(annotations, phoneADetectionLog.payloadShortName, phoneBLogFile,
				logFolder, "-B.csv");
		logger.log(Level.INFO, "Wrote segmented file for phone B : " + phoneBReferenceDataFile);

		// Apply statistical analysis to phone A and B reference data
		logger.log(Level.INFO, "Statistical analysis of phone A data");
		final double phoneAPearson = statisticalAnalysis(phoneAReferenceDataFile,
				new TextFile(logFolder, "statisticsA.csv", System.out));
		logger.log(Level.INFO, "Statistical analysis of phone B data");
		final double phoneBPearson = statisticalAnalysis(phoneBReferenceDataFile,
				new TextFile(logFolder, "statisticsB.csv", System.out));
		logger.log(Level.INFO,
				"Pearson correlation coefficient (phoneA=" + phoneAPearson + ",phoneB=" + phoneBPearson + ")");
		final TextFile correlationFile = new TextFile(logFolder, "correlation.csv", System.out);
		correlationFile.write("phone,pearson");
		correlationFile.write("A," + phoneAPearson);
		correlationFile.write("B," + phoneBPearson);
		correlationFile.close();
	}

	protected final static double statisticalAnalysis(final File logFile, final TextFile outputFile) throws Exception {
		// Statistical analysis to obtain summary statistics
		final StatisticalAnalysis statisticalAnalysis = new StatisticalAnalysis();
		ReferenceDataLogParser.apply(logFile, statisticalAnalysis);
		outputFile.write("distance,count,mean,standardDeviation,min,max,skewness,kurtosis");
		statisticalAnalysis.distributions().forEach(d -> outputFile.write(d.toString()));
		outputFile.close();
		// Pearson correlation analysis
		final CorrelationAnalysis correlationAnalysis = new CorrelationAnalysis(statisticalAnalysis.distributions());
		ReferenceDataLogParser.apply(logFile, correlationAnalysis);
		return correlationAnalysis.pearsonCorrelationCoefficient();
	}

	protected final static List<Annotation> annotations(final List<Movement> movements, final int sampleDurationMinutes,
			final int sampleDistanceCentimetres, final int sampleSteps) {
		final List<Annotation> annotations = new ArrayList<>(movements.size() - 1);
		for (int i = 0; i < movements.size() - 1 && i < sampleSteps + 1; i++) {
			final Movement movement = movements.get(i);
			final Movement nextMovement = movements.get(i + 1);
			final int distance = ((i + 1) % (sampleSteps + 1)) * sampleDistanceCentimetres;
			final Annotation annotation = new Annotation(new Date(movement.time), new Date(nextMovement.time), distance,
					movement.inertia);
			annotations.add(annotation);
		}
		// Adjust first annotation start time based on end time
		if (annotations.size() > 0) {
			final Annotation firstAnnotation = annotations.get(0);
			firstAnnotation.startTime = new Date(firstAnnotation.endTime.getTime() - sampleDurationMinutes * 60000);
		}
		// Adjust last annotation end time based on start time
		if (annotations.size() > 1) {
			final Annotation lastAnnotation = annotations.get(annotations.size() - 1);
			lastAnnotation.endTime = new Date(lastAnnotation.startTime.getTime() + sampleDurationMinutes * 60000);
		}
		// Adjust all annotation start and end times to discard data during movement
		// (+/- 60 seconds)
		for (final Annotation annotation : annotations) {
			annotation.startTime = new Date(annotation.startTime.getTime() + 60000);
			annotation.endTime = new Date(annotation.endTime.getTime() - 60000);
		}
		return annotations;
	}

	protected final static File getCalibrationLogInSubFolder(final File folder, final String withPrefix) {
		for (final File subFolder : folder.listFiles()) {
			if (subFolder.isDirectory() && subFolder.getName().toLowerCase().startsWith(withPrefix.toLowerCase())) {
				final File calibrationLogFile = new File(subFolder, "calibration.csv");
				if (calibrationLogFile.exists()) {
					return calibrationLogFile;
				}
			}
		}
		return null;
	}

	protected final static File annotate(final List<Annotation> annotations, final String targetPayload,
			final File logFile, final File outputFolder, final String suffix) throws Exception {
		final File outputFile = new File(outputFolder,
				fileNameDateFormatter.format(annotations.get(0).startTime) + suffix);
		final PrintWriter printWriter = new PrintWriter(new BufferedWriter(new FileWriter(outputFile)));
		printWriter.println("time,rssi,distance");
		CalibrationLogParser.apply(logFile, new CalibrationLogConsumer() {
			private final Queue<Annotation> queue = new ConcurrentLinkedQueue<>(annotations);
			private Annotation annotation = queue.poll();

			@Override
			public boolean rssi(Date time, String target, double rssi) {
				// Move to next annotation
				while (annotation != null && time.getTime() >= annotation.endTime.getTime()) {
					annotation = queue.poll();
				}
				// No more work to do
				if (annotation == null) {
					return false;
				}
				// Only output data associated with specific target
				if (!target.equals(targetPayload)) {
					return true;
				}
				// Write annotated data
				if (time.getTime() >= annotation.startTime.getTime()
						&& time.getTime() <= annotation.endTime.getTime()) {
					printWriter.println(dateFormatter.format(time) + "," + rssi + "," + annotation.distance);
				}
				return true;
			}
		});
		printWriter.flush();
		printWriter.close();
		return outputFile;
	}

}
