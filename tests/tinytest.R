# See inst/tinytest/ for test files

# Check internet connection (only works on unix-alike)
checkInternet <- function(site = "www.r-project.org") {
  os <- .Platform$OS.type
  if (os == "windows") {
    return(NA)
  }
  hasInternet <- !is.null(suppressWarnings(utils::nsl(site)))
  if (!hasInternet) message("No internet connection")
  return(invisible(hasInternet))
}
checkInternet()

# Only run all tests if using a development version (which has 4 components,
# e.g. 0.0.0.1). CRAN releases have the standard 3 component version. This
# prevents spurious errors due to websites changing how they serve their
# favicon.
version <- utils::packageVersion("faviconPlease")
home <- length(unclass(version)[[1]]) == 4

if (requireNamespace("tinytest", quietly = TRUE)){
  tinytest::test_package("faviconPlease", at_home = home)
}
