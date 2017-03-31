#!/usr/bin/env Rscript
#
# Script: PlotFeatMFX.R
# Purpose: Make a graphical description of a 2nd level FLAME analysis in FSL
# Author: T. Nichols
# Version: http://github.com/nicholst/FSLutils/tree/$Format:%h$
#          $Format:%ci$
#
# Requires companion shell script PlotFeatMFX.sh to extract data from Feat result directory.

args = commandArgs(TRUE)

if (length(args)!=1) {
  stop("Wrong number of arguments.  Only intened for use with PlotFeatMFX.sh script.")
}
BaseNm=args[1]
  
PlotFeatMFX <- function(BaseNm) {
  # Takes data from a companion shell script and plots FLAME's MFX
  # model fit and compares it to OLS

  # Load data from temporary files
  copes     = scan(paste(BaseNm,'copes.txt',sep=""),quiet=TRUE)
  varcopes  = scan(paste(BaseNm,'varcopes.txt',sep=""),quiet=TRUE)
  sigsG     = scan(paste(BaseNm,'sigma2G.txt',sep=""),quiet=TRUE)
  bhG       = scan(paste(BaseNm,'bhG.txt',sep=""),quiet=TRUE)
  tG        = scan(paste(BaseNm,'tstatG.txt',sep=""),quiet=TRUE)
  varbhG    = scan(paste(BaseNm,'varbhG.txt',sep=""),quiet=TRUE)


  # Process into various summary measures
  N       = length(copes)
  MyCope  = sum(copes/(sigsG+varcopes))/sum(1/(sigsG+varcopes)); # same as bhG
  SEGLS   = sd(N*copes/(sigsG+varcopes))/sum(1/(sigsG+varcopes))/sqrt(N)
  bhOLS   = mean(copes);
  SEOLS   = (sd(copes)/sqrt(N))
  tOLS    = bhOLS/SEOLS
  AvgVar  = mean(varcopes)
  
  # Prepare plot
  pdf(paste(BaseNm,'plot.pdf',sep=""))
  par(mfrow=c(2,1))


  #
  # First plot, mean estimates
  #
  barplot(copes,
          ylab=expression(paste(c,hat(beta)[k])),xlab="Subject",
          names.arg=as.character(1:N))
  title(expression(paste("Intrasubject Contrast Estimates:  ", c,hat(beta)[k])),line=3)
#  title(bquote(beta[plain(OLS)] == .(sprintf("%0.3f",bhOLS)) ~~~ ),line=1)
  abline(h=bhOLS,col="red")
  abline(h=bhG,col="blue")
  legend("topright",legend=c(expression(paste(c,hat(beta)[plain(OLS)])),expression(paste(c,hat(beta)[plain(GLS)]))),col=c("red","blue"),lty=1)
  
  #
  # Second plot, intrasubject variance estimates
  #
  Vars=t(matrix(c(rep(sigsG,N),varcopes),ncol=2))
  # print(c(mean(varcopes),mean(varcopes)+sigsG,AvgVar,AvgVar+sigsG,SEOLS^2*N))
  barplot(Vars,
          ylab=expression(sigma[G]^2+Var(paste(c,hat(beta)[k]))),
          xlab=bquote(paste(,sigma[G]^2==.(sprintf("%0.3f",sigsG))~~~bar(Var(paste(c,hat(beta))))==.(sprintf("%0.3f",AvgVar)),"    OLS Var (red) ",.(sprintf("%0.3f",SEOLS^2*N)),"    GLS AvgVar (blue) ",.(sprintf("%0.3f",sigsG+AvgVar)))),
          names.arg=as.character(1:N),
          legend=c(expression(sigma[G]^2),
            expression(Var(paste(c,hat(beta)[k]))))
          )
  title(bquote(paste(plain("Mixed Effect Variance by Subject"))),line=0.7)
  title(bquote(paste(c,hat(beta)[plain(GLS)] == .(sprintf("%0.3f",bhG)) ~~~
                     plain(SE)[plain(GLS)] == .(sprintf("%0.3f",SEGLS)) ~~~ 
                     t[plain(GLS)] == .(sprintf("%0.2f",tG)))),
        line=2.3,cex.main=1)
  title(bquote(paste(c,hat(beta)[plain(OLS)] == .(sprintf("%0.3f",bhOLS)) ~~~
                     plain(SE)[plain(OLS)] == .(sprintf("%0.3f",SEOLS)) ~~~ 
                     t[plain(OLS)] == .(sprintf("%0.2f",tOLS)))), 
        line=3.5,cex.main=1)
  
  abline(h=SEOLS^2*N,col="red")      # lty=3)
  abline(h=sigsG+AvgVar,col="blue")  # lty=2)
  
  invisible(capture.output(dev.off()))
}

PlotFeatMFX(BaseNm)

