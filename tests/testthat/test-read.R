test_that("read_gpx parses a Strava GPX", {
  skip_without_example("Morning_Hike.gpx")
  tr <- read_gpx(example_file("Morning_Hike.gpx"))
  expect_equal(nrow(tr), 29187)
  expect_equal(tr$time[1], as.POSIXct("2026-10-04 05:55:27", tz = "UTC"))
  expect_false(anyNA(tr$lat))
})

test_that("read_gpx parses the demo track", {
  tr <- read_gpx(example_file("demo_track.gpx"))
  expect_equal(nrow(tr), 3601)
  expect_equal(as.numeric(diff(range(tr$time)), units = "secs"), 3600)
})

test_that("read_sensors builds one time column from gps/wifi/ts_ms", {
  s <- read_sensors(example_file("demo_sensors.csv"))
  expect_false(anyNA(s$time))
  expect_true(all(c("pm1", "pm25", "pm10", "co2") %in% attr(s, "pollutants")))
  expect_false(any(c("lat", "ts_ms", "gps_valid") %in% attr(s, "pollutants")))
  expect_equal(nrow(s), 451)
  expect_setequal(unique(s$time_source), c("gps", "wifi", "ts_ms"))
  # ts_ms-estimated rows land exactly on the 10 s grid
  est <- s$time[s$time_source == "ts_ms"]
  expect_true(all(as.numeric(est) %% 10 == 0))
})

test_that("read_sensors parses a real sensor log", {
  skip_without_example("2026-10-12_log.csv")
  s <- read_sensors(example_file("2026-10-12_log.csv"))
  expect_equal(nrow(s), 1136)
  expect_false(anyNA(s$time))
  expect_true(all(c("pm1", "pm25", "pm10", "co2") %in% attr(s, "pollutants")))
})
