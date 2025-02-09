//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.herald.app.test;

import java.text.SimpleDateFormat;
import java.util.Date;

public class TestDevice implements Comparable<TestDevice> {
	private final static SimpleDateFormat dateFormatter = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
	public int id = -1;
	public final String model;
	public final String operatingSystem;
	public final String operatingSystemVersion;
	public final String payload;
	public String status;
	public Date lastSeen;
	public String lastSeenString;
	public String commands = null;

	public TestDevice(final String model, final String operatingSystem, final String operatingSystemVersion,
			final String payload, final String status) {
		this.model = model;
		this.operatingSystem = operatingSystem;
		this.operatingSystemVersion = operatingSystemVersion;
		this.payload = payload;
		this.status = status;
		lastSeen(new Date());
	}

	public String label() {
		return String.join("::", model, operatingSystem, operatingSystemVersion, payload).intern();
	}

	public void lastSeen(final Date time) {
		this.lastSeen = time;
		this.lastSeenString = dateFormatter.format(lastSeen);
	}

	@Override
	public String toString() {
		return "TestDevice [id=" + id + ", model=" + model + ", operatingSystem=" + operatingSystem
				+ ", operatingSystemVersion=" + operatingSystemVersion + ", payload=" + payload + ", status=" + status
				+ ", lastSeen=" + lastSeenString + ", commands=" + commands + "]";
	}

	@Override
	public int compareTo(TestDevice other) {
		return label().compareTo(other.label());
	}

}
