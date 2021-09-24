#! /bin/bash
#
#

# Register perfusion-weighted image to MNI152 via MPRAGE scan

localDir=/media/will/My\ Passport/Ubuntu/vcid/vcid_hadamard_data

for subjectDir in "${localDir}"/*; do
    for sessionType in BASELINE FOLLOWUP; do
        #inputs
        perfFile=$(find "${subjectDir}" -type f | grep $sessionType | grep pw | grep -v MNI)
        ttFile=$(find "${subjectDir}" -type f | grep $sessionType | grep tt | grep -v MNI | grep -v struc)
        warpDir=$(find "${subjectDir}" -type d | grep $sessionType | grep warp)
        #outputs
        brainMask="${subjectDir}/sub-$(basename "${subjectDir}")_ses-MR_${sessionType}_brainmask.nii.gz"
        perfFileMasked="${subjectDir}/sub-$(basename "${subjectDir}")_ses-MR_${sessionType}_pw_masked.nii.gz"
        perfFileMNI="${subjectDir}/sub-$(basename "${subjectDir}")_ses-MR_${sessionType}_MNI152_pw.nii.gz"

        echo
        echo $perfFile
        echo $warpDir
        echo $perfFileMNI
        
        if [[ -f $perfFile ]]; then
        
            echo 'Creating brain masks for perfusion-weighted images...'
            fslmaths "${ttFile}" -bin "${brainMask}"
            fslmaths "${perfFile}" -mas "${brainMask}" "${perfFileMasked}"
        
            echo 'Normalizing perfusion-weighted images...'
            applywarp --ref=${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz --in="${perfFileMasked}" --warp="${warpDir}"/struc2standard_warp \
                      --premat="${warpDir}"/tt2struc.mat --out="${perfFileMNI}"
        fi
    done   
done