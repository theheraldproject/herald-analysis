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

filtertimemin <- as.POSIXct(paste("2021-12-12", "09:00:00"), format="%Y-%m-%d %H:%M:%S")
filtertimemin
filtertimemax <- as.POSIXct(paste("2021-12-12", "21:00:00"), format="%Y-%m-%d %H:%M:%S")
filtertimemax

cestart <- as.POSIXct(paste("2021-12-12", "09:00:00"), format="%Y-%m-%d %H:%M:%S")
ceend <-   as.POSIXct(paste("2021-12-12", "21:00:00"), format="%Y-%m-%d %H:%M:%S")

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

# We only care about measures (and their RSSI and TxPower values)
# i.e. the didMeasure calls (for ALL nearby devices, prefiltering)
measures <- dplyr::filter(csvdata,measure==3)
head(measures)
measures <- dplyr::select(measures,c("time","id","data"))
measures <- dplyr::distinct(measures)
names(measures) <- c("time","macuuid","data")
head(measures)


# Filter by time
measures$t <- as.POSIXct(measures$time, format="%Y-%m-%d %H:%M:%S")
#measures <- dplyr::filter(measures,t>=filtertimemin)
#measures <- dplyr::filter(measures,t<=filtertimemax)
head(measures)

# Now extract RSSI and txPower (if present)
rssiAndTxPowerPattern <- "RSSI:(-[0-9]+\\.0)(TxPower:([0-9]+))?"
matches <- str_match(measures$data,rssiAndTxPowerPattern)
head(matches)
measures$rssi <- str_match(measures$data,rssiAndTxPowerPattern)[,2]
measures$txpower <- str_match(measures$data,rssiAndTxPowerPattern)[,4]
head(measures)

# Filter out those without RSSI
measures <- dplyr::filter(measures,!is.na(rssi))
measures$rssiint <- as.numeric(measures$rssi)
head(measures)


chartWidth <- 300
chartHeight <- 200

# Graph 1 - Show RSSI frequencies by macuuid across whole time period
# Note: As devices rotate mac address, some devices will be the same but 
#       appear as different mac addresses
p <- ggplot(measures, aes(x=rssiint, color=macuuid, fill=macuuid)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend=T) +
  labs(x="RSSI",
       y="Count of each RSSI value",
       title="RSSI histogram for each phone detected",
       subtitle="Some phones may be duplicates")  + 
  theme(legend.position = "bottom")
p
ggsave(paste(basedir,"/",phonedir,"-rssi-values.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(measures, aes(x=rssiint, y=..density..  , color=macuuid, fill=macuuid)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend=T) +
  geom_density(alpha=0.3, fill=NA, show.legend = F) +
  labs(x="RSSI",
       y="Relative Density",
       title="RSSI histogram for each phone detected",
       subtitle="Some phones may be duplicates")  + 
  theme(legend.position = "bottom")
p
ggsave(paste(basedir,"/",phonedir,"-rssi-density.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")




# Now analyse txpower
#withtxpower <- dplyr::filter(measures,!is.na(txpower))
#head(withtxpower)
