//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

/**
 * Represents a described device which is part of the test.
 * 
 * NOT used for devices detected over Bluetooth
 */
public class TestDevice {
    /** This is the internal OS provided device type string, not folder name */
    protected String deviceTypeString = "";
    protected String broadcastId = "";
    protected OS os = OS.Unknown;
    protected String osVersion = "";

    public TestDevice() {
    }

    public String getDeviceTypeString() {
        return deviceTypeString;
    }

    public void setDeviceTypeString(String description) {
        deviceTypeString = description;
    }

    public OS getOs() {
        return os;
    }

    public void setOs(OS os) {
        this.os = os;
    }

    public String getOsVersion() {
        return osVersion;
    }

    public void setOsVersion(String version) {
        this.osVersion = version;
    }

    public String getBroadcastId() {
        return broadcastId;
    }

    public void setBroadcastId(String id) {
        this.broadcastId = id;
    }

    @Override
    public boolean equals(Object other) {
        if (other instanceof TestDevice) {
            TestDevice otherDevice = ((TestDevice)other);
            return (
                otherDevice.deviceTypeString == deviceTypeString &&
                otherDevice.broadcastId == broadcastId
            );
        }
        return false;
    }

    public enum OS {
        Unknown,
        iOS,
        Android,
        Zephyr,
        Windows,
        Linux,
    }
}
