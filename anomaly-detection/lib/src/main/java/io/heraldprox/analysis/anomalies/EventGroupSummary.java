//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

import java.util.SortedSet;

public class EventGroupSummary {
    public final SortedSet<EventType> types;
    public final long eventCount;

    public EventGroupSummary(final SortedSet<EventType> types, final long eventCount) {
        this.types = types;
        this.eventCount = eventCount;
    }
}
