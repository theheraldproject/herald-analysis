//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies.sources;

import io.heraldprox.analysis.anomalies.Event;
import io.heraldprox.analysis.anomalies.EventType;
import io.heraldprox.analysis.anomalies.EventGroupSummary;
import io.heraldprox.analysis.anomalies.EventSource;
import io.heraldprox.analysis.anomalies.EventList;
import io.heraldprox.analysis.anomalies.EventPointer;
import io.heraldprox.analysis.anomalies.TestDevice;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.io.File;
import java.util.SortedSet;
import java.util.TreeSet;
import java.util.Date;

/**
 * Represents each individual phone's detection.csv file.
 * 
 * The detection.csv file is a single line, with additional columns beyond the first ID for subsequent
 * identifiers.
 */
public class DetectionLogSource implements EventSource {

    protected File file;
    protected boolean initialised = false;

    protected TestDevice sourceDevice;

    // variables that depend upon initialise() being called:-
    protected EventGroupSummary summary = new EventGroupSummary(new TreeSet<EventType>(),0);

    protected int lastIndex = 0;
    protected EventList events = new EventList();

    protected String deviceName = "";
    protected String osName = "";
    protected String osVersion = "";
    protected String ownBroadcastId = "";

    protected TreeSet<String> broadcastIDsSeen = new TreeSet<String>();

    protected String[] elements = new String[]{};

    public DetectionLogSource(File contactFile, TestDevice toDescribe) {
        file = contactFile;
        sourceDevice = toDescribe;

        initialise();
    }

    public String getDeviceName() {
        return deviceName;
    }

    public String getOsName() {
        return osName;
    }

    public String getOsVersion() {
        return osVersion;
    }

    public String getOwnBroadcastId() {
        return ownBroadcastId;
    }

    protected void readElements() {
        if (initialised) {
            return;
        }
        try {
            BufferedReader reader = new BufferedReader(new FileReader(file));
            // Read header line
            String data = reader.readLine();
            reader.close();

            // There's only one line!
            if (null != data) {
                elements = data.split("[,]");
                reader.close();
            }

            reader.close();
        } catch (IOException ioe) {
            ioe.printStackTrace(System.err);
        }
    }

    protected void initialise() {
        if (initialised) {
            return;
        }
        readElements();

        long detectionCount = 0;
        SortedSet<EventType> types = new TreeSet<EventType>();

        if (elements.length > 3) {
            deviceName = elements[0];
            osName = elements[1];
            osVersion = elements[2];
            ownBroadcastId = elements[3];

            // Mark up test device now too
            sourceDevice.setDeviceTypeString(deviceName);
            sourceDevice.setBroadcastId(ownBroadcastId);
            sourceDevice.setOsVersion(osVersion);
            if ("ios".equalsIgnoreCase(osName)) {
                sourceDevice.setOs(TestDevice.OS.iOS);
            } else if ("android".equalsIgnoreCase(osName)) {
                sourceDevice.setOs(TestDevice.OS.Android);
            } // TODO other types, if this becomes true in future

            Date read = new Date();

            for (int i = 4;i < elements.length;++i) {
                types.add(EventType.DetectionBroadcastIdLoggedBefore);
                detectionCount++;
                // Note: Using column index as the event pointer start/end value (NOT line number)
                events.add(new Event(
                    read, 
                    EventType.DetectionBroadcastIdLoggedBefore, 
                    new EventPointer(this,i,i)
                ));
            }
        }

        summary = new EventGroupSummary(types, detectionCount);

        // If it fails, it won't suddenly succeed later, so mark as initialised
        initialised = true;
    }

    @Override
    public EventGroupSummary summarise() {
        return summary;
    }

    @Override
    public boolean hasEvent() {
        return 0 != events.size() && lastIndex < events.size();
    }

    @Override
    public Event first() {
        lastIndex = 0;
        if (!hasEvent()) {
            return null;
        }
        return events.atIndex(lastIndex);
    }

    protected Event findNextByType(final EventType type) {
        Event found = events.atIndex(lastIndex);
        boolean matches = false;
        while (!matches && null != found && lastIndex < events.size()) {
            matches = (found.type() == type);
            if (!matches) {
                lastIndex++;
                found = events.atIndex(lastIndex);
            }
        }
        if (lastIndex > events.size()) {
            lastIndex = events.size();
        }
        return found;
    }

    @Override
    public Event firstByType(EventType type) {
        lastIndex = 0;
        return findNextByType(type);
    }

    @Override
    public Event next() {
        lastIndex++;

        Event found = events.atIndex(lastIndex);
        if (lastIndex > events.size()) {
            lastIndex = events.size();
        }
        return found;
    }

    @Override
    public Event nextByType(EventType type) {
        lastIndex++;
        return findNextByType(type);
    }

    @Override
    public String text(long lineNumber) {
        readElements(); // just in case

        if ((elements.length - 1) < lineNumber) {
            return "";
        }
        return elements[(int)lineNumber];
    }
}
