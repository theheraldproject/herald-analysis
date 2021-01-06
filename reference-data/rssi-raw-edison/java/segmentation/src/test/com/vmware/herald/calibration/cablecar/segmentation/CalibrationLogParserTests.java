//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.segmentation;

import static org.junit.Assert.assertEquals;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.InputStreamReader;
import java.util.Date;
import java.util.concurrent.atomic.AtomicLong;

import org.junit.Test;

public class CalibrationLogParserTests {

	@Test
	public void testEmpty() throws Exception {
		final String content = "";
		final BufferedReader bufferedReader = new BufferedReader(
				new InputStreamReader(new ByteArrayInputStream(content.getBytes())));
		final AtomicLong lines = new AtomicLong();
		CalibrationLogParser.apply(bufferedReader, new CalibrationLogConsumer() {
			@Override
			public boolean rssi(Date time, String target, double rssi) {
				lines.incrementAndGet();
				return super.rssi(time, target, rssi);
			}

			@Override
			public boolean inertia(Date time, double x, double y, double z) {
				lines.incrementAndGet();
				return super.inertia(time, x, y, z);
			}
		});
		assertEquals(0, lines.get());
	}

	@Test
	public void testHeaderOnly() throws Exception {
		final String content = "time,target,rssi,x,y,z\n";
		final BufferedReader bufferedReader = new BufferedReader(
				new InputStreamReader(new ByteArrayInputStream(content.getBytes())));
		final AtomicLong lines = new AtomicLong();
		CalibrationLogParser.apply(bufferedReader, new CalibrationLogConsumer() {
			@Override
			public boolean rssi(Date time, String target, double rssi) {
				lines.incrementAndGet();
				return super.rssi(time, target, rssi);
			}

			@Override
			public boolean inertia(Date time, double x, double y, double z) {
				lines.incrementAndGet();
				return super.inertia(time, x, y, z);
			}
		});
		assertEquals(0, lines.get());
	}

	@Test
	public void testRssi() throws Exception {
		final String content = "time,target,rssi,x,y,z\n" + "2021-01-06 10:00:01,abc,-10,,,\n";
		final BufferedReader bufferedReader = new BufferedReader(
				new InputStreamReader(new ByteArrayInputStream(content.getBytes())));
		final AtomicLong lines = new AtomicLong();
		CalibrationLogParser.apply(bufferedReader, new CalibrationLogConsumer() {
			@Override
			public boolean rssi(Date time, String target, double rssi) {
				lines.incrementAndGet();
				assertEquals("abc", target);
				assertEquals(-10, rssi, Double.MIN_VALUE);
				return super.rssi(time, target, rssi);
			}

			@Override
			public boolean inertia(Date time, double x, double y, double z) {
				lines.incrementAndGet();
				return super.inertia(time, x, y, z);
			}
		});
		assertEquals(1, lines.get());
	}

	@Test
	public void testInertia() throws Exception {
		final String content = "time,target,rssi,x,y,z\n" + "2021-01-06 10:00:01,,,1,2,3\n";
		final BufferedReader bufferedReader = new BufferedReader(
				new InputStreamReader(new ByteArrayInputStream(content.getBytes())));
		final AtomicLong lines = new AtomicLong();
		CalibrationLogParser.apply(bufferedReader, new CalibrationLogConsumer() {
			@Override
			public boolean rssi(Date time, String target, double rssi) {
				lines.incrementAndGet();
				return super.rssi(time, target, rssi);
			}

			@Override
			public boolean inertia(Date time, double x, double y, double z) {
				lines.incrementAndGet();
				assertEquals(1, x, Double.MIN_VALUE);
				assertEquals(2, y, Double.MIN_VALUE);
				assertEquals(3, z, Double.MIN_VALUE);
				return super.inertia(time, x, y, z);
			}
		});
		assertEquals(1, lines.get());
	}
}
