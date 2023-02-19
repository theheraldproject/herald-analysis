//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

import java.util.Collection;
import java.util.Hashtable;
import java.util.TreeSet;
import java.util.Set;

/**
 * Correlates detected devices from logged data
 */
public class Correlator {
    protected Collection<DeviceFolder> folders;

    protected Hashtable<String,TestDevice> devicesByBroadcastId = new Hashtable<String,TestDevice>();

    // Linking a TestDevice to its physical Mac Addresses, as detected by other devices, over time
    protected Hashtable<TestDevice,TreeSet<String>> deviceOSAddresses = new Hashtable<TestDevice,TreeSet<String>>();

    protected boolean processedAddresses = false;

    public Correlator(Collection<DeviceFolder> deviceFolders) {
        folders = deviceFolders;

        // Ensure they read correlation info!
        for (DeviceFolder f : folders) {
            // These for own broadcast IDs
            f.setCheckingDetections(true);
            // These for linking detections to devices
            f.setCheckingContacts(true);

            TestDevice dev = f.getDevice();

            String bid = dev.getBroadcastId();
            if (null != bid && !"".equals(bid)) {
                devicesByBroadcastId.put(bid,dev);
            }

            deviceOSAddresses.put(dev,new TreeSet<String>());
        }
    }

    /**
     * Finds the TestDevice by broadcastId.
     * 
     * @param broadcastId
     * @return Device for the broadcastId. May return null
     */
    public TestDevice getDevice(String broadcastId) {
        if (!devicesByBroadcastId.keySet().contains(broadcastId)) {
            return null;
        }
        return devicesByBroadcastId.get(broadcastId);
    }

    /**
     * Convenience method to return detections made BY a particular device
     * 
     * @param device
     * @return May return null if no detections made
     */
    public EventGroup getDetectionsByDevice(TestDevice device) {
        for (DeviceFolder df : folders) {
            if (df.getDevice() == device) {
                for (EventGroup eg : df.getEventGroups()) {
                    if (eg.getSummary().types.contains(EventType.DetectionBroadcastIdLoggedBefore)) {
                        return eg;
                    }
                }
            }
        }
        return null;
    }

    public EventList getDetectionsOfDevice(TestDevice toDetect) {
        String bid = toDetect.getBroadcastId();
        EventList matching = new EventList();
        for (DeviceFolder df : folders) {
            if (df.getDevice() == toDetect) {
                continue; // Don't try to detect self!
            }
            for (EventGroup eg : df.getEventGroups()) {
                if (eg.getSummary().types.contains(EventType.DetectionBroadcastIdLoggedBefore)) {
                    // Always force starting at the beginning (in case we've already gone through it)
                    Event next = eg.source.firstByType(EventType.DetectionBroadcastIdLoggedBefore);
                    while (null != next) {
                        // Check event
                        if (bid.equals(next.text())) {
                            matching.add(next);
                        }

                        next = eg.source.nextByType(EventType.DetectionBroadcastIdLoggedBefore);
                    }
                }
            }
        }
        return matching;
    }

    protected TreeSet<String> addressSetForBid(String bid) {
        for (TestDevice device: deviceOSAddresses.keySet()) {
            if (device.getBroadcastId().equals(bid)) {
                return deviceOSAddresses.get(device);
            }
        }
        return null;
    }

    protected void initOsAddresses() {
        if (!processedAddresses) {
            processedAddresses = true;
            
            // Loop over all devices
            for (DeviceFolder matchTo : folders) {
                TestDevice checkDevice = matchTo.getDevice();

                // Loop over all (other) device folders
                for (DeviceFolder df : folders) {
                    // Don't try to detect self!
                    if (!df.getDevice().equals(checkDevice)) {
                        // Find all read events in other devices
                        for (EventGroup eg : df.getEventGroups()) {
                            if (eg.getSummary().types.contains(EventType.ContactRead)) {
                                // Always force starting at the beginning (in case we've already gone through it)
                                Event next = eg.source.firstByType(EventType.ContactRead);
                                while (null != next) {
                                    // Check event
                                    String eventText = next.text();
                                    String[] eventSplit = eventText.split("[,]",-1); // include empties
                                    if (eventSplit.length < 3) {
                                        throw new Error("Event split should have length 3: '" + eventText + "' for event ID: " + next.pointer.startLine + " for device: " + df.name);
                                    }
                                    TreeSet<String> addresses = addressSetForBid(eventSplit[2]);
                                    if (null != addresses) {
                                        addresses.add(eventSplit[1]);
                                    }

                                    next = eg.source.nextByType(EventType.ContactRead);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    public Set<String> getOsAddressesForDevice(TestDevice device) {
        initOsAddresses();

        if (!deviceOSAddresses.keySet().contains(device)) {
            return null;
        }

        return deviceOSAddresses.get(device);
    }

    public TestDevice getDeviceByAddress(String osAddress) {
        initOsAddresses();

        for (TestDevice device : deviceOSAddresses.keySet()) {
            for (String address : deviceOSAddresses.get(device)) {
                if (address.equals(osAddress)) {
                    return device;
                }
            }
        }

        return null;
    }

    public String getOsAddressesMap() {
        initOsAddresses();

        String map = "";

        for (TestDevice device : deviceOSAddresses.keySet()) {
            for (String address : deviceOSAddresses.get(device)) {
                map += device.getBroadcastId() + "@" + address + ",";
            }
        }

        return map;
    }
}
