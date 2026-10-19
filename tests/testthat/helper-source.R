root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
for (f in list.files(file.path(root, "R"), full.names = TRUE)) source(f)
example_file <- function(name) file.path(root, "example", name)

# Real recordings (Strava export + sensor log) are optional local files;
# tests that need them skip when they are absent.
skip_without_example <- function(...) {
  for (name in c(...)) testthat::skip_if_not(file.exists(example_file(name)),
                                             paste("missing example/", name))
}
