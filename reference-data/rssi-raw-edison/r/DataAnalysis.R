# Apache 2.0 licensed
# 
# Copyright (c) 2020-2021 Herald Project Contributors
# 
# Combine raw RSSI-distance observation data from multiple phones and experiments,
# then establish intercept and coefficient for Smoothed Linear Model that uses
# the median of recent RSSI measurements to estimate distance.
# - Data captured at 1cm distance resolution is aligned with dynamic time warping
# - Combined data is smoothed by median over sliding window
# - Linear model parameters established by regression
# - Using linear instead of logarithmic model as log trend is only obvious in first 0-30cm

library(ggplot2)
library(dtw)
library(slider)
library(constants)

# MARK:- Define sample data

# STEP 1. Define folder containing the sample data
folder <- "/Users/Fred/Documents/Software/C19X/dev/herald-analysis/reference-data/rssi-raw-edison"
# STEP 2. Define the experiments to include in analysis
experiments <- c(
  "20210311-0901",
  "20210312-1049",
  "20210313-1005",
  "20210314-1021",
  "20210315-1040"
)
# STEP 3. Scroll to end of script to choose output

files <- sort(c(paste(folder, "/", experiments,"-A.csv",sep=""), paste(folder, "/", experiments,"-B.csv",sep="")))


# MARK:- Data summarisation and visualisation

# Read CSV file, compute density of RSSI at distance (distance,rssi,density)
density <- function(file) {
  # Load CSV file
  csv <- rbind(read.table(file, header=TRUE, sep=","))
  # Define distances
  distances <- sort(unique(csv$distance))
  # Define histogram bins
  breaks <- sort(unique(csv$rssi))
  breaks <- append(breaks, breaks[length(breaks)]+1)
  breaks <- breaks - 0.5
  df <- data.frame()
  for (distance in distances) {
    histogram <- hist(csv$rssi[csv$distance==distance], breaks=breaks, plot=FALSE)
    histogramDf <- data.frame(distance=distance, rssi=histogram$mids, density=histogram$density)
    df <- rbind(df, subset(histogramDf, density>0))
  }
  return(df)
}

# Given density, compute mode at distance (distance,rssi,rank)
mode <- function(density) {
  # Define distances
  distances <- sort(unique(density$distance))
  df <- data.frame()
  for (d in distances) {
    histogram <- subset(density, distance==d)
    index <- which(histogram$density==max(histogram$density))[1]
    df <- rbind(df, data.frame(distance=d, rssi=histogram$rssi[index], density=histogram$density[index]))
  }
  df$rank <- rank(df$rssi, ties.method = "min")
  return(df)
}

# Given density, plot mode, density, and fitted curve for mode
plotDensity <- function(density) {
  m <- mode(density)
  print(
    ggplot() +
      xlab("Distance (cm)") +
      ylab("RSSI") +
      geom_tile(density, mapping = aes(distance, rssi, fill=density)) +
      scale_fill_gradient(low="#EEEEEE", high="red") +
      theme_bw() +
      geom_line(m, mapping = aes(distance, rssi)) +
      stat_smooth(m, mapping = aes(distance, rssi),
                  method = "lm", formula = y ~ log(x+1),
                  colour = "blue")
  )
}

# Given mode, plot mode, and fitted curve for mode
plotModePathloss <- function(mode) {
  d <- mode
  window <- 400
  d$smoothed <- slide_dbl(mode$rssi, ~median(.x), .before = window, .after = window)
  d$distance <- d$distance / 100
  # Fit linear equation for distances > 30cm
  fitLinear <- lm(distance ~ smoothed, data = subset(d, distance>0.3))
  interceptLinear <- coef(fitLinear)[1]
  coefficientLinear <- coef(fitLinear)[2]
  eq <- paste0("distance = ", round(interceptLinear, 4),
              " + ", round(coefficientLinear, 4), " smoothed ")
  d$linear <- (d$distance - interceptLinear) / coefficientLinear
  # Fit log equation for all distances
  fitLog <- lm(log(distance + 0.01) ~ smoothed, data = d)
  interceptLog <- coef(fitLog)[1]
  coefficientLog <- coef(fitLog)[2]
  d$log <- (log(d$distance + 0.01) - interceptLog) / coefficientLog
  print(
    ggplot() +
      xlab("Distance (metres)") +
      ylab("RSSI") +
      # ggtitle(eq) +
      geom_line(d, mapping = aes(distance, rssi, colour="A: Observation")) +
      # geom_line(d, mapping = aes(distance, smoothed, colour="smoothed")) +
      geom_line(d, mapping = aes(distance, linear, colour="B: Linear model")) +
      geom_line(d, mapping = aes(distance, log, colour="C: Log model"))
  )
  summary(fitLinear)
}

