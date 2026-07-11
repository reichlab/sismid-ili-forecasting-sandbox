# SISMID ILI Forecasting Sandbox

A template of a Sandbox hub of forecasts based on the original [FluSight Challenge](https://github.com/cdcepi/FluSight-forecasts) run by the CDC. All data and the repository structure have been formatted according to [hubverse](https://hubverse.io/) standards.

The purpose of this hub is to provide a sandbox environment for training, research or benchmarking purposes.

## Short-term forecasts of outpatient influenza-like illness (ILI) cases

Predictions are quantile forecasts of weighted influenza-like illness (ILI) percentage, converted from the original CDF forecasts for the same target. This hub is set up to receive new forecast submissions for educational purposes.

**Dates:** The Challenge Period ran for five respiratory virus seasons (2015-2019). Forecasts may be submitted for any of the original submission dates.

**Prediction Targets:**
Participants are asked to provide national and/or jurisdiction-specific (10 HHS regions) retrospective quantile forecasts for weighted ILI percentage.

Modelers will submit these retrospective quantile forecasts for the epidemiological week (EW) ending on the reference dates used for the original FluSight forecasts, up to 4 weeks ahead in the future. Modelers can but are not required to submit forecasts for all four week horizons or for all locations. We will use the specification of EWs defined by the
[CDC](https://wwwn.cdc.gov/nndss/document/MMWR_Week_overview.pdf), which run Sunday through Saturday. The target end
date for a prediction is the Saturday that ends an EW of interest, and can be calculated using the expression:
**target end date = reference date + horizon * (7 days)**.

The evaluation data for forecasts will be the weighted ILI percentage collected by the US Outpatient Influenza-like Illness Surveillance Network (ILINet).
Ground truth target data [was downloaded](scripts/get_target_data.R) using [the epidatr R package](https://cmu-delphi.github.io/epidatr/).

There are standard software packages to convert from dates to epidemic weeks and vice versa (*e.g.*,
[MMWRweek](https://cran.r-project.org/web/packages/MMWRweek/) and
[lubridate](https://lubridate.tidyverse.org/reference/week.html) for R and [pymmwr](https://pypi.org/project/pymmwr/)
and [epiweeks](https://pypi.org/project/epiweeks/) for Python).

## Data versions, reporting backfill, and forecast timing

ILINet data are **revised after they are first published** — as more outpatient
providers report, the weighted-ILI value for a given week is updated over the
following weeks and months. This phenomenon is called **backfill**. Because of
it, "the ILI value for week *W*" is not a single number: it depends on *when you
ask*. Getting this right matters for a retrospective hub, because a forecaster
in real time saw only the (often incomplete) data available at the time, not the
finalized values we can look up today.

This hub handles versioning deliberately, and it is the source of two easily
confused date issues. Read this section before changing
[`scripts/get_target_data.R`](scripts/get_target_data.R).

### What data a forecast could actually use (the real-time cutoff)

Each forecast is labelled by its **`origin_date`**, the Saturday ending the most
recent epiweek of data used in the forecast (`origin_epiweek`, "EWXX" in the
original FluSight naming). Targets are then 1–4 weeks *ahead* of that week:

> **target end date = origin_date + horizon × 7 days**

So a forecast with `origin_date = 2016-01-30` (EW2016-04) has its horizon-1
target on **2016-02-06** (EW2016-05).

The key timing rule comes from the original challenge. Per the
[FluSight Network guidelines](https://github.com/FluSightNetwork/cdc-flusight-ensemble/blob/master/guidelines.md),
a forecast labelled EWXX is *"due (i.e. may only use data through) Monday 11:59pm
of week XX+2"*, and EWXX is *"the latest week … of ILINet data used in the
forecast"* (see also the
[`hubverse-org/flusight_hub_archive`](https://github.com/hubverse-org/flusight_hub_archive)
conversion of the original [`cdcepi/FluSight-forecasts`](https://github.com/cdcepi/FluSight-forecasts),
where `origin_epiweek` is defined as the latest MMWR week of data used). In
calendar terms that deadline is:

> **data cutoff = origin_date + 9 days**  (Monday of week XX+2)

This works out because ILINet first publishes week XX on the **Friday of week
XX+1** (≈ `origin_date + 6`), so by the Monday deadline (`origin_date + 9`) the
first report of the origin week is available — but the *next* week's first
report (Friday of week XX+2 ≈ `origin_date + 13`) is **not**. Hence a forecast
"as of" `origin_date` was built from data **through the origin week, at its
first-reported (unrevised) values**.

**Worked example** (`origin_date = 2016-01-30`, HHS Region 2):

| week ending | value the forecaster had (as of the deadline) | season-final value (scoring truth) |
|---|---|---|
| 2016-01-23 | 2.689 (as re-reported 2016-02-05) | 2.18 |
| 2016-01-30 | **2.810** (first reported 2016-02-05) | 2.33 |

The origin week (2016-01-30) was first published on Friday 2016-02-05 at 2.810
and was only later revised down to a season-final 2.33. A forecaster at the
2016-02-08 deadline used **2.810**, not 2.33 — so that is the value shown in the
`as_of = 2016-01-30` snapshot, and the value the forecast launches from.

### Two target-data files, two different "as of" choices

- **[`target-data/time-series.csv`](target-data/time-series.csv) — the versioned
  observed series (what the forecaster saw).** It carries an **`as_of`** column
  equal to the forecast `origin_date`. For each `as_of` we record every week from
  the start of the 2014/2015 season up to that date, each at its **latest release
  on or before `origin_date + 9`** (the deadline above). This is the series the
  [`predtimechart`](https://docs.hubverse.io/en/latest/user-guide/dashboards.html)
  dashboard displays alongside a forecast, so the observed line matches the data
  the model launched from — including visible backfill. **The full history is
  repeated in every `as_of` snapshot on purpose:** predtimechart will not render
  a snapshot that is missing early weeks.

- **[`target-data/oracle-output.csv`](target-data/oracle-output.csv) — the
  scoring truth (what actually happened).** Forecasts are scored against the
  **season-final** value of each week: the latest release **on or before 1 July
  of that week's season-end year** (weeks in Aug–Dec belong to the season ending
  the following year). This is *not* the all-time-latest value, because CDC
  **re-baselines the entire ILINet history between seasons** — e.g. a release in
  October 2017 retroactively shifted 2015/16 values by ~0.04 wILI. Freezing the
  truth at the following summer captures the season as it actually settled while
  preventing later, cross-season revisions from leaking into scores.

### Common pitfalls when regenerating

- Do **not** use finalized (all-time-latest) data for the observed `time-series`:
  it overstates what forecasters knew and makes the observed line disagree with
  the forecast's starting point at the origin week.
- Do **not** use `release_date <= origin_date` (with no `+9`): the origin week is
  not published until ~`origin_date + 6`, so it would be missing and fall back to
  a finalized value — the exact bug this design avoids.
- Do **not** score against the latest data: use the July-1 season-final snapshot,
  or cross-season re-baselines will change past scores.

Real-time (issue-versioned) ILINet data are pulled from the
[Delphi Epidata API](https://cmu-delphi.github.io/delphi-epidata/) via
[epidatr](https://cmu-delphi.github.io/epidatr/) using its `issues`/`as_of`
support; see [`scripts/get_target_data.R`](scripts/get_target_data.R).

## Acknowledgments

This repository follows the guidelines and standards outlined by [the
hubverse](https://hubverse.io), which provides a set of data formats and open source tools for modeling hubs.
