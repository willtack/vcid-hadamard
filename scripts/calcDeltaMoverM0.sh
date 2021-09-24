#! /bin/bash
#
# Resample M0 using transit time map as template
# Then divide the masked perfusion weighted image by M0 to get dM/m0 maps
#
#

localDir="../data/subjects"
# cd $localDir
for subjectDir in ${localDir}/HC*; do
    for sessionType in BASELINE FOLLOWUP; do
        #inputs
        ttFile="${subjectDir}/sub-$(basename "${subjectDir}")_ses-MR_${sessionType}_tt.nii"
        perfFileMasked="${subjectDir}/sub-$(basename "${subjectDir}")_ses-MR_${sessionType}_pw_masked.nii.gz"
        m0File="${subjectDir}/sub-$(basename "${subjectDir}")_ses-MR_${sessionType}_m0.nii.gz"

        echo
        echo $ttFile
        echo $perfFileMasked
        echo $m0File

        if [[ -f $perfFileMasked ]]; then
            m0Resample="${subjectDir}/sub-$(basename "${subjectDir}")_ses-MR_${sessionType}_m0_resample"

            # The M0 has 2 volumes -- we just need the first
            echo 'Trimming M0'
            fslroi ${m0File} ${m0Resample}tmp.nii.gz 0 1
            echo 'Resampling M0 to transit-time map space'
            3dresample -master ${ttFile} -input ${m0Resample}tmp.nii.gz -prefix ${m0Resample}.nii.gz
            echo 'Dividing perfusion-weighted images by M0'
            dMM0File="${subjectDir}/sub-$(basename "${subjectDir}")_ses-MR_${sessionType}_dMM0"
            fslmaths ${perfFileMasked} -div ${m0Resample} ${dMM0File}

            # the pw image has a bright "control" image at the end that we're ignoring
            fslroi ${dMM0File} ${dMM0File} 0 7

        fi
    done
done

rm $(find $localDir -type f | grep tmp.nii.gz)
