# Deploy the app to shinyapps.io.
# Credentials come from .Renviron in the project folder (git-ignored, never
# committed). Copy .Renviron.example to .Renviron and fill it in first.
# Run from the project folder:  Rscript scripts/deploy.R
if (file.exists(".Renviron")) readRenviron(".Renviron")

env <- Sys.getenv(c("SHINYAPPS_ACCOUNT", "SHINYAPPS_TOKEN", "SHINYAPPS_SECRET"))
missing <- names(env)[env == ""]
if (length(missing) > 0) {
  stop("Missing in .Renviron: ", paste(missing, collapse = ", "),
       "\nCopy .Renviron.example to .Renviron and fill it in.", call. = FALSE)
}

rsconnect::setAccountInfo(name = env[["SHINYAPPS_ACCOUNT"]],
                          token = env[["SHINYAPPS_TOKEN"]],
                          secret = env[["SHINYAPPS_SECRET"]])

# only what the app needs at runtime: no docs, tests or scripts
rsconnect::deployApp(
  appDir = ".",
  appName = Sys.getenv("SHINYAPPS_APP_NAME", "particularmatter-gpx"),
  appFiles = c("app.R", list.files("R", full.names = TRUE),
               list.files("www", full.names = TRUE)),
  account = env[["SHINYAPPS_ACCOUNT"]],
  server = "shinyapps.io",
  launch.browser = interactive()
)
