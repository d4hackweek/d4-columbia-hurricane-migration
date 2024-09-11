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


## out-migration / sum by sending county
irs_out <- irs %>%
  dplyr::group_by(y1_statefips, y1_countyfips, year) %>%
  dplyr::summarize(
    nOutMigr = sum(n1, na.rm = T),
    nOutMigr_wExempt = sum(n1 + n2, na.rm = T)
  ) %>%
  dplyr::mutate(
    GEOID = paste0(y1_statefips, y1_countyfips),
  ) %>%
  dplyr::ungroup() %>%
  dplyr::select(GEOID, year, nOutMigr, nOutMigr_wExempt) %>%
  dplyr::arrange(GEOID, year)

# sum by destination county
irs_in <- irs %>%
  dplyr::group_by(y2_statefips, y2_countyfips, year) %>%
  dplyr::summarize(
    nInMigr = sum(n1, na.rm = T),
    nInMigr_wExempt = sum(n1 + n2, na.rm = T)
  ) %>%
  dplyr::mutate(
    GEOID = paste0(y2_statefips, y2_countyfips),
  ) %>%
  dplyr::ungroup() %>%
  dplyr::select(GEOID, year, nInMigr, nInMigr_wExempt) %>%
  dplyr::arrange(GEOID, year)

# net migration
irs_ready <- irs_in %>%
  dplyr::left_join(irs_out) %>%
  dplyr::mutate(
    netMigr = nInMigr - nOutMigr,
    netMigr_wExempt  = nInMigr_wExempt - nOutMigr_wExempt
  ) %>%
  dplyr::select(GEOID, year, nInMigr, nInMigr_wExempt, nOutMigr, nOutMigr_wExempt, netMigr, netMigr_wExempt) %>%
  dplyr::arrange(GEOID, year)



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
    nOutMigr = sum(nMigr, na.rm = T)
  ) %>%
  dplyr::ungroup() %>%
  dplyr::rename("GEOID" = "origin")  %>%
  dplyr::select(GEOID, year, nOutMigr) %>%
  dplyr::arrange(GEOID, year)

## sum by destination county
irs_old_in <- irs_old %>%
  dplyr::group_by(destination, year = as.integer(year)) %>%
  dplyr::summarize(
    nInMigr = sum(nMigr, na.rm = T)
  ) %>%
  dplyr::ungroup() %>%
  dplyr::rename("GEOID" = "destination")  %>%
  dplyr::select(GEOID, year, nInMigr) %>%
  dplyr::arrange(GEOID, year)

## net migration
irs_old_ready <- irs_old_in %>%
  dplyr::left_join(irs_old_out) %>%
  dplyr::mutate(
    netMigr = nInMigr - nOutMigr
  ) %>%
  dplyr::select(GEOID, year, nInMigr, nOutMigr, netMigr) %>%
  dplyr::arrange(GEOID, year)


# combine both irs dataset
irs_joint <- dplyr::bind_rows(
  irs_old_ready,
  dplyr::select(irs_ready, -contains("_wExempt"))
) %>%
  dplyr::mutate(
    year = as.integer(year)
  ) %>%
  dplyr::arrange(GEOID, year)


# export data
readr::write_csv(irs_joint, file = "contributors/fcottier/migration/processedData/irs_migration_joint.csv")
readr::write_csv(irs_ready, file = "contributors/fcottier/migration/processedData/irs_migration_2011_2021.csv")
readr::write_csv(irs_old_ready, file = "contributors/fcottier/migration/processedData/irs_migration_1990_2010.csv")
