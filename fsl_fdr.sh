#!/bin/bash
#
# Script: fsl_fdr
# Purpose: Take a z image and produce a FDR rendered_thresh_fdrzstat
# Author:
# Version: $Id$
#

###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null
TmpDir=/tmp
Tmp=$TmpDir/`basename $0`-${$}-
trap CleanUp INT

alphaFDR=0.05

###############################################################################
#
# Functions
#
###############################################################################

Usage() {
cat <<EOF
Usage: `basename $0` zstat mask fdrout

By default, produces an fdrout image, which shows the 1-PcorrFDR values (1 minus 
FDR-corrected P-values).  Replace mask with "0" to have an implicit mask computed from 
the exact zero voxels in the image.

OPTIONS
  -Tdf <df>  Image is *not* a Z, but rather is T image with specified degrees of freedom
  -1mp       Image is *not* a Z, but rather is a 1-minus-uncorrected P-value image
             (e.g. as produced by randomise, *_vox_p_*, or *_tfce_p_*)      
  -rend <BgImg> <OutRndImg>
             Produce rendered_thresh_fdrout, using BgImg as background
  -aFDR <alpha>
             Critical FDR level to use (0.05 by default; only applicable if rendering)

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

while (( $# > 1 )) ; do
    case "$1" in
        "-help")
            Usage
            ;;
        "-1mp")
            shift
            omPval=1;
            ;;
        "-tdf")
            shift
            Tdf="$1"
            shift
            ;;
        "-rend")
            shift
            BgImg="$1"
            shift
            RendImg="$1"
            shift
            ;;
        "-aFDR")
            shift
            alphaFDR="$1"
            shift
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

if (( $# <= 2 )) ; then
    Usage
fi
Zstat="$1"
Mask="$2"
FDRout="$3"

if [ "$Mask" = "0" ] ; then
    Mask=${Tmp}mask
    fslmaths "$Zstat" -abs -bin $Mask
fi

###############################################################################
#
# Script Body
#
###############################################################################

if [ "$omPval" = 1 ] ; then
    fslmaths "$Zstat" -mul -1 -add 1 -mas "$Mask" ${Tmp}-pval
else
    if [ "$Tdf" != "" ] ; then
	fslmaths "$Mask" -bin ${Tmp}-bin-mask
	ttoz -zout ${Tmp}-zstat ${Tmp}-bin-mask "$Zstat" "$Tdf"
	Zstat=${Tmp}-zstat
    fi
    fslmaths "$Zstat" -ztop -mas "$Mask" ${Tmp}-pval
fi
fdr -i ${Tmp}-pval -m "$Mask" -o ${Tmp}-fdrpval
fslmaths ${Tmp}-fdrpval -min 1 -mul -1 -add 1 -mas "$Mask" "$FDRout"


if [ "$RendImg" != "" ] ; then
    pFDR=$(fdr -i ${Tmp}-pval -m "$Mask" -q "$alphaFDR" | awk 'NR==2{print $0}')
    zMax=$(fslstats "$Zstat" -R | awk '{print $2}')
    if [ "$pFDR" = 0 ] ; then
	echo "WARNING: No voxels significant at FDR $alphaFDR"
	overlay 1 0 "$BgImg" -a "$Zstat" $(echo $zMax+1|bc -l) $(echo $zMax+2|bc -l) "$RendImg"
    else
	alphaFDRz=$(ptoz $pFDR)
	echo "NOTE: level $alphaFDR FDR threshold is P=$pFDR or Z=$alphaFDRz"
	overlay 1 0 "$BgImg" -a "$Zstat" $alphaFDRz $zMax "$RendImg"
    fi
fi


###############################################################################
#
# Exit & Clean up
#
###############################################################################

CleanUp

