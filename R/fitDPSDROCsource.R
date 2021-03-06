#' Estimation of recollection and familiarity by fitting source memory ROC data with the Dual Process Signal Detection (DPSD) model
#'
#' This function allows to estimate recollection and familiarity for source memory data by fitting data to the DPSD model.
#' The optimization is attempted by minimizing the total squared difference between observed and
#' predicted cumulative hit and false alarm rates using the Broyden-Fletcher-Goldfarb-Shanno (BFGS) algorithm in \code{\link{optim}}.
#' The function uses random start values on each iteration in order to find the set of parameters,
#' which fit the data best by returning the values with the lowest total squared difference.
#' Optional arguments in the function allow the user to specify an equal-variance model and/or specify if recollection is
#' to be estimated as a separate parameter for both target and lure items.
#' Recollection is bounded to be between 0 and 1, Familiarity and the standard deviation of the target distribution to be positive.
#' Criteria are unbounded.
#' A high number of iterations is necessary to avoid local minima.
#'
#' @author Nicholas Lange, \email{lange.nk@gmail.com}
#' @param falseAlarms A vector containing the cumulative source false alarm rate.
#' @param hit A vector containing the cumulative source hit rate.
#' @param iterations A numeric value specifying the number of iterations. Default is set to 200.
#' @param eqRecollection A boolean value specifying if recollection is set equal for the target and lure source (TRUE) or is estimates separately for both sources (FALSE). Default is set to FALSE.
#' @param eqVar A boolean value specifying if the standard deviation of the target distribution is equal to that of the lure distribution (i.e. = 1) (TRUE) or estimated separately (FALSE). Default is set to TRUE.
#' @return The function returns a dataframe with components:
#' \item{(parameters)}{The estimated parameters (recollection_target, recollection_lure, familiarity, sd_target, criteria) for the iteration with the lowest SumSquareError}
#' \item{SSE}{Minimum sum square error}
#' @references Yonelinas, A. P. (1999). The Contribution of Recollection and Familiarity to Recognition and Source-Memory Judgments: A Formal Dual-Process Model and an Analysis of Receiver Operating Characteristics. Journal of Experimental Psychology: Learning, Memory, and Cognition, 25(6), 1415 - 1434. http://doi.org/10.1037//0278-7393.25.6.1415
#' @keywords ROC recollection familiarity DPSD
#' @export

