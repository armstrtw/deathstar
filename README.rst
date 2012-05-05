************
Introduction
************

:Date: Sept 27, 2011
:Authors: Whit Armstrong
:Contact: armstrong.whit@gmail.com
:Web site: http://github.com/armstrtw/deathstar
:License: GPL-3


Purpose
=======

deathstar is a distributed computing tool for R


Features
========

deathstar allows distributed lapply into Amazon's EC2 cloud or across local compute nodes

* dead simple

* allows both local and remote compute nodes to be used simultaneously



Usage
=====

A minimal example of parallel remote execution.::


	require(deathstar)
	
	estimatePi <- function(seed) {
	    set.seed(seed)
	    numDraws <- 1e5
	    r <- .5
	    x <- runif(numDraws, min=-r, max=r)
	    y <- runif(numDraws, min=-r, max=r)
	    inCircle <- ifelse( (x^2 + y^2)^.5 < r , 1, 0)
	    sum(inCircle) / length(inCircle) * 4
	}
	
	cluster <- c("krypton","node1","mongodb","xenon","research")
	run.time <-
	    system.time(ans <-
	                zmq.cluster.lapply(cluster=cluster,
	                                   as.list(1:1e3),
	                                   estimatePi))
	                                   ##echoBack))
	print(mean(unlist(ans)))
	print(run.time)
	print(attr(ans,"execution.report"))
	
	
