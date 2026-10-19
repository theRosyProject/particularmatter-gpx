test_that("measurements map to the dashboard's band sets", {
  expect_identical(field_bands("pm25"), PM25_BANDS)
  expect_identical(field_bands("pm1"), PM25_BANDS)
  expect_identical(field_bands("PM10"), PM10_BANDS)
  expect_null(field_bands("no2"))
})

test_that("band_index follows the dashboard thresholds", {
  lvl <- function(bands, v) bands$level[band_index(bands, v)]
  expect_equal(lvl(PM25_BANDS, c(0, 12, 12.05, 35.4, 35.5, 55.5, 150.5, 300)),
               c("GOOD", "GOOD", "GOOD", "MODERATE", "UNHEALTHY_SENSITIVE",
                 "UNHEALTHY", "VERY_UNHEALTHY", "HAZARDOUS"))
  expect_equal(lvl(PM10_BANDS, c(15, 16, 200)), c("GOOD", "MODERATE", "UNHEALTHY"))
  expect_equal(lvl(TEMPERATURE_BANDS, c(-5, 18, 23.95, 28)), c("COLD", "COMFORTABLE", "COMFORTABLE", "HOT"))
  expect_equal(lvl(HUMIDITY_BANDS, c(65, 80)), c("HUMID", "VERY_HUMID"))
  expect_equal(lvl(PRESSURE_BANDS, c(850, 1013)), c("PRESSURE_EXTREME_LOW", "PRESSURE_NORMAL"))
})

test_that("legend labels match the dashboard's format", {
  expect_equal(band_labels(PM25_BANDS),
               c("Good (0-12)", "Moderate (12-35)", "Unhealthy for Sensitive Groups (36-55)",
                 "Unhealthy (56-150)", "Very Unhealthy (151-250)", "Hazardous (251+)"))
  expect_equal(band_labels(TEMPERATURE_BANDS)[1], "Cold (<10)")
})
