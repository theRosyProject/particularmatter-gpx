# Air-quality bands (thresholds + colours), mirrored from the ParticularMatter
# dashboard: particularmatter-app/frontend/src/components/AirQualityChart.tsx.
# Keep the two in sync when either changes.

make_bands <- function(min, max, level, label, color) {
  data.frame(min = min, max = max, level = level, label = label, color = color,
             stringsAsFactors = FALSE)
}

# EPA PM2.5/PM1 AQI breakpoints (ug/m3)
PM25_BANDS <- make_bands(
  min   = c(0, 12.1, 35.5, 55.5, 150.5, 250.5),
  max   = c(12, 35.4, 55.4, 150.4, 250.4, Inf),
  level = c("GOOD", "MODERATE", "UNHEALTHY_SENSITIVE", "UNHEALTHY", "VERY_UNHEALTHY", "HAZARDOUS"),
  label = c("Good", "Moderate", "Unhealthy for Sensitive Groups", "Unhealthy", "Very Unhealthy",
            "Hazardous"),
  color = c("#68E143", "#ffcf55", "#EF8533", "#EA3324", "#8C1A4B", "#731425")
)

PM10_BANDS <- make_bands(
  min   = c(0, 15.1, 45.1, 106.1, 255.1),
  max   = c(15, 45, 106, 255, Inf),
  level = c("GOOD", "MODERATE", "UNHEALTHY_SENSITIVE", "UNHEALTHY", "VERY_UNHEALTHY"),
  label = c("Good", "Moderate", "Unhealthy for Sensitive Groups", "Unhealthy", "Very Unhealthy"),
  color = c("#22c55e", "#f59e0b", "#f97316", "#ef4444", "#dc2626")
)

CO2_BANDS <- make_bands(
  min   = c(0, 800.1, 1000.1, 1500.1),
  max   = c(800, 1000, 1500, Inf),
  level = c("GOOD", "MODERATE", "POOR", "VERY_POOR"),
  label = c("Good", "Moderate", "Poor", "Very Poor"),
  color = c("#22c55e", "#f59e0b", "#f97316", "#ef4444")
)

TEMPERATURE_BANDS <- make_bands(
  min   = c(-Inf, 10, 18, 24, 28),
  max   = c(9.9, 17.9, 23.9, 27.9, Inf),
  level = c("COLD", "COOL", "COMFORTABLE", "WARM", "HOT"),
  label = c("Cold", "Cool", "Comfortable", "Warm", "Hot"),
  color = c("#3b82f6", "#60a5fa", "#22c55e", "#f59e0b", "#ef4444")
)

HUMIDITY_BANDS <- make_bands(
  min   = c(0, 30, 60, 70),
  max   = c(29.9, 59.9, 69.9, Inf),
  level = c("DRY", "COMFORTABLE", "HUMID", "VERY_HUMID"),
  label = c("Dry", "Comfortable", "Humid", "Very Humid"),
  color = c("#f59e0b", "#22c55e", "#0891b2", "#2563eb")
)

# Sea-level pressure (hPa)
PRESSURE_BANDS <- make_bands(
  min   = c(870, 980, 1000, 1020, 1040),
  max   = c(979.9, 999.9, 1019.9, 1039.9, 1083.8),
  level = c("PRESSURE_EXTREME_LOW", "PRESSURE_LOW", "PRESSURE_NORMAL", "PRESSURE_HIGH",
            "PRESSURE_EXTREME_HIGH"),
  label = c("Extreme Low", "Low", "Normal", "High", "Extreme High"),
  color = c("#2563eb", "#60a5fa", "#22c55e", "#f97316", "#dc2626")
)

FIELD_BANDS <- list(
  pm25 = PM25_BANDS, pm2_5 = PM25_BANDS, pm1 = PM25_BANDS,
  pm10 = PM10_BANDS,
  co2 = CO2_BANDS,
  temperature = TEMPERATURE_BANDS,
  pressure = PRESSURE_BANDS,
  humidity = HUMIDITY_BANDS
)

field_bands <- function(field) FIELD_BANDS[[tolower(field)]]

# Band index for each value: the highest band whose lower bound is <= value.
# Values below the first bound fall in the first band, above the last in the
# last. Using lower bounds only means values inside the dashboard's 0.1 gaps
# (e.g. 12.05 ug/m3) stay in the band below, as with EPA's truncation to one
# decimal, instead of falling through to the top band.
band_index <- function(bands, values) {
  pmax(1L, findInterval(values, bands$min))
}

# Colour (and band label) for each value of a measurement, shared by the map and
# the time series: dashboard bands when known, otherwise the teal ramp.
value_colors <- function(field, values) {
  bands <- field_bands(field)
  if (!is.null(bands)) {
    b <- band_index(bands, values)
    out <- list(fill = bands$color[b], level = bands$label[b], bands = bands, pal = NULL)
  } else {
    pal <- leaflet::colorNumeric(PM_RAMP, domain = range(values, na.rm = TRUE),
                                 na.color = "#555555")
    out <- list(fill = pal(values), level = NULL, bands = NULL, pal = pal)
  }
  out$fill[is.na(values)] <- "#555555"
  out
}

# Legend labels formatted like the dashboard's: "Good (0-12)", "Hazardous (250+)", "Cold (<10)".
band_labels <- function(bands) {
  js_round <- function(x) floor(x + 0.5)  # JavaScript Math.round: halves round up
  rng <- ifelse(is.infinite(bands$min), paste0("<", js_round(bands$max)),
         ifelse(is.infinite(bands$max), paste0(js_round(bands$min), "+"),
                paste0(js_round(bands$min), "-", js_round(bands$max))))
  sprintf("%s (%s)", bands$label, rng)
}
