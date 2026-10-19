# Compare the time ranges of the track and the (offset-shifted) sensor data.
# status: "ok" (>= 50% of sensor rows fall within the track), "partial", "none".
check_overlap <- function(track, sensors, offset_s = 0) {
  s_time <- sensors$time + offset_s
  t_rng <- range(track$time)
  s_rng <- range(s_time)

  start <- max(t_rng[1], s_rng[1])
  end   <- min(t_rng[2], s_rng[2])
  overlap_s <- max(0, as.numeric(difftime(end, start, units = "secs")))
  inside <- mean(s_time >= t_rng[1] & s_time <= t_rng[2])

  status <- if (overlap_s == 0) "none" else if (inside < 0.5) "partial" else "ok"

  list(
    status = status,
    track_range = t_rng,
    sensor_range = s_rng,
    overlap = if (overlap_s > 0) c(start, end) else NULL,
    overlap_s = overlap_s,
    share_inside = inside,
    # positive: sensor data starts after the track ends; negative: ends before the track starts
    gap_s = if (s_rng[1] > t_rng[2]) as.numeric(difftime(s_rng[1], t_rng[2], units = "secs"))
            else if (s_rng[2] < t_rng[1]) -as.numeric(difftime(t_rng[1], s_rng[2], units = "secs"))
            else 0
  )
}

# Attach an interpolated position to each sensor reading recorded during the track.
align_sensors_track <- function(sensors, track, offset_s = 0, max_gap_s = 30) {
  s_time <- as.numeric(sensors$time + offset_s)
  t_time <- as.numeric(track$time)

  keep <- s_time >= min(t_time) & s_time <= max(t_time)
  # drop readings that fall inside a gap in the track (e.g. paused recording)
  nxt <- findInterval(s_time, t_time, rightmost.closed = TRUE)
  nxt <- pmin(pmax(nxt, 1), length(t_time))
  gap <- t_time[pmin(nxt + 1, length(t_time))] - t_time[nxt]
  keep <- keep & gap <= max_gap_s

  interp <- function(y) stats::approx(t_time, y, xout = s_time[keep], ties = "ordered")$y

  out <- tibble::tibble(
    time = sensors$time[keep] + offset_s,
    lat  = interp(track$lat),
    lon  = interp(track$lon),
    ele  = if (all(is.na(track$ele))) NA_real_ else interp(track$ele)
  )
  pollutants <- attr(sensors, "pollutants") %||% setdiff(names(sensors), c("time", "time_source"))
  out <- dplyr::bind_cols(out, sensors[keep, pollutants, drop = FALSE],
                          tibble::tibble(time_source = sensors$time_source[keep]))
  attr(out, "pollutants") <- pollutants
  out
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# Human-readable duration, e.g. "7 d 18 h", "25 min".
format_duration <- function(secs) {
  secs <- abs(secs)
  d <- secs %/% 86400; h <- (secs %% 86400) %/% 3600; m <- (secs %% 3600) %/% 60
  parts <- c(if (d > 0) paste(d, "d"), if (h > 0) paste(h, "h"), if (d == 0 && m > 0) paste(m, "min"))
  if (length(parts) == 0) paste(round(secs), "s") else paste(parts, collapse = " ")
}
