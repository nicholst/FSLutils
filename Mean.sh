#!/bin/bash
#
# Script: Mean.sh
# Purpose: Compute mean of an arbitrary number of NIFTI images
# Author: TE Nichols
# Version: 
#


###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob     # No-match globbing expands to null
set -eu               # Immediately stop on error or even unset variable
Tmp=$(mktemp -t `basename $0`) # Safe temp basename
trap CleanUp INT

###############################################################################
#
# Functions
#
###############################################################################

Usage() {
cat <<EOF
Usage: `basename $0` [options] FilenameTxtList MeanImgOut

Compute the mean of an arbitrary number of NIFTI images.  The images must be
in FilenameTxtList, one per line.  The mean is written to MeanImgOut.

Options
  -n Normalise non-zero voxels to be median 100
_________________________________________________________________________
EOF
exit
}

CleanUp () {
    if [ "$Tmp" != "" ] ; then
	# Avoid disaster if Tmp has somehow been cleared
	/bin/rm -f ${Tmp}*
    fi
    exit 0
}


###############################################################################
#
# Parse arguments
#
###############################################################################

MedianNorm=
while getopts ":hn" Opt ; do
    case "$Opt" in
        "h"  )
            Usage
            ;;
        "n"  )
            MedianNorm=1
            ;;
        "?"  )
            echo "ERROR: Unknown option '${OPTARG}'"
            exit 1
            ;;
    esac
done

shift $(( OPTIND - 1 ))

MinArgs=2
if (( $# < $MinArgs )) ; then
    Usage
fi

Files="$1"
OutMean="$2"
export FSLFILETYPE=NIFTI # Avoid FSL's default of NIFTI_GZ
nFiles=$(cat "$Files" | wc -l)

###############################################################################
#
# Script Body
#
###############################################################################

Img1="$(head -n 1 "$Files")"
fslmaths $Img1 -mul 0 $Tmp -odt double

Scale=1
echo "Working on..."
for ((i=0; i<$nFiles; i++)) ; do
    Img="$(sed -n "$((i+1))p" $Files)"
    echo "$Img"
    if [ $MedianNorm ] ; then
        Median=$(fslstats $Img -k $Img -P 50)
        Scale=$(echo "100 / $Median" | bc -l)
    fi        
    fslmaths $Img -mul $Scale -add $Tmp $Tmp -odt double
done

fslmaths $Tmp -div $nFiles "$OutMean" -odt float

###############################################################################
#
# Exit & Clean up
#
###############################################################################

CleanUp

