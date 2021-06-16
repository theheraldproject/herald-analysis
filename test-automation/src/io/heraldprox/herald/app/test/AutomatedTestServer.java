//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.herald.app.test;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;

import io.heraldprox.herald.app.test.handler.BroadcastHandler;
import io.heraldprox.herald.app.test.handler.HeartbeatHandler;
import io.heraldprox.herald.app.test.handler.StatusHandler;
import io.heraldprox.herald.app.test.handler.UploadHandler;

public class AutomatedTestServer {
	private final static Logger logger = Logger.getLogger(AutomatedTestServer.class.getName());
	private final HttpServer httpServer;
	private final ThreadPoolExecutor threadPoolExecutor;
	private final Map<String, TestDevice> testDevices = new ConcurrentHashMap<>();
	private final File uploadFolder;
	private final List<ScheduledBroadcast> scheduledBroadcasts = new ArrayList<>();
	private final Timer timer;

	private final static class ScheduledBroadcast {
		public final String commands;
		public final long inSeconds;
		public final long atTime;

		public ScheduledBroadcast(final String commands, final long inSeconds) {
			this.commands = commands;
			this.inSeconds = inSeconds;
			this.atTime = System.currentTimeMillis() + (inSeconds * 1000);
		}

		@Override
		public String toString() {
			return "ScheduledBroadcast [commands=" + commands + ", inSeconds=" + inSeconds + ", atTime=" + atTime + "]";
		}

	}

	public AutomatedTestServer(final String host, final int port, final int backLogging, final int threadPool,
			final File uploadFolder) throws IOException {
		this.httpServer = HttpServer.create(new InetSocketAddress(host, port), backLogging);
		this.threadPoolExecutor = (ThreadPoolExecutor) Executors.newFixedThreadPool(threadPool);
		this.uploadFolder = uploadFolder;
		this.timer = scheduledCommandsTimer();
		httpServer.setExecutor(threadPoolExecutor);
		logger.log(Level.INFO, "Server created (host=" + host + ",port=" + port + ",backLogging=" + backLogging
				+ ",threadPool=" + threadPool + ",uploadFolder=" + uploadFolder + ")");
		createContexts(httpServer);
	}

	public void start() {
		logger.log(Level.INFO, "Server starting");
		httpServer.start();
		logger.log(Level.INFO, "Server started");
	}

	public void stop() {
		logger.log(Level.INFO, "Server stopping");
		httpServer.stop(0);
		threadPoolExecutor.shutdown();
		try {
			threadPoolExecutor.awaitTermination(1, TimeUnit.MINUTES);
			logger.log(Level.INFO, "Server stopped");
		} catch (Throwable e) {
			logger.log(Level.SEVERE, "Server stop failed", e);
		}
	}

	private final void createContexts(final HttpServer httpServer) {
		httpServer.createContext("/status", new StatusHandler(this));
		httpServer.createContext("/heartbeat", new HeartbeatHandler(this));
		httpServer.createContext("/broadcast", new BroadcastHandler(this));
		httpServer.createContext("/upload", new UploadHandler(this));
	}

	private final Timer scheduledCommandsTimer() {
		final Timer timer = new Timer();
		timer.schedule(new TimerTask() {
			@Override
			public void run() {
				final long now = System.currentTimeMillis();
				final List<ScheduledBroadcast> broadcastsExecuted = new ArrayList<>();
				for (final ScheduledBroadcast scheduledBroadcast : scheduledBroadcasts) {
					if (now >= scheduledBroadcast.atTime) {
						broadcast(scheduledBroadcast.commands);
						broadcastsExecuted.add(scheduledBroadcast);
					}
				}
				scheduledBroadcasts.removeAll(broadcastsExecuted);
				logger.log(Level.INFO, "scheduledCommandsTimer (now=" + now + ",executed=" + broadcastsExecuted
						+ ",remaining=" + scheduledBroadcasts + ")");
			}
		}, 0, 4000);
		return timer;
	}

	// MARK: - main(host,port,backLogging,threadPool,uploadFolder)

	public static void main(String[] args) throws Throwable {
		final String host = args[0];
		final int port = Integer.parseInt(args[1]);
		final int backLogging = Integer.parseInt(args[2]);
		final int threadPool = Integer.parseInt(args[3]);
		final File uploadFolder = new File(args[4]);
		final AutomatedTestServer automatedTestServer = new AutomatedTestServer(host, port, backLogging, threadPool,
				uploadFolder);
		automatedTestServer.start();
	}

	// MARK: - Server functions

	/**
	 * Client sends status update to server at regular intervals and obtains any
	 * pending commands.
	 * 
	 * @param testDevice
	 * @return Registered test device.
	 */
	public synchronized TestDevice heartbeat(final TestDevice testDevice) {
		final TestDevice knownTestDevice = testDevices.get(testDevice.id());
		if (null == knownTestDevice) {
			testDevices.put(testDevice.id(), testDevice);
		} else {
			knownTestDevice.status = testDevice.status;
			knownTestDevice.lastSeen = testDevice.lastSeen;
		}
		logger.log(Level.INFO, "heartbeat (device=" + knownTestDevice + ")");
		return knownTestDevice;
	}

