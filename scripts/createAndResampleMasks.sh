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
fslmaths ${subcortAtlas} -thr 4.5 -uthr 5.5 -bin left_caudate_roi
fslmaths ${subcortAtlas} -thr 15.5 -uthr 16.5 -bin right_caudate_roi
fslmaths ${subcortAtlas} -thr 5.5 -uthr 6.5 -bin left_putamen_roi
fslmaths ${subcortAtlas} -thr 16.5 -uthr 17.5 -bin right_putamen_roi


fslmaths left_acc_roi.nii.gz -add right_acc_roi.nii.gz acc_roi.nii.gz
fslmaths left_insula_roi.nii.gz -add right_insula_roi.nii.gz insula_roi.nii.gz
fslmaths left_caudate_roi.nii.gz -add right_caudate_roi.nii.gz caudate_roi.nii.gz
fslmaths left_putamen_roi -add right_putamen_roi putamen_roi.nii.gz

rm left* right* || echo already removed left/right

# Resample ROIs to perfusion space (64x64x36 3.75 3.75 3.75)
for subDir in $dataDir/HC*; do
  for sessionType in BASELINE FOLLOWUP; do
      prefix=${subDir}/sub-$(basename ${subDir})_ses-MR_${sessionType}
      warpDir=$(find "${subDir}" -type d | grep $sessionType | grep warp)
      ttFile=$(find "${subDir}" -type f | grep $sessionType | grep tt | grep -v MNI | grep -v struc)
      mprageFile=$(find "${subDir}" -type f | grep $sessionType | grep mprage_bet)
      echo ${subDir}/sub-$(basename ${subDir})_ses-MR_${sessionType}

      outRoiDir=${subDir}/sub-$(basename ${subDir})_ses-MR_${sessionType}_rois
      mkdir -p ${outRoiDir}
      rm ${outRoiDir}/* # cleanup before running

      # coregister T1 image to asl space
      echo  Coregistering mprage image to asl space...
      flirt -in ${mprageFile} -ref ${ttFile} -out ${subDir}/tmpMPRAGE_IN_ASL.nii.gz -init ${warpDir}/struc2tt.mat -applyxfm
      # downsample the coregistered image to asl
      echo  Downsampling the coregistered image to asl voxel space...
      if [[ ! -f ${prefix}_asl-space.nii.gz ]]; then
        3dresample -master ${ttFile} -input ${subDir}/tmpMPRAGE_IN_ASL.nii.gz -prefix ${prefix}_asl-space.nii.gz || echo RESAMPLING ALREADY DONE
        rm ${subDir}/tmpMPRAGE_IN_ASL.nii.gz
      else
        echo  Resampling already done
      fi
      # segment the coregistered and resampled mprage image
      echo  Segmenting the coregistered and resampled mprage image...
      gmSeg=$(find ${subDir} -type f | grep $sessionType | grep pve_1)
      if [[ ! -f ${gmSeg} ]]; then
        fast ${prefix}_asl-space.nii.gz
        gmSeg=$(find ${subDir} -type f | grep $sessionType | grep pve_1)
        # output steps
        outName=${outRoiDir}/sub-$(basename ${subDir})_ses-MR_${sessionType}_GM_roimask.nii.gz
        fslmaths ${gmSeg} -thr 0.85 -bin ${outName}
      else
        echo  Segmentation already done
      fi

      # remove extra segmentation outputs
      echo  Removing extra segmentation files
      pushd ${subDir}; rm *mixeltype* *pve* *seg*; popd || echo Extras already cleaned up

      for roi in ${roiDir}/*_roi.nii.gz; do
        roiName=$(basename $roi | cut -d '_' -f 1)
        echo  Processing $roiName...
        outRoiDir=${subDir}/sub-$(basename ${subDir})_ses-MR_${sessionType}_rois
        mkdir -p $outRoiDir
        outName=${outRoiDir}/sub-$(basename ${subDir})_ses-MR_${sessionType}_${roiName}_roimask.nii.gz
        applywarp --ref="${ttFile}" --in="${roi}" --warp=${warpDir}/struc2standard_warp_inv --postmat=${warpDir}/struc2tt.mat --out=${outName} || echo ${subDir}
        #fslmaths ${TERRITORIES_DIR}/${new_mask_name} -thrP 50 -bin ${TERRITORIES_DIR}/${new_mask_name}
      done
  done
done
