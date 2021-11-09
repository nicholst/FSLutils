#!/bin/bash

Nimg=20 # Number of images to simulate
FWHM=9  # FWHM in mm

sigma=$(echo "$FWHM / 2.355" | bc -l)
FD=$FSLDIR/data/standard

# Calibrate SD
fslmaths $FD/MNI152_T1_2mm -mul 0 -randn -kernel gauss 5 -fmean -mas $FD/MNI152_T1_2mm_brain_mask /tmp/$$
sd=$(fslstats /tmp/$$ -S)
fslmaths /tmp/$$ -mul 0 /tmp/$$
gunzip /tmp/$$.nii.gz # Uncompress once, instead of repeatedly inside the loop

# Simulate!
for i in $(seq $Nimg) ; do
    fNm=$(printf "SimImg_%05d" $i)
    fslmaths /tmp/$$ -seed $(echo "$RANDOM * $RANDOM" | bc -l) \
	     -randn -kernel gauss $sigma -fmean \
	     -div $sd \
	     -mas $FD/MNI152_T1_2mm_brain_mask \
	     $fNm
done
imrm /tmp/$$