	/**
	 * Get and clear commands for a device.
	 * 
	 * @param testDevice
	 * @return Pending commands, or null if none.
	 */
	public synchronized String getAndClearCommands(final TestDevice testDevice) {
		final String commands = testDevice.commands;
		testDevice.commands = null;
		logger.log(Level.INFO, "commands (commands=" + commands + ",device=" + testDevice + ")");
		return commands;
	}

	/**
	 * Set pending commands for broadcasting to all clients on next heart beat.
	 * 
	 * @param commands Pending commands, or null to cancel current command.
	 * @return Status of all clients.
	 */
	public synchronized String broadcast(final String commands) {
		for (final TestDevice testDevice : testDevices.values()) {
			if (null == commands) {
				testDevice.commands = commands;
			} else {
				testDevice.commands = (null == testDevice.commands || testDevice.commands.isEmpty() ? commands
						: testDevice.commands + "," + commands);
			}
		}
		return status();
	}

	/**
	 * Schedule pending commands for broadcasting to all clients in the future.
	 * 
	 * @param commands
	 * @param inMillis
	 * @return Scheduled commands.
	 */
	public synchronized String broadcast(final String commands, final long inSeconds) {
		final ScheduledBroadcast scheduledBroadcast = new ScheduledBroadcast(commands, inSeconds);
		scheduledBroadcasts.add(scheduledBroadcast);
		try {
			final String json = new ObjectMapper().writerWithDefaultPrettyPrinter()
					.writeValueAsString(scheduledBroadcasts);
			logger.log(Level.INFO, "broadcast, generated JSON (broadcasts=" + scheduledBroadcasts.size() + ")");
			return (null == json || json.isEmpty() ? "[ ]" : json);
		} catch (Throwable e) {
			logger.log(Level.WARNING, "broadcast, failed to generate JSON");
			return "[ ]";
		}
	}

	/**
	 * Get status of all clients, and optionally set pending commands for all
	 * clients.
	 * 
	 * @return Status of all clients.
	 */
	public synchronized String status() {
		final List<TestDevice> testDeviceList = new ArrayList<>(testDevices.values());
		Collections.sort(testDeviceList);
		try {
			final String json = new ObjectMapper().writerWithDefaultPrettyPrinter().writeValueAsString(testDeviceList);
			logger.log(Level.INFO, "status, generated JSON (devices=" + testDeviceList.size() + ")");
			return (null == json || json.isEmpty() ? "[ ]" : json);
		} catch (Throwable e) {
			logger.log(Level.WARNING, "status, failed to generate JSON");
			return "[ ]";
		}
	}

	/**
	 * Store uploaded file data to upload folder under a folder for the test device.
	 * 
	 * @param testDevice  Test device associated with the file.
	 * @param filename    Name of the uploaded file.
	 * @param inputStream Content of the uploaded file.
	 * @return Total bytes received.
	 */
	public long upload(final TestDevice testDevice, final String filename, final InputStream inputStream) {
		final TestDevice knownTestDevice = heartbeat(testDevice);
		final String deviceFolderName = (knownTestDevice.model + "_" + knownTestDevice.payload)
				.replaceAll("[^a-zA-Z0-9_]", "");
		final File deviceFolder = new File(uploadFolder, deviceFolderName);
		if (!deviceFolder.exists()) {
			if (!deviceFolder.mkdirs()) {
				logger.log(Level.WARNING, "upload, failed to create device folder (folder=" + deviceFolder + ")");
				return 0;
			}
		}
		final File uploadFile = new File(deviceFolder, filename);
		long totalBytesRead = 0;
		try {
			final BufferedInputStream bufferedInputStream = new BufferedInputStream(inputStream);
			final FileOutputStream fileOutputStream = new FileOutputStream(uploadFile);
			final BufferedOutputStream bufferedOutputStream = new BufferedOutputStream(fileOutputStream);
			final byte[] bytesBuffer = new byte[1024];
			int bytesRead;
			while ((bytesRead = bufferedInputStream.read(bytesBuffer, 0, bytesBuffer.length)) != -1) {
				bufferedOutputStream.write(bytesBuffer, 0, bytesRead);
				totalBytesRead += bytesRead;
			}
			bufferedOutputStream.flush();
			bufferedOutputStream.close();
			fileOutputStream.close();
			bufferedInputStream.close();
			inputStream.close();
			logger.log(Level.INFO,
					"upload (file=" + uploadFile + ",bytesRead=" + totalBytesRead + ",device=" + knownTestDevice + ")");
		} catch (Throwable e) {
			logger.log(Level.WARNING,
					"upload, failed to store uploaded file (file=" + uploadFile + ",bytesRead=" + totalBytesRead + ")",
					e);
		}
		return totalBytesRead;
	}
}
