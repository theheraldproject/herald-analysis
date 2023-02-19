//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

import io.heraldprox.analysis.anomalies.detection.RssiGapDetection;

import java.io.File;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Locale;
import java.util.Date;
import java.util.Collection;

public class AnomalyDetector {
    public static void main(String[] args) {
        if (args.length < 3) {
            System.err.println("Usage: AnomalyDetector ./path/to/folder '2022-11-29 09:00:00' '2022-11-29 21:00:00'");
            System.exit(1);
        }
        File folder = new File(args[0]);
        if (!folder.exists()) {
            System.err.println("Folder '" + args[0] + " does not exist");
            System.exit(1);
        }
        if (!folder.isDirectory()) {
            System.err.println("Folder '" + args[0] + " is a file, not a folder!");
            System.exit(1);
        }

        TestFolder testFolder = new TestFolder(folder);

        SimpleDateFormat dateFormatter = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.UK);
        Date startDate = null;
        Date endDate = null;
        try {
            startDate = dateFormatter.parse(args[1]);
        } catch (ParseException pe) {
            System.err.println("Could not parse start date: '" + args[1] + "'");
            pe.printStackTrace();
            System.exit(1);
        }
        try {
            endDate = dateFormatter.parse(args[2]);
        } catch (ParseException pe) {
            System.err.println("Could not parse end date: '" + args[2] + "'");
            pe.printStackTrace();
            System.exit(1);
        }

        Correlator c = new Correlator(testFolder.getDeviceFolders());

        // TODO run all anomaly detectors
        RssiGapDetection gap = new RssiGapDetection(c, 20 * 60 * 1000);

        Collection<Anomaly> anomalies = gap.detect(testFolder, startDate, endDate);

        for (Anomaly an : anomalies) {
            System.out.println(an);
        }
        if (anomalies.size() == 0) {
            System.out.println("No anomalies detected!");
        }

        System.exit(0);
    }
}
