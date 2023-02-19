//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

import java.util.Vector;
import java.util.Collection;

public class EventList {
    protected Vector<Event> events = new Vector<Event>();

    public void add(Event event) {
        events.add(event);
    }

    public Collection<Event> getEvents() {
        return events;
    }

    public int size() {
        return events.size();
    }

    public Event atIndex(int position) {
        if (position >= events.size()) {
            return null;
        }
        return events.get(position);
    }
}