# Given mode, plot mode, and fitted curve for mode
plotModePathlossLinear <- function(mode) {
  d <- mode
  window <- 400
  d$smoothed <- slide_dbl(mode$rssi, ~median(.x), .before = window, .after = window)
  d$distance <- d$distance / 100
  # Fit linear equation for distances > 30cm
  fit <- lm(distance ~ smoothed, data = subset(d, distance>0.3))
  intercept <- coef(fit)[1]
  coefficient <- coef(fit)[2]
  eq <- paste0("distance = ", round(intercept, 4),
               " + ", round(coefficient, 4), " smoothed ")
  d$linear <- (d$distance - intercept) / coefficient
  print(
    ggplot() +
      xlab("Distance (metres)") +
      ylab("RSSI") +
      geom_line(d, mapping = aes(distance, rssi, colour="A: Observation")) +
      geom_line(d, mapping = aes(distance, smoothed, colour="B: Smoothed")) +
      geom_line(d, mapping = aes(distance, linear, colour="C: Linear model"))
  )
  summary(fit)
  print(eq)
}

# Given mode, plot mode, and fitted curve for mode
plotModePathlossLinearMultichannel <- function(mode) {
  d <- mode
  window <- 400
  d$smoothed <- slide_dbl(mode$rssi, ~median(.x), .before = window, .after = window)
  d$distance <- d$distance / 100
  # Fit linear equation for distances > 30cm
  model <- lm(smoothed ~ distance, data = subset(d, distance>0.3))
  d$one <- sapply(d$distance, pathloss, model=model)
  d$two <- sapply(d$distance, reflectionModel, model=model, height=0.45, los=1, reflected=0)
  print(
    ggplot() +
      xlab("Distance (metres)") +
      ylab("RSSI") +
      geom_line(d, mapping = aes(distance, rssi, colour="A: Observation")) +
      #geom_line(d, mapping = aes(distance, smoothed, colour="smoothed")) +
      geom_line(d, mapping = aes(distance, one, colour="B: Linear model")) +
      geom_line(d, mapping = aes(distance, two, colour="C: Multi-channel interference"))
  )
  summary(model)
}

# Given mode, plot mode, and fitted curve for mode
plotModePathlossLinearMultichannelReflection <- function(mode) {
  d <- mode
  window <- 400
  d$smoothed <- slide_dbl(mode$rssi, ~median(.x), .before = window, .after = window)
  d$distance <- d$distance / 100
  # Fit linear equation for distances > 30cm
  model <- lm(smoothed ~ distance, data = subset(d, distance>0.3))
  d$one <- sapply(d$distance, pathloss, model=model)
  d$two <- sapply(d$distance, reflectionModel, model=model, height=0.45, distanceShift=0, los=0.5, reflected=0.5)
  print(
    ggplot() +
      xlab("Distance (metres)") +
      ylab("RSSI") +
      geom_line(d, mapping = aes(distance, rssi, colour="A: Observation")) +
      #geom_line(d, mapping = aes(distance, smoothed, colour="smoothed")) +
      geom_line(d, mapping = aes(distance, one, colour="B: Linear model")) +
      geom_line(d, mapping = aes(distance, two, colour="C: Two-ray model"))
  )
  summary(model)
}

# MARK:- Align and combine sample data

