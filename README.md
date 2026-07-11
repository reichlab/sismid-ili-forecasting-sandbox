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

## Acknowledgments

This repository follows the guidelines and standards outlined by [the
hubverse](https://hubverse.io), which provides a set of data formats and open source tools for modeling hubs.
