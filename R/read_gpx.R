# Read the track points of a GPX 1.x file (Strava, Garmin, ...) into a tibble.
# XPath matches on local-name() so it works with or without the GPX namespace
# (xml2::xml_ns_strip is avoided: it takes minutes on long activities).
read_gpx <- function(path) {
  doc <- xml2::read_xml(path)
  el <- function(name) sprintf("*[local-name()='%s']", name)

  # only points with a timestamp are useful for alignment
  pts_xpath <- sprintf("//%s[%s]", el("trkpt"), el("time"))
  pts <- xml2::xml_find_all(doc, pts_xpath)
  if (length(pts) == 0) stop("No timestamped <trkpt> points found in GPX file.")
  time <- xml2::xml_text(xml2::xml_find_all(doc, sprintf("%s/%s[1]", pts_xpath, el("time"))))

  n_ele <- xml2::xml_find_num(doc, sprintf("count(%s[%s])", pts_xpath, el("ele")))
  ele <- if (n_ele == length(pts)) {
    as.numeric(xml2::xml_text(xml2::xml_find_all(doc, sprintf("%s/%s[1]", pts_xpath, el("ele")))))
  } else {
    NA_real_
  }

  track <- tibble::tibble(
    time = lubridate::ymd_hms(time, tz = "UTC", quiet = TRUE),
    lat  = as.numeric(xml2::xml_attr(pts, "lat")),
    lon  = as.numeric(xml2::xml_attr(pts, "lon")),
    ele  = ele
  )

  track <- track[!is.na(track$time) & !is.na(track$lat) & !is.na(track$lon), ]
  if (nrow(track) == 0) stop("GPX has no track points with a valid timestamp.")
  track[order(track$time), ]
}
