###########################################################################
## Copyright (C) 2012  Whit Armstrong                                    ##
##                                                                       ##
## This program is free software: you can redistribute it and#or modify  ##
## it under the terms of the GNU General Public License as published by  ##
## the Free Software Foundation, either version 3 of the License, or     ##
## (at your option) any later version.                                   ##
##                                                                       ##
## This program is distributed in the hope that it will be useful,       ##
## but WITHOUT ANY WARRANTY; without even the implied warranty of        ##
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         ##
## GNU General Public License for more details.                          ##
##                                                                       ##
## You should have received a copy of the GNU General Public License     ##
## along with this program.  If not, see <http:##www.gnu.org#licenses#>. ##
###########################################################################

require(methods)
require(rzmq)


## NOTES
## possibly add deathstar method for max capacity, so that if node$capacity == node$max.capcaity
## then we know the node is idle, and jobs can be picked up
deathStar <-
    setRefClass("deathStar",
                fields = list(endpoint="character",status.port="integer",exec.port="integer",
                status.socket="externalptr", exec.socket="externalptr",
                capacity.asof="integer", pending.jobs="integer"),
                methods = list(
                initialize = function(zmq.context,endpoint,exec.port=6000L,status.port=6001L) {
                    endpoint <<- endpoint
                    status.port <<- status.port
                    exec.port <<- exec.port
                    status.socket <<- init.socket(zmq.context,"ZMQ_REQ")
                    connect.socket(status.socket,paste(endpoint,as.integer(status.port),sep=":"))

                    exec.socket <<- init.socket(zmq.context,"ZMQ_DEALER")
                    connect.socket(exec.socket,paste(endpoint,as.integer(exec.port),sep=":"))
                },
                get.name = function() {
                    endpoint
                },
                ## finalize = function() {
                ##     rzmq::close.socket(status.port)
                ##     rzmq::close.socket(exec.port)
                ## },
                submit.job = function(index,fun,...) {
                    if(is.na(index)) {
                        stop("can't submit null job.id")
                    }

                    if(index %in% pending.jobs) {
                        stop("this job has already been submitted.")
                    }

                    ## append job to pending list
                    pending.jobs[length(pending.jobs) + 1] <<- index

                    ## expects socket to be ZMQ_DEALER
                    ## send as though this is a req message
                    ## by sending null first
                    data <- list(index=index,fun=fun,args=list(...))
                    send.null.msg(exec.socket, send.more=TRUE)
                    send.socket(exec.socket, data=data, send.more=FALSE)
                },
                get.result = function() {
                    if(length(pending.jobs)==0) {
                        stop("no pending jobs to retrieve.")
                    }
                    receive.null.msg(exec.socket)
                    ans <- receive.socket(exec.socket)

                    ## remove job.id from pending list
                    pending.jobs <<- pending.jobs[-match(ans$index,pending.jobs)]

                    ## return result
                    ans
                },
                get.capacity = function() {
                    send.null.msg(status.socket)
                    receive.int(status.socket)
                },
                mark.capacity = function() {
                    capacity.asof <<- get.capacity()
                },
                number.pending = function() {
                    length(pending.jobs)
                },
                show = function() {
                    cat(endpoint,":",exec.port,"/",status.port,"\n")
                    if(length(pending.jobs)) {
                        cat("pending jobs:\n")
                        print(unlist(pending.jobs))
                    } else {
                        cat("no jobs pending.\n")
                    }
                }
                ))

zmq.cluster.lapply <- function(cluster,X,FUN,...,exec.port=6000L,status.port=6001L,sleep.interval=0.01) {
    ## for debugging
    jobs.submitted <- 0

    FUN <- match.fun(FUN)
    if (!is.vector(X) || is.object(X))
        X <- as.list(X)


    ## connect exec and status sockets to all remote servers
    ctx = init.context()
    death.servers <- list()
    for(nm in cluster) {
        death.servers[[nm]] <- deathStar$new(ctx,paste("tcp://",nm,sep=""),exec.port,status.port)
    }

    ## catalog jobs
    remaining.jobs <- 1:length(X)
    ## submit jobs
    while(length(remaining.jobs)) {
        for(node in death.servers) {
            ##cat("*** run for node:",node$get.name(),"\n")
            capacity <- node$get.capacity()
            ##cat("capacity:",capacity,"\n")

            if(capacity && length(remaining.jobs)) {
                ##cat("length(remaining.jobs):",length(remaining.jobs),"\n")
                number.of.jobs.to.submit <- min(capacity,length(remaining.jobs))
                ##cat("number.of.jobs.to.submit:",number.of.jobs.to.submit,"\n")

                ## submit jobs in positions[1..(min(capacity,jobs.remaining)]
                ##cat("submit full index:",1:(number.of.jobs.to.submit),"\n")
                for(i in 1:(number.of.jobs.to.submit)) {
                    ##cat("remaining.jobs:\n")
                    ##print(remaining.jobs)

                    ## always submit position 1 in job queue
                    job.id <- remaining.jobs[1]

                    ##cat("submitting job.id:",job.id,"\n")
                    node$submit.job(index=job.id,fun=FUN,X[[job.id]],...)

                    ## remove submitted job from queue
                    remaining.jobs <- remaining.jobs[-1]
                    jobs.submitted <- jobs.submitted + 1
                }
            }
        }
        Sys.sleep(sleep.interval)
    }

    stopifnot(sum(jobs.submitted)== length(X))

    ans <- vector("list",length(X))
    execution.report <- vector("list",length(X))
    ## apply names if they exist
    if(!is.null(names(X))) { names(ans) <- names(X) }

    ## collect results
    for(node in death.servers) {
        if(node$number.pending()) {
            for(i in 1:node$number.pending()) {
                this.ans <- node$get.result()
                if(!is.null(class(this.ans$result)) && class(this.ans$result) == "try-error") { warning("remote node returned an error.") }
                ans[[ this.ans$index ]] <- this.ans$result
                execution.report[[ this.ans$index ]] <- this.ans$node
            }
        }
    }

    execution.report <- as.matrix(table(do.call(rbind,execution.report)))
    colnames(execution.report) <- "jobs.completed"
    attr(ans,"execution.report") <- execution.report
    ans
}
