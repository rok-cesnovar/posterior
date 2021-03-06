# function for making rvars from arrays that expects last index to be
# draws (for testing so that when array structure changes tests don't have to)
rvar_from_array = function(x) {
  .dim = dim(x)
  last_dim = length(.dim)
  new_rvar(aperm(x, c(last_dim, seq_len(last_dim - 1))))
}

# creating rvars ----------------------------------------------------------

test_that("rvar creation with custom dim works", {
  x_matrix <- array(1:24, dim = c(2,12))
  x_array <- array(1:24, dim = c(2,3,4))

  expect_equal(rvar(x_matrix, dim = c(3,4)), rvar(x_array))
})

test_that("rvar can be created with specified number of chains", {
  x_array <- array(1:20, dim = c(4,5))

  expect_error(rvar(x_array, nchains = 0))
  expect_equal(rvar(x_array, nchains = 1), rvar(x_array))
  expect_equal(nchains(rvar(x_array, nchains = 2)), 2)
  expect_error(rvar(x_array, nchains = 3), "Number of chains does not divide the number of draws")
})


# unique, duplicated, etc -------------------------------------------------

test_that("unique.rvar and duplicated.rvar work", {
  x <- rvar_from_array(matrix(c(1,2,1, 1,2,1, 3,3,3), nrow = 3))
  unique_x <- rvar_from_array(matrix(c(1,2, 1,2, 3,3), nrow = 2))

  expect_equal(unique(x), unique_x)
  expect_equal(as.vector(duplicated(x)), c(FALSE, FALSE, TRUE))
  expect_equal(anyDuplicated(x), 3)

  x <- rvar(array(c(1,2, 2,3, 1,2, 3,3, 1,2, 2,3), dim = c(2, 2, 3)))
  unique_x <- x
  unique_x_2 <- rvar(array(c(1,2, 2,3, 1,2, 3,3), dim = c(2, 2, 2)))
  expect_equal(unique(x), unique_x)
  expect_equal(unique(x, MARGIN = 2), unique_x_2)
})


# tibbles -----------------------------------------------------------------

test_that("rvars work in tibbles", {
  skip_if_not_installed("dplyr")
  skip_if_not_installed("tidyr")

  x_array = array(1:20, dim = c(4,5))
  x = rvar_from_array(x_array)
  df = tibble::tibble(x, y = x + 1)

  expect_identical(df$x, x)
  expect_identical(df$y, rvar_from_array(x_array + 1))
  expect_identical(dplyr::mutate(df, z = x)$z, x)

  expect_equal(dplyr::mutate(df, z = x * 2)$z, rvar_from_array(x_array * 2))
  expect_equal(
    dplyr::mutate(dplyr::group_by(df, 1:4), z = x * 2)$z,
    rvar_from_array(x_array * 2)
  )

  df = tibble::tibble(g = letters[1:4], x)
  ref = tibble::tibble(
    a = rvar_from_array(x_array[1,, drop = FALSE]),
    b = rvar_from_array(x_array[2,, drop = FALSE]),
    c = rvar_from_array(x_array[3,, drop = FALSE]),
    d = rvar_from_array(x_array[4,, drop = FALSE])
  )
  expect_equal(tidyr::pivot_wider(df, names_from = g, values_from = x), ref)
  expect_equal(tidyr::pivot_longer(ref, a:d, names_to = "g", values_to = "x"), df)

  df$y = df$x + 1
  ref2 = tibble::tibble(
    y = df$y,
    a = c(df$x[[1]], NA, NA, NA),
    b = c(rvar(NA), df$x[[2]], NA, NA),
    c = c(rvar(NA), NA, df$x[[3]], NA),
    d = c(rvar(NA), NA, NA, df$x[[4]]),
  )
  expect_equal(tidyr::pivot_wider(df, names_from = g, values_from = x), ref2)
})

# broadcasting ------------------------------------------------------------

test_that("broadcast_array works", {
  expect_equal(broadcast_array(5, c(1,2,3,1)), array(rep(5, 6), dim = c(1,2,3,1)))
  expect_equal(
    broadcast_array(array(1:4, c(1,4)), c(2,4)),
    array(rep(1:4, each = 2), c(2,4))
  )
  expect_equal(
    broadcast_array(array(1:4, c(4,1)), c(4,2)),
    array(c(1:4, 1:4), c(4,2))
  )

  expect_error(broadcast_array(array(1:9, dim = c(3,3)), c(1,9)))
  expect_error(broadcast_array(array(1:9, dim = c(3,3)), c(9)))
})


# conforming chains / draws -----------------------------------------------

test_that("warnings for unequal draws/chains are correct", {
  expect_warning(
    expect_equal(rvar(1:10) + rvar(1:10, nchains = 2), rvar(1:10 + 1:10)),
    "chains were dropped"
  )

  expect_error(
    draws_rvars(x = rvar(1:10), y = rvar(1:11)),
    "variables have different number of draws"
  )

  expect_error(
    rvar(1:10, nchains = 0),
    "chains must be >= 1"
  )
})

# rep ---------------------------------------------------------------------

test_that("rep works", {
  x_array = array(1:10, dim = c(5,2))
  x = rvar(x_array)

  expect_equal(rep(x, times = 3), new_rvar(cbind(x_array, x_array, x_array)))
  expect_equal(rep.int(x, 3), new_rvar(cbind(x_array, x_array, x_array)))
  each_twice = cbind(x_array[,1], x_array[,1], x_array[,2], x_array[,2])
  expect_equal(rep(x, each = 2), new_rvar(each_twice))
  expect_equal(rep(x, each = 2, times = 3), new_rvar(cbind(each_twice, each_twice, each_twice)))
  expect_equal(rep(x, length.out = 3), new_rvar(cbind(x_array, x_array[,1])))
  expect_equal(rep_len(x, 3), new_rvar(cbind(x_array, x_array[,1])))
})

# all.equal ---------------------------------------------------------------------

test_that("all.equal works", {
  x_array = array(1:10, dim = c(5,2))
  x = rvar(x_array)

  expect_true(all.equal(x, x))
  expect_true(!isTRUE(all.equal(x, x + 1)))
  expect_true(!isTRUE(all.equal(x, "a")))
})

# apply functions ---------------------------------------------------------

test_that("apply family functions work", {
  x_array = array(1:24, dim = c(2,3,4))
  x = rvar(x_array)

  expect_equal(lapply(x, function(x) sum(draws_of(x))), as.list(apply(draws_of(x), 2, sum)))
  expect_equal(sapply(x, function(x) sum(draws_of(x))), apply(draws_of(x), 2, sum))
  expect_equal(vapply(x, function(x) sum(draws_of(x)), numeric(1)), apply(draws_of(x), 2, sum))
  expect_equal(apply(x, 1, function(x) sum(draws_of(x))), apply(draws_of(x), 2, sum))
  expect_equal(apply(x, 1:2, function(x) sum(draws_of(x))), apply(draws_of(x), 2:3, sum))
})
