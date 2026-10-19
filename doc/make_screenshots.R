# Screenshots for doc/user-guide.qmd: start the app, load the demo data in a
# headless Chrome and capture each step into doc/images/.
# Run from the project folder:  Rscript doc/make_screenshots.R
port <- 8765
out_dir <- file.path("doc", "images")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
gpx <- normalizePath("example/demo_track.gpx")
csv <- normalizePath("example/demo_sensors.csv")

app <- processx::process$new(
  "Rscript", c("-e", sprintf("shiny::runApp(port = %d, launch.browser = FALSE)", port)),
  stdout = "|", stderr = "2>&1"
)
on.exit(app$kill(), add = TRUE)
for (i in 1:60) {
  ok <- tryCatch({ readLines(sprintf("http://127.0.0.1:%d", port), warn = FALSE); TRUE },
                 error = function(e) FALSE)
  if (ok) break
  Sys.sleep(0.5)
}
if (!ok) stop("App did not start:\n", app$read_all_output())

b <- chromote::ChromoteSession$new(width = 1400, height = 2000)
on.exit(b$close(), add = TRUE)

js <- function(code) invisible(b$Runtime$evaluate(code))
wait <- function(s = 2) Sys.sleep(s)
shot <- function(name, selector = "html", ...) {
  b$screenshot(file.path(out_dir, paste0(name, ".png")), selector = selector,
               scale = 2, delay = 0.5, ...)
}
upload <- function(id, path) {
  root <- b$DOM$getDocument()$root$nodeId
  node <- b$DOM$querySelector(root, paste0("#", id))$nodeId
  b$DOM$setFileInputFiles(files = list(path), nodeId = node)
}
set_number <- function(id, value) {
  js(sprintf("$('#%s').val(%s).trigger('change');", id, value))
}

b$Page$navigate(sprintf("http://127.0.0.1:%d", port))
b$Page$loadEventFired()
wait(4)  # fonts and map tiles
# tall window so every card is on screen (no scrolling); fixed map height
js("$('.pm-map').css('height', '620px'); $('.pm-timeseries').css('height', '480px');")
wait(1)

# 1. empty app
shot("01-start", cliprect = c(0, 0, 1400, 900))
shot("01-sidebar", ".bslib-sidebar-layout > .sidebar")

# 2. GPX only: the faint track
upload("gpx", gpx); wait(4)
shot("02-track", ".card:has(.pm-map)")

# 3. both files: coloured readings, chart, summary
upload("sensors", csv); wait(5)
shot("03-loaded", cliprect = c(0, 0, 1400, 900))
shot("03-map", ".pm-map")
shot("05-summary", ".bslib-value-box")

# 4. measurement dropdown, then PM10 on the map
js("$('#pollutant')[0].selectize.open();"); wait(1)
shot("04-measurement", ".bslib-sidebar-layout > .sidebar")
js("var s = $('#pollutant')[0].selectize; s.setValue('pm10'); s.close();"); wait(4)
shot("04-pm10-map", ".pm-map")
js("var s = $('#pollutant')[0].selectize; s.setValue('pm25');"); wait(4)

# 5. click a reading: open the popup of the highest value
js("
  var map = HTMLWidgets.find('#map').getMap(), last = null;
  map.eachLayer(function (l) { if (l instanceof L.CircleMarker) last = l; });
  if (last) { map.setView(last.getLatLng(), 17); last.openPopup(); }
"); wait(4)
shot("05-popup", ".pm-map")

# 6. time series
shot("06-timeseries", ".card:has(.pm-timeseries)")

# 7. overlap warnings via the clock offset
set_number("offset", 2700); wait(4)
shot("07-partial", ".pm-flag")
set_number("offset", 7200); wait(4)
shot("07-none", ".pm-flag")
set_number("offset", 0); wait(4)

# 8. download button
shot("08-download", "#download", region = "margin")

message("Screenshots written to ", out_dir)
