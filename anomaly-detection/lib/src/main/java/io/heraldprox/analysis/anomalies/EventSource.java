//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

public interface EventSource {
    public EventGroupSummary summarise();

    public boolean hasEvent();

    public Event first();

    public Event firstByType(final EventType type);

    public Event next();

    public Event nextByType(final EventType type);

    /**
     * Note event IDS do NOT have to be contiguous - they could be lines, and multi-line.
     * At this point in the API information lifecycle, they are raw line numbers.
     * 
     * @param lineNumber
     * @return
     */
    public String text(long lineNumber);
}
