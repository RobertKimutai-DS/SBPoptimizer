#' Utility Functions
#'
#' @name utils
NULL

#' Null-default operator
#' @param x Left side
#' @param y Right side (default value)
#' @return x if not NULL, otherwise y
#' @export
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
