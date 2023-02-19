//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

import java.util.Date;

/**
 * Represents a Raw event. May be subclassed to describe event more accurately
 */
public class Event {
    protected final EventType type;
    protected final EventPointer pointer;
    protected final Date occurred;

    public Event(Date occurred,EventType type,EventPointer pointer) {
        this.type = type;
        this.occurred = occurred;
        this.pointer = pointer;
    }

    public EventType type() {
        return type;
    }

    public String text() {
        return pointer.text();
    }

    public Date whenOccurred() {
        return occurred;
    }

    public EventPointer getPointer() {
        return pointer;
    }
}
