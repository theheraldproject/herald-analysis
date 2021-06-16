//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.herald.app.test;

import java.util.Date;

public class TestDevice implements Comparable<TestDevice> {
	public final String model;
	public final String operatingSystem;
	public final String operatingSystemVersion;
	public final String payload;
	public String status;
	public Date lastSeen;
	public String commands = null;

	public TestDevice(final String model, final String operatingSystem, final String operatingSystemVersion,
			final String payload, final String status) {
		this.model = model;
		this.operatingSystem = operatingSystem;
		this.operatingSystemVersion = operatingSystemVersion;
		this.payload = payload;
		this.status = status;
		this.lastSeen = new Date();
	}

	public String id() {
		return String.join("::", model, operatingSystem, operatingSystemVersion, payload).intern();
	}

	@Override
	public String toString() {
		return "TestDevice [model=" + model + ", operatingSystem=" + operatingSystem + ", operatingSystemVersion="
				+ operatingSystemVersion + ", payload=" + payload + ", status=" + status + ", lastSeen=" + lastSeen
				+ ", commands=" + commands + "]";
	}

	@Override
	public int compareTo(TestDevice other) {
		return id().compareTo(other.id());
	}

}
