# MIT License
# 
# Copyright (c) 2020 VMware Inc.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#   
#   The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Author Adam Fowler adamf@vmware.com adam@adamfowler.org

library(plyr)
library(chron)
library(ggplot2)
library(parsedate)
library(scales)
library(caTools)

# 1. Set the folder that contains a sub folder per phone in the test
basedir <- "~/Documents/git/skunkworks/test-data/2020-08-31-home-office-rc-03-copy"
# 2. Set the app name and version (for the chart titles)
appversion <- "rc-03"

# 3. (Optional) Time shift - If your protocol saves time in different time zones between mobile OS'
timeshift <- 0 * 60 * 60 # Actually in seconds for posix time. Time to ADD to log file times to match RSSI (normally exact hours)
# Set this wide by +/ 1 day until you figure out the right timeshift value

# 4. Set the test outer time to be a couple of minutes before you started setting up the first phone in the environment, until after the last phone was deactivated
filtertimemin <- as.POSIXct(paste("2020-08-31", "12:50:00"), format="%Y-%m-%d %H:%M:%S")
filtertimemin
filtertimemax <- as.POSIXct(paste("2020-08-31", "21:30:00"), format="%Y-%m-%d %H:%M:%S")
filtertimemax

# 5. For FORMAL statistical calculations, set the start time to be the time at which the LAST phone was introduced to the group (or removed from shielded sleeve)
#    Set the end time to be the time at which the FIRST phone was moved/had the app or BLE deactivated after the test
cestart <- as.POSIXct(paste("2020-08-31", "12:55:00"), format="%Y-%m-%d %H:%M:%S")
ceend <-   as.POSIXct(paste("2020-08-31", "21:15:00"), format="%Y-%m-%d %H:%M:%S")

# 6. Select all lines in this file, and click Run. After several minutes (for 8 hour tests) you will see charts and summary CSV appear in the above folder

# DO NOT EDIT BELOW THIS LINE

# time interval calcs
ceinterval <- "30 seconds" # for POSIXct cut
cetotal <- ceiling(as.numeric(difftime(ceend, cestart, units = "secs"), units="secs") / 30)
cetotal

## New as of cx-47 - build phones.csv from folder contents (detection.csv contents)
pcsv <- data.frame(matrix(ncol = 8, nrow=0))
names(pcsv) <- c("PhoneId","FolderName","Model","BroadcastId","OSVersion","AppVersion","OSType","Reserved")
  
dirs <- list.dirs(path = basedir, recursive = FALSE)
pcount <- 0
for (i in 1:length(dirs) ) {
  pcount <- pcount + 1
  dcsv <- read.table(paste(dirs[i] , "/detection.csv",sep=""),sep=",",header=FALSE, stringsAsFactors=FALSE)
  dcsv
  dcsv <- dcsv[c(1,2,3,4)]
  names(dcsv) = c("Model","OSType","OSVersion","initialBID") # Deliberately too short
  linecsv <- data.frame(matrix(ncol = 8, nrow=1))
  names(linecsv) <- c("PhoneId","FolderName","Model","BroadcastId","OSVersion","AppVersion","OSType","Reserved")
  linecsv$PhoneId <- pcount
  linecsv$FolderName <- dirs[i]
  linecsv$Model <- dcsv$Model
  linecsv$BroadcastId <- dcsv$initialBID
  linecsv$OSVersion <- dcsv$OSVersion
  linecsv$AppVersion <- appversion
  linecsv$OSType <- dcsv$OSType
  linecsv$Reserved <- ""
  pcsv <- rbind(pcsv,linecsv)
}
write.csv(pcsv,paste(basedir , "/phones.csv",sep=""))
pcsv
dcsv
linecsv


# Determine longevity window time filters
hour <- 1 * 60 * 60 # seconds for an hour
cehour <- 2 * 60 # 2 per minute, 60 minutes in an hour
longfirststart <- filtertimemin
longfirstend <- filtertimemin + hour
longsecondstart <- filtertimemax - hour
longsecondend <- filtertimemax


allmu <- data.frame(matrix(ncol = 3, nrow=0))
names(allmu) <- c("seenby","shortname","windows")

raw_to_initial_bid <- function(original) {
  bytes <- base64decode(original,"raw")
  bytes
  newbytes <- bytes[-c(1,2)]
  newbytes
  firstfew <- newbytes[c(1:8)]
  firstfew
  final <- base64encode(firstfew)
  final <- substr(final,1,6)
  final
}

