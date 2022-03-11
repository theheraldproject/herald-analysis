# Apache 2.0 licensed
# 
# Copyright (c) 2020-2021 Herald Project Contributors

# Author Adam Fowler <adam@adamfowler.org>

# This file provides the RSSI accuracy (observed vs expected at distance)
# analysis for the Fair Efficacy Formula.

library(plyr)
library(chron)
library(ggplot2)
library(parsedate)
library(scales)
library(caTools)

# 1. Set the base directory within which there is a sub folder for each phone
basedir = "../test-data/2020-08-13-cx-54-office-accuracy-1"
# 2. Specify the subfolder of the 'receiver' for the accuracy measure (ideally most popular phone in country)
receiverdir = "iPhone7(3)" # the static phone's folder
# 3. Specify the unique test-long ID shared in the CSV file (ours are 6 character short codes unique per phone, for testing) of the TRANSMITTING phone
#    (i.e. the ID of the phone the receiving phone should have seen). Ideally the second most popular phone in a country.
onlyusebid = "b7kaDw" # the moving phones ID

# 4. Select all lines in this file and hit Run. You should see a formal distance summary CSV file generated for the receiver phone.

## Read metadata file Distance, Expected rssi, start time, end time
metafile <- paste(basedir,"/rssi-metadata.csv",sep="")

metafull <- FALSE
metadata <- tryCatch({
  tp <- read.table(metafile, sep=",",header = TRUE)
  # names: distance, rssi, start, end
  
  metafull <- TRUE
  tp
}, error = function(err) {
  #  # error handler picks up where error was generated 
  print(paste("Read.table didn't work for metadata file!:  ",err))
})
metadata$startt <- as.POSIXct(metadata$start, format="%Y-%m-%d %H:%M:%S")
metadata$endt <- as.POSIXct(metadata$end, format="%Y-%m-%d %H:%M:%S")

## Read RSSI values file
valuesfile <- paste(basedir,"/",receiverdir,"-formal-distance-values.csv",sep="")

valuesfull <- FALSE
rssivalues <- tryCatch({
  tp <- read.table(valuesfile, sep=",",header = TRUE)
  # names: time,sensor,id,detect,read,measure,share,visit,data
  
  valuesfull <- TRUE
  tp
}, error = function(err) {
  #  # error handler picks up where error was generated 
  print(paste("Read.table didn't work for RSSI Values!:  ",err))
})
# Create t value
rssivalues$pt <- as.POSIXct(rssivalues$time, format="%Y-%m-%d %H:%M:%S")
rssivalues <- dplyr::filter(rssivalues,initialBID == onlyusebid)

getmode <- function(v) {
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

## For each distance, filter by time, summarise all data at that distance, calculate error value, append to output data
alldata <- data.frame(matrix(ncol = 4, nrow = 0))
names(alldata) <- c("time","t","pt","rssi")
for (i in 1:dim(metadata)[1]) {
  metarow <- metadata[i,]
  dataatdist <- rssivalues
  dataatdist <- dplyr::filter(dataatdist,pt>=metarow$startt)
  dataatdist <- dplyr::filter(dataatdist,pt<=metarow$endt)
  
  # abs error
  dataatdist$abserror <- abs(dataatdist$rssi - metarow$rssi)
  
  alldata <- rbind(alldata,dataatdist)
  
  mu <- ddply(dataatdist, "initialBID", summarise, grp.var=var(abserror), 
              grp.mean=mean(abserror), grp.median=median(abserror), 
              grp.mode=getmode(abserror), grp.min=min(abserror), grp.max=max(abserror),
              grp.modeshift=100+getmode(abserror), grp.modelog=log10(grp.modeshift),
              grp.modeloge=log(grp.modeshift))
  mu
  mu$distance <- metarow$distance
  ## Create full data output CSV
  write.csv(mu,paste(basedir, "/", receiverdir, "-distance-analysis-" ,metarow$distance, ".csv", sep=""))
}
mu <- ddply(alldata, "initialBID", summarise, grp.var=var(abserror), 
            grp.mean=mean(abserror), grp.median=median(abserror), 
            grp.mode=getmode(abserror), grp.min=min(abserror), grp.max=max(abserror),
            grp.modeshift=100+getmode(abserror), grp.modelog=log10(grp.modeshift),
            grp.modeloge=log(grp.modeshift))
mu


## Create formal-accuracy report csv
write.csv(mu,paste(basedir, "/", receiverdir, "-formal-distance-summary.csv", sep=""))
