N_break_point <- function(serie, n_max = 1, n_period=10,
                          seed=FALSE, auto_select = FALSE,
                          alpha = NULL,method='SNHT',dstr='norm',
                          seed_set = 9658, change_random_seed = TRUE,
                          seed_method = 6842){
  # select method
  if(!change_random_seed){
    if(exists(x = '.Random.seed')){
      old_random <- .Random.seed
    }
  }
  if(!is.null(seed_set)){
    if(is.numeric(seed_set)){
      set.seed(seed_set)
    }else{
      stop(paste0('seed_set must be either NULL or a number to use as argument to set.seed'))
    }
  }

  if(!is.logical(seed)){
    if(length(seed) != n_max){
      stop('The given seed is not supported. If seed is given must be of length n_max')
    }
  }

  {
    if( method == 'pettit'){
      fun <- pettit
    }else if( method == 'student'){
      fun <- stu
    }else if( method == 'mann-whitney'){
      fun <- man.whi
    }else if( method == 'buishand'){
      fun <- function(x,n_period){
        return(Buishand_R(serie = x,n_period = n_period,dstr = dstr, seed_set = seed_method))
      }
    }else if( method == 'SNHT'){
      fun <- function(x,n_period){
        return(SNHT(serie = x,n_period = n_period,dstr = dstr, seed_set = seed_method))
      }
    }else{stop('Not supported method')}
  }


  target <- as.vector(serie)
  n_targ <- length(target)
  isna <- as.numeric(is.na(target))
  n_period_2 <- as.integer(n_period)
  ii <- c(rep(0,n_period_2),rollapply(isna,width=n_period+1,sum),rep(0,n_period_2))
  ii <- which(ii >= (n_period_2/2))
  if(length(ii) > 1){
    na_break <- c(ii , n_targ+1)
    ii_aux <- ii[2:length(ii)] - ii[1:(length(ii)-1)]
    ii_aux <- ii_aux < 10
    jump <- c(ii[1]<n_period_2,ii_aux,n_targ+1-ii[length(ii)]<n_period_2)
  }else if(length(ii) == 1){
    na_break <- c(ii , n_targ+1)
    jump <- c(ii<n_period_2,n_targ+1-ii<n_period_2)
  }else{
    na_break <- n_targ+1
    jump <- FALSE
  }
  new_target <- target
  new_n_targ <- n_targ
  output <- list()
  n_max_new <- n_max
  outputcont <- 0
  for(new_serie in 1:length(na_break)){
    n_max <- n_max_new
    if(new_serie == 1){
      if(jump[1]){next}
      ini <- 0
      target <- new_target[1:(na_break[new_serie]-1)]
    }else{
      if(jump[new_serie]){next}
      ini <- na_break[new_serie-1]-1
      target <- new_target[na_break[new_serie-1]:(na_break[new_serie]-1)]
    }
    outputcont <- outputcont +1

    n_targ <- length(target)
    if((n_max+1)*n_period > n_targ-2){
      n_max <- n_targ%/%n_period-1
      if(n_max < 1){
        if(length(na_break) > 1){
          warning(('Not possible to find breakpoints in part of the serie, too short'))
          outputcont <- outputcont - 1; next
        }else{
          stop('Not possible to find breakpoints, target serie too short')
        }
      }
      warning(paste0('the given n is too big for the target and n_period length, ',n_max, ' will be use as maximal amount of breakpoints') )
    }
    output_aux <- list(breaks = list(),p.value=list(),n=list())
    for(n in 1:n_max){
      if(is.logical(seed)){
        breaks <- as.integer(1:n * (n_targ/(n+1)))+1
      }else{
        if(length(seed[[n]])==n){
          breaks <- seed[[n]]
        }else{
          warning(paste('The seed provided at',n,'breaks differs in length equal space break seed will be use instead',sep=' '))
          breaks <- as.integer(1:n * (n_targ/(n+1)))+1
        }
      }
      breaks <- sort(breaks,decreasing = F)
      p <- rep(1,length(breaks))
      breaks_old <- rep(0,length(breaks))
      if(n == 1){
        ff <- fun(target,n_period)
        breaks <- ff$breaks
        p <- ff$p.value
      }else {
        no_problem <- T
        iters <- 0
        breaks_old_old_old <-breaks
        breaks_old_old <-breaks
        p_old_old <- p
        p_old <- p
        while (any(breaks_old != breaks) & no_problem){
          iters <- iters + 1
          breaks_old_old_old <- breaks_old_old
          breaks_old_old <- breaks_old
          breaks_old <- breaks
          p_old_old <- p_old
          p_old <- p
          for(i in 1:n){
            if(i == 1){
              aux <- target[1:(breaks[2]-1)]
              break_aux <- 0
            }else if(i == n){
              aux <- target[breaks[n-1]:n_targ]
              break_aux <- breaks[n-1]-1
            }else{
              aux <- target[breaks[i-1]:(breaks[i+1]-1)]
              break_aux <- breaks[i-1]-1
            }

            ff <- fun(aux,n_period)
            breaks[i] <- ff$breaks + break_aux
            p[i] <- ff$p.value
          }
          if(iters > 3){
            if(all(breaks==breaks_old_old)){
              no_problem <- F
              warning(paste0('several critical point found at n =', n))
              breaks <- NULL
              next
            }else if(all(breaks==breaks_old_old_old)){
              no_problem <- F
              warning(paste0('several critical point found at n =', n))
              breaks <- NULL
              next
            }
          }
        }
      }
      if(is.null(breaks)){
        output_aux$breaks[[n]] <- NA
        output_aux$p.value[[n]] <- 1
        output_aux$n[[n]] <- n
      }else{
        output_aux$breaks[[n]] <- breaks+ini
        output_aux$p.value[[n]] <- p
        output_aux$n[[n]] <- n
      }
    }
    output[[outputcont]] <- output_aux
  }

  if(auto_select){
    output_new <- output
    output <- list(breaks = NULL,p.value=NULL,n=NULL)
    cont <-0
    bb <- NULL
    pp_final <- NULL
    n_final <- 0
    for(output_aux in output_new){
      cont <- cont + 1
      n_max <- length(output_aux$p.value)
      pp <- vector(mode = 'double',length = n_max)
      for(i in 1:n_max){
        pp[i] <- max(output_aux$p.value[[i]])
      }
      if(is.null(alpha)){
        i <- which.min(pp)
      } else{
        aa <- 1:n_max
        i <-max(aa[pp < alpha])
        if(is.infinite(i)){next}
      }
      bb <- c(bb,output_aux$breaks[[i]])
      pp_final <- c(pp_final,output_aux$p.value[[i]])
      n_final <- i + n_final
    }
    output <- list(breaks = bb,p.value=pp_final,n=n_final)
  }

  if(!change_random_seed){
    if(exists(x = 'old_random')){
      .Random.seed <- old_random
    }
  }
  return(output)

}
