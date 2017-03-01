# FSLutils
These are a collection of utilities for FSL, slowly being migrated from my FSL Scripts page, http://warwick.ac.uk/tenichols/scripts/fsl.

## PlotFeatMFX: `PlotFeatMFX.sh` & `PlotFeatMFX.R`

This pair of companion scripts produces a plot that visualizes a
one-sample mixed effects result at a given voxel. Showing the effect
magnitude for each subject and the contribution of intra- and
-inter-subject variance, it explains how and why Feat FLAME mixed
effects results can vary from OLS. Only `PlotFeatMFX.sh` is directly
called by the user, like
```
PlotFeatMFX.sh Nback.gfeat 23 37 57
```
or
```
PlotFeatMFX.sh -usemm Nback.gfeat 44 -52 42
```
but of course requires [R](http://www.r-project.org/).
