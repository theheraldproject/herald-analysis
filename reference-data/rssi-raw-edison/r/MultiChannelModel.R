# Apache 2.0 licensed
# 
# Copyright (c) 2020-2021 Herald Project Contributors
# 
# Simulation for impact of multi-channel advertising over three frequencies

library(ggplot2)
library(constants)
library(slider)

# BLE advertises on three channels
# Channel 37 = 2.402 GHz
# Channel 38 = 2.426 GHz
# Channel 39 = 2.480 GHz
bleChannelFrequency <- c(2.402, 2.426, 2.480)

# Wavelength given frequency in GHz
wavelength <- function(frequencyInGhz) {
  return(syms$c0 / (frequencyInGhz * 1000000000))
}

# Free space path loss given frequency in GHz and distance in metres
pathloss <- function(distance) {
  return(0.540132 + -0.216412 * log(distance))
}

# Amplitude at distance
bleChannels <- function(distance, frequencies=c(2.402, 2.426, 2.480), phaseShift=c(0,0,0)) {
  w <- wavelength(frequencies)
  a <- abs(mean(sin(2*pi*(distance/w)+phaseShift)))
  return(a)
}

simulate <- function(from=0.10, to=10) {
  distance <- seq(from,to,by=0.002)
  aPathloss <- sapply(distance, pathloss)
  aBleChannels <- sapply(distance, bleChannels)
  slide_dbl(abs(values), ~max(.x), .before = 30)
}

rms <- function(values) {
  slide_dbl(abs(values), ~max(.x), .before = 30)
}

plot <- function(f, from=0.10, to=10) {
  distance <- seq(from,to,by=0.001)
  amplitude <- sapply(distance, f)

  df <- data.frame(distance=distance, amplitude=amplitude)
  ggplot() +
    xlab("Distance (m)") +
    ylab("Amplitude") +
    geom_line(df, mapping = aes(distance, amplitude))
}

plot(bleChannels)
