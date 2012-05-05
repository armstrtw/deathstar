\name{zmq.lapply}
\alias{zmq.cluster.lapply}
\title{
  apply a function to a list.
}
\description{
  \code{zmq.lapply} returns a list of the same length as \code{X}, each element of
  which is the result of applying \code{FUN} to the corresponding element
  of \code{X}.

  The execution of the function is performed in parallel over zmq sockets.
}
\usage{
zmq.cluster.lapply(cluster,X,FUN,...,exec.port=6000L,status.port=6001L,sleep.interval=0.01)
}
\arguments{
  \item{cluster}{a vector of computer names to use for the parallel lapply}
  \item{X}{a list or vector.}
  \item{FUN}{the function to be applied to each element of \code{X}}
  \item{exec.port}{the port to use to send jobs/receive results.}
  \item{status.port}{the port to use to check node capacity.}
  \item{sleep.interval}{the amount of time to sleep (in seconds) before
    checking the capacity of the compute nodes.}
  \item{\dots}{additional arguments to lapply.}
}
\details{
  Successful "parallelization" of lapply requires a deathstar daemon
  to be running on the remote nodes.

  deathstar is packaged for debian and debian derivatives here:
  https://github.com/downloads/armstrtw/deathstar.core/deathstar_0.0.1-1_amd64.deb
}
\value{a list of the same length as X}
\references{
  http://www.zeromq.org
  http://api.zeromq.org
  http://zguide.zeromq.org/page:all
  http://zguide.zeromq.org/page:all#Divide-and-Conquer
  https://gist.github.com/406824
  http://www.vcasmo.com/video/drewconway/8468
  http://www.r-bloggers.com/abusing-amazon%E2%80%99s-elastic-mapreduce-hadoop-service%E2%80%A6-easily-from-r
  http://code.google.com/p/segue
}
\author{
  ZMQ was written by Martin Sustrik <sustrik@250bpm.com> and Martin Lucina <mato@kotelna.sk>.
  rzmq was written by Whit Armstrong.
  segue and estimatePi were written by JD Long.
}

\seealso{
  \code{\link{connect.socket},\link{bind.socket},\link{receive.socket},\link{send.socket}}
}

\examples{\dontrun{
library(rzmq)

## run locally
## estimatePi example courtesy of JD Long / Jeffrey Breen

library(AWS.tools)
library(rzmq)

cl <- startCluster(ami="ami-4bc90522",key="kls-ec2",instance.count=5,instance.type="c1.xlarge")

estimatePi <- function(seed) {
    set.seed(seed)
    numDraws <- 1e6

    r <- .5
    x <- runif(numDraws, min=-r, max=r)
    y <- runif(numDraws, min=-r, max=r)
    inCircle <- ifelse( (x^2 + y^2)^.5 < r , 1, 0)
    
    sum(inCircle) / length(inCircle) * 4
}

run.time <- system.time(ans <- zmq.cluster.lapply(cluster=cl$instances[,"PublicDNS"],as.list(1:1000),estimatePi))

print(mean(unlist(ans)))
print(run.time)
print(attr(ans,"execution.report"))

res <- terminateCluster(cl)

pi.est <- mean(unlist(ans))
print(pi.est)

}}
\keyword{utilities}
