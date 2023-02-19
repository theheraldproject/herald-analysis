//  Copyright 2022-2023 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

import io.heraldprox.analysis.anomalies.TestFolder;
import io.heraldprox.analysis.anomalies.sources.DetectionLogSource;
import io.heraldprox.analysis.anomalies.DeviceFolder;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

import java.util.List;
import java.util.Set;
import java.io.File;

class CorrectionTest {
    @Test void canReadSingleDetectionFile() {
        File base = new File(System.getenv("PWD"));
        File rawFolder = new File(base,"lib/data/2022-12-03-01");
        TestFolder folder = new TestFolder(rawFolder);

        File rawDeviceFolder = new File(rawFolder,"AndroidA40");
        DeviceFolder dv = new DeviceFolder(rawDeviceFolder);

        // Disable extraneous file reading
        dv.setCheckingContacts(false);
        assertTrue(dv.isCheckingDetections(),"Should be checking detections");
        assertFalse(dv.isCheckingContacts(),"Should NOT be checking contacts");

        // Do test device first to ensure we ALWAYS read detections, without asking for specific detection events
        TestDevice device = dv.getDevice();
        assertNotNull(device,"Device description should have a value");
        assertEquals(TestDevice.OS.Android,device.getOs(),"incorrect device OS read");
        assertEquals("29",device.getOsVersion(),"Wrong OS version read");
        assertEquals("ZqFdag",device.getBroadcastId(),"wrong broadcast ID read");
        assertEquals("SM-A405FN",device.getDeviceTypeString(),"Wrong device type string read");

        EventGroup eg = null;
        EventGroupSummary summary = null;
        for (EventGroup g : dv.getEventGroups()) {
            EventGroupSummary egs = g.getSummary();
            if (egs.types.contains(EventType.DetectionBroadcastIdLoggedBefore)) {
                eg = g;
                summary = egs;
            }
        }

        assertNotNull(eg,"Should have an event group for Detections");
        assertNotNull(summary,"Summary should have a value");

        assertEquals(2,summary.eventCount,"Android A40 detection event count is wrong");
        assertEquals(1,summary.types.size(),"Android A40 detection has wrong type count");
        assertEquals(EventType.DetectionBroadcastIdLoggedBefore,summary.types.first(),"Wrong event type recorded");
    }

