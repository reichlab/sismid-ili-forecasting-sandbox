#' Fetch FluSight ILI target data
#'
#' Produces two target-data artifacts for the sandbox hub:
#'
#'   * oracle-output.csv : the *finalized* (fully revised) wILI, used as the
#'     scoring truth -- forecasts are judged against what actually happened.
#'   * time-series.csv   : a *versioned* (vintage) observed series carrying an
#'     `as_of` column. For each forecast reference date R we record the ILINet
#'     data as it was available in real time at R (the FluView release whose
#'     newest week is R, i.e. `issue == R - 6 days`), with earlier weeks filled
#'     from finalized data. predtimechart uses `as_of` = reference_date, so the
#'     dashboard's observed line shows the data a forecaster actually saw --
#'     revealing reporting backfill week to week.
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

## ---------------------------------------------------------------------------
## 1. Finalized data -> raw archive + oracle-output (the scoring truth)
## ---------------------------------------------------------------------------
finalized_raw <- locations |>
  map(\(loc) pub_fluview(loc, epiweeks = epirange(200335, 202030))) |>
  list_rbind()

write.csv(finalized_raw, "target-data/target-data-raw.csv", row.names = FALSE)

finalized_ts <- finalized_raw |>
  transmute(region,
            target_end_date = as.Date(epiweek) + 6,
            target = "ili perc",
            observation = wili) |>
  left_join(loc_df, by = "region")

ili_oracle_output <- finalized_ts |>
  filter(target_end_date >= as.Date("2015-10-01")) |>
  transmute(location, target_end_date, target,
            output_type = "quantile",
            output_type_id = NA,
            oracle_value = observation)

write.csv(ili_oracle_output, "target-data/oracle-output.csv", row.names = FALSE)

## ---------------------------------------------------------------------------
## 2. Vintage data -> versioned time-series (one as_of snapshot per round)
## ---------------------------------------------------------------------------
## Pull the issue history covering the forecastable seasons.
start_years <- 2015:2019
vintage_raw <- map(start_years, function(y) {
  locations |>
    map(\(loc) pub_fluview(
      loc,
      epiweeks = epirange(200335, (y + 1) * 100 + 20),
      issues   = epirange(y * 100 + 40, (y + 1) * 100 + 20)
    )) |>
    list_rbind()
}) |>
  list_rbind() |>
  transmute(region,
            target_end_date = as.Date(epiweek) + 6,
            issue = as.Date(issue),
            observation_v = wili)

## Display window: from 1 August of the season through the reference date.
season_start <- function(R) {
  as.Date(ifelse(month(R) >= 8,
                 sprintf("%d-08-01", year(R)),
                 sprintf("%d-08-01", year(R) - 1)))
}

make_snapshot <- function(R) {
  vint <- vintage_raw |>
    filter(issue == R - 6) |>
    select(region, target_end_date, observation_v)

  finalized_ts |>
    filter(target_end_date >= season_start(R), target_end_date <= R) |>
    left_join(vint, by = c("region", "target_end_date")) |>
    transmute(location, target_end_date, target,
              observation = coalesce(observation_v, observation),
              as_of = R)
}

ili_time_series <- map(round_ids, make_snapshot) |> list_rbind()

write.csv(ili_time_series, "target-data/time-series.csv", row.names = FALSE)

message("Wrote oracle-output.csv (", nrow(ili_oracle_output), " rows) and ",
        "versioned time-series.csv (", nrow(ili_time_series), " rows, ",
        dplyr::n_distinct(ili_time_series$as_of), " as_of snapshots).")
