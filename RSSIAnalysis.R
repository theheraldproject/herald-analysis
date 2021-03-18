# Apache 2.0 licensed
# 
# Copyright (c) 2020-2021 Herald Project Contributors
# 

# Author Adam Fowler adamf@vmware.com adam@adamfowler.org
# File originally in the herald-calibration project but copied here to be used for reference data analysis

library(plyr)
library(dplyr)
library(readr)
library(ggplot2)
library(ggpubr)
library(chron)
library(parsedate)
library(scales)
library(caTools)

# 1. Set the folder within which you have a set of CSVs, one recorded for each distance. This should be for one phone of the pair only, not both
basedir <- "/Volumes/TB3-1/git/skunkworks/herald-analysis/reference-data/rssi-raw-edison"

# 2. Set the ID number (as a STRING) of the test you wish to generate charts for (It'll generate charts for both devices under test)
ourtestid <- "26"

# 3. Do 'select all' and click 'run' in R studio. Download any extensions, if prompted.
# 4. After a few seconds you'll see output charts generated in the above folder

# DO NOT EDIT BELOW THIS LINE
outputdir <- paste(basedir , "/output",sep="")

# Load tests metadata file metadata.csv
metadata <- read.table(paste(basedir , "/metadata.csv",sep=""),sep=",",header=TRUE, stringsAsFactors=FALSE)
# Retrieve our test's data
testmeta <- dplyr::filter(metadata,testid==ourtestid)
# Run script for phone b in that test
#fields <- subset(testmeta, select = c("testid","date","phonebname","distfrom","distto","diststep","durationmins","filenamephoneb"))
# Receiver (rec) is phone B for now
#names(fields) <- c("testid","date","name","distfrom","distto","diststep","durationmins","filename")

# mix in phoneb's metadata from phones.csv
phones <- read.table(paste(basedir , "/phones.csv",sep=""),sep=",",header=TRUE, stringsAsFactors=FALSE)
names(phones) <- c("phonebname","model","os","osversion","notes")
enriched <- join(testmeta,phones,by="phonebname")
# we now have fields: testid,date,phoneaname,phonebname,distfrom,distto,diststep,durationmins,filenamephonea,filenamephoneb AND model,os,osversion,notes
names(enriched) <- c("testid","date","phoneaname","recname","distfrom","distto","diststep","durationmins","filenamephonea","filenamephoneb","recmodel","recosname","recosver","recnotes")

# now mix in phone A's metadata
phones <- read.table(paste(basedir , "/phones.csv",sep=""),sep=",",header=TRUE, stringsAsFactors=FALSE)
names(phones) <- c("phoneaname","model","os","osversion","notes")
enriched <- join(enriched,phones,by="phoneaname")
names(enriched) <- c("testid","date","name","recname","distfrom","distto","diststep","durationmins","filename","recfilename",
                     "recmodel","recosname","recosver","recnotes",
                     "model","osname","osver","notes")

# Now we can finally load the data from the test
rundata <- read.table(paste(basedir , "/", enriched$recfilename,sep=""),sep=",",header=TRUE, stringsAsFactors=FALSE)
head(rundata)
# time (YYYY-MM-DD HH:mm:ss), rssi, distance (cm)
# And mix in the metadata
basedata <- rundata
basedata$model <- enriched$model
basedata$osname <- enriched$osname
basedata$osver <- enriched$osver
basedata$recmodel <- enriched$recmodel
basedata$recosname <- enriched$recosname
basedata$recosver <- enriched$recosver

# Convert from cm to metres!
basedata$distance <- 0.01 * basedata$distance

# Push distance of 0 to slightly higher due to log math
#basedata[basedata$distance == "0", "distance"] <- "0.00001"

# filter distance = 0 instead
basedata <- filter(basedata, distance!="0")

# hardcoded unknown values
basedata$txpower <- 1
basedata$rxpower <- 1
basedata$yourtxpower <- 1



