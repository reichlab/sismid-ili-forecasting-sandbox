#' Fetch FluSight ILI target data
#'
#' Produces two target-data artifacts for the sandbox hub:
#'
#'   * oracle-output.csv : the scoring truth. For each target week we use the
#'     wILI value as it stood at the **end of that week's season** -- the latest
#'     issue on or before 1 July of the season's end year -- NOT the all-time
#'     latest value. ILINet is re-baselined between seasons, so the "final"
#'     value for, say, 2015/16 drifts if you take a 2019 snapshot; freezing it
#'     at ~1 July of the following summer is the value the season was actually
#'     scored against.
#'   * time-series.csv   : a *versioned* (vintage) observed series carrying an
#'     `as_of` column. For each forecast reference date R we record the data as
#'     it was available in real time at R (the latest release on or before R).
#'     predtimechart uses `as_of` = reference_date, so the dashboard's observed
#'     line shows the data a forecaster actually saw -- revealing reporting
#'     backfill week to week.
#'
#' Run from the hub root (the directory containing hub-config/ and target-data/).

library(dplyr)
library(lubridate)
library(epidatr)
library(purrr)

options(timeout = 600)

locations <- c("nat", "hhs1", "hhs2", "hhs3", "hhs4", "hhs5",
               "hhs6", "hhs7", "hhs8", "hhs9", "hhs10")
location_formal_names <- c("US National", paste("HHS Region", 1:10))
loc_df <- data.frame(region = locations, location = location_formal_names)

## Forecast reference dates (Saturdays) defined by the hub's tasks config.
round_ids <- hubUtils::read_config(".", "tasks") |>
  hubUtils::get_round_ids() |>
  as.Date()

## Season-end year for a target week, and the "final" as_of used as truth:
## weeks in Aug-Dec belong to the season ending the following year.
season_end_year <- function(d) {
  d <- as.Date(d)
  ifelse(month(d) >= 8, year(d) + 1, year(d))
}
final_as_of <- function(d) as.Date(sprintf("%d-07-01", season_end_year(d)))

## ---------------------------------------------------------------------------
## Vintage issue history covering the forecastable seasons, through early July
## so each season's ~1-July final values are present.
## ---------------------------------------------------------------------------
start_years <- 2015:2019
vintage_raw <- map(start_years, function(y) {
  locations |>
    map(\(loc) pub_fluview(
      loc,
      epiweeks = epirange(200335, (y + 1) * 100 + 30),
      issues   = epirange(y * 100 + 40, (y + 1) * 100 + 30)
    )) |>
    list_rbind()
}) |>
  list_rbind()

write.csv(vintage_raw, "target-data/target-data-raw.csv", row.names = FALSE)

vintage <- vintage_raw |>
  transmute(region,
            target_end_date = as.Date(epiweek) + 6,
            release_date = as.Date(release_date),
            observation = wili) |>
  left_join(loc_df, by = "region")

## ---------------------------------------------------------------------------
## 1. oracle-output = season-final value (latest issue on/before 1 July)
## ---------------------------------------------------------------------------
ili_oracle_output <- vintage |>
  filter(month(target_end_date) %in% c(1:6, 10:12),
         target_end_date >= as.Date("2015-10-01"),
         release_date <= final_as_of(target_end_date)) |>
  group_by(location, target_end_date) |>
  slice_max(release_date, n = 1, with_ties = FALSE) |>
  ungroup() |>
  transmute(location, target_end_date, target = "ili perc",
            output_type = "quantile", output_type_id = NA,
            oracle_value = observation)

write.csv(ili_oracle_output, "target-data/oracle-output.csv", row.names = FALSE)

## ---------------------------------------------------------------------------
## 2. versioned time-series (one as_of snapshot per reference date)
## ---------------------------------------------------------------------------
## Finalized fallback (latest available version) for weeks older than a
## release's revision window.
finalized_ts <- vintage |>
  group_by(location, target_end_date) |>
  slice_max(release_date, n = 1, with_ties = FALSE) |>
  ungroup() |>
  transmute(location, target_end_date, observation)

season_start <- function(R) {
  as.Date(ifelse(month(R) >= 8,
                 sprintf("%d-08-01", year(R)),
                 sprintf("%d-08-01", year(R) - 1)))
}

make_snapshot <- function(R) {
  vint <- vintage |>
    filter(release_date <= R) |>
    group_by(location, target_end_date) |>
    slice_max(release_date, n = 1, with_ties = FALSE) |>
    ungroup() |>
    select(location, target_end_date, observation_v = observation)

  finalized_ts |>
    filter(target_end_date >= season_start(R), target_end_date <= R) |>
    left_join(vint, by = c("location", "target_end_date")) |>
    transmute(location, target_end_date, target = "ili perc",
              observation = coalesce(observation_v, observation),
              as_of = R)
}

ili_time_series <- map(round_ids, make_snapshot) |> list_rbind()

write.csv(ili_time_series, "target-data/time-series.csv", row.names = FALSE)

message("Wrote oracle-output.csv (", nrow(ili_oracle_output), " rows, ",
        "season-final truth) and versioned time-series.csv (",
        nrow(ili_time_series), " rows, ",
        dplyr::n_distinct(ili_time_series$as_of), " as_of snapshots).")
