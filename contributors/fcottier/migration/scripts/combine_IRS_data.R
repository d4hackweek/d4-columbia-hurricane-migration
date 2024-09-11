# Fabien Cottier, D4 HACK
# Summer 2024

# setup

##libraries
library(tidyverse)

# load irs data
irs <- readr::read_rds("contributors/fcottier/migration/processedData/irs_migration_county.Rds")
irs_old <- readr::read_csv("contributors/fcottier/migration/IRS_1990_2010_Hauer_DemographicResearch.csv")

# irs recent

## clean data
irs <- irs %>%
  dplyr::mutate(
    y1_statefips = stringr::str_pad(y1_statefips, 2, pad = "0"),
    y2_statefips = stringr::str_pad(y2_statefips, 2, pad = "0"),
    y1_countyfips = stringr::str_pad(y1_countyfips, 3, pad = "0"),
    y2_countyfips = stringr::str_pad(y2_countyfips, 3, pad = "0")
  ) %>%
  dplyr::filter(y1_countyfips != "000", y2_countyfips != "000") %>% # remove state totals
  dplyr::filter(y2_statefips <= 56) %>% # remove all entities above fips 56 (Wyoming)
  dplyr::filter(y1_countyfips!=y2_countyfips) #remove stayers


## sum by sending county
irs_out <- irs %>%
  dplyr::group_by(y1_statefips, y1_countyfips, year) %>%
  dplyr::summarize(
    nMigr = sum(n1, na.rm = T),
    nMigr_wExempt = sum(n1 + n2, na.rm = T)
  ) %>%
  dplyr::mutate(
    origin = paste0(y1_statefips, y1_countyfips),
  ) %>%
  dplyr::ungroup() %>%
  dplyr::select(origin, year, nMigr, nMigr_wExempt) %>%
  dplyr::arrange(origin, year)



# irs_old

## clean data
irs_old <- irs_old %>%
  tidyr::pivot_longer(cols = `1990`:`2010`, names_to = "year", values_to = "nMigr") %>%
  dplyr::filter(origin!=destination) %>%
  dplyr::arrange(origin, destination, year)

## sum by sending county
irs_old_out <- irs_old %>%
  dplyr::group_by(origin, year = as.integer(year)) %>%
  dplyr::summarize(
    nMigr = sum(nMigr, na.rm = T)
  ) %>%
  dplyr::ungroup() %>%
  dplyr::select(origin, year, nMigr) %>%
  dplyr::arrange(origin, year)


# combine both irs dataset
irs_joint <- dplyr::bind_rows(irs_old_out, dplyr::select(irs_out, -nMigr_wExempt)) %>%
  dplyr::mutate(
    year = as.integer(year)
  ) %>%
  dplyr::arrange(origin, year)


# export data
readr::write_csv(irs_joint, file = "contributors/fcottier/migration/processedData/irs_migration_joint.csv")
readr::write_csv(irs_out, file = "contributors/fcottier/migration/processedData/irs_migration_2011_2021.csv")
readr::write_csv(irs_old_out, file = "contributors/fcottier/migration/processedData/irs_migration_1990_2010.csv")