# now we have the same data as the previous script's format - so just run it

#basedata <- data.frame(matrix(ncol = 11, nrow=0))
#names(basedata) <- c("distance","rssi","model","osname","osver","txpower","rxpower","yourtxpower","recmodel","recosname","recosver")
#list_file <- list.files(pattern="*.csv")
#for (i in 1:length(list_file) ) {
#  filerows <- read.table(paste(list_file[i] ,sep=""),sep=",",header=TRUE, stringsAsFactors=FALSE)
#  basedata <- rbind(basedata,filerows)
#}
#head(basedata)
#tail(basedata)

#summary(basedata)

# EXAMPLE: Filter out of band rssi - FIX not doing this now. Doesn't appear in calibration results.
#filter<-c(-90:100)
#basedata = subset(basedata, rssi %in% filter)
#head(basedata)
# EXAMPLE: Filter 0.1m
##filter<-c(0.1)
##basedata = subset(basedata, !distance %in% filter)

# convert distance to a factor variable
attach(basedata)
basedata <- basedata[order(distance),]
basedata$distance <- as.factor(basedata$distance)
basedata$seq <- seq.int(nrow(basedata))

# Try converting RSSI to the Cube of RSSI
#basedata$rssi <- (basedata$rssi/20.0)**3

getmode <- function(v) {
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

# PRE PROCESSING OF DATA - RAW VALUE PRINT OUTS

# Plot reading number (sequence number) by RSSI
#deseq <- ggplot(basedata, aes(x=seq, y=rssi, color=distance)) +
#  geom_point() +
#  labs(x="Sequence Number", y="RSSI", 
#       title="RSSI over time at each distance") + 
#  theme(legend.position = "bottom")
##deseq
#ggsave(paste(basedir,"/output/",ourtestid,"-","phoneb-rssi-sequence.png", sep=""))

# Raw data per distance bound - RSSI frequencies


# now need to recalculate summary stats for plots to be drawn correctly
mu <- ddply(basedata, "distance", summarise, grp.var=var(rssi), 
            grp.mean=mean(rssi), grp.median=median(rssi), 
            grp.mode=getmode(rssi), grp.min=min(rssi), grp.max=max(rssi),
            grp.modeshift=100+getmode(rssi), grp.modelog=log10(grp.modeshift),
            grp.modeloge=log(grp.modeshift))
#mu
mu$distnumeric <- as.numeric(levels(mu$distance))[mu$distance]
mu$distsq <- mu$distnumeric * mu$distnumeric

# Output raw summary
write.csv(mu,paste(basedir,"/output/",ourtestid,"-","phoneb-summary-raw.csv", sep=""))

# determine the ideal chart size - raw and distribution charts
uniqueDistances <- as.data.frame.factor(unique(mu$distance))
names(uniqueDistances) <- c("uniqdistance")
#uniqueDistances
numUniqueDistances <- NROW(uniqueDistances)
#numUniqueDistances
# Check for very large nrows (i.e. readings < 10cm distance)
#everyXMu <- mu
#everyXBase <- basedata
#if (numUniqueDistances > 96) {
#  seq(1, numUniqueDistances, 10)
#  uniqueDistances <- dplyr::filter(uniqueDistances, row_number() %% 5 == 1)
#  numUniqueDistances <- NROW(uniqueDistances)
#  numUniqueDistances
#  # now filter source data by these distances
#  everyXMu <- dplyr::filter(mu,mu$distance %in% uniqueDistances$uniqdistance)
#  everyXBase <- dplyr::filter(basedata,basedata$distance %in% uniqueDistances$uniqdistance)
#}
numCols <- 8
numRows <- ceiling(numUniqueDistances / numCols)
if (numRows < 1) {
  numRows <- 1
}
chartWidth <- 300
chartHeight <- ceiling(numRows/6)*150
if (chartHeight > 1200) {
  chartHeight <- 1250
}
#uniqueDistancesAgain <- as.data.frame.factor(unique(everyXMu$distance))
#names(uniqueDistancesAgain) <- c("uniqdistance")
#numUniqueDistancesAgain <- NROW(uniqueDistancesAgain)
#numUniqueDistancesAgain
#uniqueDistancesAgain
#uniqueDistances
#numCols
#numRows
#chartWidth
#chartHeight

p <- ggplot(basedata, aes(x=rssi , y=..density.. , color=distance, fill=distance)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend=T) +
  geom_density(alpha=0.3, fill=NA, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.mean), color="orange", linetype="dashed", size=1, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.max), color="black", linetype="solid", size=0.5, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.min), color="black", linetype="solid", size=0.5, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.mean + sqrt(mu$grp.var)), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.mean - sqrt(mu$grp.var)), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.mean + 2*sqrt(mu$grp.var)), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.mean - 2*sqrt(mu$grp.var)), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.mean + 3*sqrt(mu$grp.var)), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.mean - 3*sqrt(mu$grp.var)), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  facet_wrap(~distance, ncol=numCols, nrow=numRows, scales="free") +
  labs(x="RSSI values with mean shown and 3 SDs plotted",
       y="Relative density of population",
       title="RSSI population distribution by distance",
       subtitle="No outliers have been removed. Orange line is the mean value.")  + 
  theme(legend.position = "none")
