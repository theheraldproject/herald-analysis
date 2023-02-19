//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

/**
 * Stores a set of related Events. Normally separated out for speed of processing.
 * E.g. one event group for contact information
 * 
 * Holds time indexed data pointing to a log file, with events over a number of lines (normally just 1).
 * 
 * These events are lazy loaded, and so an EventGroup uses an EventSource
 */
public class EventGroup {
    public final EventSource source;

    public EventGroup(EventSource src) {
        source = src;
    }

    public EventGroupSummary getSummary() {
        return source.summarise();
    }
}
