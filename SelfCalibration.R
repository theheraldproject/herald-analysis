# Apache 2.0 licensed
# 
# Copyright (c) 2021 Herald Project Contributors
# 

# Author Adam Fowler <adam@adamfowler.org>

# This file analyses the raw RSSI data in the contacts.csv file on the demo
# app in order to see how viable self calibration of each phone is over time.

# Note: Only the Android demo app shows all nearby phones, not just Herald
#       enabled phones, and so please use Android phones for self calibration
#       analysis.

library(ggplot2)
library(parsedate)
library(stringr)

# 1. Set the folder that contains a sub folder per phone in the test
basedir <- "./sample-output/2020-08-11-cx-47"
phonedir <- "Pixel3XL"

# Filter data stored by the dates of interest (if phone is not cleared between tests)
filtertimemin <- as.POSIXct(paste("2021-11-16", "12:30:00"), format="%Y-%m-%d %H:%M:%S")
filtertimemax <- as.POSIXct(paste("2021-11-16", "18:45:00"), format="%Y-%m-%d %H:%M:%S")

thisdir <- paste(basedir,phonedir,sep="/")

## load csv file
csvdatafull <- FALSE
csvdata <- tryCatch({
  tp <- read.table(paste(thisdir , "/contacts.csv",sep=""), sep=",",header = TRUE)
  # names: time,sensor,id,detect,read,measure,share,visit,data
  
  cvsdatafull <- TRUE
  tp
}, error = function(err) {
  #  # error handler picks up where error was generated 
  print(paste("Read.table didn't work for contacts!:  ",err))
})
head(csvdata)

# We only care about measures (and their RSSI and TxPower values)
# i.e. the didMeasure calls (for ALL nearby devices, prefiltering)
measures <- dplyr::filter(csvdata,measure==3)
head(measures)
measures <- dplyr::select(measures,c("time","id","data"))
#measures <- dplyr::distinct(measures) # DO NOT DO THIS - reduces RSSI data
names(measures) <- c("time","macuuid","data")
head(measures)


# Filter by time
measures$t <- as.POSIXct(measures$time, format="%Y-%m-%d %H:%M:%S")
measures <- dplyr::filter(measures,t>=filtertimemin)
measures <- dplyr::filter(measures,t<=filtertimemax)
head(measures)

# Now extract RSSI and txPower (if present)
rssiAndTxPowerPattern <- "RSSI:(-[0-9]+\\.0)(,TxPower:([0-9]+))?"
#matches <- str_match(measures$data,rssiAndTxPowerPattern)
#head(matches)
measures$rssi <- str_match(measures$data,rssiAndTxPowerPattern)[,2]
measures$txpower <- str_match(measures$data,rssiAndTxPowerPattern)[,4]
head(measures)

# Filter out those without RSSI
measures <- dplyr::filter(measures,!is.na(rssi))
measures$rssiint <- as.numeric(measures$rssi)
head(measures)







# PART A
# Analyse RSSI values

# Filter invalid RSSIs (Same as we do in the Herald analysis API)
measures <- dplyr::filter(measures,rssiint>-100)

# Limit columns to only those of interest (performance tweak)
measures <- dplyr::select(measures,c("t","macuuid","rssiint","txpower"))
names(measures) <- c("t","macuuid","rssiint","txpower")
head(measures)

chartWidth <- 400
chartHeight <- 300

# Graph 1a&b - Show RSSI frequencies by macuuid across whole time period
# Note: As devices rotate mac address, some devices will be the same but 
#       appear as different mac addresses
p <- ggplot(measures, aes(x=rssiint, color=macuuid, fill=macuuid)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend=F) +
  labs(x="RSSI",
       y="Count of each RSSI value",
       title="RSSI histogram for each phone detected",
       subtitle="Some phones may be duplicates")  + 
  theme(legend.position = "bottom")
p
ggsave(paste(basedir,"/",phonedir,"-rssi-values.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(measures, aes(x=rssiint, y=..density..  , color=macuuid, fill=macuuid)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend=F) +
  geom_density(alpha=0.3, fill=NA, show.legend = F) +
  labs(x="RSSI",
       y="Relative Density",
       title="RSSI histogram for each phone detected",
       subtitle="Some phones may be duplicates")  + 
  theme(legend.position = "bottom")
p
ggsave(paste(basedir,"/",phonedir,"-rssi-density.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

# Graph 2 - Smoothed line of rssi over time (3 degrees of freedom)
p <- ggplot(measures, aes(x=t,y=rssiint,color=macuuid)) +
  geom_point(show.legend = F) +
  labs(x="Time",
       y="RSSI",
       title="RSSI detected over time",
       subtitle="Some phones may be duplicates") +
  scale_x_datetime(date_breaks = "60 min", date_minor_breaks = "10 min")
#  + geom_smooth(method="lm", formula=y ~ poly(x,3), show.legend = F)
#  geom_smooth(method="loess")
p
ggsave(paste(basedir,"/",phonedir,"-rssi-over-time.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")






# PART B
# Now analyse txpower
withtxpower <- dplyr::filter(measures,!is.na(txpower))
withtxpower$txpowerint <- as.numeric(withtxpower$txpower)
# Limit columns to only those of interest (performance tweak)
withtxpower <- dplyr::select(withtxpower,c("t","macuuid","rssiint","txpowerint"))
names(withtxpower) <- c("t","macuuid","rssiint","txpowerint")
head(withtxpower)

# TODO add 'correction' logic for txPower of the remote (partial, ideally need both sides)
