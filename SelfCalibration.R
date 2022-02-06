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
library(moments) # For skewness calculation
library(zoo) # rolling mean
library(lubridate) # working with time durations

# 1. Set the folder that contains a sub folder per phone in the test
#basedir <- "D:\\git\\skunkworks\\test-data\\2021-12-28-roaming"
#phonedir <- "Pixel3XL"
basedir <- "D:\\git\\skunkworks\\test-data\\2022-01-09-partner-data"
#phonedir <- "S10Lite"
phonedir <- "A40"
#basedir <- "d:\\git\\skunkworks/test-data/2021-11-16-garage"
#phonedir <- "A-S10lite"
#basedir <- "./sample-output/2020-08-11-cx-47"
#phonedir <- "Pixel3XL"

# Filter data stored by the dates of interest (if phone is not cleared between tests)
#A40Nov
#filtertimemin <- as.POSIXct(paste("2021-11-13", "00:00:01"), format="%Y-%m-%d %H:%M:%S")
#filtertimemax <- as.POSIXct(paste("2021-11-15", "23:59:59"), format="%Y-%m-%d %H:%M:%S")
#A4012-17Dec

#filtertimemin <- as.POSIXct(paste("2021-12-12", "00:00:01"), format="%Y-%m-%d %H:%M:%S")
#filtertimemax <- as.POSIXct(paste("2021-12-17", "23:59:59"), format="%Y-%m-%d %H:%M:%S")
filtertimemin <- as.POSIXct(paste("2020-05-12", "00:00:01"), format="%Y-%m-%d %H:%M:%S")
filtertimemax <- as.POSIXct(paste("2020-05-17", "23:59:59"), format="%Y-%m-%d %H:%M:%S")

#filtertimemin <- as.POSIXct(paste("2021-11-16", "12:30:00"), format="%Y-%m-%d %H:%M:%S")
#filtertimemax <- as.POSIXct(paste("2021-11-16", "18:45:00"), format="%Y-%m-%d %H:%M:%S")

# Runtime settings
heraldCsvDateFormat <- "%Y-%m-%d %H:%M:%S" # PRE v2.1.0-beta3 - integer seconds
#heraldCsvDateFormat <- "%Y-%m-%d %H:%M:%OS3%z" # v2.1.0-beta3 onwards - 3 decimal places of seconds with timezone as E.g. -0800
rssiCharts <- TRUE # Output RSSI chart images
dotxpower <- TRUE # Provide TXPower analyses
ignoreHeraldDevices <- TRUE

# DO NOT EDIT BEYOND THIS LINE

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

if (ignoreHeraldDevices) {
  # Collect macuuids for devices with Herald payloads
  heraldcontacts <- dplyr::filter(csvdata,read==2)
  measures <- dplyr::filter(measures, !(macuuid %in% heraldcontacts$id) )
}

# Filter by time
measures$t <- as.POSIXct(measures$time, format=heraldCsvDateFormat)
measures <- dplyr::filter(measures,t>=filtertimemin)
measures <- dplyr::filter(measures,t<=filtertimemax)
head(measures)

# Now extract RSSI and txPower (if present)
# Example $data value: RSSI:-97.0[BLETransmitPower:8.0]
rssiAndTxPowerPattern <- "RSSI:(-[0-9]+\\.0)(.BLETransmitPower:([0-9.]+).)?"
matches <- str_match(measures$data,rssiAndTxPowerPattern)
head(matches)
measures$rssi <- str_match(measures$data,rssiAndTxPowerPattern)[,2]
measures$txpower <- str_match(measures$data,rssiAndTxPowerPattern)[,4]
head(measures)

# Filter out those without RSSI
measures <- dplyr::filter(measures,!is.na(rssi))
measures$rssiint <- as.numeric(measures$rssi)
head(measures)





