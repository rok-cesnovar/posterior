% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/extract_variable_matrix.R
\name{extract_variable_matrix}
\alias{extract_variable_matrix}
\alias{extract_variable_matrix.default}
\alias{extract_variable_matrix.draws}
\alias{extract_variable_matrix.draws_rvars}
\title{Extract matrix of a single variable}
\usage{
extract_variable_matrix(x, variable, ...)

\method{extract_variable_matrix}{default}(x, variable, ...)

\method{extract_variable_matrix}{draws}(x, variable, ...)

\method{extract_variable_matrix}{draws_rvars}(x, variable, ...)
}
\arguments{
\item{x}{(draws) A \code{draws} object or another \R object for which the method
is defined.}

\item{variable}{(string) The name of the variable to extract.}

\item{...}{Arguments passed to individual methods (if applicable).}
}
\value{
A \code{matrix} with dimension iterations x chains.
}
\description{
Extract an iterations x chains matrix of draws of a single variable.
This is primarily used for convergence diagnostic functions such as \code{\link[=rhat]{rhat()}}.
}
\examples{
x <- example_draws()
mu <- extract_variable_matrix(x, variable = "mu")
dim(mu)
rhat(mu)

}
