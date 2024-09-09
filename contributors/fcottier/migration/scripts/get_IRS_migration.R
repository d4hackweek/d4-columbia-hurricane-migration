# Fabien Cottier, D4 HACK
# Summer 2024

# setup

## librarieslibrary(tidyverse)
library(foreach)
library(doFuture)
library(countrycode)
library(tictoc)
library(mapdeck)

## census API and mapdeck keys 
source("../api keys/keys.R")

# extract IRS data

## extract zip file
yearList <- 2011:2021

plan(multisession)
foreach (i = yearList) %dofuture% {
  cat(i)
  year <- as.integer(substring(i, 3, 4))
  url <- paste0("https://www.irs.gov/pub/irs-soi/",year,year+1,"migrationdata.zip")
  fPath <- paste0("./rawDatasets/",year, year+1,"migrationdata.zip")
  dirPath <- paste0("./rawDatasets/",year, year+1,"migrationdata")
  download.file(url, destfile = fPath)
  unzip(zipfile = fPath, exdir = dirPath)
  return(i)
}

## assemble county-to-county table into single out-flow dataset
tic()
US_irs_migration <- foreach (i = yearList, .combine=rbind) %dofuture% {
  year <- as.integer(substring(i, 3, 4))
  fPath <- paste0("./rawData/",year, year+1,"migrationdata/countyoutflow", year, year+1,".csv")
  f <- readr::read_csv(file = fPath)
  f$year <- i
  return(f)
}
toc()

## export data
readr::write_rds(US_irs_migration, file = "processedData/irs_migration_county.Rds", compress = "gz")


# data inspection


# preliminary exploration of the data
US_irs_migration_y <- US_irs_migration %>% 
  filter(y1_statefips == y2_statefips, y1_countyfips != y2_countyfips ) %>% 
  group_by(year) %>% 
  summarise(
    migr = sum(n2, na.rm=T))


# plot annual change
ggplot(US_irs_migration_y, aes(x = year, y=migr/1e6)) + 
  geom_line() + geom_point() + 
  scale_x_continuous(breaks=2010:2021) +
  xlab(NULL) + ylab("Million migrants")