fitDPSDROCsource <- function(falseAlarms, hit, iterations = 200, eqVar = TRUE, eqRecollection = FALSE){

  if (length(falseAlarms) != length(hit)) ('Vectors containing hit and false alarm rates do not have the same length')

  parameters            <- c()
  results               <- c()
  value                 <- c()

  # Function calculating total squared prediction error for hit and false alarm rates
  solver  <- function(x) {
    if (eqVar == TRUE & eqRecollection == FALSE) {
      rt <- exp(x[1]) / (1 + exp(x[1]))
      rl <- exp(x[2]) / (1 + exp(x[2]))
      dpri <- exp(x[3])
      sd_target <- 1
      crit <- c()
      for (i in c(1:length(falseAlarms))) {
        crit[i] <- x[3 + i]
      }
    } else if (eqVar == FALSE & eqRecollection == FALSE) {
      rt <- exp(x[1]) / (1 + exp(x[1]))
      rl <- exp(x[2]) / (1 + exp(x[2]))
      dpri <- exp(x[3])
      sd_target <- exp(x[4])
      crit <- c()
      for (i in c(1:length(falseAlarms))) {
        crit[i] <- x[4 + i]
      }
    } else if (eqVar == TRUE & eqRecollection == TRUE) {
      rt <- exp(x[1]) / (1 + exp(x[1]))
      rl <- rt
      dpri <- exp(x[2])
      sd_target <- 1
      crit <- c()
      for (i in c(1:length(falseAlarms))) {
        crit[i] <- x[2 + i]
      }
    } else if (eqVar == FALSE & eqRecollection == TRUE) {
      rt <- exp(x[1]) / (1 + exp(x[1]))
      rl <- rt
      dpri <- exp(x[2])
      sd_target <- exp(x[3])
      crit <- c()
      for (i in c(1:length(falseAlarms))) {
        crit[i] <- x[3 + i]
      }
    }



    predhit          <- (1 - rt) * stats::pnorm(crit,-dpri / 2, sd_target) + rt
    predfalseAlarm   <- (1 - rl) * stats::pnorm(crit, dpri / 2, 1)

    sqdiffhit        <- (hit - predhit) * (hit - predhit)
    sqdifffalseAlarm <- (falseAlarms - predfalseAlarm) * (falseAlarms - predfalseAlarm)
    total            <- sum(sqdiffhit) + sum(sqdifffalseAlarm)
    return(total)
  }

  # starting parameters

  for (i in 1:iterations) {
    x0 <- NULL
    if (eqVar == TRUE & eqRecollection == FALSE) {
      rstart <- stats::runif(1, 0.2, 0.7)
      x0 <-
        c(log(rstart / (1 - rstart)),
          log(rstart / (1 - rstart)),
          log(truncnorm::rtruncnorm(1, 0.4, 0.1, a = 0)),
          stats::runif(length(falseAlarms), min = -5, 5))

    } else if (eqVar == FALSE & eqRecollection == FALSE) {
      rstart <- stats::runif(1, 0.2, 0.7)
      x0 <-
        c(log(rstart / (1 - rstart)),
          log(rstart / (1 - rstart)),
          log(truncnorm::rtruncnorm(1, 0.4, 0.4, a = 0)),
          log(truncnorm::rtruncnorm(1, 1, 0.5, a = 0)),
          stats::runif(length(falseAlarms), min = -5, 5)
        )

    } else if (eqVar == TRUE & eqRecollection == TRUE) {
      rstart <- stats::runif(1, 0.2, 0.7)
      x0 <- c(log(rstart / (1 - rstart)),
              log(truncnorm::rtruncnorm(1, 0.4, 0.1, a = 0)),
              stats::runif(length(falseAlarms), min = -5, 5))

    } else {
      rstart <- stats::runif(1, 0.2, 0.7)
      x0 <- c(log(rstart / (1 - rstart)),
              log(truncnorm::rtruncnorm(1, 0.4, 0.1, a = 0)),
              log(truncnorm::rtruncnorm(1, 1, 0.4, a = 0)),
              stats::runif(length(falseAlarms), min = -5, 5))
    }



    cat('\rProgress: |',rep('=',floor((i/iterations)*50)),rep(' ',50 - floor((i/iterations)*50)),'|', sep = '')

    # optimize
    control <- list('maxit', 10000000, 'reltol', 0.0000000001)
    temp    <- try(stats::optim(x0, solver, method = "BFGS", control = control), silent = TRUE)

    # Move to next iteration if it crashes out of one
    if (class(temp) == "try-error") {
      parameters[i]        <- NA
      value[i]             <- NA
    } else {
      parameters           <- rbind(parameters, temp$par)
      value                <- rbind(value, temp$value)
    }

  }

  # Identify best-fitting
  Best <- parameters[which(value == min(value, na.rm = TRUE)),]

  # Prepare output
  Bestcolumns <- c("recollection_target","recollection_lure","familiarity","sd_target")
  fanames<-NULL
  for (i in c(1:length(falseAlarms))){
    fanames[i] <- paste0("c",i)
  }
  resultscolnames<-c(Bestcolumns,fanames,"SSE")

  tempresult <- NULL
  if (eqVar == TRUE & eqRecollection == FALSE) {
    tempresult <-
      c(exp(Best[1]) / (1 + exp(Best[1])),
        exp(Best[2]) / (1 + exp(Best[2])),
        exp(Best[3]),
        1,
        Best[4:length(Best)],
        min(value))

  } else if (eqVar == FALSE & eqRecollection == FALSE) {
    tempresult <-
      c(exp(Best[1]) / (1 + exp(Best[1])),
        exp(Best[2]) / (1 + exp(Best[2])),
        exp(Best[3]),
        exp(Best[4]),
        Best[5:length(Best)],
        min(value)
      )

  } else if (eqVar == TRUE & eqRecollection == TRUE) {
    tempresult <-
      c(exp(Best[1]) / (1 + exp(Best[1])),
        exp(Best[1]) / (1 + exp(Best[1])),
        exp(Best[2]),
        1,
        Best[3:length(Best)],
        min(value))

  } else {
    tempresult <-
      c(exp(Best[1]) / (1 + exp(Best[1])),
        exp(Best[1]) / (1 + exp(Best[1])),
        exp(Best[2]),
        exp(Best[3]),
        Best[4:length(Best)],
        min(value)
      )
  }

  results <- as.data.frame(matrix(tempresult,nrow=1, dimnames = list(NULL, resultscolnames)))
  cat('\n')
  cat('\n')
  return(results)
}
