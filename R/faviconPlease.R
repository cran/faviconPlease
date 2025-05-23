#' Find the URL to a website's favicon
#'
#' \code{faviconPlease()} first applies the favicon functions specified in the
#' argument \code{functions}. If these do not find a favicon URL, then it
#' applies the fallback function specified by the argument \code{fallback}.
#'
#' @param links Character vector of URLs
#' @param functions List of functions for finding URL to a website's favicon.
#'   They are tried in order until a URL is found. If no URL is found, the
#'   fallback is applied.
#' @param fallback Either a function or a single character vector. It is
#'   applied when none of the supplied functions are able to find a favicon.
#'
#' @return Character vector with URLs to the favicons for the websites specified
#'   in the input argument \code{links}. The URLs are generated from one of the
#'   favicon functions specified in the input argument \code{functions}. If a
#'   favicon URL cannot be identified, then the returned URL is generated by the
#'   input argument \code{fallback}.
#'
#' @seealso \code{\link{faviconLink}},
#'          \code{\link{faviconIco}},
#'          \code{\link{faviconDuckDuckGo}},
#'          \code{\link{faviconGoogle}}
#'
#' @export
faviconPlease <- function(
  links,
  functions = list(faviconLink, faviconIco),
  fallback = faviconDuckDuckGo
) {

  if (!is.character(links)) {
    stop("The argument `links` must be a character vector of URLs")
  }

  if (!validFunctions(functions)) {
    stop("The argument `functions` must be a list of functions or NULL")
  }

  if (!validFallback(fallback)) {
    stop("The argument `fallback` must be a function with one argument or a single character string")
  }

  linksParsed <- xml2::url_parse(links)
  favicons <- character(length = length(links))

  for (i in seq_along(links)) {
    scheme <- linksParsed[i, "scheme"]
    server <- linksParsed[i, "server"]
    path <- linksParsed[i, "path"]

    for (favFunc in functions) {
      favicons[i] <- tryCatch(
        favFunc(scheme, server, path),
        error = function(e) return("")
      )
      if (favicons[i] != "") break
    }

    if (favicons[i] == "") {
      if (is.function(fallback)) {
        favicons[i] <- fallback(server)
      } else {
        favicons[i] <- fallback
      }
    }

  }

  return(favicons)
}

#' Search for a link element that specifies the location of the favicon
#'
#' @param scheme "http" or "https"
#' @param server The name of the server, e.g. "www.r-project.org"
#' @param path The path to a target file on the server (must start with a
#'   forward slash)
#'
#' @return URL to favicon or \code{""}.
#'
#' @seealso \code{\link{faviconPlease}},
#'          \code{\link{faviconIco}}
#'
#' @export
faviconLink <- function(scheme, server, path) {
  if (scheme == "file") { # primarily for testing purposes
    if (.Platform$OS.type == "windows") {
      filepath <- sub("^/", "", path)
    } else {
      filepath <- path
    }
    xml <- xml2::read_html(filepath)
  } else {
    siteUrl <- sprintf("%s://%s%s", scheme, server, path)
    xml <- readHtml(siteUrl)
    # If that returned an empty result, try the base URL
    if (xml2::xml_length(xml) == 0) {
      siteUrlBase <- sprintf("%s://%s", scheme, server)
      xml <- readHtml(siteUrlBase)
    }
  }
  xpath <- "/html/head/link[@rel = 'icon' or @rel = 'shortcut icon']"
  linkElement <- xml2::xml_find_first(xml, xpath)
  href <- xml2::xml_attr(linkElement, "href")
  if (is.na(href)) return("")

  # Check for HTML element `base` to modify relative links
  # https://developer.mozilla.org/en-US/docs/Web/HTML/Element/base
  baseElement <- xml2::xml_find_first(xml, "/html/head/base")
  baseLink <- xml2::xml_attr(baseElement, "href")
  if (!is.na(baseLink)) {
    href <- paste0(baseLink, href)
  }

  # The link in href could be absolute, protocol-relative, root-relative, or
  # relative
  if (startsWith(href, "http")) { # absolute
    favicon <- href
  } else if (startsWith(href, "//")) { # protocol-relative
    favicon <- sprintf("%s:%s", scheme, href)
  } else if (startsWith(href, "/")) { # root-relative
    favicon <- sprintf("%s://%s%s", scheme, server, href)
  } else { # relative
    # This is experimental. I need a good test case to improve it. Fortunately
    # this is quite rare.
    warning("Support for relative URLs to icons is experimental. Please open an Issue if this fails.")
    pathRelative <- file.path(dirname(path), href)
    favicon <- sprintf("%s://%s%s", scheme, server, pathRelative)
  }
  return(favicon)
}