getmode <- function(v) {
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

# PART A
# Analyse RSSI values

# Filter invalid RSSIs (Same as we do in the Herald analysis API)
#measures <- dplyr::filter(measures,rssiint>-99)
measuresinrange <- measures # So we have all the data still, not just that used for self calibration



# CALIBRATION FILTERING
# Now filter by mean rssi < cut off
#validmacs <- measures %>%
#  dplyr::group_by(macuuid) %>%
#  dplyr::summarise(mean=mean(rssiint), sd=sd(rssiint), min=min(rssiint), max=max(rssiint), n=dplyr::n())
#cepre <- NROW(validmacs)

# Save summary for introspection
#prefilterrssisummary <- validmacs %>%
#  dplyr::group_by(mean) %>%
#  dplyr::summarise(cnt=dplyr::n())
#p <- ggplot(prefilterrssisummary, aes(x=mean, color=cnt, fill=cnt)) +
#  geom_histogram(alpha=0.5, binwidth=1, show.legend=F) +
#  labs(x="Mean RSSI",
#       y="Number of encounters with this mean",
#       title="Mean RSSI histogram by frequency")  + 
#  theme(legend.position = "bottom")
#p
#ggsave(paste(basedir,"/",phonedir,"-rssi-mean-freq-prefilter.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")



# Then filter by min number
#validmacs <-  dplyr::filter(validmacs,mean > -85) # & n > 15)
#head(validmacs)

#cepost <- NROW(validmacs)

#postfilterrssisummary <- validmacs %>%
#  dplyr::group_by(mean) %>%
#  dplyr::summarise(cnt=dplyr::n())
#p <- ggplot(postfilterrssisummary, aes(x=mean, color=cnt, fill=cnt)) +
#  geom_histogram(alpha=0.5, binwidth=1, show.legend=F) +
#  labs(x="Mean RSSI",
#       y="Number of encounters with this mean",
#       title="Mean RSSI histogram by frequency")  + 
#  theme(legend.position = "bottom")
#p
#ggsave(paste(basedir,"/",phonedir,"-rssi-mean-freq-postfilter.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")





#measures <- dplyr::filter(measures,macuuid %in% validmacs$macuuid)







# TODO SHOW ONLY THOSE WHERE THE CONTACT EVENTS ARE LESS THAN 20 MINUTES (I.e. devices with Bluetooth Privacy enabled) - FILTER ALL FOR THIS


cestats <- measuresinrange %>%
  dplyr::group_by(macuuid) %>%
  dplyr::summarise(n=dplyr::n(), mint=min(t), maxt=max(t), difft=maxt-mint, sdrssi=sd(rssiint), meanrssi=mean(rssiint), moderssi=getmode(rssiint), minrssi=min(rssiint), maxrssi=max(rssiint), rangerssi=max(rssiint)-min(rssiint)) %>%
  dplyr::arrange(dplyr::desc(n))
cestats$durmin <- as.numeric(cestats$difft) / 60 #assume seconds conversion
head(cestats)

p <- ggplot(cestats, aes(x=meanrssi,color=1, fill=1)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  labs(x="Mean RSSI",
       y="Relative Frequency",
       title="Mean RSSI Chart",
       subtitle="Across filtered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-prefiltered-meanrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(cestats, aes(x=moderssi,color=1, fill=1)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  labs(x="Mode RSSI",
       y="Relative Frequency",
       title="Mode RSSI Chart",
       subtitle="Across prefiltered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-prefiltered-moderssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(cestats, aes(x=sdrssi,color=1, fill=1)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  labs(x="SD RSSI",
       y="Relative Frequency",
       title="SD RSSI Chart",
       subtitle="Across prefiltered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-prefiltered-sdrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(cestats, aes(x=minrssi,color=1, fill=1)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  labs(x="Minimum RSSI",
       y="Relative Frequency",
       title="Minimum RSSI Chart",
       subtitle="Across prefiltered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-prefiltered-minrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(cestats, aes(x=maxrssi,color=1, fill=1)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  labs(x="Maximum RSSI",
       y="Relative Frequency",
       title="Maximum RSSI Chart",
       subtitle="Across prefiltered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-prefiltered-maxrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")



# Show maxrssi by meanrssi and similar scatter plots

p <- ggplot(cestats, aes(x=meanrssi, y=maxrssi,color=1, fill=1)) +
  geom_point(alpha=0.5, show.legend = F) +
  labs(x="Mean RSSI",
       y="Max RSSI",
       title="Mean vs Max RSSI",
       subtitle="Across prefiltered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-prefiltered-meanvsmaxrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(cestats, aes(x=meanrssi, y=minrssi,color=1, fill=1)) +
  geom_point(alpha=0.5, show.legend = F) +
  labs(x="Mean RSSI",
       y="Min RSSI",
       title="Mean vs Min RSSI",
       subtitle="Across prefiltered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-prefiltered-meanvsminrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(cestats, aes(x=meanrssi, y=rangerssi,color=1, fill=1)) +
  geom_point(alpha=0.5, show.legend = F) +
  labs(x="Mean RSSI",
       y="Range RSSI",
       title="Mean vs Range RSSI",
       subtitle="Across prefiltered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-prefiltered-meanvsrangerssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(cestats, aes(x=meanrssi, y=sdrssi,color=1, fill=1)) +
  geom_point(alpha=0.5, show.legend = F) +
  labs(x="Mean RSSI",
       y="SD RSSI",
       title="Mean vs SD RSSI",
       subtitle="Across prefiltered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-prefiltered-meanvssdrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(cestats, aes(x=maxrssi, y=minrssi,color=1, fill=1)) +
  geom_point(alpha=0.5, show.legend = F) +
  labs(x="Max RSSI",
       y="Min RSSI",
       title="Max vs Min RSSI",
       subtitle="Across prefiltered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-prefiltered-maxvsminrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")




# Check validity of duration calculations by looking at their distribution
# write chart of frequency of durations in minutes
# Limit max duration in graph to 60 mins
cestatslim <- cestats
cestatslim$durmin[cestatslim$durmin > 60] <- 60
p <- ggplot(cestatslim, aes(x=durmin,color=1, fill=1)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  labs(x="Duration (minutes)",
       y="Relative Frequency",
       title="Contact Event Duration Frequency",
       subtitle="Across all interactions (max of 60 minutes)")
p
ggsave(paste(basedir,"/",phonedir,"-ce-prefiltered-duration.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

# Also show a chart of number of readings for each contact event, in the tens of readings
cestatscntlim <- cestats
cestatscntlim$n[cestatscntlim$n > 350] <- 350
p <- ggplot(cestatscntlim, aes(x=n,color=1, fill=1)) +
  geom_histogram(alpha=0.5, binwidth=5, show.legend = F, aes( y=..density.. )) +
  labs(x="Readings (count)",
       y="Relative Frequency",
       title="Contact Event Reading Count Frequency",
       subtitle="Across all interactions (limited to n=350)")
p
ggsave(paste(basedir,"/",phonedir,"-ce-prefiltered-readingcount.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
cestatscntenough <- dplyr::filter(cestatscntlim, n > 35)




# count lower and higher than 20 mins
celong <- dplyr::filter(cestats, durmin >= 60)
cemiddle <- dplyr::filter(cestats, durmin >= 26 & durmin < 60)
ceshort <- dplyr::filter(cestats, durmin < 26)
NROW(celong)
NROW(cemiddle)
NROW(ceshort)

# Filter remaining data by those likely as phones (with BL E Privacy enabled)
NROW(measuresinrange)
measuresinrange <- dplyr::filter(measuresinrange, macuuid %in% ceshort$macuuid)
NROW(measuresinrange)
# Filter out contact events with less than 35 readings
measuresinrange <- dplyr::filter(measuresinrange, macuuid %in% cestatscntenough$macuuid)
NROW(measuresinrange)
# Filter for maxrssi
cestatsmaxrssi <- cestats
cestatsmaxrssi <- dplyr::filter(cestatsmaxrssi, maxrssi > -90)
measuresinrange <- dplyr::filter(measuresinrange, macuuid %in% cestatsmaxrssi$macuuid)
NROW(measuresinrange)
# Filter for meanrssi
cestatsmeanrssi <- cestats
cestatsmeanrssi <- dplyr::filter(cestatsmeanrssi, meanrssi > -80)
measuresinrange <- dplyr::filter(measuresinrange, macuuid %in% cestatsmeanrssi$macuuid)
NROW(measuresinrange)
# Filter for rangerssi > 5
cestatsrangerssi <- cestats
cestatsrangerssi <- dplyr::filter(cestatsrangerssi, rangerssi > 5)
measuresinrange <- dplyr::filter(measuresinrange, macuuid %in% cestatsrangerssi$macuuid)
NROW(measuresinrange)


# To confirm filtering at this point, view the effect on aggregate information
cestatsfiltered <- measuresinrange %>%
  dplyr::group_by(macuuid) %>%
  dplyr::summarise(n=dplyr::n(), mint=min(t), maxt=max(t), difft=maxt-mint, sdrssi=sd(rssiint), meanrssi=mean(rssiint), moderssi=getmode(rssiint), minrssi=min(rssiint), maxrssi=max(rssiint), rangerssi=max(rssiint)-min(rssiint)) %>%
  dplyr::arrange(dplyr::desc(n))
cestatsfiltered$durmin <- as.numeric(cestatsfiltered$difft) # WHY IS THIS MINUTES AND NOT SECONDS NOW!?! / 60 #assume seconds conversion
head(cestatsfiltered)

p <- ggplot(cestatsfiltered, aes(x=meanrssi,color=1, fill=1)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  labs(x="Mean RSSI",
       y="Relative Frequency",
       title="Mean RSSI Chart",
       subtitle="Across filtered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-filtered-meanrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(cestatsfiltered, aes(x=moderssi,color=1, fill=1)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  labs(x="Mode RSSI",
       y="Relative Frequency",
       title="Mode RSSI Chart",
       subtitle="Across filtered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-filtered-moderssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(cestatsfiltered, aes(x=sdrssi,color=1, fill=1)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  labs(x="SD RSSI",
       y="Relative Frequency",
       title="SD RSSI Chart",
       subtitle="Across filtered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-filtered-sdrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(cestatsfiltered, aes(x=minrssi,color=1, fill=1)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  labs(x="Minimum RSSI",
       y="Relative Frequency",
       title="Minimum RSSI Chart",
       subtitle="Across filtered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-filtered-minrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(cestatsfiltered, aes(x=maxrssi,color=1, fill=1)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  labs(x="Maximum RSSI",
       y="Relative Frequency",
       title="Maximum RSSI Chart",
       subtitle="Across filtered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-filtered-maxrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

head(cestatsfiltered)
cestatslim <- cestatsfiltered
cestatslim$durmin[cestatslim$durmin > 60] <- 60
p <- ggplot(cestatslim, aes(x=durmin,color=1, fill=1)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  labs(x="Duration (minutes)",
       y="Relative Frequency",
       title="Contact Event Duration Frequency",
       subtitle="Across filtered interactions (max of 60 minutes)")
p
ggsave(paste(basedir,"/",phonedir,"-ce-filtered-duration.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

# Also show a chart of number of readings for each contact event, in the tens of readings
cestatscntlim <- cestatsfiltered
cestatscntlim$n[cestatscntlim$n > 350] <- 350
p <- ggplot(cestatscntlim, aes(x=n,color=1, fill=1)) +
  geom_histogram(alpha=0.5, binwidth=5, show.legend = F, aes( y=..density.. )) +
  labs(x="Readings (count)",
       y="Relative Frequency",
       title="Contact Event Reading Count Frequency",
       subtitle="Across filtered interactions (limited to n=350)")
p
ggsave(paste(basedir,"/",phonedir,"-ce-filtered-readingcount.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")



# Show maxrssi by meanrssi and similar scatter plots

p <- ggplot(cestatsfiltered, aes(x=meanrssi, y=maxrssi,color=1, fill=1)) +
  geom_point(alpha=0.5, show.legend = F) +
  labs(x="Mean RSSI",
       y="Max RSSI",
       title="Mean vs Max RSSI",
       subtitle="Across filtered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-filtered-meanvsmaxrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(cestatsfiltered, aes(x=meanrssi, y=minrssi,color=1, fill=1)) +
  geom_point(alpha=0.5, show.legend = F) +
  labs(x="Mean RSSI",
       y="Min RSSI",
       title="Mean vs Min RSSI",
       subtitle="Across filtered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-filtered-meanvsminrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(cestatsfiltered, aes(x=meanrssi, y=rangerssi,color=1, fill=1)) +
  geom_point(alpha=0.5, show.legend = F) +
  labs(x="Mean RSSI",
       y="Range RSSI",
       title="Mean vs Range RSSI",
       subtitle="Across filtered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-filtered-meanvsrangerssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(cestatsfiltered, aes(x=meanrssi, y=sdrssi,color=1, fill=1)) +
  geom_point(alpha=0.5, show.legend = F) +
  labs(x="Mean RSSI",
       y="SD RSSI",
       title="Mean vs SD RSSI",
       subtitle="Across filtered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-filtered-meanvssdrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(cestatsfiltered, aes(x=maxrssi, y=minrssi,color=1, fill=1)) +
  geom_point(alpha=0.5, show.legend = F) +
  labs(x="Max RSSI",
       y="Min RSSI",
       title="Max vs Min RSSI",
       subtitle="Across filtered interactions")
p
ggsave(paste(basedir,"/",phonedir,"-ce-filtered-maxvsminrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")




# TODO also check distributions of 0700-1900 and 1900-0700 (i.e. remove overnight data)
# TODO also check affects of filtering that may skew result - E.g. look at duration pre and post filtering around 13-15 minutes, also look at txpower is na vs not





# Copy back (so I don't have to search and replace...)
measures <- measuresinrange

# TEMPORARILY restrict self calibration to txpower=="7.0" to see its effect
measures <- dplyr::filter(measures,txpower=="7.0")



# Limit columns to only those of interest (performance tweak)
measures <- dplyr::select(measures,c("t","macuuid","rssiint","txpower"))
names(measures) <- c("t","macuuid","rssiint","txpower")
head(measures)

# Some summary stats
meanrssi <- mean(measures$rssiint)
sdrssi <- sd(measures$rssiint)
countrssi <- NROW(measures)
minrssi <- min(measures$rssiint)
maxrssi <- max(measures$rssiint)



# A2 Try to normalise these values - by using the mean and local maxima peaks based on human behaviour
# - First, Filter for only those rssiint between -3 (or -97) and -1 SD and 1 and 3 SD (or minrssi if smaller)
weakmin <- max(meanrssi - (2 * sdrssi), -98)# -98 is the boundary value for bluetooth chips to receive data, so ignore
weakmax <- meanrssi - sdrssi
strongmin <- meanrssi + sdrssi
strongmax <- min(meanrssi + (2 * sdrssi), maxrssi, 0)
sdmeasures <- dplyr::filter(measures, (rssiint > weakmin & rssiint <= weakmax) | (rssiint >= strongmin & rssiint <= strongmax))
# Chart these as a debug step

p <- ggplot(sdmeasures, aes(x=rssiint)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend=F, aes( y=..density.. )) +
  labs(x="RSSI In Range",
       y="Number of values",
       title="RSSIs in range of local maxima")  + 
  theme(legend.position = "bottom") + 
  stat_function(fun = dnorm, args = list(mean = meanrssi, sd = sdrssi), show.legend = F)
p
ggsave(paste(basedir,"/",phonedir,"-debug-rssivalues.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

# - Second, for each RSSI, find local proportion above the curve (local maxima) beyond 1 SD
rssicounts <- sdmeasures %>%
  dplyr::group_by(rssiint) %>%
  dplyr::summarise(cnt=dplyr::n())
rssicounts$probrssi <- countrssi * (pnorm(rssicounts$rssiint - 0.5, mean = meanrssi, sd = sdrssi, lower.tail=FALSE) - pnorm(rssicounts$rssiint + 0.5, mean = meanrssi, sd = sdrssi, lower.tail=FALSE) )
rssicounts$abovecurve <- rssicounts$cnt - rssicounts$probrssi
head(rssicounts)
rssicounts <- dplyr::filter(rssicounts, abovecurve > 0)
rssicounts$abovefrac <- rssicounts$abovecurve / rssicounts$cnt # Larger is better (more above the curve)
rssicounts$lowerarea <- rssicounts$rssiint < meanrssi
head(rssicounts)

rssicountssummary <- rssicounts %>%
  dplyr::group_by(lowerarea) %>%
  dplyr::slice(which.max(abovefrac))
head(rssicountssummary)
rssicountssummary$sdpos <- (rssicountssummary$rssiint - meanrssi) / sdrssi
write.csv(rssicountssummary,paste(basedir , "/", phonedir,"-rssi-peaks.csv",sep=""))
lowerpeak <- as.integer(rssicountssummary[2:2,"rssiint"]) # WARNING ASSUMES A SINGLE PEAK
lowerpeak
upperpeak <- as.integer(rssicountssummary[1:1,"rssiint"]) # WARNING ASSUMES A SINGLE PEAK
upperpeak
#print(paste("Lower peak RSSI:",lowerpeak,"Upper Peak RSSI:", upperpeak)," ")
# Calculate peak positions relative to mean by number of RSSI SD positions
lowersdpos <- (lowerpeak - meanrssi) / sdrssi
uppersdpos <- (upperpeak - meanrssi) / sdrssi
lowersdpos
uppersdpos
skewrssi <- moments::skewness(measures$rssiint, na.rm = TRUE)
skewrssi
kurtosisrssi <- moments::kurtosis(measures$rssiint, na.rm = TRUE)

# NOW CREATE NORMALISED (scaled) DATASET
# Now alter rssi values to the idealised normal distribution
# NOTE: Not actually to a N(0,1) as yet - not got the scale factors right...
# Calculate fitness
scaled <- measures
# Filter beyond the two peaks
scaled <- dplyr::filter(scaled, rssiint >= lowerpeak & rssiint <= upperpeak)
scaled$rssicorrected <- 0
scaled$rssicorrected[scaled$rssiint < meanrssi] <- (scaled$rssiint[scaled$rssiint < meanrssi] - meanrssi) / abs(lowersdpos)
scaled$rssicorrected[scaled$rssiint > meanrssi] <- (scaled$rssiint[scaled$rssiint > meanrssi] - meanrssi) / abs(uppersdpos)
head(scaled)
meancor <- mean(scaled$rssicorrected)
sdcor <- sd(scaled$rssicorrected)
skewcor <- moments::skewness(scaled$rssicor, na.rm = TRUE)
kurtosiscor <- moments::kurtosis(scaled$rssicor, na.rm = TRUE)


# Hypothesis 1, Null point 1 - Each contact event RSSI is normally distributed
# Method: Find 12 contact events with highest number of rssi readings, and chart their RSSI over time, and rssi distribution
























mostdatacontactevents <- measuresinrange %>%
  dplyr::group_by(macuuid) %>%
  dplyr::summarise(n=dplyr::n(), mint=min(t), maxt=max(t), difft=maxt-mint) %>%
  dplyr::arrange(dplyr::desc(n))
mostdatacontactevents <- dplyr::slice_head(mostdatacontactevents, n=50)
head(mostdatacontactevents)
NROW(mostdatacontactevents)
measuresinrangewithmostdata <- dplyr::filter(measuresinrange, macuuid %in% mostdatacontactevents$macuuid)
head(measuresinrangewithmostdata)
measuresinrangewithmostdatanomean <- measuresinrangewithmostdata

## Note: Pre-v2.1.0-beta3 workaround for multiple readings at same integer second point in time (as it skews running mean line otherwise)
measuresinrangewithmostdata <- measuresinrangewithmostdata %>%
  dplyr::group_by(macuuid,t) %>%
  dplyr::summarise(rssiint=mean(rssiint))
head(measuresinrangewithmostdata)


longestcontactevents <- mostdatacontactevents %>%
  dplyr::arrange(dplyr::desc(difft))
longestcontactevents <- dplyr::slice_head(longestcontactevents, n=20)
head(longestcontactevents)
NROW(longestcontactevents)

measuresinrangewithlongestduration <- dplyr::filter(measuresinrange, macuuid %in% longestcontactevents$macuuid)
head(measuresinrangewithlongestduration)

## Note: Pre-v2.1.0-beta3 workaround for multiple readings at same integer second point in time (as it skews running mean line otherwise)
measuresinrangewithlongestduration <- measuresinrangewithlongestduration %>%
  dplyr::group_by(macuuid,t) %>%
  dplyr::summarise(rssiint=mean(rssiint))
head(measuresinrangewithlongestduration)


# B TxPower

# Now process the TXPower values
withtxpower <- dplyr::filter(measuresinrange,!is.na(txpower))
head(withtxpower)
withtxpower$txpowerint <- as.numeric(withtxpower$txpower)
# Limit columns to only those of interest (performance tweak)
withtxpower <- dplyr::select(withtxpower,c("t","macuuid","rssiint","txpowerint"))
names(withtxpower) <- c("t","macuuid","rssiint","txpowerint")
head(withtxpower)

# Rows with any TxPower
txcewithhastx <- dplyr::filter(measuresinrange,!is.na(txpower))

# TxPower==12
head(txcewithhastx)
txoftwelve <- dplyr::filter(txcewithhastx, txpower=="12.0") %>%
  dplyr::group_by(macuuid) %>%
  dplyr::summarise(n=dplyr::n())
head(txoftwelve)
measurestxtwelve <- dplyr::filter(measuresinrange,macuuid %in% txoftwelve$macuuid)
# tx=12 summary
meanrssi12 <- mean(measurestxtwelve$rssiint)
sdrssi12 <- sd(measurestxtwelve$rssiint)
countrssi12 <- NROW(measurestxtwelve)
minrssi12 <- min(measurestxtwelve$rssiint)
maxrssi12 <- max(measurestxtwelve$rssiint)
skewrssi12 <- moments::skewness(measurestxtwelve$rssiint, na.rm = TRUE)
kurtosisrssi12 <- moments::kurtosis(measurestxtwelve$rssiint, na.rm = TRUE)

# TxPower==7
head(txcewithhastx)
txofseven <- dplyr::filter(txcewithhastx, txpower=="7.0") %>%
  dplyr::group_by(macuuid) %>%
  dplyr::summarise(n=dplyr::n())
head(txofseven)
NROW(txoftwelve)
NROW(txofseven)
txoverlap <- dplyr::filter(txoftwelve,macuuid %in% txofseven$macuuid)
NROW(txoverlap)
measurestxseven <- dplyr::filter(measuresinrange,macuuid %in% txofseven$macuuid)
# TxPower==24
head(txcewithhastx)
txof24 <- dplyr::filter(txcewithhastx, txpower=="24.0") %>%
  dplyr::group_by(macuuid) %>%
  dplyr::summarise(n=dplyr::n())
measurestx24 <- dplyr::filter(measuresinrange,macuuid %in% txof24$macuuid)



























































# A99 - Charts

chartWidth <- 400
chartHeight <- 300

if (rssiCharts) {
# Graph 1a&b - Show RSSI frequencies by macuuid across whole time period
# Note: As devices rotate mac address, some devices will be the same but 
#       appear as different mac addresses
p <- ggplot(measuresinrange, aes(x=rssiint, color=macuuid, fill=macuuid)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend=F) +
  labs(x="RSSI",
       y="Count of each RSSI value",
       title="RSSI histogram for each phone detected",
       subtitle="Some phones may be duplicates")  + 
  theme(legend.position = "bottom")
p
ggsave(paste(basedir,"/",phonedir,"-rssi-values.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(measuresinrange, aes(x=rssiint, y=..density..  , color=macuuid, fill=macuuid)) +
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
p <- ggplot(measuresinrange, aes(x=t,y=rssiint,color=macuuid)) +
  geom_point(show.legend = F) +
  labs(x="Time",
       y="RSSI",
       title="RSSI detected over time",
       subtitle="Some phones may be duplicates") +
  scale_x_datetime(date_breaks = "10 min", date_minor_breaks = "2 min")
#  scale_x_datetime(date_breaks = "60 min", date_minor_breaks = "10 min")
#  + geom_smooth(method="lm", formula=y ~ poly(x,3), show.legend = F)
#  geom_smooth(method="loess")
p
ggsave(paste(basedir,"/",phonedir,"-rssi-over-time.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(measuresinrangewithmostdata, aes(x=t,y=rssiint,color=macuuid)) +
  geom_point(show.legend = F) +
  labs(x="Time",
       y="RSSI",
       title="RSSI detected over time",
       subtitle="50 Contact Events with most in range data only") +
  geom_line(aes(y=zoo::rollmean(rssiint, 5, na.pad=TRUE))) +
  scale_x_datetime(date_breaks = "5 min", date_minor_breaks = "1 min")  +
  facet_wrap(~macuuid, ncol=2, nrow=25, scales="free") +
  theme(legend.position = "none")
p
ggsave(paste(basedir,"/",phonedir,"-rssi-over-time-top50.png", sep=""), width = 400, height = 1250, units = "mm")

p <- ggplot(measuresinrangewithlongestduration, aes(x=t,y=rssiint,color=macuuid)) +
  geom_point(show.legend = F) +
  labs(x="Time",
       y="RSSI",
       title="RSSI detected over time",
       subtitle="20 Contact Events withlongest duration") +
  geom_line(aes(y=zoo::rollmean(rssiint, 5, na.pad=TRUE))) +
  scale_x_datetime(date_breaks = "5 min", date_minor_breaks = "1 min")  +
  facet_wrap(~macuuid, ncol=4, nrow=5, scales="free") +
  theme(legend.position = "none")
p
ggsave(paste(basedir,"/",phonedir,"-rssi-over-time-longest20.png", sep=""), width = 400, height = 1250, units = "mm")

# Density of ones with most data, above

p <- ggplot(measuresinrangewithmostdatanomean, aes(x=rssiint, y=..density..  , color=macuuid, fill=macuuid)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend=F) +
  geom_density(alpha=0.3, fill=NA, show.legend = F) +
  labs(x="RSSI",
       y="Relative Density",
       title="RSSI histogram for each phone detected",
       subtitle="Top 50 events with most data")  + 
  facet_wrap(~macuuid, ncol=5, nrow=10, scales="free") +
  theme(legend.position = "bottom")
p
ggsave(paste(basedir,"/",phonedir,"-rssi-density-top50.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")



# Graph 3 - All RSSIs against a calculated normal distribution
print(paste("Stats for RSSI: mean=",meanrssi," sd=",sdrssi," n=",countrssi, sep=""))
p <- ggplot(measures, aes(x=rssiint,color=1, fill=1)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  geom_vline(data=measures, aes(xintercept=meanrssi), color="blue", linetype="dashed", size=1, show.legend = F) +
  geom_vline(data=measures, aes(xintercept=maxrssi), color="black", linetype="solid", size=0.5, show.legend = F) +
  geom_vline(data=measures, aes(xintercept=minrssi), color="black", linetype="solid", size=0.5, show.legend = F) +
  geom_vline(data=measures, aes(xintercept=meanrssi + sdrssi), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=measures, aes(xintercept=meanrssi - sdrssi), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=measures, aes(xintercept=meanrssi + 2*sdrssi), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=measures, aes(xintercept=meanrssi - 2*sdrssi), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=measures, aes(xintercept=meanrssi + 3*sdrssi), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=measures, aes(xintercept=meanrssi - 3*sdrssi), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=measures, aes(xintercept=lowerpeak), color="blue", linetype="dashed", size=1, show.legend = F) +
  geom_vline(data=measures, aes(xintercept=upperpeak), color="blue", linetype="dashed", size=1, show.legend = F) +
  geom_text(aes(x=lowerpeak, label=paste("Lower peak = ",lowerpeak,sep=""), y=0.04), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
  geom_text(aes(x=upperpeak, label=paste("Upper peak = ",upperpeak,sep=""), y=0.04), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
  geom_text(aes(x=meanrssi, label=paste("Mean = ",meanrssi,"\nSD = ",sdrssi,"\nSkewness = ",skewrssi,"\nKurtosis = ",kurtosisrssi,sep=""), y=0.04), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
  labs(x="RSSI",
       y="Relative Frequency",
       title="RSSI Frequency",
       subtitle="Across all interactions") + 
  stat_function(fun = dnorm, args = list(mean = meanrssi, sd = sdrssi), show.legend = F)
p
ggsave(paste(basedir,"/",phonedir,"-rssi-distribution.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

# Scaled RSSI chart
p <- ggplot(scaled, aes(x=rssicorrected,color=1, fill=1)) +
  geom_histogram(alpha=0.5, binwidth=2, show.legend = F, aes( y=..density.. )) +
  geom_vline(data=scaled, aes(xintercept=meancor), color="blue", linetype="dashed", size=1, show.legend = F) +
  geom_vline(data=measures, aes(xintercept=meancor + sdcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=measures, aes(xintercept=meancor - sdcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=measures, aes(xintercept=meancor + 2*sdcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=measures, aes(xintercept=meancor - 2*sdcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=measures, aes(xintercept=meancor + 3*sdcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=measures, aes(xintercept=meancor - 3*sdcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_text(aes(x=meancor, label=paste("Mean = ",meancor,"\nSD = ",sdcor,"\nSkewness = ",skewcor,"\nKurtosis = ",kurtosiscor,sep=""), y=0.04), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
  labs(x="Corrected RSSI",
       y="Relative Frequency",
       title="Corrected RSSI Frequency",
       subtitle="Across all interactions") + 
  stat_function(fun = dnorm, args = list(mean = meancor, sd = sdcor), show.legend = F)
p
ggsave(paste(basedir,"/",phonedir,"-rssi-distribution-corrected.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")






# TxPower RSSI Distribution Charts
p <- ggplot(measurestxtwelve, aes(x=rssiint,color=macuuid, fill=macuuid)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  geom_vline(data=measurestxtwelve, aes(xintercept=meanrssi12), color="blue", linetype="dashed", size=1, show.legend = F) +
  geom_vline(data=measurestxtwelve, aes(xintercept=maxrssi12), color="black", linetype="solid", size=0.5, show.legend = F) +
  geom_vline(data=measurestxtwelve, aes(xintercept=minrssi12), color="black", linetype="solid", size=0.5, show.legend = F) +
  geom_vline(data=measurestxtwelve, aes(xintercept=meanrssi12 + sdrssi12), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=measurestxtwelve, aes(xintercept=meanrssi12 - sdrssi12), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=measurestxtwelve, aes(xintercept=meanrssi12 + 2*sdrssi12), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=measurestxtwelve, aes(xintercept=meanrssi12 - 2*sdrssi12), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=measurestxtwelve, aes(xintercept=meanrssi12 + 3*sdrssi12), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=measurestxtwelve, aes(xintercept=meanrssi12 - 3*sdrssi12), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_text(aes(x=meanrssi12, label=paste("Mean = ",meanrssi12,"\nSD = ",sdrssi12,"\nSkewness = ",skewrssi12,"\nKurtosis = ",kurtosisrssi12,sep=""), y=0.04), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
  labs(x="RSSI",
       y="Relative Frequency",
       title="RSSI Frequency",
       subtitle="Across all interactions with a TxPower of 12")
p
ggsave(paste(basedir,"/",phonedir,"-rssi-distribution-txpower12.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(measurestxseven, aes(x=rssiint,color=macuuid, fill=macuuid)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  labs(x="RSSI",
       y="Relative Frequency",
       title="RSSI Frequency",
       subtitle="Across all interactions with a TxPower of 7")
p
ggsave(paste(basedir,"/",phonedir,"-rssi-distribution-txpower7.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

p <- ggplot(measurestx24, aes(x=rssiint,color=macuuid, fill=macuuid)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  labs(x="RSSI",
       y="Relative Frequency",
       title="RSSI Frequency",
       subtitle="Across all interactions with a TxPower of 24")
p
ggsave(paste(basedir,"/",phonedir,"-rssi-distribution-txpower24.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")





} # end if rssiCharts




# PART B
# Now analyse txpower
if (dotxpower) {
  
# Get percentage of contacts with TXPower %>%
powercontactevents <- measuresinrange %>%
  dplyr::group_by(macuuid) %>%
  dplyr::summarise(hastxpower=any(!is.na(txpower)))
totalces <- NROW(powercontactevents)
head(powercontactevents)
head(measuresinrange)
totalces
powercecounts <- powercontactevents %>%
  dplyr::group_by(hastxpower) %>%
  dplyr::summarise(n=dplyr::n())
powercecounts
write.csv(powercecounts,paste(basedir , "/", phonedir,"-txpower-ce-prevalence.csv",sep=""))


# Stats B1 - Calculate mean & sd of RSSI for each txpowerint value
txsummary <- withtxpower %>%
  dplyr::group_by(txpowerint) %>%
  dplyr::summarise(mean=mean(rssiint), sd=sd(rssiint), min=min(rssiint), max=max(rssiint), n=dplyr::n())
head(txsummary)
write.csv(txsummary,paste(basedir , "/", phonedir,"-txpower-distribution-values.csv",sep=""))

# Stats B2, do the same but summarise by contact event and not advertisementmeasuresinrange %>%
txcewith <- txcewithhastx %>%
  dplyr::group_by(macuuid,txpower) %>%
  dplyr::summarise(n=dplyr::n())
txcewith
txcewithtx <- txcewithhastx %>%
  dplyr::group_by(txpower) %>%
  dplyr::summarise(mean=mean(rssiint), sd=sd(rssiint), min=min(rssiint), max=max(rssiint), n=dplyr::n())
head(txcewithtx)
write.csv(txcewithtx,paste(basedir , "/", phonedir,"-txpower-distribution-by-contactevent.csv",sep=""))
txcevaries <- txcewith %>%
  dplyr::group_by(macuuid,txpower) %>%
  dplyr::summarise(n=dplyr::n())
txcevaries <- dplyr::filter(txcevaries,n > 1)
txcevaries

# TODO add 'correction' logic for txPower of the remote (partial, ideally need both sides)


} # end if dotxpower

# FINALLY Print out summary for the person who ran this (data not saved by the script in csv/png files)
print(paste("Valid Contact Events (Mac Addresses) pre filtering:", cepre, "and post filtering:", cepost," "))
