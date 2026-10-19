# Air-quality track map: upload a GPX track + a sensor CSV, align them by time,
# and map pollutant values along the route. Functions live in R/ (auto-sourced).
library(shiny)
library(bslib)

options(shiny.maxRequestSize = 100 * 1024^2)

ui <- page_sidebar(
  title = pm_header("Track map"),
  window_title = "ParticularMatter · Track map",
  theme = pm_theme(),
  # scrolling page: cards keep their own (user-resizable) heights
  fillable = FALSE,
  tags$head(
    tags$link(rel = "icon", type = "image/svg+xml", href = "particularmatter-favicon.svg"),
    tags$link(rel = "stylesheet", href = "pm.css"),
    tags$script(src = "resize.js")
  ),
  sidebar = sidebar(
    width = 320,
    fileInput("gpx", "GPX track", accept = ".gpx"),
    fileInput("sensors", "Sensor data (CSV)", accept = ".csv"),
    selectInput("pollutant", "Measurement", choices = NULL),
    numericInput("offset", "Sensor clock offset (s)", value = 0, step = 1),
    numericInput("max_gap", "Max track gap (s)", value = 30, min = 1, step = 1),
    downloadButton("download", "Download CSV", class = "btn-pm"),
    tags$footer(
      class = "pm-credits",
      tags$a(href = "https://github.com/theRosyProject/particularmatter-gpx",
             target = "_blank", rel = "noopener", "Source code on GitHub"),
      tags$p("Credits: Federico Dallo (CNR) · Marta Coronado (UAB)")
    )
  ),
  uiOutput("overlap_flag"),
  # drag the bottom-right corner of the map or chart to resize it
  card(
    full_screen = TRUE,
    card_header("Map"),
    div(class = "pm-resizable pm-map", leaflet::leafletOutput("map", height = "100%"))
  ),
  card(
    full_screen = TRUE,
    card_header("Over time"),
    div(class = "pm-resizable pm-timeseries",
        plotly::plotlyOutput("timeseries", height = "100%"))
  ),
  uiOutput("summary")
)

server <- function(input, output, session) {
  track <- reactive({
    req(input$gpx)
    tryCatch(read_gpx(input$gpx$datapath),
             error = function(e) validate(paste("Could not read GPX:", conditionMessage(e))))
  })

  sensors <- reactive({
    req(input$sensors)
    tryCatch(read_sensors(input$sensors$datapath),
             error = function(e) validate(paste("Could not read sensor CSV:", conditionMessage(e))))
  })

  observeEvent(sensors(), {
    p <- attr(sensors(), "pollutants")
    updateSelectInput(session, "pollutant", choices = p,
                      selected = if ("pm25" %in% p) "pm25" else p[1])
  })

  offset <- reactive(if (is.numeric(input$offset) && !is.na(input$offset)) input$offset else 0)

  overlap <- reactive(check_overlap(track(), sensors(), offset()))

  matched <- reactive({
    gap <- if (is.numeric(input$max_gap) && !is.na(input$max_gap)) input$max_gap else 30
    align_sensors_track(sensors(), track(), offset(), gap)
  })

  output$overlap_flag <- renderUI({
    req(input$gpx, input$sensors)
    ov <- overlap()
    if (ov$status == "ok") return(NULL)
    fmt <- function(r) paste(format(r, "%Y-%m-%d %H:%M:%S"), collapse = " \u2192 ")
    ranges <- tags$ul(
      tags$li("Track: ", fmt(ov$track_range), " UTC"),
      tags$li("Sensors: ", fmt(ov$sensor_range), " UTC",
              if (offset() != 0) sprintf(" (offset %+g s applied)", offset()))
    )
    if (ov$status == "none") {
      where <- if (ov$gap_s > 0) "starts %s after the track ends" else "ends %s before the track starts"
      pm_flag("danger", "No time overlap",
              sprintf(paste0("The sensor data ", where,
                             ". Check that both files are from the same outing, or adjust the clock offset."),
                      format_duration(ov$gap_s)),
              ranges)
    } else {
      pm_flag("warn", "Partial overlap",
              sprintf("Only %.0f%% of the sensor readings fall within the track.",
                      100 * ov$share_inside),
              ranges)
    }
  })

  output$map <- leaflet::renderLeaflet({
    validate(need(input$gpx, "Upload a GPX track and a sensor CSV to map air quality along the route."))
    tr <- track()
    m <- if (isTruthy(input$sensors) && overlap()$status != "none") matched() else NULL
    aq_map(m, tr, input$pollutant)
  })

  output$summary <- renderUI({
    req(input$gpx, input$sensors)
    layout_column_wrap(
      width = 1 / 3, fill = FALSE,
      value_box("Track points", format(nrow(track()), big.mark = ",")),
      value_box("Sensor readings", format(nrow(sensors()), big.mark = ",")),
      value_box("Matched readings", format(nrow(matched()), big.mark = ","))
    )
  })

  output$timeseries <- plotly::renderPlotly({
    validate(need(input$sensors, "Upload sensor data to see readings over time."))
    req(input$pollutant, input$pollutant %in% names(sensors()))
    s <- sensors()
    tr <- if (isTruthy(input$gpx)) range(track()$time) else NULL
    # same colours as the map: a neutral line, points coloured by band
    vals <- s[[input$pollutant]]
    vc <- value_colors(input$pollutant, vals)
    level <- if (is.null(vc$level)) "" else paste0(" · ", vc$level)
    p <- plotly::plot_ly(x = s$time + offset(), y = vals, type = "scatter",
                         mode = "lines+markers", name = input$pollutant,
                         line = list(color = "rgba(255,255,255,0.35)", width = 2),
                         marker = list(color = vc$fill, size = 7,
                                       line = list(color = "rgba(255,255,255,0.6)", width = 1)),
                         text = level,
                         hovertemplate = "%{y}%{text}<br>%{x|%H:%M:%S} UTC<extra></extra>")
    shapes <- if (!is.null(tr)) list(list(type = "rect", xref = "x", yref = "paper",
                                          x0 = tr[1], x1 = tr[2], y0 = 0, y1 = 1, layer = "below",
                                          fillcolor = "rgba(255,255,255,0.06)", line = list(width = 0)))
    axis <- list(gridcolor = "rgba(255,255,255,0.06)", zeroline = FALSE,
                 linecolor = "rgba(255,255,255,0.12)", color = PM_COLORS$text_dim)
    p <- plotly::layout(p, shapes = shapes, margin = list(t = 10),
                        paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
                        font = list(family = "Inter, sans-serif", color = PM_COLORS$text),
                        hovermode = "x", hoverlabel = list(bgcolor = PM_COLORS$bg_alt,
                                                           bordercolor = PM_COLORS$teal),
                        xaxis = c(axis, list(title = "Time (UTC) · shaded = track")),
                        yaxis = c(axis, list(title = input$pollutant)))
    plotly::config(p, displaylogo = FALSE)
  })

  output$download <- downloadHandler(
    filename = function() {
      paste0(tools::file_path_sans_ext(input$gpx$name %||% "track"), "_air_quality.csv")
    },
    content = function(file) {
      out <- matched()
      out$time <- format(out$time, "%Y-%m-%dT%H:%M:%SZ")
      readr::write_csv(out, file, na = "")
    }
  )
}

shinyApp(ui, server)
