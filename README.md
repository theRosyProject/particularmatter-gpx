# ParticularMatter Track Map

Map the air you breathed along your route.

This is a small R Shiny app that combines two files:

- a **GPS track** (`.gpx`, e.g. exported from Strava), which says *where* you were, and
- an **air-quality sensor log** (`.csv`, e.g. from a ParticularMatter / KongQi node), which says *what* the sensor measured.

The app matches the two by time and draws a **map of your route coloured by
pollution level**, plus a time series. You can then download the combined
data as a single CSV.

It uses the visual style and air-quality colour bands of
[ParticularMatter](https://particularmatter.org/setup.html).

---

## Contents

- [Quick start](#quick-start)
- [Using the app](#using-the-app)
- [Input files](#input-files)
- [How matching works](#how-matching-works)
- [Colour bands](#colour-bands)
- [Output CSV](#output-csv)
- [Demo data](#demo-data)
- [Project structure](#project-structure)
- [Running the tests](#running-the-tests)
- [Deploying to shinyapps.io](#deploying-to-shinyappsio)
- [Troubleshooting](#troubleshooting)
- [Credits](#credits)

---

## Quick start

### 1. Install R

You need **R 4.1 or newer** ([download R](https://cran.r-project.org/)).
[RStudio](https://posit.co/download/rstudio-desktop/) is optional but convenient.

### 2. Install the packages (once)

In an R console:

```r
install.packages(c(
  "shiny", "bslib", "leaflet", "plotly",
  "xml2", "readr", "dplyr", "lubridate", "tibble",
  "testthat"  # only needed to run the tests
))
```

### 3. Start the app

**From RStudio:** open `particularmatter-gpx.Rproj`, open `app.R`, then click **Run App**.

**From an R console** (with the project folder as working directory):

```r
shiny::runApp()
```

**From a terminal:**

```sh
cd path/to/particularmatter-gpx
Rscript -e 'shiny::runApp(launch.browser = TRUE)'
```

The app opens in your browser. Press `Ctrl+C` in the terminal (or the stop
button in RStudio) to quit.

> An internet connection is needed for the map tiles and fonts.

---

## Using the app

1. **Upload a GPX track.**
   On Strava: open the activity on the website, click **⋯** and choose
   **Export GPX**. Any GPX 1.1 file with timestamps works (Garmin, Komoot, phone apps, …).
2. **Upload the sensor CSV.**
   For a KongQi node, this is the log file copied from the SD card.
3. **Pick a measurement** (PM2.5, PM10, CO₂, temperature, …) in the sidebar.
4. **Read the map.** Each dot is one sensor reading, placed where you were at
   that moment and coloured by its air-quality band. Click a dot to see its
   value, band and time.
5. **Check the time series** below the map. The shaded area is the period
   covered by the GPS track.
6. **Download the combined data** with **Download CSV**.

### Tips

- **Resize** the map or the chart by dragging the teal handle in its
  bottom-right corner, or use the full-screen button in the card's corner.
- **Clock offset:** if the sensor clock was wrong by a known amount, enter the
  correction in seconds (positive moves the sensor data later). The map and
  chart update immediately.
- **Max track gap:** readings taken while the GPS track has a gap longer than
  this (e.g. recording paused) are dropped instead of being placed on a
  straight line between the two ends of the gap. Default: 30 s.

### Warnings about time overlap

If the two files don't cover the same period, a banner appears above the map:

- 🔴 **No time overlap**: the files don't share any time. The banner shows
  both time ranges and how far apart they are. Usually this means files from
  different outings were loaded, or the sensor clock is wrong.
- 🟡 **Partial overlap**: fewer than half of the sensor readings fall within
  the track. Check that the sensor clock was set correctly.

---

## Input files

### GPS track (`.gpx`)

A standard GPX file. The app reads every track point (`<trkpt>`) that has a
`<time>`; elevation (`<ele>`) is used when present.

### Sensor log (`.csv`)

One row per reading, with a header row. Expected columns:

| Column | Required | Meaning |
|---|---|---|
| `gps_datetime` | one of the two | Time from the sensor's GPS, ISO 8601 in UTC, e.g. `2026-10-12T08:05:10Z` |
| `wifi_datetime` | one of the two | Time from the internet (NTP), same format; used when there is no GPS time |
| `ts_ms` | optional | Milliseconds since the device started. Used to estimate the time of rows that have neither timestamp |
| `pm1`, `pm25`, `pm10`, `co2`, `temperature`, `humidity`, `pressure`, … | at least one | Measurements. **Any other numeric column** is also treated as a measurement and can be mapped |
| `lat`, `lng`, `altitude`, `hdop`, `satellites`, `gps_valid` | optional | The sensor's own GPS info; ignored (the GPX track is used for position) |

Example:

```csv
gps_datetime,wifi_datetime,ts_ms,pm1,pm25,pm10,co2,temperature,humidity,pressure,lat,lng,altitude,hdop,satellites,gps_valid
2026-10-12T08:05:10Z,,615000,30,43,68,606,22.16,67.33,1016.02,44.493500,11.342687,54.1,1.72,11,1
,2026-10-12T08:05:20Z,625000,28,40,61,598,22.20,67.10,1016.01,,,,,,0
```

---

## How matching works

1. **One time per reading.** The app uses the GPS time if present, otherwise
   the internet time. If a row has neither, its time is estimated from
   `ts_ms`, counting from the nearest row that does have a time. A drop in
   `ts_ms` is treated as a device restart.
2. **Clock offset.** The offset you enter is added to every sensor time.
3. **Position.** For each reading inside the track's time range, the position
   (and elevation) is interpolated between the two nearest GPS points.
   Readings before or after the track, or inside a gap longer than *Max track
   gap*, are left out.

All times are handled in **UTC**.

---

## Colour bands

The map and time series use the same thresholds and colours as the
ParticularMatter dashboard. PM1 uses the PM2.5 bands. Values are in µg/m³
unless noted.

| Level | PM2.5 / PM1 | Colour | PM10 | Colour |
|---|---|---|---|---|
| Good | 0 – 12 | `#68E143` | 0 – 15 | `#22c55e` |
| Moderate | 12.1 – 35.4 | `#ffcf55` | 15.1 – 45 | `#f59e0b` |
| Unhealthy for Sensitive Groups | 35.5 – 55.4 | `#EF8533` | 45.1 – 106 | `#f97316` |
| Unhealthy | 55.5 – 150.4 | `#EA3324` | 106.1 – 255 | `#ef4444` |
| Very Unhealthy | 150.5 – 250.4 | `#8C1A4B` | 255.1 + | `#dc2626` |
| Hazardous | 250.5 + | `#731425` | – | – |

| Measurement | Bands |
|---|---|
| CO₂ (ppm) | Good ≤ 800 · Moderate ≤ 1000 · Poor ≤ 1500 · Very Poor > 1500 |
| Temperature (°C) | Cold < 10 · Cool 10–17.9 · Comfortable 18–23.9 · Warm 24–27.9 · Hot ≥ 28 |
| Humidity (%) | Dry < 30 · Comfortable 30–59.9 · Humid 60–69.9 · Very Humid ≥ 70 |
| Pressure (hPa) | Extreme Low < 980 · Low < 1000 · Normal < 1020 · High < 1040 · Extreme High ≥ 1040 |

Any other measurement is shown on a teal scale from dim (low) to bright (high).

The bands are defined in [`R/bands.R`](R/bands.R). They mirror the
dashboard's `frontend/src/components/AirQualityChart.tsx`; keep the two in
sync when either changes.

---

## Output CSV

**Download CSV** gives one row per matched reading:

| Column | Meaning |
|---|---|
| `time` | Reading time in UTC (with the clock offset applied) |
| `lat`, `lon`, `ele` | Position and elevation interpolated from the GPX track |
| `pm1`, `pm25`, `pm10`, `co2`, … | All measurement columns from the sensor file |
| `time_source` | Where the time came from: `gps`, `wifi` or `ts_ms` (estimated) |

---

## Demo data

The `example/` folder contains a synthetic one-hour walk around a block in
central Bologna, with a matching sensor log:

- `example/demo_track.gpx`: two laps, one point per second
- `example/demo_sensors.csv`: one reading every 10 seconds

The south side of the block is a busy road, so PM is clearly higher there.
Load both files in the app to see it.

To regenerate them (the result is always the same):

```sh
Rscript scripts/make_example_data.R
```

---

## Project structure

```
app.R                     The Shiny app: layout and server logic
R/                        Helper functions (loaded automatically by Shiny)
  read_gpx.R              Read a GPX file into a table of time, lat, lon, ele
  read_sensors.R          Read the sensor CSV and build one time per reading
  align.R                 Check time overlap and match readings to positions
  bands.R                 Air-quality bands and colours (from the dashboard)
  map.R                   Build the Leaflet map
  theme.R                 ParticularMatter colours, fonts and header
www/                      Files served to the browser
  pm.css                  Visual style
  resize.js               Redraws the map/chart when resized
  particularmatter-favicon.svg
scripts/
  make_example_data.R     Generates the demo data in example/
example/                  Demo GPX and sensor CSV
tests/testthat/           Automated tests
```

---

## Running the tests

```sh
Rscript -e 'testthat::test_dir("tests/testthat")'
```

A few tests use real recordings (`example/Morning_Hike.gpx`,
`example/2026-10-12_log.csv`) that are not part of the repository. They are
skipped automatically when those files are missing.

---

## Deploying to shinyapps.io

1. Copy `.Renviron.example` to `.Renviron` and fill in your account name,
   token and secret (shinyapps.io → **Account → Tokens → Show**).
   `.Renviron` is git-ignored: never commit it.
2. Install `rsconnect` once: `install.packages("rsconnect")`.
3. Deploy from the project folder:

   ```sh
   Rscript scripts/deploy.R
   ```

Only `app.R`, `R/` and `www/` are uploaded. Run the same command again to
update the app.

---

## Troubleshooting

| Problem | What to do |
|---|---|
| Red **No time overlap** banner | Make sure both files are from the same outing. If the sensor clock was wrong, set the **clock offset**. |
| Map shows only a grey line, no dots | No readings fall within the track's time range; see the banner above the map. |
| Map tiles or fonts don't load | The app needs an internet connection for map tiles and fonts. |
| "Could not read GPX" | The file must be a GPX with `<trkpt>` points that have `<time>`. Re-export it from Strava. |
| "Could not read sensor CSV" | The CSV needs a `gps_datetime` and/or `wifi_datetime` column (see [Input files](#input-files)). |
| Upload rejected as too large | The limit is 100 MB per file. Change `shiny.maxRequestSize` at the top of `app.R`. |
| `there is no package called …` | Install the missing package (see [Quick start](#quick-start)). |

---

## Credits

- **Federico Dallo**: [federico.dallo@cnr.it](mailto:federico.dallo@cnr.it)
- **Marta Coronado**: [Marta.Coronado@uab.cat](mailto:Marta.Coronado@uab.cat)

See also [CREDITS.md](CREDITS.md).
Source code: <https://github.com/theRosyProject/particularmatter-gpx>
