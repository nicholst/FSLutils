# FSLutils
These are a collection of utilities for FSL, slowly being migrated from my FSL Scripts page, http://warwick.ac.uk/tenichols/scripts/fsl.

## fsl_fdr.sh

Based on a zstat, tstat or randomise P-value image creates an image of
1 minus FDR-corrected P-values; optionally creates a rendering
(colored blobs on a specified background image). For example, in a
Feat results directory, running
```
fsl_fdr.sh stats/zstat1 mask stats/zstat1_fdrcorrp 
```
will produce a 1-P<sub>FDR</sub> image called zstat1_fdrcorrp in the stats
directory. To additionally create an rendered image, use the `-rend`
option, like
```
fsl_fdr.sh `-rend` example_func rendered_thresh_zstat1_fdrcorrp \
    stats/zstat1 mask stats/zstat1_fdrcorrp    
```
For 1-P images from randomise, use the `-1mp` option, as in:
```
fsl_fdr.sh -1mp results_vox_p_tstat1 mask results_vox_corrp_tstat1    
```
Finally, if you've got SPM T images, and `$dof` is the
degrees-of-freedom, you can use
```
fsl_fdr.sh -Tdf $dof spmT_0001 0 spmT_0001_Pfdr 
```
where setting the mask name to "0" has the effect of using an implicit
mask (<>0 means in the brain).

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