#p
ggsave(paste(basedir,"/output/",ourtestid,"-","phoneb-distance-raw.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")



# Plot SD by raw distance to see if there's a trend
desd <- ggplot(mu, aes(x=distnumeric, y=sqrt(grp.var), color=3)) +
  geom_point() +
  stat_cor(label.x = 1, label.y = 0.3) + 
  stat_regline_equation(label.x = 1, label.y = 0.1) +
  geom_smooth(method=lm) +
  labs(x="Distance (meters)", y="Standard Deviation", 
       title="Distance's effect on standard deviation of RSSI",
       subtitle="Meters and RSSI") + 
  theme(legend.position = "none")
#desd
ggsave(paste(basedir,"/output/",ourtestid,"-","phoneb-distance-effects-sd.png", sep=""))

# Plot Mean RSSI by distance
demean <- ggplot(mu, aes(x=distnumeric, y=grp.mean, color=4)) +
  geom_point() +
  geom_errorbar(aes(ymin=grp.mean-sqrt(grp.var), ymax=grp.mean+sqrt(grp.var)), 
                width=.05, position=position_dodge(.9)) +
  stat_cor(label.x = 1, label.y = -40) + 
  stat_regline_equation(label.x = 1, label.y = -42) +
  geom_smooth(method=lm) +
  labs(x="Distance (meters)", y="Mean RSSI", 
       title="Regression for Mean RSSI to distance (m)",
       subtitle="Errors bars show +/- 1 standard deviation from mean") + 
  theme(legend.position = "none")
#demean
ggsave(paste(basedir,"/output/",ourtestid,"-","phoneb-distance-effects-mean-sd.png", sep=""))

# Plot mean by distance squared
desquare <- ggplot(mu, aes(x=distsq, y=grp.mean, color=4)) +
  geom_point() +
  geom_errorbar(aes(ymin=grp.mean-sqrt(grp.var), ymax=grp.mean+sqrt(grp.var)), 
                width=.05, position=position_dodge(.9)) +
  stat_cor(label.x = 1, label.y = -70) + 
  stat_regline_equation(label.x = 1, label.y = -72) +
  geom_smooth(method=lm) +
  labs(x="Distance squared (meters)", y="Mean RSSI", 
       title="Regression for Mean RSSI to distance squared(m)") + 
  theme(legend.position = "none")
#desquare
ggsave(paste(basedir,"/output/",ourtestid,"-","phoneb-distance-effects-squared.png", sep=""))






mu <- ddply(basedata, "distance", summarise, grp.var=var(rssi), 
            grp.mean=mean(rssi), grp.median=median(rssi), 
            grp.mode=getmode(rssi), grp.min=min(rssi), grp.max=max(rssi),
            grp.modeshift=100+getmode(rssi), grp.modelog=log10(grp.modeshift),
            grp.modeloge=log(grp.modeshift))
#mu

# filter each data set by std dev
for (d in mu$distance) {
  idx = which(mu$distance == d)
  #write(d,stdout())
  #write(idx,stdout())
  #write(length(basedata$rssi),stdout())
  minRssi = mu$grp.median[idx] - 3*sqrt(mu$grp.var[idx])
  maxRssi = mu$grp.median[idx] + 3*sqrt(mu$grp.var[idx])
  #write(minRssi,stdout())
  #write(maxRssi,stdout())
  basedata = subset(basedata, !distance %in% d | (rssi >= minRssi & rssi <= maxRssi))
  #write(length(basedata$rssi),stdout())
  #write("----",stdout())
}


# Creates multiple plots by distance
p <- ggplot(basedata, aes(x=rssi , y=..density.. , color=distance, fill=distance)) +
  geom_histogram(alpha=0.5, binwidth=1, show.legend=T) +
  geom_density(alpha=0.3, fill=NA, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.mode), color="orange", linetype="dashed", size=1, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.max), color="black", linetype="solid", size=0.5, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.min), color="black", linetype="solid", size=0.5, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.mode + sqrt(mu$grp.var)), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.mode - sqrt(mu$grp.var)), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.mode + 2*sqrt(mu$grp.var)), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.mode - 2*sqrt(mu$grp.var)), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.mode + 3*sqrt(mu$grp.var)), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  geom_vline(data=mu, aes(xintercept=mu$grp.mode - 3*sqrt(mu$grp.var)), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  facet_wrap(~distance, ncol=numCols, nrow=numRows, scales="free") +
  labs(x="RSSI values within 3 std devs of original data",
       y="Relative density of population",
       title="RSSI population distribution by distance",
       subtitle="Outliers beyond 3 standard deviations have been removed")  + 
  theme(legend.position = "none")
#p
ggsave(paste(basedir,"/output/",ourtestid,"-","phoneb-distribution.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

# Now figure out the regression line - RSSI drops off logarithmically with distance
mu$distnumeric <- as.numeric(levels(mu$distance))[mu$distance]
mu$distlog10 <- log10(mu$distnumeric)
mu$distloge <- log(mu$distnumeric)

# Output filtered summary
write.csv(mu,paste(basedir,"/output/",ourtestid,"-","phoneb-summary-filtered.csv", sep=""))

#mu
rplot <- ggplot(mu, aes(x=distlog10, y=grp.mode, color=3)) +
  geom_point() +
  geom_errorbar(aes(ymin=grp.mode-sqrt(grp.var), ymax=grp.mode+sqrt(grp.var)), 
                width=.05, position=position_dodge(.9)) +
  stat_cor(label.x = -0.4, label.y = -50) + 
  stat_regline_equation(label.x = -0.4, label.y = -52) +
  geom_smooth(method=lm) +
  labs(x="log10 of Distance (meters)", y="Modal RSSI", 
       title="Regression for Modal RSSI to log10 of distance (m)",
       subtitle="Errors bars show 1 standard deviation from mode") + 
  theme(legend.position = "none")
#rplot
ggsave(paste(basedir,"/output/",ourtestid,"-","phoneb-regression.png", sep=""))

# R number almost -1 because we're using mode and not mean
#  - See http://www.fairlynerdy.com/what-is-r-squared/
# Very low p number means a good fit
#  - See Anderson, Faye. (2016). Re: What is the relationship between R-squared and p-value in a regression?. Retrieved from: https://www.researchgate.net/post/What_is_the_relationship_between_R-squared_and_p-value_in_a_regression/57612faddc332d362552c5f1/citation/download. 

write("done",stdout())