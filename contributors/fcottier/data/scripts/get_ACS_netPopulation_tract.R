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
census_api_key("8c27fe8ef7271e1999f37806659da0c9d17e5755")
mapdeck(token = "pk.eyJ1IjoiZmNvdHRpZXIiLCJhIjoiY2x5c3N0ZXM5MG5vYjJpb2c0MXc2YmNibiJ9.ZKsNGWDF7aYjK0fnLD57sQ")

# Data exploration

## get 2000 variable dictionary
dict <- tidycensus::load_variables(year = 2010, dataset = "acs5")
View(dict)


## TX test tract
tic()
plan(multisession)
test_tract <- foreach(year = 2009:2022, .combine = rbind) %dofuture% {
  tmp <- tidycensus::get_acs(
    geography = "tract",
    state = "TX",
    year = year,
    variables = c(Population = "B01003_001"), geometry = F, keep_geo_vars = F
  )
  tmp$year <- year
  return(tmp)
} %>% as_tibble()
toc()

# plot data for Harris county Texas
test_tract %>% 
  group_by(county = substr(GEOID, 1, 5), year) %>% 
  summarize(
    variable = first(variable),
    estimate = sum(estimate, na.rm = T),
    moe = tidycensus::moe_sum(moe, estimate, na.rm = T)
  ) %>% 
  dplyr::group_by(county) %>% 
  dplyr::mutate(popCH = estimate - lag(estimate)) %>% 
  dplyr::filter(county == 48339) %>% 
  ggplot() + geom_line(aes(x = year, y = popCH))



# extract population growth data 

## download population county data
yearList <- 2009:2022
stateList <- datasets::state.abb
mp_part <- expand.grid(state = stateList, year = yearList)
plan(multisession)

tic()
acs_pop_county <- foreach(year = yearList, .combine = rbind) %dofuture% {
  tmp <- tidycensus::get_acs(
    geography = "county",
    year = year,
    variables = c(Population = "B01003_001"), 
    geometry = F, keep_geo_vars = 
  )
  tmp$year <- year
  return(tmp)
} %>% as_tibble()
toc()
acs_pop_county

## download population tract data

tic()
acs_pop_tract <- foreach(i = 1:nrow(mp_part), .combine = rbind) %dofuture% {
  tmp <- tidycensus::get_acs(
    geography = "tract",
    state = mp_part$state[i],
    year =  mp_part$year[i],
    variables = c(Population = "B01003_001"), 
    geometry = F, keep_geo_vars = F,
  )
  tmp$year <- mp_part$year[i]
  return(tmp)
} %>% as_tibble()
toc()
acs_pop_tract 

# add FIPS code
acs_pop_tract <- acs_pop_tract %>% 
  dplyr::mutate(county_fips = substr(GEOID, 1, 5)) %>% 
  dplyr::left_join(tidycensus::fips_codes %>%  
    dplyr::mutate(county_fips = paste0(state_code, county_code))
  ) %>% 
  dplyr::select(GEOID, NAME, state_code, state, state_name, county_fips, county_code, county, variable, estimate, moe)

# save data
readr::write_rds(acs_pop_county, file = "processedData/acs_pop_county.Rds", compress = "gz")
readr::write_rds(acs_pop_tract, file = "processedData/acs_pop_tract.Rds", compress = "gz")

