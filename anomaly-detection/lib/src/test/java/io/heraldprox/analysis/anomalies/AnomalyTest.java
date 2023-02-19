//  Copyright 2022-2023 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

import io.heraldprox.analysis.anomalies.TestFolder;
import io.heraldprox.analysis.anomalies.detection.RssiGapDetection;
import io.heraldprox.analysis.anomalies.DeviceFolder;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

import java.util.List;
import java.io.File;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Locale;
import java.util.TimeZone;
import java.util.Date;
import java.util.Collection;
import java.util.Iterator;

class AnomalyTest {
    @Test void foundLongRssiGapForA70FromA40() throws ParseException {
        File base = new File(System.getenv("PWD"));
        File rawFolder = new File(base,"lib/data/2022-12-03-01");
        TestFolder folder = new TestFolder(rawFolder);
        // DeviceFolder dv = new DeviceFolder(new File(rawFolder,"AndroidA40"));

        Correlator c = new Correlator(folder.getDeviceFolders());
        RssiGapDetection gap = new RssiGapDetection(c, 20 * 60 * 1000);
        SimpleDateFormat dateFormatter = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.UK);
        Date startDate = dateFormatter.parse("2022-11-29 22:21:00.000+0000");
        Date endDate = dateFormatter.parse("2022-11-29 23:59:00.000+0000");
        Collection<Anomaly> anomalies = gap.detect(folder, startDate, endDate);

        // assertNotEquals(0,anomalies.size(),"There should be some anomalies");
        // None of these anomalies in this short test data!
        assertEquals(0,anomalies.size(),"Anomaly count wrong");

        // Iterator<Anomaly> anIter = anomalies.iterator();
        // Anomaly an = anIter.next();

    }
}