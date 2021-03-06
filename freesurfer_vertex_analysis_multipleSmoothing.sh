#!/bin/bash

#=============================================================================
# Created by Kirstie Whitaker on 27th October 2014
# Contact kw401@cam.ac.uk
#
# This code completes analysis of any surface measure at a variety of
# smoothing kernels of subjects defined in the fsgd file
#
#-----------------------------------------------------------------------------
# USAGE: freesurfer_vertex_analysis.sh <analysis_dir> <fsgd> <contrast> <measure>
#
# Note that this code assumes that recon-all has been run for all subjects
# in the fsgd file and that the appropriate SUBJECTS_DIR has already been set
# as an enviromental variable
#=============================================================================

#=============================================================================
# Define usage function
#=============================================================================
function usage {

    echo "freesurfer_vertex_analysis.sh <analysis_dir> <fsgd> <contrast> <measure>"
    echo "    analysis_dir is wherever you want to save your output"
    echo "    fsgd is the freesurfer group descriptor file - must end is .fsgd"
    echo "    contrast file contains the contrast of interest - must end in .mtx"
    echo "    measure is whatever surface measure you're interested in - eg: thickness"
    exit
}

#=============================================================================
# Read in command line arguments
#=============================================================================

# analysis_dir is wherever you want to save your output
analysis_dir=$1

# fsgd is the freesurfer group descriptor file - must end in .fsgd
fsgd=$2

# contrast file contains your contrast of interest - must end in .mtx
contrast_file=$3

# measure is whatever surface measure you're interested in - eg: thickness
measure=$4
measure_name=${measure%.*}

#=============================================================================
# Check that the files all exist etc
#=============================================================================
if [[ ! -f ${fsgd} ]]; then
    echo "FS GROUP DESCRIPTOR FILE does not exist. Check ${fsgd}"
    print_usage=1
fi

if [[ ! -f ${contrast_file} ]]; then
    echo "CONTRAST FILE does not exist. Check ${contrast_file}"
    print_usage=1
fi

if [[ -z ${measure} ]]; then
    echo "MEASURE not set - assuming thickness"
    measure=thickness
    measure_name=${measure%.*}
fi

if [[ ${print_usage} == 1 ]]; then
    usage
fi

#=============================================================================
# Define a couple of variables
#=============================================================================
# Figure out the analysis name from the Freesurfer group descriptor file
analysis_name=`basename ${fsgd} .fsgd`

# Figure out the contrast name from the contrast file
contrast_name=`basename ${contrast_file} .mtx`

#=============================================================================
# Get started
#-----------------------------------------------------------------------------
# Resample all the subjects in the Freesurfer group descriptor file
# to fsaverage space for each hemisphere separately
#=============================================================================

# Process for each hemisphere separately
for hemi in lh rh; do

    # Process the individual data as defined in the fsgd unless it's already
    # been completed
    if [[ ! -f ${analysis_dir}/${hemi}.${analysis_name}.${measure_name}.00.mgh ]]; then
    
        mris_preproc \
          --fsgd ${fsgd}      `# Freesurfer group descriptor file` \
          --target fsaverage  `# Target file to which all inputs will be aligned` \
          --hemi ${hemi}      `# Hemisphere` \
          --meas ${measure}   `# Surface measure to be represented in target space` \
          --fwhm 0            `# Smooth after registration to fsaverage with a gaussian kernel of ${fwhm} mm` \
          --out ${analysis_dir}/${hemi}.${analysis_name}.${measure_name}.00.mgh
          
    fi
    
    # Smooth the data at a variety of gaussian kernel sizes
    for fwhm in 00 05 10 15; do
    
        # Because all these analyses are going to get messy we should create
        # an appropriately named directory
        glm_dir=${analysis_dir}/GLM.${hemi}.${analysis_name}.${measure_name}.${fwhm}
        
        mkdir -p ${glm_dir}
        
        if [[ ! -f ${glm_dir}/${hemi}.${analysis_name}.${measure_name}.${fwhm}.mgh ]]; then
        
            mri_surf2surf \
              --hemi ${hemi}  `# Hemisphere` \
              --s fsaverage   `# Source and target subject are the same` \
              --fwhm ${fwhm}  `# Smooth surface to full width half maximum of (eg) 10` \
              --cortex        `# Only smooth vertices that are within the cortex label` \
              --sval ${analysis_dir}/${hemi}.${analysis_name}.${measure_name}.00.mgh \
                              `# Input surface file` \
              --tval ${glm_dir}/${hemi}.${analysis_name}.${measure_name}.${fwhm}.mgh \
                              `# Output surface file - will be same dimensions as the input file`
                              
        fi
        
        # Calculate the mean across all subjects for visualisation purposes
        
        if [[ ! -f ${glm_dir}/${hemi}.${analysis_name}.${measure_name}.${fwhm}.MEAN.mgh ]]; then
            
            mri_concat ${glm_dir}/${hemi}.${analysis_name}.${measure_name}.${fwhm}.mgh \
                        --o ${glm_dir}/${hemi}.${analysis_name}.${measure_name}.${fwhm}.MEAN.mgh \
                        --mean
                        
        fi
        
        # Now run the general linear model
        
        if [[ ! -f ${glm_dir}/${contrast_name}/sig.mgh ]]; then
        
            mri_glmfit \
                --y ${glm_dir}/${hemi}.${analysis_name}.${measure_name}.${fwhm}.mgh \
                                     `# Input surface data` \
                --fsgd ${fsgd}       `# Freesurfer group descriptor file` \
                             dods    `# dods stands for different offset different slope - usually the right choice` \
                --C ${contrast_file}      `# Contrast file` \
                --surf fsaverage     `# Common space surface file` \
                            ${hemi}  `# Hemisphere` \
                --cortex             `# only test within the cortex label` \
                --glmdir ${glm_dir}  `# GLM directory for output data`
                
        fi

        # And finally calculate cluster correction for the p values
        
        if [[ ! -f ${glm_dir}/${contrast_name}/cache.th20.neg.sig.cluster.mgh ]]; then
        
            # Calculate both positive and negative findings
            
            for direction in pos neg; do 
                
                # Here we're using a cached simulation
                # see the documentation to run a permutation test
                mri_glmfit-sim \
                    --glmdir ${glm_dir}  `# GLM directory - contains the output of the glm fit` \
                    --cache 2            `# Set the cluster forming threshold of -log10(p) [ 2 <--> 0.01; 3 <--> 0.001 etc ]` \
                    ${direction}         `# Consider positive or negative results separately` \
                    --cwp 0.05           `# Keep clusters that have p < 0.05` \
                    --2spaces            `# Correct for the fact that you have two hemispheres` 
                                        
            mris_calc -o ${glm_dir}/${contrast_name}/gamma_thr20.pos.sig.cluster.mgh \
                        ${glm_dir}/${contrast_name}/gamma.mgh \
                        masked \
                        ${glm_dir}/${contrast_name}/cache.th20.pos.sig.cluster.mgh
                        
            done # Close the direction loop
            
        fi
        
    done # Close fwhm loop
done # Close hemi loop

echo "All done!"

