# Leaflet map: faint full track + readings coloured by the chosen measurement.
# Measurements known to the ParticularMatter dashboard (R/bands.R) use its
# threshold bands and colours; any other column falls back to a teal ramp.
# Uses keyless OpenStreetMap tiles; www/pm.css darkens them (.leaflet-tile-pane)
# to match the ParticularMatter look.
aq_map <- function(matched, track, pollutant = NULL) {
  m <- leaflet::leaflet() |>
    leaflet::addTiles() |>
    leaflet::addPolylines(lng = track$lon, lat = track$lat,
                          color = "#FFFFFF", weight = 2, opacity = 0.35,
                          group = "Track")

  if (!is.null(matched) && nrow(matched) > 0 && !is.null(pollutant) &&
      pollutant %in% names(matched) && any(!is.na(matched[[pollutant]]))) {
    vals <- matched[[pollutant]]
    vc <- value_colors(pollutant, vals)
    fill <- vc$fill
    level <- vc$level
    bands <- vc$bands
    pal <- vc$pal

    # draw high values last so hotspots sit on top
    o <- order(vals)
    popup <- sprintf("<b>%s</b>: %s%s<br>%s UTC", pollutant, signif(vals, 4),
                     if (is.null(level)) "" else paste0(" &middot; ", level),
                     format(matched$time, "%Y-%m-%d %H:%M:%S"))
    # a light ring keeps the darkest band colours visible on the dark basemap
    m <- m |>
      leaflet::addCircleMarkers(lng = matched$lon[o], lat = matched$lat[o],
                                radius = 5, stroke = TRUE, color = "#FFFFFF",
                                weight = 1, opacity = 0.6, fillOpacity = 0.95,
                                fillColor = fill[o], popup = popup[o],
                                label = sprintf("%s: %s", pollutant, signif(vals[o], 4)),
                                group = "Readings")

    m <- if (!is.null(bands)) {
      leaflet::addLegend(m, "bottomright", colors = bands$color,
                         labels = band_labels(bands), title = pollutant, opacity = 1)
    } else {
      leaflet::addLegend(m, "bottomright", pal = pal, values = vals,
                         title = pollutant, opacity = 1)
    }
  }

  m |> leaflet::fitBounds(min(track$lon), min(track$lat), max(track$lon), max(track$lat))
}
