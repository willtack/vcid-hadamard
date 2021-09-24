#!/bin/bash
#
# create masks from Harvard-Oxford atlas
# Resample masks to be compatible with glymph data
#
#

roiDir="../rois"
dataDir="../data/subjects"

cd ${roiDir}
cortAtlas=tpl-MNI152NLin2009cAsym_res-01_atlas-HOCPAL_desc-th0_dseg.nii.gz
subcortAtlas=tpl-MNI152NLin2009cAsym_res-01_atlas-HOSPA_desc-th0_dseg.nii.gz

# Generate ROIs
fslmaths ${cortAtlas} -thr 56.5 -uthr 57.5 -bin left_acc_roi
fslmaths ${cortAtlas} -thr 57.5 -uthr 58.5 -bin right_acc_roi
fslmaths ${cortAtlas} -thr 2.5 -uthr 3.5 -bin left_insula_roi
fslmaths ${cortAtlas} -thr 3.5 -uthr 4.5 -bin right_insula_roi
fslmaths ${subcortAtlas} -thr 15.5 -uthr 16.5 -bin right_caudate_roi
fslmaths ${subcortAtlas} -thr 4.5 -uthr 5.5 -bin left_caudate_roi
fslmaths ${subcortAtlas} -thr 16.5 -uthr 17.5 -bin right_putamen_roi
fslmaths ${subcortAtlas} -thr 5.5 -uthr 6.5 -bin left_putamen_roi

# Resample ROIs to perfusion space (64x64x36 3.75 3.75 3.75)
for subDir in $dataDir/HC*; do
  for sessionType in BASELINE FOLLOWUP; do
      prefix=${subDir}/sub-$(basename ${subDir})_ses-MR_${sessionType}
      warpDir=$(find "${subDir}" -type d | grep $sessionType | grep warp)
      ttFile=$(find "${subDir}" -type f | grep $sessionType | grep tt | grep -v MNI | grep -v struc)
      mprageFile=$(find "${subDir}" -type f | grep $sessionType | grep mprage_bet)
      # coregister T1 image to asl space
      flirt -in ${mprageFile} -ref ${ttFile} -out ${subDir}/tmpMPRAGE_IN_ASL.nii.gz -init ${warpDir}/struc2tt.mat -applyxfm
      # downsample the coregistered image to asl
      3dresample -master ${ttFile} -input ${subDir}/tmpMPRAGE_IN_ASL.nii.gz -prefix ${prefix}_asl-space.nii.gz || echo RESAMPLING ALREADY DONE
      rm ${subDir}/tmpMPRAGE_IN_ASL.nii.gz
      # segment the coregistered and resample mprage image
      fast ${prefix}_asl-space.nii.gz
      gmSeg=$(find ${subDir} -type f | grep $sessionType | grep pve_1)
      # output steps
      outRoiDir=${subDir}/sub-$(basename ${subDir})_ses-MR_${sessionType}_rois
      outName=${outRoiDir}/sub-$(basename ${subDir})_ses-MR_${sessionType}_GM_roimask.nii.gz
      fslmaths ${gmSeg} -thr 0.85 -bin ${outName}

      # remove extra segmentation outputs
      pushd ${subDir}; rm *mixeltype* *pve* *seg*; popd

      for roi in ${roiDir}/*_roi.nii.gz; do
        roiName=$(echo $(basename $roi) | cut -d '_' -f 1,2)
        outRoiDir=${subDir}/sub-$(basename ${subDir})_ses-MR_${sessionType}_rois
        mkdir -p $outRoiDir
        outName=${outRoiDir}/sub-$(basename ${subDir})_ses-MR_${sessionType}_${roiName}_roimask.nii.gz
        applywarp --ref="${ttFile}" --in="${roi}" --warp=${warpDir}/struc2standard_warp_inv --postmat=${warpDir}/struc2tt.mat --out=${outName} || echo ${subDir}
        #fslmaths ${TERRITORIES_DIR}/${new_mask_name} -thrP 50 -bin ${TERRITORIES_DIR}/${new_mask_name}
      done
  done
done
