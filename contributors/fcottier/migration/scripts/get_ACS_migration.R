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
library(tictoc)
library(mapdeck)

## docs
# ACSmigration flows
#  https://www.census.gov/data/developers/data-sets/acs-migration-flows.2021.html#list-tab-189383790
# using tidycensus for acs flows
#   https://walker-data.com/tidycensus/articles/other-datasets.html

## census API and mapdeck keys 
source("../api keys/keys.R")


## functions
get_acsMigrationNY <- function(year, geometry = FALSE){
  tidycensus::get_flows(
    geography = "county",
    state = "NY",
    year = year,
    geometry = geometry
  )
}
get_acsMigration <- function(partition = i, geometry = FALSE) {
  tidycensus::get_flows(
    geography = "county",
    state = mp_part$state[partition],
    year = mp_part$year[partition],
    geometry = geometry
  )
}


# script test

## county-to-county New York
tic()
test_cnty <- get_flows(
  geography = "county",
  state = "NY",
  county = "Westchester",
  year = 2018 # available up to 2021; 2021 only county-to-state
)
toc()


## county subdivision # only 12 states with county subdivioms. the rest county
tic()
test_suvcounty <- get_flows(
  geography = "county subdivision",
  state = "NY",
  county = "Westchester",
  year = 2010
)
toc()

## mapdeck visualization
test_msa_geom <- phx_flows <- get_flows(
  geography = "metropolitan statistical area",
  msa = 38060,
  year = 2018,
  geometry = TRUE
)

top_move_in <- test_msa_geom %>% 
  filter(!is.na(GEOID2), variable == "MOVEDIN") %>% 
  slice_max(n = 25, order_by = estimate) %>% 
  mutate(
    width = estimate / 500,
    tooltip = paste0(
      scales::comma(estimate * 5, 1),
      " people moved from ", str_remove(FULL2_NAME, "county"),
      " to ", str_remove(FULL1_NAME, "county"), " between 2014 and 2018"
    )
  )

top_move_in %>% 
  mapdeck(style = mapdeck_style("dark"), pitch = 45) %>% 
  add_arc(
    origin = "centroid1",
    destination = "centroid2",
    stroke_width = "width",
    auto_highlight = TRUE,
    highlight_colour = "#8c43facc",
    tooltip = "tooltip"
  )


# extract county to county data

# parameters
yearList <- 2010:2021 # available from 2010 to 2021
stateList <- datasets::state.abb
mp_part <- expand.grid(state = stateList, year = yearList)
plan(multisession)


## New York test all counties

tic()
NY_migration <- foreach (i = yearList, .combine=rbind) %dofuture% {
  require(tidyverse, tidycensus)
  f <- get_acsMigrationNY(year = i)
  f$year <- i
  return(f)
}
toc()


## All states
tic()
US_acs_migration <- foreach (i = 1:nrow(mp_part), .combine=rbind) %dofuture% {
  require(tidyverse, tidycensus)
  f <- get_acsMigration(partition = i)
  f$year <- mp_part$year[i]
  return(f)
}
toc()
US_acs_migration 


## export data
readr::write_rds(US_acs_migration, file = "rawDatasets/acs5y_migration_county.Rds", compress = "gz")


# data inspection

## preliminary exploration of the data
US_acs_migration_y <- US_acs_migration %>% 
  filter(variable == "MOVEDOUT") %>% 
  group_by(year) %>% 
  summarise(
    migr = sum(estimate, na.rm=T),
    moe = moe_sum(moe, estimate = estimate, na.rm = TRUE))
# summing moe; see https://walker-data.com/tidycensus/articles/margins-of-error.html

## plot annual change
ggplot(US_acs_migration_y, aes(x = year, y=migr/1e6)) + 
  geom_line() + geom_point() + 
  scale_x_continuous(breaks=2010:2020) +
  xlab(NULL) + ylab("Million migrants")

## plot annual change with confidence band
ggplot(US_acs_migration_y, aes(x = year, y=migr/1e6)) + 
  geom_line() + geom_errorbar(aes(ymin = (migr-moe)/1e6, ymax = (migr+moe)/1e6)) + geom_point() + 
  scale_x_continuous(breaks=2010:2020) +
  xlab(NULL) + ylab("Million migrants")
