# Generate a synthetic GPX track and a matching air-quality sensor log for demos/tests.
#   Rscript scripts/make_example_data.R
# Writes example/demo_track.gpx and example/demo_sensors.csv. The walk is two laps
# around a block in central Bologna; the south side is a busy road (pollution hotspot).

set.seed(42)

start <- as.POSIXct("2026-10-12 08:00:00", tz = "UTC")
duration_s <- 3600

# --- track: rectangle loop, constant walking speed, 1 Hz -------------------------
corners <- data.frame(lat = c(44.4935, 44.4935, 44.4975, 44.4975, 44.4935),
                      lon = c(11.3380, 11.3460, 11.3460, 11.3380, 11.3380))
m_per_deg_lat <- 111320
m_per_deg_lon <- 111320 * cos(44.495 * pi / 180)
seg_len <- sqrt((diff(corners$lat) * m_per_deg_lat)^2 + (diff(corners$lon) * m_per_deg_lon)^2)
cum_len <- c(0, cumsum(seg_len))
lap_len <- sum(seg_len)

t <- 0:duration_s
dist <- (t * 2 * lap_len / duration_s) %% lap_len  # exactly two laps
lat_true <- approx(cum_len, corners$lat, xout = dist)$y
lon_true <- approx(cum_len, corners$lon, xout = dist)$y

track <- data.frame(
  time = start + t,
  lat = lat_true + rnorm(length(t), 0, 1.5 / m_per_deg_lat),
  lon = lon_true + rnorm(length(t), 0, 1.5 / m_per_deg_lon),
  ele = 54 + 6 * (lat_true - 44.4935) / 0.004 + rnorm(length(t), 0, 0.3)
)

trkpts <- sprintf(
  '   <trkpt lat="%.7f" lon="%.7f">\n    <ele>%.1f</ele>\n    <time>%s</time>\n   </trkpt>',
  track$lat, track$lon, track$ele, format(track$time, "%Y-%m-%dT%H:%M:%SZ"))
gpx <- c(
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<gpx creator="make_example_data.R" version="1.1" xmlns="http://www.topografix.com/GPX/1/1">',
  sprintf(" <metadata>\n  <time>%s</time>\n </metadata>", format(start, "%Y-%m-%dT%H:%M:%SZ")),
  " <trk>", "  <name>Demo walk</name>", "  <type>walking</type>", "  <trkseg>",
  trkpts, "  </trkseg>", " </trk>", "</gpx>")
writeLines(gpx, "example/demo_track.gpx")

# --- sensors: every 10 s from 07:55 to 09:10 --------------------------------------
s_time <- seq(start - 300, start + duration_s + 600, by = 10)
n <- length(s_time)
rel <- as.numeric(s_time - start)
on_track <- rel >= 0 & rel <= duration_s
idx <- pmin(pmax(rel, 0), duration_s) + 1
pos_lat <- lat_true[idx]
pos_lon <- lon_true[idx]

# hotspot: south edge of the block (busy road), fading over ~60 m
dist_road_m <- (pos_lat - 44.4935) * m_per_deg_lat
hotspot <- ifelse(on_track, exp(-dist_road_m / 60), 0)

ar1 <- function(n, phi, sd) as.numeric(stats::filter(rnorm(n, 0, sd), phi, method = "recursive"))
rescale <- function(x, lo, hi) lo + (hi - lo) * (x - min(x)) / (max(x) - min(x))

# PM: slowly drifting background + bursty traffic on the south road + a few
# short plumes elsewhere (bus, smoker, barbecue). PM10 spans 0-200 ug/m3;
# PM2.5 and PM1 are size fractions of it, so PM1 <= PM2.5 <= PM10 <= 200.
background <- pmax(0, 20 + ar1(n, 0.97, 2.5))
traffic <- hotspot * (60 + 90 * rexp(n, 1) * rbinom(n, 1, 0.6))
plumes <- rep(0, n)
for (start_i in sample(which(on_track & hotspot < 0.2), 4)) {
  len <- sample(3:8, 1)
  i <- start_i:min(n, start_i + len - 1)
  plumes[i] <- plumes[i] + runif(1, 50, 120) * exp(-(seq_along(i) - 1) / 3)
}
pm_raw <- background + traffic + plumes + rnorm(n, 0, 3)
pm10 <- round(rescale(pmax(pm_raw, 0), 0, 200))
pm25 <- pmin(pm10, round(pm10 * runif(n, 0.6, 0.85)))
pm1  <- pmin(pm25, round(pm25 * runif(n, 0.6, 0.8)))
co2  <- round(420 + 180 * hotspot + 0.8 * plumes + rnorm(n, 0, 10))

# temperature 18-28 C (warming morning, sun/shade on alternating sides of the block),
# relative humidity 60-80 % moving opposite to temperature
sunny_side <- ifelse(on_track, sin(2 * pi * 2 * pmax(rel, 0) / duration_s), 0)
temp_signal <- rel / max(rel) * 4 + 1.5 * sunny_side + ar1(n, 0.9, 0.25)
temperature <- round(rescale(temp_signal, 18, 28), 2)
humidity <- round(rescale(-temp_signal + ar1(n, 0.9, 0.4), 60, 80), 2)

# timestamp source: ~80% GPS, ~20% wifi only, a few with neither (ts_ms fallback)
src <- sample(c("gps", "wifi"), n, replace = TRUE, prob = c(0.8, 0.2))
src[c(60, 61, 150, 320)] <- "none"
iso <- format(s_time, "%Y-%m-%dT%H:%M:%SZ")

# device uptime with one reboot two-thirds of the way through
reboot <- round(n * 2 / 3)
ts_ms <- c(5000 + 10000 * (0:(reboot - 1)), 8000 + 10000 * (0:(n - reboot - 1)))

gps_ok <- src == "gps"
sensors <- data.frame(
  gps_datetime = ifelse(gps_ok, iso, ""),
  wifi_datetime = ifelse(src == "wifi", iso, ""),
  ts_ms = ts_ms,
  pm1 = pm1, pm25 = pm25, pm10 = pm10, co2 = co2,
  temperature = temperature,
  humidity = humidity,
  pressure = round(1016 + rnorm(n, 0, 0.05), 2),
  lat = ifelse(gps_ok, sprintf("%.6f", pos_lat), ""),
  lng = ifelse(gps_ok, sprintf("%.6f", pos_lon), ""),
  altitude = ifelse(gps_ok, sprintf("%.1f", track$ele[idx]), ""),
  hdop = ifelse(gps_ok, sprintf("%.2f", runif(n, 0.8, 2.5)), ""),
  satellites = ifelse(gps_ok, sample(6:12, n, replace = TRUE), ""),
  gps_valid = as.integer(gps_ok)
)
write.csv(sensors, "example/demo_sensors.csv", row.names = FALSE, quote = FALSE)

cat("Wrote example/demo_track.gpx (", nrow(track), "points ) and example/demo_sensors.csv (",
    n, "rows )\n")
