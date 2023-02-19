//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

public class EventPointer {
    protected EventSource source;
    protected long startLine;
    protected long endLine;

    public EventPointer(EventSource source,long startLine,long endLine) {
        this.source = source;
        this.startLine = startLine;
        this.endLine = endLine;
    }

    public String text() {
        StringBuffer buffer = new StringBuffer();
        for (long line = startLine;line <= endLine;++line) {
            buffer.append(source.text(line));
            if (line != endLine) {
                buffer.append("\n");
            }
        }
        return buffer.toString();
    }
}
