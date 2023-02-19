//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

import io.heraldprox.analysis.anomalies.sources.ContactLogSource;
import io.heraldprox.analysis.anomalies.sources.DetectionLogSource;

import java.io.File;
import java.util.List;
import java.util.ArrayList;

public class DeviceFolder {
    protected String name;
    protected File folder;

    protected ArrayList<EventGroup> eventGroups = new ArrayList<EventGroup>();

    protected TestDevice device = new TestDevice();

    protected boolean checkingContacts = true;
    protected boolean checkingDetections = true;

    // Runtime lazy flags
    protected boolean hasCheckedForEvents = false;
    protected boolean hasReadDetections = false;

    public DeviceFolder(File folder) {
        this.folder = folder;
        // Assign temporary name for now
        this.name = folder.getName();
    }

    public File getFolder() {
        return folder;
    }

    public void setCheckingContacts(boolean doCheck) {
        checkingContacts = doCheck;
    }

    public boolean isCheckingContacts() {
        return checkingContacts;
    }

    protected void readDetections() {
        if (hasReadDetections) {
            return;
        }

        if (checkingDetections) {

            hasReadDetections = true;

            File detectionFile = new File(folder,"detection.csv");
            DetectionLogSource dl = new DetectionLogSource(detectionFile, device);
            eventGroups.add(new EventGroup(dl));
        }
    }
    
    public void setCheckingDetections(boolean doCheck) {
        checkingDetections = doCheck;
    }

    public boolean isCheckingDetections() {
        return checkingDetections;
    }

    public List<EventGroup> getEventGroups() {
        if (hasCheckedForEvents) {
            return eventGroups;
        }
            
        if (checkingContacts) {

            hasCheckedForEvents = true;

            File contactFile = new File(folder,"contacts.csv");
            ContactLogSource cl = new ContactLogSource(contactFile);
            eventGroups.add(new EventGroup(cl));
        }

        readDetections();
        
        return eventGroups;
    }

    public TestDevice getDevice() {
        readDetections(); // sets device broadcast ID
        return device;
    }

}
