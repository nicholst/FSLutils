#!/bin/bash -x
# mriqc_airmask.sh
#
# Replicates MRIQC's air, hat and artfiact masks, crucial for computing 
# structural MRI QC features
#
# T. Nichols 25 Jan 2022


#
# Bash/FSL version of MRIQC's masking used for SNR computations.
#
# Code mostly in these files
# https://github.com/nipreps/mriqc/blob/master/mriqc/workflows/anatomical.py
# https://github.com/nipreps/mriqc/blob/master/mriqc/interfaces/anatomical.py
#

# Relvant steps (from top of workflows/anatomical.py)
#   2. Skull-stripping (afni)
#      --> Brain mask becomes AirMaskWorkflow input "in_mask" *however*, the brain mask
#          *only* is every used as a reference image for resampling... not clear why 
#          they couldn't just use original input image (e.g. raw T1).
#   3. Head mask (i.e. whole head)
#      --> Uses dipy or bet (-A, betsurf); AirMaskWorkflow input "head_mask"
#   4. Spatial Normalization, using ANTs
#      --> Needed to inverse warp 'nasion-cerebellum'  mask, AirMaskWorkflow input "inverse_composite_transform"
#   5. Air mask (with and without artifacts)                                                               
#      --> "AirMaskWorkflow" in function airmsk_wf() which has inputs:
#          "in_file"  - Original native space image (actually, MRIQC reorients to standard orientation)
#          "in_mask"  - Brain mask, native space (only used as ref space)
#          "head_mask"- Head mask, native space
#          "inverse_composite_transform"- xform from MNI to native space
#      ... and outputs:
#          "hat_mask" - Crown of head mask, union of next two...
#          "air_mask" - Mask of air excluding artifacts
#          "art_mask" - Mask of artifacts above/outside head
#          "rot_mask" - Map of exact zeros (i.e. induced by rotations, or any reason)
#
#  AirMaskWorkflow has following steps 
#    a. Create rotation (exact zero) mask (see RotationMask() in interfaces/anatomical.py)
#    b. Apply inverse transformation of MNI "head mask" (really, head and below nasion-cerebellum line)
#    c. Create hat, artifact and air mask (see ArtifactMask() in interfaces/anatomical.py)
#
#  RotationMask has following steps
#    a. Make mask of exact zeros (<=0 to be exact)
#    b. Erode and then dialate this mask (elimiates small specks, regularlises shape)
#    c. Find clusters; if 3 or more found, delete all but 2 largest
#
#  ArtifactMask has following steps
#    a. Set negative values to zero
#    b. Set air mask as negation of head_mask (i.e. that from betsurf)
#    c. Calculate distance in air to air/non-air boundary
#    d. Mask air with negation of nasion_post_mask (kills everything below nasion)
#    e. Mask distance map the same as previous; rescale max distance to 1.0
#    f. Mask air with negation of rot_mask (i.e. exclude exact zeros)
#    g. Detect artifacts (air voxels > 10 MAD from median *and* dist >= 0.1; erode & dialate)
#    h. Save artifacts as "out_art_msk", 
#            air as "out_hat_msk", then 
#            delete artifacts from air and save it as "out_air_msk"
#
#
# Changes 
#   - Can't be bothered to get a proper head mask from betsurf; just using brain mask dialated



#
# Inputs
# 
InDir="."
in_file=$InDir/Structural
# The mat file from native to MNI space
Nat2MNImat=$InDir/Structural_2mni.mat
# MNI space "nasion to posterior of cerebellum mask" mask - basically all space below nose + crown of head
# Available from Templateflow project https://www.templateflow.org
MNIhat_mask=/Users/nichols/git/_OpenSci/templateflow/tpl-MNI152NLin2009cAsym/tpl-MNI152NLin2009cAsym_res-01_desc-head_mask
# This is a *head* mask (not brain mask)
head_mask=
# This is a brain mask, but actually isn't used(!)
in_mask=$InDir/Structural_brain


#
# Outputs
#
OutDir="."
ArtImg=$OutDir/"out_art_msk"
HatImg=$OutDir/"out_hat_msk"
AirImg=$OutDir/"out_air_msk"


# Save CPU on compression
export FSLOUTPUTTYPE=NIFTI

# Make 'Rotation mask' (mask of true zeros); see RotationMask()
rot_mask=/tmp/${$}rotmask
$FSLDIR/bin/fslmaths $in_file -thr 0 -binv -dilF -eroF $rot_mask -odt char
$FSLDIR/bin/cluster -i $rot_mask -t 1 --osize=/tmp/${$}csize > /tmp/${$}clust
# Save two largest clusters
if (( "$(cat /tmp/${$}clust | wc -l)" >= 3)) ; then
   cTh="$(awk '(NR==3){print $2}' /tmp/${$}clust)"