readHtml <- function(theUrl) {
  theUrlConnection <- url(theUrl)

  # If it works right away, exit early with the result
  xml <- try(xml2::read_html(theUrlConnection), silent = TRUE)
  if (!inherits(xml, "try-error")) {
    return(xml)
  }
  close(theUrlConnection)

  # If the suggested package httr is installed, try downloading the file without
  # authenticating the SSL certificate
  if (requireNamespace("httr", quietly = TRUE)) {
    os <- Sys.info()["sysname"]
    if (os == "Linux") {
      curlOpts <- httr::config(
        ssl_verifypeer = 0L,
        ssl_cipher_list = "DEFAULT@SECLEVEL=1"
      )
    } else {
      curlOpts <- httr::config(
        ssl_verifypeer = 0L
      )
    }
    theUrlDownloaded <- httr::RETRY(
      verb = "GET",
      url = theUrl,
      config = curlOpts,
      quiet = TRUE
    )
    if (!httr::http_error(theUrlDownloaded)) {
      return(xml2::read_html(theUrlDownloaded))
    }
  }

  # If neither xml2 nor httr can download the file, return an empty XML doc
  return(xml2::xml_new_root("empty"))
}

#' Check for the existence of favicon.ico
#'
#' @inheritParams faviconLink
#' @inheritParams utils::download.file
#'
#' @return URL to \code{favicon.ico} or \code{""}.
#'
#' @seealso \code{\link{faviconPlease}},
#'          \code{\link{faviconLink}}
#'
#' @export
faviconIco <- function(
  scheme,
  server,
  path,
  method = getOption("download.file.method", default = "auto"),
  extra = getOption("download.file.extra"),
  headers = NULL
) {
  favicon <- sprintf("%s://%s/favicon.ico", scheme, server)
  response <- tryCatch(
    suppressWarnings(
      utils::download.file(
        url = favicon,
        destfile = nullfile(),
        method = method,
        quiet = TRUE,
        extra = extra,
        headers = headers
      )
    ),
    error = function(e) return(1)
  )
  if (response == 0) {
    return(favicon)
  } else {
    return("")
  }
}

#' Use DuckDuckGo's favicon service
#'
#' The search engine \href{https://duckduckgo.com/}{DuckDuckGo} includes site
#' favicons in its search results, and it makes this service publicly available.
#' If it can't find a favicon, it returns a default fallback. faviconPlease uses
#' this as a fallback function if the favicon can't be found directly via the
#' standard methods.
#'
#' @inheritParams faviconLink
#'
#' @return Character vector
#'
#' @examples
#'   faviconDuckDuckGo("reactome.org")
#'
#' @references
#'   \href{https://duckduckgo.com/duckduckgo-help-pages/privacy/favicons/}{DuckDuckGo favicons privacy}
#'
#' @seealso \code{\link{faviconPlease}},
#'          \code{\link{faviconGoogle}}
#'
#' @export
faviconDuckDuckGo <- function(server) {
  iconService <- "https://icons.duckduckgo.com/ip3/%s.ico"
  favicon <- sprintf(iconService, server)
  return(favicon)
}

#' Use Google's favicon service
#'
#' @inheritParams faviconLink
#'
#' @return Character vector
#'
#' @examples
#'   faviconGoogle("reactome.org")
#'
#' @seealso \code{\link{faviconPlease}},
#'          \code{\link{faviconDuckDuckGo}}
#'
#' @export
faviconGoogle <- function(server) {
  iconService <- "https://www.google.com/s2/favicons?domain_url=%s"
  favicon <- sprintf(iconService, server)
  return(favicon)
}

validFunctions <- function(functions) {
  if (is.null(functions)) return(TRUE)

  if (!is.list(functions)) return(FALSE)

  eachIsFunction <- vapply(functions, is.function, logical(1))
  if (!all(eachIsFunction)) return(FALSE)

  return(TRUE)
}

validFallback <- function(fallback) {
  if (is.character(fallback) && length(fallback) == 1) {
    return(TRUE)
  }

  if (is.function(fallback) && length(formals(fallback)) == 1) {
    return(TRUE)
  }

  return(FALSE)
}
