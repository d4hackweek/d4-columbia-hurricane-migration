# libraries
library(tidyverse)
library(readxl)
library(tidycensus)
library(tigris)
library(glue)
library(doFuture)
library(foreach)

# read function()
fileRead <- function(fpath, storm, state, type = "Res") {
  files <- list.files(
    glue::glue("{fpath}/{storm}/{state}"),
    pattern = glue::glue("{type}"),
    ignore.case = TRUE)
  dplyr::bind_rows(lapply(
    files,
    function(x)
    readxl::read_excel(glue::glue("{fpath}/{storm}/{state}/{x}"))
  ))
}

# setup

## list of storms
fpath <- "contributors/mhemmati/Storm_Analysis_Results"
storm_df <- readr::read_csv(glue("{fpath}/stormList.csv"))

## remove Jeanne // absent from the damage data
storm_df <- storm_df %>% 
  dplyr::filter(name != "Jeanne")
stormList <- storm_df$name

## Notes of duplicates
#   - Rita TX: files_1 subset of files_2 (appears to be the same data; based on column EDU, RES,COM)
#   - Wilma FL (3 copies) is not a duplicate
#   - Irma FL (2 copies) is not a duplicate

# loop through files and assemble residential damage loss datasets

## Residential damage loss
plan(multisession)
resLoss <- foreach(storm = stormList, .combine = rbind) %dofuture% {

  # params
  stateList <- list.dirs(glue::glue("{fpath}/{storm}"), recursive = F, full.names = F)
  year <- storm_df$year[storm_df$name == storm]
  month <- storm_df$month[storm_df$name == storm]

  ## load residential damage data
  dat <- dplyr::bind_rows(
    lapply(
      stateList, 
      function(state)
        fileRead(fpath, storm, state)
        #readxl::read_excel(glue("{fpath}/{storm}/{i}/RES_Loss.xlsx"))
    ))
  ## compute total damage without the relocation cost
  dat <- dat |> 
    dplyr::rename("GEOID" = `Census Tract`) |>
    dplyr::mutate(
      GEOID = stringr::str_pad(as.character(GEOID), 11, "left", 0)
    ) |> 
    dplyr::rowwise() |> 
    dplyr::mutate(
      storm = storm,
      fips = stringr::str_sub(GEOID, 1, 5),
      TotalResLoss = 1000*sum(dplyr::c_across(Building:Wage), na.rm = T) - `Relocation Cost`,
      Building = 1000*Building 
    ) |> 
    dplyr::ungroup() |> 
    dplyr::select(storm, GEOID, fips, TotalResLoss, Building) |> 
    dplyr::rename("BuildingLoss" = Building)
  
  ## aggregate by county
  datCounty <- dat |> 
    dplyr::group_by(fips) |> 
    dplyr::summarize(
      TotalResLoss = sum(TotalResLoss, na.rm = T),
      BuildingLoss = sum(BuildingLoss, na.rm = T),
    ) |> 
    dplyr::ungroup() |>
    dplyr::mutate(
      storm = storm,
      year = year,
      month = month
    ) |>
    dplyr::select(storm, year, month, fips, TotalResLoss, BuildingLoss)

  return(datCounty)
} %globals% c("fpath", "storm_df", "fileRead") %seed% TRUE 


## Employment loss
plan(multisession)
empLoss <- foreach(storm = stormList, .combine = rbind) %dofuture% {

  # params
  stateList <- list.dirs(glue::glue("{fpath}/{storm}"), recursive = F, full.names = F)
  year <- storm_df$year[storm_df$name == storm]
  month <- storm_df$month[storm_df$name == storm]

  ## load residential damage data
  dat <- dplyr::bind_rows(
    lapply(
      stateList, 
      function(state)
        fileRead(fpath, storm, state, type = "Emp")
        #readxl::read_excel(glue("{fpath}/{storm}/{i}/Employement_Loss.xlsx"))
    ))
  ## compute total damage without the relocation cost
  dat <- dat |> 
    dplyr::rename("GEOID" = `Census Tract`) |>
    dplyr::mutate(
      GEOID = stringr::str_pad(as.character(GEOID), 11, "left", 0)
    ) |> 
    dplyr::rowwise() |> 
    dplyr::mutate(
      storm = storm,
      fips = stringr::str_sub(GEOID, 1, 5),
      EmpLoss = 1000*sum(dplyr::c_across(RES:EDU), na.rm = T)
    ) |> 
    dplyr::ungroup() |> 
    dplyr::select(storm, GEOID, fips, EmpLoss) 
  
  ## aggregate by county
  datCounty <- dat |> 
    dplyr::group_by(fips) |> 
    dplyr::summarize(
      EmpLoss = sum(EmpLoss, na.rm = T)
    ) |> 
    dplyr::ungroup() |>
    dplyr::mutate(
      storm = storm,
      year = year,
      month = month
    ) |>
    dplyr::select(storm, year, month, fips, EmpLoss)

  return(datCounty)
} %globals% c("fpath", "storm_df", "fileRead") %seed% TRUE

