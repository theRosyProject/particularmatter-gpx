# ParticularMatter visual identity (particularmatter.org/setup.html).
PM_COLORS <- list(
  bg = "#212529", bg_alt = "#24292E", text = "#C4C5C6", text_dim = "#8A9096",
  teal = "#61FFD0", yellow = "#F6C90E", coral = "#FF6B6B"
)

# Sequential ramp for values on a dark map: one hue (brand teal), dim -> bright,
# so higher readings stand out. Lowest step keeps >= 3.7:1 contrast on dark tiles.
PM_RAMP <- grDevices::colorRampPalette(c("#2A8C76", "#61FFD0", "#E6FFF7"), space = "Lab")(256)

pm_theme <- function() {
  bslib::bs_theme(
    version = 5,
    bg = PM_COLORS$bg, fg = PM_COLORS$text,
    primary = PM_COLORS$teal, secondary = PM_COLORS$bg_alt,
    warning = PM_COLORS$yellow, danger = PM_COLORS$coral,
    base_font = bslib::font_google("Inter", wght = c(300, 400, 500, 700), local = FALSE),
    heading_font = bslib::font_google("Antonio", wght = c(500, 700), local = FALSE),
    code_font = bslib::font_google("Fira Code", wght = c(400, 500), local = FALSE),
    "font-weight-base" = 300,
    "headings-color" = "#FFFFFF",
    "border-radius" = "0.875rem"
  )
}

pm_header <- function(app_name) {
  shiny::tags$span(
    class = "pm-logo",
    shiny::tags$img(src = "particularmatter-favicon.svg", alt = "ParticularMatter"),
    shiny::tags$span(class = "pm-wordmark", shiny::HTML("Particular<mark>Matter</mark>")),
    shiny::tags$span(class = "pm-app-name", app_name)
  )
}

# Overlap flag in the site's info-box style: icon + label + text, never colour alone.
pm_flag <- function(level = c("warn", "danger"), title, ...) {
  level <- match.arg(level)
  icon <- shiny::HTML(paste0(
    '<svg viewBox="0 0 24 24" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">',
    '<path d="M12 3 2 21h20L12 3z"/><path d="M12 10v5"/><path d="M12 18h.01"/></svg>'))
  shiny::div(class = paste("pm-flag", level), role = "alert", icon,
             shiny::div(shiny::tags$h4(title), ...))
}
