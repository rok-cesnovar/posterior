#' The `draws_rvars` format
#'
#' @name draws_rvars
#' @family formats
#'
#' @templateVar draws_format draws_rvars
#' @templateVar base_class "list"
#' @template draws_format-skeleton
#' @template args-format-nchains
#'
#' @details Objects of class `"draws_rvars"` are lists of [rvar] objects. See **Examples**.
#'
NULL

#' @rdname draws_rvars
#' @export
as_draws_rvars <- function(x, ...) {
  UseMethod("as_draws_rvars")
}

#' @rdname draws_rvars
#' @export
as_draws_rvars.default <- function(x, ...) {
  x <- as_draws(x)
  as_draws_rvars(x, ...)
}

#' @rdname draws_rvars
#' @export
as_draws_rvars.draws_rvars <- function(x, ...) {
  x
}

#' @rdname draws_rvars
#' @export
as_draws_rvars.list <- function(x, ...) {
  .as_draws_rvars(x, ...)
}

#' @rdname draws_rvars
#' @export
as_draws_rvars.draws_matrix <- function(x, ...) {
  # split x[y,z] names into base name and indices
  vars_indices <- strsplit(variables(x), "(\\[|\\])")
  vars <- sapply(vars_indices, `[[`, 1)

  # pull out each var into its own rvar
  var_names <- unique(vars)
  rvars_list <- lapply(var_names, function (var) {
    var_i <- vars == var
    var_matrix <- x[, var_i, drop = FALSE]

    if (ncol(var_matrix) == 1) {
      # single variable, no indices
      out <- rvar(var_matrix)
      dimnames(out) <- NULL
    } else {
      # variable with indices => we need to reshape the array
      # basically, we're going to do a bunch of work up front to figure out
      # a single array slice that does most of the work for us.

      # first, pull out the list of indices into a data frame
      # where each column is an index variable
      indices <- sapply(vars_indices[var_i], `[[`, 2)
      indices <- as.data.frame(do.call(rbind, strsplit(indices, ",")))
      # for numeric indices, we need to convert them to numerics
      # so that we can sort them in numerical order (not string order)
      for (i in seq_along(indices)) {
        numeric_index <- suppressWarnings(as.numeric(indices[[i]]))
        if (!anyNA(numeric_index)) indices[[i]] = numeric_index
      }

      # sort indices and fill in missing indices as NA to ensure
      # (1) even if the order of the variables is something weird (like the
      # column for x[2,2] comes before x[1,1] in the matrix) the result
      # places those columns in the correct cells of the array
      # (2) if some combination of indices is missing (say x[2,1] isn't
      # in the input) that cell in the array gets an NA
      unique_indices <- lapply(indices, function(x) sort(unique(x)))
      # reverse indices here because merge() will do a sort automatically
      # and we need it to sort in reverse order of the indices (because
      # the value of the last index should move slowest)
      all_indices <- expand.grid(rev(unique_indices))
      # merge with all.x = TRUE (left join) to fill in missing cells with NA
      indices <- merge(all_indices, cbind(indices, index = seq_len(nrow(indices))), all.x = TRUE)

      # re-sort the array and fill in missing cells with NA
      var_matrix <- var_matrix[, indices$index, drop = FALSE]

      #convert to rvar and adjust dimensions
      out <- rvar(var_matrix)
      .dimnames <- unname(unique_indices)
      dim(out) <- c(lengths(.dimnames))
      dimnames(out) <- .dimnames
    }
    out
  })
  names(rvars_list) <- var_names
  as_draws_rvars(rvars_list)
}

#' @rdname draws_rvars
#' @export
as_draws_rvars.draws_df <- function(x, ...) {
  stop("TODO: IMPLEMENT")
}

#' @rdname draws_rvars
#' @export
as_draws_rvars.draws_list <- function(x, ...) {
  stop("TODO: IMPLEMENT")
}

#' @rdname draws_rvars
#' @export
as_draws_rvars.mcmc <- function(x, ...) {
  as_draws_rvars(as_draws_matrix(x), ...)
}

#' @rdname draws_rvars
#' @export
as_draws_rvars.mcmc.list <- function(x, ...) {
  as_draws_rvars(as_draws_array(x), ...)
}

# try to convert any R object into a 'draws_rvars' object
.as_draws_rvars <- function(x) {
  x <- as.list(x)
  # convert all elements to rvars
  x <- lapply(x, as_rvar)
  # replace blank variable names with defaults
  if (is.null(names(x))) {
    names(x) <- default_variables(length(x))
  } else {
    blank_names <- nchar(names(x)) == 0
    names(x)[blank_names] <- default_variables(length(x))[blank_names]
  }
  check_new_variables(names(x))
  if (length(unique(sapply(x, ndraws))) != 1L)  {
    stop2("All variables must have the same number of draws.")
  }
  # TODO: check nchains is it was set

  class(x) <- class_draws_rvars()
  x
}

#' @rdname draws_rvars
#' @export
draws_rvars <- function(..., .nchains = 1) {
  # TODO: should this be as_rvar or rvar? depends on desired constructor...
  out <- lapply(list(...), as_rvar)
  if (!rlang::is_named(out)) {
    stop2("All variables must be named.")
  }
  .nchains <- as_one_integer(.nchains)
  if (.nchains < 1) {
    stop2("Number of chains must be positive.")
  }
  .ndraws <- ndraws(out[[1]])
  if (.ndraws %% .nchains != 0) {
    stop2("Number of chains does not divide the number of draws.")
  }
  # TODO: store nchains somewhere, maybe as an attribute
  as_draws_rvars(out)
}

class_draws_rvars <- function() {
  c("draws_rvars", "draws", "list")
}

#' @rdname draws_rvars
#' @export
is_draws_rvars <- function(x) {
  inherits(x, "draws_rvars")
}

# is an object looking like a 'draws_rvars' object?
is_draws_rvars_like <- function(x) {
  is.list(x) && all(sapply(x, is_rvar))
}

#' @export
`[.draws_rvars` <- function(x, i, j, ..., drop = FALSE) {
  # TODO: add a warning that 'drop' is ignored?
  out <- NextMethod("[", drop = FALSE)
  class(out) <- class(x)
  out
}

# create an empty draws_rvars object
empty_draws_rvars <- function(variables = character(0), nchains = 0) {
  assert_character(variables, null.ok = TRUE)
  assert_number(nchains, lower = 0)
  out <- named_list(variables, rvar())
  class(out) <- class_draws_rvars()
  out
}