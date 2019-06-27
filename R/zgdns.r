ipv4_regex <-
  "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"

S_GET <- safely(httr::GET)

#' Perform DNS over HTTPS queries using Google
#'
#' Traditional DNS queries and responses are sent over UDP or TCP without
#' encryption. This is vulnerable to eavesdropping and spoofing (including
#' DNS-based Internet filtering). Responses from recursive resolvers to clients
#' are the most vulnerable to undesired or malicious changes, while
#' communications between recursive resolvers and authoritative nameservers
#' often incorporate additional protection.\cr
#' \cr
#' To address this problem, Google Public DNS offers DNS resolution over an
#' encrypted HTTPS connection. DNS-over-HTTPS greatly enhances privacy and
#' security between a client and a recursive resolver, and complements DNSSEC
#' to provide end-to-end authenticated DNS lookups.
#'
#' To perform vectorized queries with only answers (and no metadata) use
#' \code{bulk_query()}).
#'
#' @param name item to lookup. Valid characters are numbers, letters, hyphen, and dot. Length
#'        must be between 1 and 255. Names with escaped or non-ASCII characters
#'        are not supported. Internationalized domain names must use the
#'        punycode format (e.g. "\code{xn--qxam}").\cr
#'        \cr If an IPv4 string is input, it will be transformed into
#'        a proper format for reverse lookups.
#' @param type RR type can be represented as a number in [1, 65535] or canonical
#'        string (A, aaaa, etc). More information on RR types can be
#'        found \href{http://www.iana.org/assignments/dns-parameters/dns-parameters.xhtml#dns-parameters-4}{here}.
#'        You can use \code{255} for an \code{ANY} query.
#' @param cd (Checking Disabled) flag. Use `TRUE` to disable DNSSEC validation;
#'        Default: `FALSE`.
#' @param do (DNSSEC OK) flag. Use `TRUE` include DNSSEC records (RRSIG, NSEC, NSEC3);
#'        Default: `FALSE`.
#' @param random_padding clients concerned about possible side-channel privacy
#'        attacks using the packet sizes of HTTPS GET requests can use this to
#'        make all requests exactly the same size by padding requests with random data.
#'        To prevent misinterpretation of the URL, restrict the padding characters to
#'        the unreserved URL characters: upper- and lower-case letters, digits,
#'        hyphen, period, underscore and tilde.
#' @param edns_client_subnet The edns0-client-subnet option. Format is an IP
#'        address with a subnet mask. Examples: \code{1.2.3.4/24},
#'        \code{2001:700:300::/48}.\cr
#'        If you are using DNS-over-HTTPS because of privacy concerns, and do
#'        not want any part of your IP address to be sent to authoritative
#'        nameservers for geographic location accuracy, use
#'        \code{edns_client_subnet=0.0.0.0/0}. Google Public DNS normally sends
#'        approximate network information (usually replacing the last part of
#'        your IPv4 address with zeroes). \code{0.0.0.0/0} is the default.
#' @return a \code{list} with the query result or \code{NULL} if an error occurred
#' @references <https://developers.google.com/speed/public-dns/docs/doh/json>
#' @export
#' @examples
#' query("rud.is")
#' dig("example.com", "255") # ANY query
#' query("microsoft.com", "MX")
#' dig("google-public-dns-a.google.com", "TXT")
#' query("apple.com")
#' dig("17.142.160.59", "PTR")
query <- function(name, type = "1", cd = FALSE, do = FALSE,
                  edns_client_subnet = "0.0.0.0/0",
                  random_padding = NULL) {

  name <- name[1]

  # helper to turn IPv4 addresses in to in-addr.arpa.

  if (grepl(ipv4_regex, name)) {
    name <- paste0(c(rev(unlist(stringi::stri_split_fixed(name, ".", 4))),
                     "in-addr.arpa."),
                   sep="", collapse=".")
  }

  res <- S_GET(
    url = "https://dns.google/resolve",
    query = list(
      name = name,
      type = type,
      cd = if (cd) 1 else 0,
      do = if (do) 1 else 0,
      ct = "application/x-javascript",
      edns_client_subnet = edns_client_subnet,
      random_padding = random_padding
    )
  )

  if (!is.null(res$result)) {
    stop_for_status(res$result)
    txt <- httr::content(res$result, as="text")
    txt <- stringi::stri_enc_toascii(txt)
    txt <- stringi::stri_replace_all_regex(txt, "[[:cntrl:][:blank:]\\n ]+", " ")
    out <- jsonlite::fromJSON(txt)
    class(out) <- c("gdns_response", "list")
    out
  } else {
    NULL
  }

}

#' @rdname query
#' @export
dig <- query
