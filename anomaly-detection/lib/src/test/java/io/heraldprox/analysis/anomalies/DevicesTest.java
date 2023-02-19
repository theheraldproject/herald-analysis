//  Copyright 2022-2023 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

import io.heraldprox.analysis.anomalies.TestFolder;
import io.heraldprox.analysis.anomalies.DeviceFolder;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

import java.util.List;
import java.io.File;

class DevicesTest {
    @Test void listsInvalidFolder() {
        File rawFolder = new File("wibble");
        TestFolder folder = new TestFolder(rawFolder);
        assertDoesNotThrow(folder::getDeviceFolders);
    }

    @Test void listsDevicesInFolder() {
        File base = new File(System.getenv("PWD"));
        File rawFolder = new File(base,"lib/data/2022-12-03-01");
        TestFolder folder = new TestFolder(rawFolder);
        List<DeviceFolder> folders = folder.getDeviceFolders();
        assertEquals(3, folders.size(), "returned wrong device folder count from PWD: " + System.getenv("PWD"));
    }

    @Test void allDevicesHaveEventGroups() {
        File base = new File(System.getenv("PWD"));
        File rawFolder = new File(base,"lib/data/2022-12-03-01");
        TestFolder folder = new TestFolder(rawFolder);
        List<DeviceFolder> folders = folder.getDeviceFolders();
        for (DeviceFolder device : folders) {
            // Disable extraneous file reading
            device.setCheckingDetections(false);
            
            assertNotEquals(0, device.getEventGroups().size(), "haven't found any events for device: " + device.name);
        }
    }

    @Test void devicesHaveCorrectContactLogCount() {
        File base = new File(System.getenv("PWD"));
        File rawFolder = new File(base,"lib/data/2022-12-03-01");
        TestFolder folder = new TestFolder(rawFolder);
        List<DeviceFolder> folders = folder.getDeviceFolders();
        int eventGroupCount = 0;
        assertEquals(3,folders.size(),"Device count is wrong");
        for (DeviceFolder device : folders) {
            // Disable extraneous file reading
            device.setCheckingDetections(false);

            List<EventGroup> eventGroups = device.getEventGroups();
            assertEquals(1,eventGroups.size(),"Processed event group size is wrong");
            for (EventGroup eg : eventGroups) {
                EventGroupSummary summary = eg.getSummary();
                // assertEquals("AndroidA40",device.name,"Wrong name");
                if ("AndroidA40".equals(device.name)) {
                    eventGroupCount++;
                    assertEquals(12234,summary.eventCount,"contact count incorrect for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactDetected),"Missing Contact Discovery events for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactRead),"Missing Contact Read events for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactMeasure),"Missing Contact Measure events for " + device.name);
                    // assertTrue(summary.types.contains(EventType.ContactShare),"Missing Contact Share events for " + device.name);
                    // assertTrue(summary.types.contains(EventType.ContactVisit),"Missing Contact Visit events for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactIsHerald),"Missing Contact Is Herald events for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactDeleted),"Missing Contact Deleted events for " + device.name);
                } else if ("AndroidA70".equals(device.name)) {
                    eventGroupCount++;
                    assertEquals(54852,summary.eventCount,"contact count incorrect for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactDetected),"Missing Contact Discovery events for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactDetected),"Missing Contact Discovery events for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactRead),"Missing Contact Read events for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactMeasure),"Missing Contact Measure events for " + device.name);
                    // assertTrue(summary.types.contains(EventType.ContactShare),"Missing Contact Share events for " + device.name);
                    // assertTrue(summary.types.contains(EventType.ContactVisit),"Missing Contact Visit events for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactIsHerald),"Missing Contact Is Herald events for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactDeleted),"Missing Contact Deleted events for " + device.name);
                } else if ("iPhoneX".equals(device.name)) {
                    eventGroupCount++;
                    assertEquals(34753,summary.eventCount,"contact count incorrect for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactDetected),"Missing Contact Discovery events for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactDetected),"Missing Contact Discovery events for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactRead),"Missing Contact Read events for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactMeasure),"Missing Contact Measure events for " + device.name);
                    // assertTrue(summary.types.contains(EventType.ContactShare),"Missing Contact Share events for " + device.name);
                    // assertTrue(summary.types.contains(EventType.ContactVisit),"Missing Contact Visit events for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactIsHerald),"Missing Contact Is Herald events for " + device.name);
                    assertTrue(summary.types.contains(EventType.ContactDeleted),"Missing Contact Deleted events for " + device.name);
                } else {
                    assertEquals(true,false,"Unexpected device name: " + device.name);
                }
            }
        }
        assertEquals(3,eventGroupCount,"Expected 3 event groups from devices");
    }
}
