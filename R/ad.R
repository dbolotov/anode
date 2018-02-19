#' ad: anomaly detection with normal probability functions.
#'
#' @param formula An object of class "formula": a symbolic description of the
#' model to be fitted.
#' @param data A data frame containing the features (predictors) and target.
#' @param x A matrix of numeric features.
#' @param y A vector of numeric target values, either 0 or 1, with 1
#' assumed to be anomalous.
#' @param na.action A function specifying the action to be taken if NAs are
#' found.
#' @param ... Currently not used.
#'
#' @return An object of class \code{ad}:
#'   \item{call}{The original call to \code{ad}.}
#'   \item{epsilon}{The threshold value.}
#'
#' @details
#'
#' \code{amelie} implements anomaly detection with normal probability functions
#' and maximum likelihood estimates.
#'
#' Features are assumed to be continuous, and the target is assumed to take
#' on values of 0 (negative case, no anomaly) or 1 (positive case, anomaly).
#'
#' The threshold \code{epsilon} is optimized using the F1 score.
#'
#' Algorithm details are described in the Introduction vignette.
#'
#' The package follows the anomaly detection approach in Andrew Ng's course on
#' machine learning.
#'
#' @references
#' \url{https://www.coursera.org/learn/machine-learning}
#'
#' @examples
#' # Examples go here.
#'
#'@importFrom stats sd


#'@export
ad <- function(x, ...){
  UseMethod("ad")
}

#'@rdname ad
#'@export
ad.formula <- function(formula, data, na.action = na.omit, ...) {
  call <- match.call()
  if (!inherits(formula, "formula"))
    stop("method is only for formula objects")

  if (!all(sapply(data,is.numeric))) {
    stop("Both x and y must be numeric.")
  }

  m <- match.call(expand.dots = FALSE)
  if (identical(class(eval.parent(m$data)), "matrix"))
    m$data <- as.data.frame(eval.parent(m$data))

  m[[1L]] <- quote(stats::model.frame)
  m$na.action <- na.action

  m <- eval(m, parent.frame())
  Terms <- attr(m, "terms")
  attr(Terms, "intercept") <- 0

  x <- model.matrix(Terms, m)
  y <- model.extract(m, "response")
  attr(x, "na.action") <- attr(y, "na.action") <- attr(m, "na.action")

  return_object <- ad.default(x, y, na.action = na.action)
  return_object$call <- call
  return_object$call[[1]] <- as.name("ad")
  return_object$terms <- Terms
  if (!is.null(attr(m, "na.action")))
    return_object$na.action <- attr(m, "na.action")
  class(return_object) <- c("ad.formula", class(return_object))
  return (return_object)
}



#' @rdname ad
#' @export
ad.default <- function(x, y, na.action = na.omit, ...) {

  #check data
  .check_data(x,y)

  #split data into training and cross-validation sets
  split_obj <- .split_data(x,y)
  train_x <- split_obj$train_x
  # train_y <- split_obj$train_y #not used, and always expected to be 0
  val_x <- split_obj$val_x
  val_y <- split_obj$val_y


  #compute mean and variance of training set
  train_x_mean <- .mean2(train_x)
  train_x_sd <- .sd2(train_x)

  #compute product of probabilities on training set
  train_x_probs_prod <- .univariate_gaussian(train_x,train_x_mean,train_x_sd)
  val_x_probs_prod <- .univariate_gaussian(val_x,train_x_mean,train_x_sd)

  #optimize epsilon using validation set
  epsilon <- .op_epsilon(val_x_probs_prod,val_y)

  #compute predictions on training set
  val_predictions <- as.numeric(val_x_probs_prod < epsilon)

  #compute f1 score on validation set
  val_score <- .f1_score(val_predictions, val_y)


  # create the return object
  call <- match.call()
  return_obj <- list(call = call,
                     epsilon = epsilon,
                     train_x_mean = train_x_mean,
                     train_x_sd = train_x_sd,
                     # val_predictions = val_predictions,
                     val_score = val_score)
  class(return_obj) <- "ad"
  return(return_obj)
}


#' @rdname ad
#' @export
print.ad <- function(x, ...) {
  cat("Call:\n")
  print(x$call)
  cat("\n")
  cat("epsilon: ",x$epsilon,sep="")
}
