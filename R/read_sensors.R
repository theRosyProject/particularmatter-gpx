# Read an air-quality sensor log (CSV) into a tibble with a single UTC `time` column.
#
# Expected (but flexible) columns: gps_datetime, wifi_datetime, ts_ms, then any
# numeric measurement columns (pm1, pm25, pm10, co2, ...). Each row's time is the
# GPS timestamp when present, else the internet (wifi) timestamp; rows with
# neither are estimated from ts_ms (device uptime) relative to the nearest timed
# row of the same boot segment.

SENSOR_META_COLS <- c("gps_datetime", "wifi_datetime", "ts_ms", "lat", "lng",
                      "lon", "altitude", "hdop", "satellites", "gps_valid")

read_sensors <- function(path) {
  raw <- readr::read_csv(path, col_types = readr::cols(.default = readr::col_guess(),
                                                       gps_datetime = readr::col_character(),
                                                       wifi_datetime = readr::col_character()),
                         show_col_types = FALSE, progress = FALSE)
  if (!any(c("gps_datetime", "wifi_datetime") %in% names(raw))) {
    stop("Sensor CSV needs a 'gps_datetime' and/or 'wifi_datetime' column.")
  }

  parse_t <- function(col) {
    if (!col %in% names(raw)) return(rep(as.POSIXct(NA, tz = "UTC"), nrow(raw)))
    lubridate::ymd_hms(raw[[col]], tz = "UTC", quiet = TRUE)
  }
  gps_t  <- parse_t("gps_datetime")
  wifi_t <- parse_t("wifi_datetime")

  time <- dplyr::coalesce(gps_t, wifi_t)
  time_source <- ifelse(!is.na(gps_t), "gps", ifelse(!is.na(wifi_t), "wifi", NA))

  if ("ts_ms" %in% names(raw)) {
    est <- estimate_from_uptime(time, raw$ts_ms)
    filled <- is.na(time) & !is.na(est)
    time[filled] <- est[filled]
    time_source[filled] <- "ts_ms"
  }

  pollutants <- setdiff(names(raw)[vapply(raw, is.numeric, logical(1))], SENSOR_META_COLS)
  out <- dplyr::bind_cols(tibble::tibble(time = time, time_source = time_source),
                          raw[pollutants])
  dropped <- sum(is.na(out$time))
  out <- out[!is.na(out$time), ]
  out <- out[order(out$time), ]

  attr(out, "pollutants") <- pollutants
  attr(out, "dropped") <- dropped
  out
}

# For untimed rows, extrapolate from the nearest timed row in the same boot
# segment (ts_ms going down marks a reboot).
estimate_from_uptime <- function(time, ts_ms) {
  ts <- suppressWarnings(as.numeric(ts_ms))
  segment <- cumsum(c(TRUE, diff(dplyr::coalesce(ts, Inf)) < 0))
  est <- rep(as.POSIXct(NA, tz = "UTC"), length(time))

  for (s in unique(segment)) {
    idx <- which(segment == s)
    anchors <- idx[!is.na(time[idx]) & !is.na(ts[idx])]
    targets <- idx[is.na(time[idx]) & !is.na(ts[idx])]
    if (length(anchors) == 0 || length(targets) == 0) next
    nearest <- anchors[vapply(targets, function(i) which.min(abs(ts[anchors] - ts[i])), integer(1))]
    est[targets] <- time[nearest] + (ts[targets] - ts[nearest]) / 1000
  }
  est
}
