//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies.detection;

import java.util.Date;

import io.heraldprox.analysis.anomalies.Anomaly;
import io.heraldprox.analysis.anomalies.Correlator;
import io.heraldprox.analysis.anomalies.Detector;
import io.heraldprox.analysis.anomalies.DeviceFolder;
import io.heraldprox.analysis.anomalies.EventGroup;
import io.heraldprox.analysis.anomalies.EventType;
import io.heraldprox.analysis.anomalies.Event;
import io.heraldprox.analysis.anomalies.EventList;
import io.heraldprox.analysis.anomalies.TestFolder;
import io.heraldprox.analysis.anomalies.TestDevice;

import java.util.Collection;
import java.util.ArrayList;
import java.util.Hashtable;
import java.util.List;
import java.text.SimpleDateFormat;
import java.util.Locale;

public class RssiGapDetection implements Detector {
    final long interval;
    final Correlator correlator;

    public RssiGapDetection(Correlator correlator, long minimumIntervalMilliseconds) {
        interval = minimumIntervalMilliseconds;
        this.correlator = correlator;
    }

    @Override
    public Collection<Anomaly> detect(TestFolder testRun, Date startBound, Date endBound) {
        ArrayList<Anomaly> anomalies = new ArrayList<Anomaly>();

        // For each device, loop through the contactLog for all RSSI elements, and maintain a lastSeen for each target Device

        List<DeviceFolder> folders = testRun.getDeviceFolders();
        // Create start times map
        Hashtable<TestDevice,Event> lastRssi = new Hashtable<TestDevice,Event>();
        for (DeviceFolder df : folders) {
            TestDevice transmitter = df.getDevice();
            lastRssi.put(transmitter,new Event(new Date(0),EventType.ContactMeasure, null));
        }

        // Process events
        for (DeviceFolder df : folders) {
            TestDevice receiver = df.getDevice();
            for (EventGroup eg : df.getEventGroups()) {
                if (eg.getSummary().types.contains(EventType.ContactMeasure)) {
                    Event e = eg.source.firstByType(EventType.ContactMeasure);
                    while (null != e) {
                        // See which test device this is for (by the Mac address)
                        String rssiEventString = e.text();
                        String[] parts = rssiEventString.split("[,]",-1);
                        TestDevice transmitter = correlator.getDeviceByAddress(parts[1]);
                        if (null != transmitter && receiver != transmitter) { // can happen if a partially mapped file
                            // See when we last saw that device
                            Event last = lastRssi.get(transmitter);
                            // if non zero, and we're in the capture zone, add anomaly
                            if (e.whenOccurred().getTime() >= (startBound.getTime() /*+ interval*/) && 
                                e.whenOccurred().getTime() <= endBound.getTime() &&
                                last.whenOccurred().getTime() != 0 && // Don't need this as we add interval to start time, above
                                (e.whenOccurred().getTime() - last.whenOccurred().getTime()) > interval) {
                                EventList evidence = new EventList();
                                evidence.add(e);
                                Date from = last.whenOccurred();
                                // Handle the case where we've interval or more into the test, and this is the FIRST RSSI
                                if (null == last.getPointer()) {
                                    from = startBound;
                                } else {
                                    evidence.add(last);
                                    anomalies.add(new Anomaly(this,receiver, transmitter, from, e.whenOccurred(), evidence));
                                }
                            }

                            // Increment last seen time
                            lastRssi.put(transmitter,e);
                        }

                        e = eg.source.nextByType(EventType.ContactMeasure);
                    }
                }
            }

            for (DeviceFolder tdf : folders) {
                TestDevice transmitter = tdf.getDevice();

                // Check if lastSeen for each transmitter was before the end of the test, and if so, check the duration
                // and see if we need another anomaly for that period too
                Event last = lastRssi.get(transmitter);
                if (null != last.getPointer() && (endBound.getTime() - last.whenOccurred().getTime()) > interval) {
                    EventList evidence = new EventList();
                    evidence.add(last);
                    anomalies.add(new Anomaly(this,receiver, transmitter, last.whenOccurred(), endBound, evidence));
                }

                // Reset last seen before moving on to next device
                lastRssi.put(transmitter,new Event(new Date(0),EventType.ContactMeasure, null));
            }
        }


        return anomalies;
    }

    @Override
    public String describe(Anomaly anomaly) {
        SimpleDateFormat dateFormatter = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.UK);
        return "RSSI Gap detected for device " + anomaly.transmitter.getDeviceTypeString() + 
            " by device " + anomaly.receiver.getDeviceTypeString() + 
            " of length " + ((long)(anomaly.to.getTime()-anomaly.from.getTime())/1000) + 
            "s from " + dateFormatter.format(anomaly.from) + 
            " with " + anomaly.evidence.size() + " events as evidence";
    }
    
}