else
    cTh="$(awk '(NR==2){print $2}' /tmp/${$}clust)"
fi
$FSLDIR/bin/fslmaths /tmp/${$}csize -thr $cTh -bin $rot_mask -odt char

# Transform MNIhat_mask into native space "nasion-cerebellum" mask
MNI2Natmat=/tmp/${$}fromMNI.mat
$FSLDIR/bin/convert_xfm -omat $MNI2Natmat -inverse $Nat2MNImat
# Account for shift between MNIhat_mask and standard MNI space
# Calculated as mm shift between MNI (0,0,0) 
cat <<EOF > /tmp/${$}MNItoBigMNI.mat
1 0 0 182
0 1 0 218
0 0 1 182
0 0 0 1
EOF
$FSLDIR/bin/convert_xfm -omat /tmp/${$}NatToBigMNI -concat /tmp/${$}MNItoBigMNI.mat $Nat2MNImat
$FSLDIR/bin/convert_xfm -omat /tmp/${$}BigMNItoNat -inverse /tmp/${$}NatToBigMNI 
nasion_post_mask=/tmp/${$}headNat
$FSLDIR/bin/flirt -interp nearestneighbour -init /tmp/${$}BigMNItoNat -applyxfm \
		  -in $MNIhat_mask -ref $in_file -out $nasion_post_mask

# From here, see ArtfactMask() class

# Invert head mask
if [ "$head_mask" == "" ] ; then
    # Replace missing head with MNI hat in native space
    head_mask=$nasion_post_mask
fi
air=/tmp/${$}air
$FSLDIR/bin/fslmaths $head_mask -binv $air -odt char

# Calculate distance to border (of air)
dist=/tmp/${$}dist
## FSL's distancemap takes foooorrreevvver
#$FSLDIR/bin/distancemap -i $air -o $dist
# Use Chris Rorden's niimath instead: https://github.com/rordenlab/niimath
niimath $air -edt $dist

# Apply "nasion-to-posterior mask" (just inverted brain mask)    
$FSLDIR/bin/fslmaths $nasion_post_mask -binv -mul $air $air  -odt char
$FSLDIR/bin/fslmaths $nasion_post_mask -binv -mul $dist $dist
MxDist=$($FSLDIR/bin/fslstats $dist -R | awk '{print $2}')
$FSLDIR/bin/fslmaths $dist -div $MxDist $dist

# Apply rotation mask -- exclude pure zeros
$FSLDIR/bin/fslmaths $rot_mask -binv -mul $air $air -odt char

# Run the artifact detection, see artifact_mask()
zscore=10
bg=/tmp/${$}bg
$FSLDIR/bin/fslmaths $in_file -thr 0 -mas $air $bg
# Find the background threshold (i.e. MAD normalise)
bgMed=$(fslstats $bg -P 50)
$FSLDIR/bin/fslmaths $bg -sub $bgMed -mas $bg -abs /tmp/${$}bgAD
bgMAD=$(fslstats /tmp/${$}bgAD -P 50)
bgZ=/tmp/${$}bgZ
$FSLDIR/bin/fslmaths $bg -sub $bgMed -div $bgMAD -mas $bg $bgZ

# Apply this threshold to the background voxels to identify voxels
# contributing artifacts. ("z"score>10 and >0.1 distance from boundary)                                        
qi1=/tmp/${$}qi1
$FSLDIR/bin/fslmaths $bgZ -thr $zscore -bin $qi1 -odt char
$FSLDIR/bin/fslmaths $dist -thr 0.1 -bin -mul $qi1 -bin $qi1 -odt char

# Create a structural element to be used in an opening operation.
# (dilate and then erode)
$FSLDIR/bin/fslmaths $qi1 -dilF -eroF -mas $air $qi1 -odt char


# Now back to ArtifactMask()
export FSLOUTPUTTYPE=NIFTI_GZ
$FSLDIR/bin/imcp $qi1 $ArtImg
$FSLDIR/bin/imcp $air $HatImg
export FSLOUTPUTTYPE=NIFTI
# Subtract non-zero qi1 from $air
$FSLDIR/bin/fslmaths $qi1 -binv -mul $air $air -odt char
export FSLOUTPUTTYPE=NIFTI_GZ
$FSLDIR/bin/imcp $air $AirImg

/bin/rm /tmp/${$}*