all_raw_to_bids <- function(bids) {
  cnt <- length(bids)
  results <- c()
  for (i in 1:cnt) {
    bid <- bids[c(i)]
    results <- rbind(results,raw_to_initial_bid(bid))
  }
  results[c(1:cnt)]
}

# read phones.csv
phones <- read.table(paste(basedir , "/phones.csv",sep=""), sep=",",header = TRUE)
#head(phones)
# Add in short name for later ease of reference
phones$shortname <- paste(phones$PhoneId,"-",phones$Model,"-",phones$OSType,phones$OSVersion,sep=" ")
phones$initialBID <- phones$BroadcastId

phonescount <- dim(phones)[1]
phonescount


allbids <- data.frame(matrix(ncol = 1, nrow=0))
names(allbids) <- c("initialBID")

alldurations <- data.frame(matrix(ncol = 9, nrow = 0))
names(alldurations) <- c("shortname","rssis.total","observer")

allrawdurations <- data.frame(matrix(ncol = 5, nrow = 0))
names(allrawdurations) <- c("t","shortname","initialBID","observer","count")
allintervals <- data.frame(matrix(ncol = 2, nrow = 0))
names(allintervals) <- c("shortname","t")

allmu <- data.frame(matrix(ncol = 3, nrow=0))
names(allmu) <- c("seenby","finalname","windows")

