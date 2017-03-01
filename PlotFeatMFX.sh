#!/bin/bash
#
# Script: PlotFeatMFX.sh
# Purpose: Make a graphical description of a 2nd level FLAME analysis in FSL
# Author: T. Nichols
# Version: http://github.com/nicholst/FSLutils/tree/$Format:%h$
#          $Format:%ci$
#
# Requires companion R script PlotFeatMFX.R (and, of course, R)


###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null
TmpDir=/tmp
Tmp=$TmpDir/`basename $0`-${$}-
trap CleanUp INT

###############################################################################
#
# Functions
#
###############################################################################

Usage() {
cat <<EOF
Usage: `basename $0` [Options] gFeatDir x y z

For a given .gfeat group results directory, it will create a plot for the results
at voxel x y z, creating a summary plot in PDF format with a filename based on
the x,y,z coordinates.  The name of the PDF file created is shown.

LIMITATIONS:  This only works when the gFeat design matrix is a one-sample t-test.

Options
   -n      RegionName (no spaces), appended to plot name.
   -usemm  Interpret x,y,z coordinates as world mm units (instead of voxels)
   -c #    Lower-level COPE number to plot (default is 1)
   -fdir   Use gFeatDir as the full path to the cope#.feat directory; -c is ignored.
           Useful if you've manually constructed your own 2nd level analysis.
_________________________________________________________________________
\$Id$
EOF
exit
}

CleanUp () {
    /bin/rm -f ${Tmp}*
    exit 0
}


###############################################################################
#
# Parse arguments
#
###############################################################################
Opts=""
Con=1
while (( $# > 1 )) ; do
    case "$1" in
        "-help")
            Usage
            ;;
        "-n")
            shift
            xyzNm=$(echo "$1" | sed 's/ *//g')
            shift
            ;;
        "-usemm")
            shift
            Opts="$Opts --usemm"
            ;;
        "-c")
            shift
            Con="$1"
            shift
            ;;
        "-fdir")
            shift
            Fdir=1
            ;;
        -*)
            echo "ERROR: Unknown option '$1'"
            exit 1
            break
            ;;
        *)
            break
            ;;
    esac
done
Tmp=$TmpDir/f2r-${$}-

if (( $# < 4 )) ; then
    Usage
fi

Dir="$1"
x="$2"
y="$3"
z="$4"

# Convert directory
if [ "$Fdir" != 1 ] ; then
    Dir="${Dir}/cope${Con}.feat"
fi

# set output name
if [ "$xyzNm" == "" ] ; then
    OutNm="PlotMFX_${x}_${y}_${z}.pdf"
else
    OutNm="PlotMFX_${xyzNm}_${x}_${y}_${z}.pdf"
fi

###############################################################################
#
# Script Body
#
###############################################################################


fslmeants -i  $Dir/filtered_func_data -c "$x" "$y" "$z"  -o ${Tmp}copes.txt     $Opts
fslmeants -i  $Dir/var_filtered_func_data \
                                      -c "$x" "$y" "$z"  -o ${Tmp}varcopes.txt  $Opts
fslmeants -i  $Dir/stats/mean_random_effects_var$Con \
                                      -c "$x" "$y" "$z"  -o ${Tmp}sigma2G.txt   $Opts
fslmeants -i  $Dir/stats/cope1        -c "$x" "$y" "$z"  -o ${Tmp}bhG.txt       $Opts
fslmeants -i  $Dir/stats/tstat1       -c "$x" "$y" "$z"  -o ${Tmp}tstatG.txt    $Opts
fslmeants -i  $Dir/stats/varcope1     -c "$x" "$y" "$z"  -o ${Tmp}varbhG.txt    $Opts

# Memo to self:
# stats/weights1 = 1/(varcope1 + mean_random_effects_var$Con)

PlotFeatMFX.R "$Tmp"

mv ${Tmp}plot.pdf $OutNm

echo "$OutNm"

###############################################################################
#
# Exit & Clean up
#
###############################################################################

CleanUp

