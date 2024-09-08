# Fabien Cottier, D4 HACK
# Summer 2024

# setup

## libraries
library(tidyverse)
library(foreach)
library(doFuture)
library(countrycode)
library(tidycensus)
library(tigris)
library(units)
library(tictoc)

# find tracts within 200 miles of coast lines 

## get geography
tracts <- tigris::tracts(cb = T, year = 2020)
counties <- tigris::counties(cb = T, year = 2020)
coastLines <- tigris::coastline(year = 2020) %>% 
  dplyr::filter(NAME %in% c("Atlantic", "Caribbean", "Gulf"))
coastLines <- sf::st_union(coastLines)


## get counties (and tracts) within 250km of coastlines
distThreshold <- units::set_units(250000, "m") 
counties$distW <- sf::st_is_within_distance(counties, coastLines, dist = distThreshold, sparse = F)[,1]
countyList <- dplyr::filter(counties, distW==T) %>% pull(GEOID)

tracts <- tracts %>% 
  dplyr::mutate(
    distW = if_else(substr(GEOID, 1, 5) %in% countyList, TRUE, FALSE)
  )
ggplot(dplyr::filter(counties, distW==TRUE)) + geom_sf(aes(fill=distW))
ggplot(dplyr::filter(tracts, distW==TRUE)) + geom_sf(aes(fill=distW))

## keep only counties / tracts within distance threshold
counties <- counties %>% dplyr::filter(distW == T) %>% select(-distW)
tracts <- tracts %>% dplyr::filter(distW == T) %>% select(-distW)

## get data set without geometry
counties_noGeom <- sf::st_drop_geometry(counties)
tracts_noGeom <- sf::st_drop_geometry(tracts)

## export data
readr::write_csv(counties_noGeom, file = "processedData/counties_200km.csv")
readr::write_csv(tracts_noGeom, file = "processedData/tracts_200km.csv")
readr::write_rds(counties, file = "processedData/counties_200km.rds", compress = "gz")
readr::write_rds(tracts, file = "processedData/tracts_200km.rds", compress = "gz")