# read each folder
for (i in 1:phonescount ) {
  # get i'th row
  thisphone <- phones[i,]
  thisphone
  thisshortname <- thisphone$shortname
  
  # pre-cx-47: thisdir <- paste(basedir,thisphone$PhoneId,sep="/") # PhoneId and NOT i!
  thisdir <- thisphone$FolderName
  thisdir
  
  print(paste("Processing folder",thisdir,"for phone",thisphone$shortname))
  
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
  
  # Copy over bids only
  
  print("Creating macuuid to bluetoothid data frame")
  ## create mac to ID to shortname lookup table
  mactobid <- dplyr::filter(csvdata,read==2)
  head(mactobid)
  mactobid <- dplyr::select(mactobid,c("id","data"))
  mactobid <- dplyr::distinct(mactobid)
  ## since cx-46 read==2 results in a CORRECT initialBID value in the data column
  # pre-cx-46
  #names(mactobid) <- c("macuuid","initialBID")
  #mactobid$initialBID <- all_raw_to_bids(mactobid$initialBID)
  # cx-46 and beyond
  names(mactobid) <- c("macuuid","data")
  mactobid$initialBID <- substr(mactobid$data,1,6)
  #head(mactobid)
  ## Now mix in phone info and select columns
  mactobid <- join(mactobid,phones,by="initialBID")
  mactobid <- subset(mactobid, select = c("macuuid","initialBID","shortname"))
  head(mactobid)
  
  
  print(" - Caching seen bluetooth IDs")
  csvBidsOnly <- subset(mactobid,select=c("initialBID"))
  csvBidsOnly <- dplyr::distinct(csvBidsOnly)
  csvBidsOnly
  
  allbids <- rbind(allbids, csvBidsOnly)
  
  ## Process for detection
  print(" - Finding detections")
  detections <- dplyr::filter(csvdata,detect==1)
  head(detections)
  detections <- dplyr::select(detections,c("time","id"))
  detections <- dplyr::distinct(detections)
  names(detections) <- c("time","macuuid")
  head(detections)
  detections <- join(detections,mactobid,by="macuuid")
  detections$t <- as.POSIXct(detections$time, format="%Y-%m-%d %H:%M:%S")
  
  detections$finalname = paste(detections$shortname, " - A. Discoveries",sep="")
  detections <- subset(detections, select = c("t","finalname"))
  detections$rt <- "A. Detections"
  head(detections)
  
  ## Process for read ID
  print(" - Finding read IDs")
  readid <- dplyr::filter(csvdata,read==2)
  head(readid)
  readid <- dplyr::select(readid,c("time","id"))
  readid <- dplyr::distinct(readid)
  names(readid) <- c("time","macuuid")
  head(readid)
  readid <- join(readid,mactobid,by="macuuid")
  readid$t <- as.POSIXct(readid$time, format="%Y-%m-%d %H:%M:%S")
  
  
  
  if (dim(readid)[1] > 0) {
    readid$finalname = paste(readid$shortname, " - E1. Broadcast ID Read",sep="")
    readid <- subset(readid, select = c("t","finalname"))
    readid$rt <- "E1. Broadcast ID Read"
    head(readid)
  }
  
  ## Process for read RSSI measurement
  print(" - Finding read RSSIs")
  rssi <- dplyr::filter(csvdata,measure==3)
  head(rssi)
  rssi <- dplyr::select(rssi,c("time","id","data"))
  rssi$rssi <- as.numeric(substr(rssi$data,7,9))
  names(rssi) <- c("time","macuuid","data","rssi")
  rssivalues <- dplyr::select(rssi,c("time","macuuid","rssi"))
  rssivalues <- join(rssivalues,mactobid,by="macuuid")
  rssivalues$t <- as.POSIXct(rssivalues$time, format="%Y-%m-%d %H:%M:%S")
  head(rssivalues)
  rssi <- dplyr::select(rssi,c("time","macuuid"))
  rssi <- dplyr::distinct(rssi)
  head(rssi)
  rssi <- join(rssi,mactobid,by="macuuid")
  rssi$t <- as.POSIXct(rssi$time, format="%Y-%m-%d %H:%M:%S")
  head(rssi)
  
  ## Process for ID written to us
  print(" - Finding IDs and RSSIs written to us (within the same write or calling card payload)")
  written <- dplyr::filter(csvdata,share==4)
  head(written)
  written <- dplyr::select(written,c("time","data"))
  written <- dplyr::distinct(written)
  names(written) <- c("time","initialBID")
  # NOTE: Data does NOT include more than one bluetooth ID per row
  head(written)
  head(mactobid)
  written <- join(written,mactobid,by="initialBID")
  written$t <- as.POSIXct(written$time, format="%Y-%m-%d %H:%M:%S")
  head(written)
  
  
  # Create intervals data pre-merge
  preintervals <- data.frame(matrix(ncol = 3, nrow = 0))
  names(preintervals) <- c("t","shortname")
  head(preintervals)
  # directly read RSSIs
  premerged <- subset(rssi, select=c("t","shortname"))
  preintervals <- rbind(preintervals, premerged)
  # written RSSIs
  prewritten <- subset(written, select=c("t","shortname"))
  preintervals <- rbind(preintervals, prewritten)
  
  print("Creating summary statistics")
  rssi <- dplyr::filter(rssi,t>=filtertimemin)
  rssi <- dplyr::filter(rssi,t<=filtertimemax)
  # Create summary statistics from the PList file HERE and output somewhere
  head(rssi)
  
  predur <- rssi
  if (dim(written)[1] > 0) {
    print(" - binding written data")
    predur <- rbind(rssi,written)
  }
  durations <- subset(predur,select=c("t","shortname","initialBID"))
  durations$observer <- thisshortname
  head(durations)
  
  # Summarise by mean, modal, median duration, count of contact events, per shortname seen
  durations$count <- 1
  du <- ddply(durations, "shortname", summarise, 
              rssis.total=sum(count)
  )
  du
  du$observer <- thisshortname
  
  print(" - binding allrawdurations")
  head(durations)
  allrawdurations <- rbind(allrawdurations,durations)
  print(" - binding alldurations")
  alldurations <- rbind(alldurations,du)
  head(alldurations)
  
  print(" - processing RSSI")
  if (dim(rssi)[1] > 0) {
    rssi$finalname = paste(rssi$shortname, " - C1. RSSIs",sep="")
    rssi <- subset(rssi, select = c("t","finalname"))
    rssi$rt <- "C1. RSSIs"
    head(rssi)
  }
  
  print(" - processing written")
  if (dim(written)[1] > 0) {
    written$finalname = paste(written$shortname, " - C2. Write ID with RSSI",sep="")
    written <- subset(written, select = c("t","finalname"))
    written$rt <- "C2. Write ID with RSSI"
    head(written)
  }
  
  #if (readrssilogsfull) {
  #  preread <- subset(readrssi, select = c("t","shortname"))
  #  preintervals <- rbind(preintervals,preread)
  #}
  #if (receivedwritesfull) {
  #  prewritten <- subset(receivedwrites, select = c("t","shortname"))
  #  preintervals <- rbind(preintervals, prewritten)
  #}
  #if (nearbyreadsconfirmedfull) {
  #  prenearby <- subset(nearbyallocated, select = c("t","shortname"))
  #  preintervals <- rbind(preintervals, prenearby)
  #}
  
  
  ## show each on chart
  
  print(" - Creating chart")
  
  # Merge
  all <- data.frame(matrix(ncol = 3, nrow = 0))
  names(all) <- c("t","finalname","rt")
  head(all)
  
  all <- rbind(all,detections,readid,rssi,written)
  
  all$t <- all$t + timeshift # seconds
  
  head(all)
  
  # General filtering
  all <- dplyr::filter(all,t>=filtertimemin)
  all <- dplyr::filter(all,t<=filtertimemax)
  
  # Plot
  p <- ggplot(all, aes(x=t, y=finalname, colour=rt)) +
    geom_point() + 
    ggtitle(paste("Phones seen by  ",thisshortname," over time",sep="") ) + 
    theme(legend.position = "bottom", legend.box = "vertical") +
    labs(color = "Operation") +
    xlab("Time") + ylab("Phone & Operation") +
    scale_x_datetime(date_breaks = "60 min", date_minor_breaks = "10 min")
    #scale_x_datetime(date_breaks = "10 min", date_minor_breaks = "2 min")
  p
  ggsave(paste(thisdir, "-report.png",sep=""), width = 600, height = 300, units = "mm")
  
  ## now plot RSSI values over time
  rssivalues <- dplyr::filter(rssivalues,t>=cestart)
  rssivalues <- dplyr::filter(rssivalues,t<=ceend)
  # Plot
  p <- ggplot(rssivalues, aes(x=t, y=rssi, colour=initialBID)) +
    geom_point() + 
    ggtitle(paste("Distance Analogue seen by  ",thisshortname," over time",sep="") ) + 
    theme(legend.position = "bottom", legend.box = "vertical") +
    labs(color = "Operation") +
    xlab("Time") + ylab("Phone & Operation") +
    scale_x_datetime(date_breaks = "60 min", date_minor_breaks = "10 min")
    #scale_x_datetime(date_breaks = "1 min", date_minor_breaks = "10 secs")
  p
  ggsave(paste(thisdir, "-accuracy.png",sep=""), width = 600, height = 300, units = "mm")
  write.csv(rssivalues,paste(thisdir , "-formal-distance-values.csv",sep=""))
  
  ## Perform per-phone formal continuity calculations
  
  # create this phone's contact event continuity summary per phone seen and save for final totals
  print(" - Creating formal evaulation for this phone")
  intervals <- dplyr::filter(preintervals,t>=cestart)
  intervals <- dplyr::filter(intervals,t<=ceend)
  intervals <- dplyr::filter(intervals,shortname != "Unknown without name")
  intervals <- dplyr::filter(intervals,shortname != thisshortname)
  thisshortname
  head(intervals)
  allintervals <- rbind(allintervals,intervals)
  if (dim(intervals)[1] > 0) {
    intervals$tc <- cut(intervals$t, breaks = "30 secs")
    head(intervals)
    # Now summarise by count
    intervals <- dplyr::count(intervals,shortname,tc)
    #head(intervals)
    # Now group by finalname (phones seen) by sum of those whose count > 0
    intervals$nboolean <- 1
    mu <- ddply(intervals, "shortname", summarise,  windows=sum(nboolean))
    mu$seenby <- thisshortname
  } else {
    mu <- data.frame(matrix(ncol = 3, nrow = 0))
    names(all) <- c("shortname","windows","seenby")
  }
  mu
  allmu
  allmu <- rbind(allmu,mu)
}

