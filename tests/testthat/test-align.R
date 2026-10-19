demo_track <- read_gpx(example_file("demo_track.gpx"))
demo_sensors <- read_sensors(example_file("demo_sensors.csv"))

test_that("check_overlap flags ok / partial / none", {
  expect_equal(check_overlap(demo_track, demo_sensors)$status, "ok")
  expect_equal(check_overlap(demo_track, demo_sensors, offset_s = 3000)$status, "partial")
  none <- check_overlap(demo_track, demo_sensors, offset_s = -1e5)
  expect_equal(none$status, "none")
  expect_lt(none$gap_s, 0)  # sensor data ends before the track starts
  expect_equal(check_overlap(demo_track, demo_sensors, offset_s = 1e5)$gap_s, 1e5 - 300 - 3600)
})

test_that("check_overlap flags real files from different days", {
  skip_without_example("Morning_Hike.gpx", "2026-10-12_log.csv")
  real <- check_overlap(read_gpx(example_file("Morning_Hike.gpx")),
                        read_sensors(example_file("2026-10-12_log.csv")))
  expect_equal(real$status, "none")
  expect_gt(real$gap_s, 7 * 86400)
})

test_that("align keeps only readings during the track and places them on it", {
  m <- align_sensors_track(demo_sensors, demo_track)
  expect_equal(nrow(m), 361)  # 08:00:00..09:00:00 every 10 s
  expect_true(all(m$time >= min(demo_track$time) & m$time <= max(demo_track$time)))
  expect_true(all(m$lat >= 44.4933 & m$lat <= 44.4977))
  # readings on the busy south road are much higher than elsewhere on the loop
  south <- m$lat < 44.4938
  expect_gt(median(m$pm25[south]), 3 * median(m$pm25[!south]))
})

test_that("align interpolates and drops readings in track gaps", {
  t0 <- as.POSIXct("2026-01-01 00:00:00", tz = "UTC")
  tr <- tibble::tibble(time = t0 + c(0, 10, 100), lat = c(0, 1, 2), lon = c(0, 10, 20), ele = NA_real_)
  s <- tibble::tibble(time = t0 + c(5, 50), time_source = "gps", pm25 = c(1, 2))
  attr(s, "pollutants") <- "pm25"
  m <- align_sensors_track(s, tr, max_gap_s = 30)
  expect_equal(nrow(m), 1)
  expect_equal(c(m$lat, m$lon), c(0.5, 5))
  expect_equal(nrow(align_sensors_track(s, tr, max_gap_s = 120)), 2)
})