## Wind
plan(multisession)
wind <- foreach(storm = stormList, .combine = rbind) %dofuture% {

  # params
  stateList <- list.dirs(glue::glue("{fpath}/{storm}"), recursive = F, full.names = F)
  year <- storm_df$year[storm_df$name == storm]
  month <- storm_df$month[storm_df$name == storm]

  ## load residential damage data
  dat <- dplyr::bind_rows(
    lapply(
      stateList, 
      function(state)
        fileRead(fpath, storm, state, type = "Wind")
        #readxl::read_excel(glue("{fpath}/{storm}/{i}/Employement_Loss.xlsx"))
    ))
  ## compute total damage without the relocation cost
  dat <- dat |> 
    dplyr::rename(
      "GEOID" = `Census Tract`,
      gustW_peak = `Peak Gust (mph)`,
      sustW_max = `Maximum Sustained (mph)`) |>
    dplyr::mutate(
      GEOID = stringr::str_pad(as.character(GEOID), 11, "left", 0)
    ) |> 
    dplyr::rowwise() |> 
    dplyr::mutate(
      storm = storm,
      fips = stringr::str_sub(GEOID, 1, 5)
    ) |> 
    dplyr::ungroup() |> 
    dplyr::select(storm, GEOID, fips, gustW_peak, sustW_max) 
  
  ## aggregate by county
  datCounty <- dat |> 
    dplyr::group_by(fips) |> 
    dplyr::summarize(
      avg_gustW_peak = mean(gustW_peak, na.rm = T),
      avg_sustW_max = mean(sustW_max, na.rm = T),
      max_gustW_peak = max(gustW_peak, na.rm = T),
      max_sustW_max = max(sustW_max, na.rm = T)
    ) |> 
    dplyr::ungroup() |>
    dplyr::mutate(
      storm = storm,
      year = year,
      month = month
    ) |>
    dplyr::select(storm, year, month, fips, avg_gustW_peak, avg_sustW_max, max_gustW_peak, max_sustW_max)

  return(datCounty)
} %globals% c("fpath", "storm_df", "fileRead") %seed% TRUE

# export data
readr::write_csv(resLoss, glue("{fpath}/resLoss.csv"))
readr::write_csv(empLoss, glue("{fpath}/empLoss.csv"))
readr::write_csv(wind, glue("{fpath}/wind.csv"))

# # load residential damage data
# resDamage    <- dplyr::bind_rows(
#   lapply(
#     states, 
#     function(i)
#       readxl::read_excel(glue("{fpath}/{stormList$Name[1]}/{i}/RES_Loss.xlsx"))
#     ))

# ## compute total damage without the relocation cost
# resDamage <- resDamage %>% 
#   dplyr::rename("GEOID" = `Census Tract`) %>%
#   dplyr::mutate(
#     GEOID = stringr::str_pad(as.character(GEOID), 11, "left", 0)
#   ) %>%
#   dplyr::rowwise() %>%
#   dplyr::mutate(
#     storm = storm,
#     fips = stringr::str_sub(GEOID, 1, 5),
#     TotalResLoss = sum(c_across(Building:Wage), na.rm = T) - `Relocation Cost`
#   ) %>%
#   dplyr::ungroup() %>%
#   dplyr::select(storm, GEOID, fips, TotalResLoss, Building) %>%
#   dplyr::rename("BuildingLoss" = Building)

# ## aggregate by county
# resDamageCounty <- resDamage %>%
#   dplyr::group_by(fips) %>%
#   dplyr::summarize(
#     TotalResLoss = sum(TotalResLoss, na.rm = T),
#     BuildingLoss = sum(BuildingLoss, na.rm = T)
#   ) %>%
#   dplyr::ungroup()

