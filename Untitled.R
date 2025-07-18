hub_con |>
  filter(model_id == "delphi-epicast",
         origin_date == "2015-11-14") |>
  collect_hub()
