#!/bin/bash

surfer_dir=$1

SUBJECTS_DIR=${surfer_dir}/../
surf_sub=`basename ${surfer_dir}`

# First you have to pull together the labels
# from the surface annotation files
for hemi in lh rh; do
    mri_annotation2label --subject ${surf_sub} \
                         --hemi ${hemi} \
                         --lobesStrict \
                         ${surfer_dir}/label/${hemi}.lobesStrict
done

# Transform the surface annotation into a segmentation volume
mri_aparc2aseg --s ${surf_sub} \
            --labelwm \
            --rip-unknown \
            --annot lobesStrict \
            --o ${surfer_dir}/mri/lobes+aseg.mgz

# And extract some statistics :)
mri_segstats --i ${surfer_dir}/mri/norm.mgz \
             --seg ${surfer_dir}/mri/lobes+aseg.mgz \
             --sum ${surfer_dir}/stats/lobes+aseg.stats \
             --pv ${surfer_dir}/mri/norm.mgz \
             --id 1001 1003 1004 1005 1006 1007 \
                  2001 2003 2004 2005 2006 2007 \
                  3001 3003 3004 3005 3006 3007 \
                  4001 4003 4004 4005 4006 4007

