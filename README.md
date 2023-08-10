
<!-- README.md is generated from README.Rmd. Please edit that file -->

# faviconPlease

[![CRAN
status](https://www.r-pkg.org/badges/version/faviconPlease)](https://cran.r-project.org/package=faviconPlease)
[![R-CMD-check](https://github.com/jdblischak/faviconPlease/workflows/R-CMD-check/badge.svg)](https://github.com/jdblischak/faviconPlease/actions)

Finds the URL to the ‘favicon’ for a website. This is useful if you want
to display the ‘favicon’ in an HTML document or web application,
especially if the website is behind a firewall.

``` r
library(faviconPlease)
faviconPlease("https://github.com/")
```

    ## [1] "https://github.githubassets.com/favicons/favicon.svg"

Also check out my [blog post on
faviconPlease](https://blog.jdblischak.com/posts/faviconplease/) for
more background and examples.

## Installation

Install latest release from CRAN:

``` r
install.packages("faviconPlease")
```

Install development version from GitHub:

``` r
install.packages("remotes")
remotes::install_github("jdblischak/faviconPlease")
```

## Code of Conduct

Please note that the faviconPlease project is released with a
[Contributor Code of
Conduct](https://contributor-covenant.org/version/2/0/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.

## Default strategy

By default, `faviconPlease()` uses the following strategy to find the
URL to the favicon for a given website. It stops once it finds a URL and
returns it.

1.  Download the HTML file and search its `<head>` for any `<link>`
    elements with `rel="icon"` or `rel="shortcut icon"`.

2.  Download the HTML file at the root of the server (i.e. discard the
    path) and search its `<head>` for any `<link>` elements with
    `rel="icon"` or `rel="shortcut icon"`.

3.  Attempt to download a file called `favicon.ico` at the root of the
    server. This is the default location that a browser looks if the
    HTML file does not specify an alternative location in a `<link>`
    element. If the file `favicon.ico` is successfully downloaded, then
    this URL is returned.

4.  If the above steps fail, as a fallback, use the [favicon
    service](https://duckduckgo.com/duckduckgo-help-pages/privacy/favicons/)
    provided by the search engine [DuckDuckGo](https://duckduckgo.com/).
    This provides a nice default for websites that don’t have a favicon
    (or can’t be easily found).

## Extending faviconPlease

The default strategy above is designed to reliably get you a favicon URL
for most websites. However, you can customize it as needed.

### Change the fallback to use Google’s favicon service

The default fallback function is `faviconDuckDuckGo()`. To instead use
Google’s favicon service, you can set the argument
`fallback = faviconGoogle`.

Note that neither DuckDuckGo nor Google have every favicon you might
expect. And the availability can change over time. You can see some
examples in my [blog
post](https://blog.jdblischak.com/posts/faviconplease/). Fortunately
they both provide a generic favicon to insert when they don’t have the
favicon.

### Use a custom fallback function

You can use your own custom fallback function instead. It must accept
one argument, which is the server, e.g. `"github.com"`. The easiest
approach would be to copy-paste one of the existing fallback functions
and modify it to use your alternative favicon service.

``` r
args(faviconDuckDuckGo)
```

    ## function (server) 
    ## NULL

``` r
body(faviconDuckDuckGo)
```

    ## {
    ##     iconService <- "https://icons.duckduckgo.com/ip3/%s.ico"
    ##     favicon <- sprintf(iconService, server)
    ##     return(favicon)
    ## }

### Use a custom fallback favicon

If you have a URL to a generic favicon file that you would like to use
as a fallback, you can directly pass this as a character vector. It
could also be a path to an image file on the server where your app is
running.

### Change the order of the favicon functions

The default strategy first checks the `<head>` for a link to the favicon
file and then checks for the availability of the file `favicon.ico`. You
can change this order, or only perform one of them, by changing the
argument `functions` passed to `faviconPlease()`. It should be a list of
functions.

``` r
# default
functions = list(faviconLink, faviconIco)
# Switch the order
functions = list(faviconIco, faviconLink)
# Only search <head>
functions = list(faviconLink)
# Only check for favicon.ico
functions = list(faviconIco)
# Skip the favicon functions entirely and just use the fallback
functions = NULL
```

### Use a custom favicon function

You can also create your own custom favicon function to pass to
`faviconPlease()`. By default it must accept 3 arguments. It will be
passed the URL’s scheme (e.g. `"https"`), server (e.g. `"github.com"`),
and path (e.g. `"/jdblischak/faviconPlease"`). Your function should
return the URL to a favicon or an empty string, `""`, if it can’t find
one.

``` r
# Favicon functions must accept at least 3 positional arguments
args(faviconLink)
```

    ## function (scheme, server, path) 
    ## NULL

As a concrete example, here is a custom function for searching for
`favicon.ico` on Ubuntu 20.04, which has increased security settings
(see troubleshooting section below).

``` r
faviconIcoUbuntu20 <- function(scheme, server, path) {
  faviconIco(scheme, server, path, method = "wget",
             extra = c("--no-check-certificate",
                       "--ciphers=DEFAULT:@SECLEVEL=1"))
}
```

It calls `faviconIco()` with the specific settings needed by
`download.file()` to work on Ubuntu 20.04. You could then use your
custom function instead of the default `faviconIco()` by calling
`faviconPlease()` with
`functions = list(faviconLink, faviconIcoUbuntu20)`.

Note that the example function `faviconIcoUbuntu20()` will likely fail
on Windows, macOS, and Ubuntu versions prior to 20.04.

## Troubleshooting

Unfortunately it’s not easy to make this fool proof for all operating
systems and all websites. Here are some known issues:

1.  `download.file()`, used by `faviconIco()`, is known to have
    cross-platform issues. Thus the official documentation in
    `?download.file` recommends:

    > Setting the `method` should be left to the end user.

    Accordingly, `faviconIco()` exposes the arguments `method`, `extra`,
    and `headers`, which are passed directly to `download.file()`.
    Alternatively you can set the global options
    `"download.file.method"` or `"download.file.extra"`.

2.  Ubuntu 20.04 increased its default security settings for downloading
    files from the internet
    ([details](https://bugs.launchpad.net/ubuntu/+source/openssl/+bug/1864689)).
    Unfortunately many websites have not updated their SSL certificates
    to comply with the increased security restrictions. `faviconLink()`
    has a workaround for this situation, but not `faviconIco()`. As an
    example, here’s how you could detect the availability of favicon.ico
    for the Ensembl website on Ubuntu 20.

    ``` r
    faviconIco("https", "www.ensembl.org", "",
               method = "wget", extra = c("--no-check-certificate",
                                              "--ciphers=DEFAULT:@SECLEVEL=1"))
    ```

    Alternatively, if it’s an option for you, you could avoid this
    workaround by using the previous Ubuntu LTS release 18.04. Also note
    that the above command will fail on Ubuntu 18.04 because the default
    `wget` installed doesn’t have the argument `--ciphers`.