# Given mode, combine by aligning distance based on rank (distance,rssi,rank)
align <- function(m1, m2) {
  a <- dtw(m1$rank, m2$rank)
  m3 <- data.frame(
    distance=(m1$distance[a$index1] + m2$distance[a$index2])/2,
    rssi=(m1$rssi[a$index1] + m2$rssi[a$index2])/2,
    rank=(m1$rank[a$index1] + m2$rank[a$index2])/2
  )
  m1s <- data.frame(distance=m1$distance[a$index1], rank=m1$rank[a$index1])
  m2s <- data.frame(distance=m2$distance[a$index2], rank=m2$rank[a$index2])
  print(
    ggplot() +
      xlab("Distance (cm)") +
      ylab("RSSI (rank)") +
      geom_line(m1s, mapping = aes(distance, rank, colour="a")) +
      geom_line(m2s, mapping = aes(distance, rank, colour="b")) +
      geom_line(m3, mapping = aes(distance, rank, colour="combined"))
  )
  return(m3)
}

# Given files, combine by aligning data from phones A and B for each
# experiment first, then combine aligned data across experiments
alignAll <- function(files) {
  m <- NULL
  for (i in seq(1,length(files),by=2)) {
    cat("merging", files[i], files[i+1], "\n")
    a <- align(mode(density(files[i])),mode(density(files[i+1])))
    if (is.null(m)) {
      m <- a
    } else {
      cat("merging master", i, "\n")
      m <- align(m, a)
    }
  }
  return(m)
}


# MARK:- Model observation

# Given observation data, normalise distance to metres and magnitude to range [0,1]
normalise <- function(observation) {
  distance <- observation$distance / 100
  rssi <- (observation$rssi - min(observation$rssi)) / (max(observation$rank) - min(observation$rssi))
  rank <- (observation$rank - min(observation$rank)) / (max(observation$rank) - min(observation$rank))
  df <- subset(data.frame(distance=distance, rssi=rssi, rank=rank), distance>0)
  return(df)
}

# Given distance and pathloss model, compute magnitude at distance
pathloss <- function(distance, model) {
  return(model$coefficients[1] + model$coefficients[2] * distance)
}

# Given aligned observations, estimate linear pathloss model
pathlossModel <- function(normalised) {
  model <- lm(rssi ~ distance, normalised)
  normalised$model <- pathloss(normalised$distance, model)
  print(
    ggplot() +
      xlab("Distance (m)") +
      ylab("Magnitude") +
      geom_line(normalised, mapping = aes(distance, rssi, colour="observation")) +
      geom_line(normalised, mapping = aes(distance, model, colour="model"))
  )
  return(model)
}

# Given distance, pathloss model, and frequencies, compute amplitude
frequencyModel <- function(distance, model, frequencies=c(2.402, 2.426, 2.480), contribution=0.15) {
  # Wavelength
  c0 <- 299792458
  w <- (c0 / (frequencies * 1000000000))
  # Sum of BLE channels
  a <- mean(sin(2*pi*(distance/w)))
  l <- pathloss(distance, model)
  return(l + contribution * l * a)
}

# Given distance and height of transmitter/receiver, compute distance of reflected path
reflectedDistance <- function(distance, height) {
  return(sqrt(distance^2 + (2 * height)^2))
}


reflectionModel <- function(distance, model, height, distanceShift=0.25, los=1, reflected=0) {
  a <- c()
  # Hypothesis
  # 55% line of sight signal (distance+0.25m to adjust for antenna location in phone)
  # 45% reflected signal at 0.45m (ceiling)
  a <- append(a, los * frequencyModel(distance+distanceShift, model))
  a <- append(a, reflected * frequencyModel(reflectedDistance(distance+distanceShift,height), model))
  return(sum(a))
}
  
pathlossReflectionModel <- function(distance, model, height) {
  a <- c()
  # Hypothesis
  # 55% line of sight signal
  # 45% reflected signal at 0.45m (ceiling)
  a <- append(a, 0.55 * pathloss(distance, model))
  a <- append(a, 0.45 * pathloss(reflectedDistance(distance, height), model))
  return(sum(a))
}

# MARK:- Align data, then plot observation and predictions

observation <- alignAll(files)

# Option 1 : Plot aligned data and fitted linear/log pathloss model
plotModePathloss(observation)

# Option 2 : Plot aligned data and fitted linear pathloss model + multi-channel interference
plotModePathlossLinearMultichannel(observation)

# Option 3 : Plot aligned data and fitted linear pathloss model + multi-channel interference + reflection
plotModePathlossLinearMultichannelReflection(observation)

# Option 4 : Plot aligned data, smoothed data, and fitted linear pathloss model, and print parameters
plotModePathlossLinear(observation)