print("Creating formal test summary")
finalmu <- allmu
finalmu$scorepct <- 100 * finalmu$windows / cetotal
finalmu$deltacewindowspct <- 100 - finalmu$scorepct
write.csv(finalmu,paste(basedir , "/formal-continuity.csv",sep=""))

formaltotals <- data.frame(matrix(ncol = 8, nrow = 1))
names(formaltotals) <- c("phonescount","maxpairs","achieveddetections","detectionpct","maxwindows","achievedwindows","deltacewindowspct","longevity")
nnminusone <- phonescount * (phonescount - 1)
formaltotals$phonescount <- phonescount
formaltotals$maxpairs <- nnminusone
formaltotals$achieveddetections <- 0
formaltotals$detectionpct <- 0
formaltotals$maxwindows <- nnminusone * cetotal
formaltotals$achievedwindows <- sum(finalmu$windows)
formaltotals$deltacewindowspct <- 100 * (1.0 - (sum(finalmu$windows) / (nnminusone * cetotal))) # possible to be v. slightly negative - if the end/start of windows do not align per device
formaltotals$longevity <- 0

# TODO other formal analyses here


# Save all BluetoothIDs seen
allbids <- dplyr::distinct(allbids)
write.csv(allbids,paste(basedir , "/info-broadcast-ids-seen.csv",sep=""))

