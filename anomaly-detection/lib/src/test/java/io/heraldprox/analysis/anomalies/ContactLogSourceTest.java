//  Copyright 2022-2023 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

import java.util.List;
import java.util.SortedSet;
import java.io.File;

class ContactLogSourceTest {
    @Test void foundAllContactEventsForA40() {
        File base = new File(System.getenv("PWD"));
        File rawFolder = new File(base,"lib/data/2022-12-03-02");
        DeviceFolder dv = new DeviceFolder(new File(rawFolder,"AndroidA40"));
        dv.setCheckingDetections(false);

        List<EventGroup> eg = dv.getEventGroups();
        assertEquals(1,eg.size(),"Should be one event group for A40");
        EventGroupSummary egs = eg.get(0).getSummary();
        assertEquals(12,egs.eventCount,"Incorrect event count");
        SortedSet<EventType> types = egs.types;
        assertEquals(3,types.size(),"Should only have three event types");
        assertTrue(types.contains(EventType.ContactDetected),"Should contain detected event");
        assertTrue(types.contains(EventType.ContactMeasure),"Should contain measured event");
        assertTrue(types.contains(EventType.ContactRead),"Should contain read event");

        // Look for known BIDs
        EventGroup eg2 = eg.get(0);
        Event next = eg2.source.firstByType(EventType.ContactRead);
        String eventText = next.text();
        assertEquals("BLE,7B:AC:AC:34:E9:4A,lGxWLg",eventText,"First event incorrect");

        next = eg2.source.nextByType(EventType.ContactRead);
        eventText = next.text();
        assertEquals("BLE,52:5B:0A:AC:6A:02,lGxWLg",eventText,"Second event incorrect");

        next = eg2.source.nextByType(EventType.ContactRead);
        eventText = next.text();
        assertEquals("BLE,50:AA:A8:4D:F3:B4,lGxWLg",eventText,"Third event incorrect");

        next = eg2.source.nextByType(EventType.ContactRead);
        assertNull(next,"Should have ran out of read events");
    }

    @Test void foundAllContactEventsForA70() {
        File base = new File(System.getenv("PWD"));
        File rawFolder = new File(base,"lib/data/2022-12-03-02");
        DeviceFolder dv = new DeviceFolder(new File(rawFolder,"AndroidA70"));
        dv.setCheckingDetections(false);

        List<EventGroup> eg = dv.getEventGroups();
        assertEquals(1,eg.size(),"Should be one event group for A70");
        EventGroupSummary egs = eg.get(0).getSummary();
        assertEquals(6,egs.eventCount,"Incorrect event count");
        SortedSet<EventType> types = egs.types;
        assertEquals(2,types.size(),"Should only have two event types");
        assertTrue(types.contains(EventType.ContactMeasure),"Should contain measured event");
        assertTrue(types.contains(EventType.ContactRead),"Should contain read event");

        // Look for known BIDs
        EventGroup eg2 = eg.get(0);
        Event next = eg2.source.firstByType(EventType.ContactRead);
        String eventText = next.text();
        assertEquals("BLE,44:E2:F3:B2:3B:F8,ZqFdag",eventText,"First event incorrect");

        next = eg2.source.nextByType(EventType.ContactRead);
        eventText = next.text();
        assertEquals("BLE,5E:62:CB:F9:93:8D,ZqFdag",eventText,"Second event incorrect");

        next = eg2.source.nextByType(EventType.ContactRead);
        eventText = next.text();
        assertEquals("BLE,52:5B:0A:AC:6A:02,lGxWLg",eventText,"Third event incorrect");

        next = eg2.source.nextByType(EventType.ContactRead);
        eventText = next.text();
        assertEquals("BLE,50:AA:A8:4D:F3:B4,lGxWLg",eventText,"Fourth event incorrect");

        next = eg2.source.nextByType(EventType.ContactRead);
        eventText = next.text();
        assertEquals("BLE,47:7A:F7:88:41:43,lGxWLg",eventText,"Fifth event incorrect");

        next = eg2.source.nextByType(EventType.ContactRead);
        assertNull(next,"Should have ran out of read events");
    }

    @Test void foundAllContactEventsForiPhoneX() {
        File base = new File(System.getenv("PWD"));
        File rawFolder = new File(base,"lib/data/2022-12-03-02");
        DeviceFolder dv = new DeviceFolder(new File(rawFolder,"iPhoneX"));
        dv.setCheckingDetections(false);

        List<EventGroup> eg = dv.getEventGroups();
        assertEquals(1,eg.size(),"Should be one event group for iPhoneX");
        EventGroupSummary egs = eg.get(0).getSummary();
        assertEquals(11,egs.eventCount,"Incorrect event count");
        SortedSet<EventType> types = egs.types;
        assertEquals(3,types.size(),"Should only have three event types");
        assertTrue(types.contains(EventType.ContactDetected),"Should contain detected event");
        assertTrue(types.contains(EventType.ContactMeasure),"Should contain measured event");
        assertTrue(types.contains(EventType.ContactRead),"Should contain read event");

        // Look for known BIDs
        EventGroup eg2 = eg.get(0);
        Event next = eg2.source.firstByType(EventType.ContactRead);
        String eventText = next.text();
        assertEquals("BLE,AB7B8E8A-1F38-4B68-9E55-19F2339D699A,ql8F4g",eventText,"First event incorrect");

        next = eg2.source.nextByType(EventType.ContactRead);
        eventText = next.text();
        assertEquals("BLE,F47B4BC0-086E-48CE-99F2-AC5CA64D6D91,ql8F4g",eventText,"Second event incorrect");

        next = eg2.source.nextByType(EventType.ContactRead);
        eventText = next.text();
        assertEquals("BLE,4924DEF8-3E09-4B23-99C0-6299EC0612D1,ZqFdag",eventText,"Third event incorrect");

        next = eg2.source.nextByType(EventType.ContactRead);
        eventText = next.text();
        assertEquals("BLE,FE8A2B0D-746E-49FD-8C10-65E11BBB5CAC,ZqFdag",eventText,"Fourth event incorrect");

        next = eg2.source.nextByType(EventType.ContactRead);
        assertNull(next,"Should have ran out of read events");
    }
}