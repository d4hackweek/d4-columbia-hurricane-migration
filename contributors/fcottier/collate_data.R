# setup

## libraries
library(tidyverse)
library(glue)

## fpath
fpath_migration <- "contributors/fcottier/migration"
fpath_hurricane <- "contributors/mhemmati/Storm_Analysis_Results"

# load data
counties <- readr::read_csv(glue("{fpath_migration}/processedData/counties_200km.csv"))
wind <- readr::read_csv(glue("{fpath_hurricane}/wind.csv"))
resLoss <- readr::read_csv(glue("{fpath_hurricane}/resLoss.csv"))
empLoss <- readr::read_csv(glue("{fpath_hurricane}/empLoss.csv"))
irs <- readr::read_csv(glue("{fpath_migration}/processedData/irs_migration_joint.csv"))

# keep only Texas, Louisiana, Mississippi, Alabama, Florida
counties <- counties %>% 
  dplyr::filter(
    STATEFP %in% c("48", "22", "28", "01", "12")
  )



# merge storm data by year 

## inspect storm by month
unique(wind$month)

##  winds: take max values in given year
wind <- wind %>%
  dplyr::group_by(fips, year) %>%
  dplyr::summarize(
    avg_gustW_peak = max(avg_gustW_peak),
    avg_sustW_max = max(avg_sustW_max),
    max_gustW_peak = max(max_gustW_peak),
    max_sustW_max = max(max_sustW_max)
  )

# residential damage, employment loss: take sum values in given year
resLoss <- resLoss %>%
  dplyr::group_by(fips, year) %>%
  dplyr::summarize(
    TotalResLoss = sum(TotalResLoss),
    BuildingLoss = sum(BuildingLoss)
  )
empLoss <- empLoss %>%
  dplyr::group_by(fips, year) %>%
  dplyr::summarize(
    EmpLoss = sum(EmpLoss)
  )



# combine data

## expand dataset
yearlist <- 2002:2021
df <- expand.grid(
  GEOID = unique(counties$GEOID),
  year = yearlist
) %>%
  dplyr::left_join(counties, by = "GEOID") %>%
  dplyr::arrange(GEOID, year) %>%
  tibble::as_tibble()

## merge with migration data
df <- df %>%
  dplyr::left_join(irs, by = c("GEOID" = "origin", "year" = "year")) %>%
  dplyr::mutate(
    nMigr = ifelse(is.na(nMigr), 0, nMigr)
  )

## merge with hurricane data 
df <- df %>%
    dplyr::left_join(wind, by = c("GEOID" = "fips", "year" = "year")) %>%
    dplyr::left_join(resLoss, by = c("GEOID" = "fips", "year" = "year")) %>%
    dplyr::left_join(empLoss, by = c("GEOID" = "fips", "year" = "year")) %>%
    tidyr::replace_na(list(
      avg_gustW_peak = 0,
      avg_sustW_max = 0,
      max_gustW_peak = 0,
      max_sustW_max = 0,
      TotalResLoss = 0,
      BuildingLoss = 0,
      EmpLoss = 0
    ))


# export data
readr::write_csv(df, file = "contributors/fcottier/df_migration_hurricane.csv")