## Create pairwise summary

if (nrow(alldurations) > 0) {
  # Pairings now
  pairings <- subset(alldurations,select=c("shortname","observer"))
  pairings <- dplyr::distinct(pairings)
  names(pairings) <- c("observed","observer")
  phones
  for (pairi in 1:nrow(pairings)) {
    shortindex = which(phones[,6] == pairings[pairi,]$observer, arr.ind=TRUE)
    shortindex
    if (length(shortindex) > 0) {
      pairings[pairi,]$observeros <- phones[shortindex,6]
    }
  }
  pairings
  pairingtable <- data.frame(matrix(ncol=phonescount+1,nrow=0))
  paircols <- c("observer",phones$shortname)
  names(pairingtable) <- paircols
  head(pairingtable)
  # initial observer column
  for (pi in 1:phonescount) {
    ph <- phones[pi,]
    nr <- data.frame(matrix(ncol=phonescount+1,nrow=1))
    names(nr) <- paircols
    nr$observer <- ph$shortname
    pairingtable <- rbind(pairingtable,nr)
  }
  pairingtable
  # Now loop over pairings
  foundcount <- 0
  for (pri in 1:nrow(pairings)) {
    pair <- pairings[pri,]
    pair
    # select row with correct observer and column with correct observed
    # put a TRUE in the right square
    rnum <- which(pairingtable[,1] == pair$observer, arr.ind=TRUE)
    cnum <- 1 + which(pairingtable[,1] == pair$observed, arr.ind=TRUE)
    rnum
    cnum
    if (length(cnum > 0)) {
      if (cnum > 1 & rnum > 0) {
        if ((cnum - 1) != rnum) {
          pairingtable[rnum,cnum] <- TRUE
          foundcount <- foundcount + 1
        }
      }
    }
  }
  formaltotals$achieveddetections <- foundcount
  formaltotals$detectionpct <- 100 * (foundcount / nnminusone)
  pairingtable
  write.csv(pairingtable,paste(basedir , "/summary-discovery-pairs.csv",sep=""))
  
}

# Longevity measures
cehourtotal <- cehour * nnminusone # Max windows to find per hour
windowsstart <- 0
windowsend <- 0
head(allintervals)
if (nrow(allintervals) > 0) {
  # Filter two hour long time windows
  firstdurations <- dplyr::filter(allintervals,t>=longfirststart)
  firstdurations <- dplyr::filter(firstdurations,t<=longfirstend)
  seconddurations <- dplyr::filter(allintervals,t>=longsecondstart)
  seconddurations <- dplyr::filter(seconddurations,t<=longsecondend)
  
  firstdurations$tc <- cut(firstdurations$t, breaks = "30 secs")
  head(firstdurations)
  # Now summarise by count
  firstdurations <- dplyr::count(firstdurations,shortname,tc)
  head(firstdurations)
  # Now group by finalname (phones seen) by sum of those whose count > 0
  firstdurations$nboolean <- 1
  sum(firstdurations$nboolean)
  
  seconddurations$tc <- cut(seconddurations$t, breaks = "30 secs")
  head(seconddurations)
  # Now summarise by count
  seconddurations <- dplyr::count(seconddurations,shortname,tc)
  head(seconddurations)
  # Now group by finalname (phones seen) by sum of those whose count > 0
  seconddurations$nboolean <- 1
  
  # Calculate windows hit
  head(firstdurations)
  head(seconddurations)
  windowsstart <- sum(firstdurations$nboolean)
  windowsend <- sum(seconddurations$nboolean)
}
errwindowsstart <- 100.0 * (1.0 - (windowsstart / cehourtotal))
errwindowsend <- 100.0 * (1.0 - (windowsend / cehourtotal))
head(cehourtotal)
head(windowsstart)
head(windowsend)
head(errwindowsstart)
head(errwindowsend)
formaltotals$longevity <- abs(errwindowsstart - errwindowsend)

# write out formal results
write.csv(formaltotals,paste(basedir , "/formal-summary.csv",sep=""))