    @Test void correlatesAllDevicesWithIDs() {
        File base = new File(System.getenv("PWD"));
        File rawFolder = new File(base,"lib/data/2022-12-03-02");
        TestFolder folder = new TestFolder(rawFolder);
        List<DeviceFolder> folders = folder.getDeviceFolders();

        assertEquals(3,folders.size(),"Device count is wrong");
        for (DeviceFolder device : folders) {
            // Disable extraneous file reading
            device.setCheckingContacts(false); // This SHOULD be change to true by the correlator
        }

        // Get devices' payloads and create device mapping class
        Correlator c = new Correlator(folders);

        // Check source detections work first
        // DeviceFolder dev1 = folders.get(0); // A40
        DeviceFolder dev1 = folder.deviceFolderByFolderName("AndroidA40"); // A40
        EventGroup det1 = c.getDetectionsByDevice(dev1.getDevice());
        assertNotNull(det1,"Should have some detections for this device");
        // DeviceFolder dev2 = folders.get(1); // A70
        DeviceFolder dev2 = folder.deviceFolderByFolderName("AndroidA70"); // A70
        EventGroup det2 = c.getDetectionsByDevice(dev2.getDevice());
        assertNotNull(det2,"Should have some detections for this device");
        // DeviceFolder dev3 = folders.get(2); // iPhoneX
        DeviceFolder dev3 = folder.deviceFolderByFolderName("iPhoneX"); // iPhoneX
        EventGroup det3 = c.getDetectionsByDevice(dev3.getDevice());
        assertNotNull(det3,"Should have some detections for this device");

        // now check these detection lengths
        assertEquals(2,det1.source.summarise().eventCount,"A40 should have detected 2 devices");
        assertEquals(2,det2.source.summarise().eventCount,"A70 should have detected 2 devices");
        assertEquals(2,det3.source.summarise().eventCount,"iPhoneX should have detected 2 devices");

        // Check each event group value
        Event det1evt1 = det1.source.first();
        assertNotNull(det1evt1,"First event for A40 should not be null");
        assertEquals(4,det1evt1.pointer.startLine,"start index should be 4 (first remote detected)");
        assertEquals("lGxWLg",det1evt1.text(),"Wrong broadcast ID compared to file");
        Event det1evt2 = det1.source.next();
        assertNotNull(det1evt2,"Second event for A40 should not be null");
        assertEquals(5,det1evt2.pointer.startLine,"start index should be 5 (second remote detected)");
        assertEquals("ql8F4g",det1evt2.text(),"Wrong broadcast ID compared to file");
        Event det2evt1 = det2.source.first();
        assertNotNull(det2evt1,"First event for A70 should not be null");
        assertEquals(4,det2evt1.pointer.startLine,"start index should be 4 (first remote detected)");
        assertEquals("ZqFdag",det2evt1.text(),"Wrong broadcast ID compared to file");
        Event det2evt2 = det2.source.next();
        assertNotNull(det2evt2,"Second event for A70 should not be null");
        assertEquals(5,det2evt2.pointer.startLine,"start index should be 5 (second remote detected)");
        assertEquals("lGxWLg",det2evt2.text(),"Wrong broadcast ID compared to file");
        Event det3evt1 = det3.source.first();
        assertNotNull(det3evt1,"First event for iPhoneX should not be null");
        assertEquals(4,det3evt1.pointer.startLine,"start index should be 4 (first remote detected)");
        assertEquals("ZqFdag",det3evt1.text(),"Wrong broadcast ID compared to file");
        Event det3evt2 = det3.source.next();
        assertNotNull(det3evt2,"Second event for iPhoneX should not be null");
        assertEquals(5,det3evt2.pointer.startLine,"start index should be 5 (second remote detected)");
        assertEquals("ql8F4g",det3evt2.text(),"Wrong broadcast ID compared to file");

        det1evt1 = det1.source.firstByType(EventType.DetectionBroadcastIdLoggedBefore);
        assertNotNull(det1evt1,"det1evt1 find first by type should have a value");
        assertEquals(4,det1evt1.pointer.startLine,"det1evt1 start index should be 4 (first remote detected)");
        assertEquals("lGxWLg",det1evt1.text(),"det1evt1 Wrong broadcast ID compared to file");
        det1evt2 = det1.source.nextByType(EventType.DetectionBroadcastIdLoggedBefore);
        assertNotNull(det1evt2,"det1evt2 find next by type should have a value");
        assertEquals(5,det1evt2.pointer.startLine,"det1evt2 start index should be 5 (second remote detected)");
        assertEquals("ql8F4g",det1evt2.text(),"det1evt2 Wrong broadcast ID compared to file");
        det2evt1 = det2.source.firstByType(EventType.DetectionBroadcastIdLoggedBefore);
        assertNotNull(det2evt1,"det2evt1 find first by type should have a value");
        assertEquals(4,det2evt1.pointer.startLine,"det2evt1 start index should be 4 (first remote detected)");
        assertEquals("ZqFdag",det2evt1.text(),"det2evt1 Wrong broadcast ID compared to file");
        det2evt2 = det2.source.nextByType(EventType.DetectionBroadcastIdLoggedBefore);
        assertNotNull(det2evt2,"det2evt2find next by type should have a value");
        assertEquals(5,det2evt2.pointer.startLine,"det2evt2start index should be 5 (second remote detected)");
        assertEquals("lGxWLg",det2evt2.text(),"det2evt2Wrong broadcast ID compared to file");
        det3evt1 = det3.source.firstByType(EventType.DetectionBroadcastIdLoggedBefore);
        assertNotNull(det3evt1,"det3evt1find first by type should have a value");
        assertEquals(4,det3evt1.pointer.startLine,"det3evt1start index should be 4 (first remote detected)");
        assertEquals("ZqFdag",det3evt1.text(),"det3evt1Wrong broadcast ID compared to file");
        det3evt2 = det3.source.nextByType(EventType.DetectionBroadcastIdLoggedBefore);
        assertNotNull(det3evt2,"det3evt2 find next by type should have a value");
        assertEquals(5,det3evt2.pointer.startLine,"det3evt2 start index should be 5 (second remote detected)");
        assertEquals("ql8F4g",det3evt2.text(),"det3evt2 Wrong broadcast ID compared to file");

        // Validate each device was detected by each other device
        // Now check that each device was detected by each other device
        EventList seenBy1 = c.getDetectionsOfDevice(dev1.getDevice());
        EventList seenBy2 = c.getDetectionsOfDevice(dev2.getDevice());
        EventList seenBy3 = c.getDetectionsOfDevice(dev3.getDevice());
        assertEquals(2,seenBy1.size(),"A40 should have been seen twice");
        assertEquals(2,seenBy2.size(),"A70 should have been seen twice");
        assertEquals(2,seenBy3.size(),"iPhoneX should have been seen twice");

        // Validate mac/ble address lists for each device over time
        String map = c.getOsAddressesMap();
        Set<String> dev1addresses = c.getOsAddressesForDevice(dev1.getDevice());
        assertNotNull(dev1addresses,"A40 physical addresses should not be null");
        assertNotEquals(0,dev1addresses.size(),"A40 addresses count should be non zero. Device " + dev1.getDevice().getDeviceTypeString() + " BID: " + dev1.getDevice().getBroadcastId() + " map: " + map);

        Set<String> dev2addresses = c.getOsAddressesForDevice(dev2.getDevice());
        assertNotNull(dev2addresses,"A70 physical addresses should not be null");
        assertNotEquals(0,dev2addresses.size(),"A70 addresses count should be non zero. Device " + dev2.getDevice().getDeviceTypeString() + " BID: " + dev2.getDevice().getBroadcastId() + " map: " + map);

        Set<String> dev3addresses = c.getOsAddressesForDevice(dev3.getDevice());
        assertNotNull(dev3addresses,"iPhoneX physical addresses should not be null");
        assertNotEquals(0,dev3addresses.size(),"iPhoneX addresses count should be non zero. Device " + dev3.getDevice().getDeviceTypeString() + " BID: " + dev3.getDevice().getBroadcastId() + " map: " + map);

        // Ensure no mac/ble address is repeated for a different device (We know this IS true for THIS data)
        for (String add : dev1addresses) {
            assertFalse(dev2addresses.contains(add),"A70 has the same address as A40 at some point");
            assertFalse(dev3addresses.contains(add),"iPhoneX has the same address as A40 at some point");
        }
        for (String add : dev2addresses) {
            assertFalse(dev1addresses.contains(add),"A40 has the same address as A70 at some point");
            assertFalse(dev3addresses.contains(add),"iPhoneX has the same address as A70 at some point");
        }
        for (String add : dev3addresses) {
            assertFalse(dev2addresses.contains(add),"A70 has the same address as iPhoneX at some point");
            assertFalse(dev1addresses.contains(add),"A40 has the same address as iPhoneX at some point");
        }
        
        // Perform count validations with grep and sort commands over log files before executing the next test
        String collect = "";
        if (dev3addresses.size() != 4) {
            for (String add : dev3addresses) {
                collect += add + ",";
            }
        }
        assertEquals(4,dev3addresses.size(),"Should be 4 unique MAC addresses for the iPhoneX. Only found: " + collect);

        // Test some known IDs
        TestDevice dev1ByAddressFromDev2 = c.getDeviceByAddress("5E:62:CB:F9:93:8D");
        assertNotNull(dev1ByAddressFromDev2,"Couldn't find A40 in A70 contacts data");
        TestDevice dev1ByAddressFromDev3 = c.getDeviceByAddress("4924DEF8-3E09-4B23-99C0-6299EC0612D1");
        assertNotNull(dev1ByAddressFromDev3,"Couldn't find A40 in iPhoneX contacts data");

        TestDevice dev3ByAddressFromDev1 = c.getDeviceByAddress("7B:AC:AC:34:E9:4A");
        assertNotNull(dev3ByAddressFromDev1,"Couldn't find iPhoneX in A40 contacts data");
        TestDevice dev3ByAddressFromDev2 = c.getDeviceByAddress("50:AA:A8:4D:F3:B4");
        assertNotNull(dev3ByAddressFromDev2,"Couldn't find iPhoneX in A70 contacts data");

        // TestDevice dev2ByAddressFromDev1 = c.getDeviceByAddress("5F:44:BF:00:4C:FE");
        // assertNotNull(dev2ByAddressFromDev1,"Couldn't find A70 in A40 contacts data");
        TestDevice dev2ByAddressFromDev3 = c.getDeviceByAddress("F47B4BC0-086E-48CE-99F2-AC5CA64D6D91");
        assertNotNull(dev2ByAddressFromDev3,"Couldn't find A70 in iPhoneX contacts data");
    }
}