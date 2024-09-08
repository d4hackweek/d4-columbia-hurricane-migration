# libraries
library(tidyverse)
library(tidycensus)

#Load data
US_irs_migration <- readr::read_rds(file = "rawDatasets/irs_migration_county.Rds")
US_acs_migration <- readr::read_rds(file = "rawDatasets/acs5y_migration_county.Rds")

# acs5 data
US_acs_migration_y <- US_acs_migration %>% 
  filter(variable == "MOVEDOUT") %>% 
  group_by(year) %>% 
  summarise(
    migr = sum(estimate, na.rm=T),
    moe = moe_sum(moe, estimate = estimate, na.rm = TRUE))
# summing moe; see https://walker-data.com/tidycensus/articles/margins-of-error.html

# plot annual change
ggplot(US_acs_migration_y, aes(x = year, y=migr/5e6)) + #5e6 because 5 year total
  geom_line() + geom_point() + 
  scale_x_continuous(breaks=2010:2020) +
  xlab(NULL) + ylab("Million migrants")

# plot annual change with confidence band
ggplot(US_acs_migration_y, aes(x = year, y=migr/5e6)) + 
  geom_line() + geom_errorbar(aes(ymin = (migr-moe)/5e6, ymax = (migr+moe)/5e6)) + geom_point() + 
  scale_x_continuous(breaks=2010:2020) +
  xlab(NULL) + ylab("Million migrants")



# IRS data
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



# spatial data
sptial_TX <- tidycensus::get_acs(
  geography = "county",
  state = c("TX"),
  variables = c(Population = "B01001A_001"), # P001001 (SF1)
  year = 2017,
  geometry = T,
  keep_geo_vars = T, output = "wide"
)
spatial$GEOID <- as.numeric(spatial$GEOID)
