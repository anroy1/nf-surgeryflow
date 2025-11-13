#!/usr/bin/env nextflow

//BIDS
include { IO_READBIDS       } from './modules/nf-neuro/io/readbids/main' 

// TRACTOFLOW
include { TRACTOFLOW        } from './subworkflows/nf-neuro/tractoflow/main'

// BUNDLESEG
include { BUNDLE_SEG        } from './subworkflows/nf-neuro/bundle_seg/main'

// NII TO DICOM
include { NII_TO_DICOM      } from './subworkflows/local/nii_to_dicom/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow get_data {
    main:
        input = file(params.input)

        // ** Loading all files. ** //
        dwi_channel = Channel.fromFilePairs("$input/**/*dwi.{nii.gz,bval,bvec}", size: 3, flat: true)
            { it.parent.name }
            .map{ sid, bvals, bvecs, dwi -> [ [id: sid], dwi, bvals, bvecs ] } // Reordering the inputs.

        t1_channel = Channel.fromFilePairs("$input/**/*t1.nii.gz", size: 1, flat: true)
            { it.parent.name }
            .map{ sid, t1 -> [ [id: sid], t1 ] }

        b0_channel = Channel.fromFilePairs("$input/**/*b0.nii.gz", size: 1, flat: true)
            { it.parent.name }
            .map{ sid, b0 -> [ [id: sid], b0 ] }

        rev_dwi_channel = Channel.fromFilePairs("$input/**/*rev_dwi.{nii.gz,bval,bvec}", size: 3, flat: true)
            { it.parent.name }
            .map{ sid, rev_bvals, rev_bvecs, rev_dwi -> [ [id: sid], rev_dwi, rev_bvals, rev_bvecs ] } // Reordering the inputs.

        rev_b0_channel = Channel.fromFilePairs("$input/**/*rev_b0.nii.gz", size: 1, flat: true)
            { it.parent.name }
            .map{ sid, rev_b0 -> [ [id: sid], rev_b0 ] }

        aparc_aseg_channel = Channel.fromFilePairs("$input/**/*aparc_aseg.nii.gz", size: 1, flat: true)
            { it.parent.name }
            .map{ sid, aparc_aseg -> [ [id: sid], aparc_aseg ] }

        wmparc_channel = Channel.fromFilePairs("$input/**/*wmparc.nii.gz", size: 1, flat: true)
            { it.parent.name }
            .map{ sid, wmparc -> [ [id: sid], wmparc ] }

        topup_channel = Channel.fromFilePairs("$input/**/*topup_config.cnf")
            
        lesion_channel = Channel.fromFilePairs("$input/**/*lesion.nii.gz", size: 1, flat: true)
            { it.parent.name }

    emit: // Those lines below define your named output, use those labels to select which file you want.
        dwi = dwi_channel
        t1 = t1_channel
        b0 = b0_channel
        rev_dwi = rev_dwi_channel
        rev_b0 = rev_b0_channel
        aparc_aseg = aparc_aseg_channel
        wmparc = wmparc_channel
        topup = topup_channel
        lesion = lesion_channel
}

workflow {
    inputs = get_data()

    /* Load bet template */
    ch_bet_template = params.preproc_t1_run_synthbet ? Channel.empty() : Channel.fromPath(params.t1_bet_template_t1, checkIfExists: true)
    ch_bet_probability = params.preproc_t1_run_synthbet ? Channel.empty() : Channel.fromPath(params.t1_bet_template_probability_map, checkIfExists: true)

    // ** Fetch license file ** //
    ch_fs_license = params.fs_license
        ? Channel.fromPath(params.fs_license, checkIfExists: true, followLinks: true)
        : Channel.empty().ifEmpty { error "No license file path provided. Please specify the path using --fs_license parameter." }

    // Check for mutually exclusive tracking methods
    if (params.run_local_tracking && params.run_pft) {
        exit 1, "SurgeryFlow doesn't support running both tracking methods at the moment. Please select either 'run_local_tracking' or 'run_pft'."
    }

    // Check profile compatibility with parameters
    if (workflow.profile.contains('tractoflow') && (params.run_synthbet || params.run_synthbet || params.run_synthseg)) {
        exit 1, "The 'tractoflow' profile is incompatible with Freesurfer's synth tools."
    }

    if (workflow.profile.contains('standard') && workflow.profile.contains('tumour')) {
        exit 1, "You have selected 'standard' and 'tumour' profile. Select only one profile to avoid conflicts."
    }

    if (workflow.profile.contains('use-gpu') && !params.run_local_tracking) {
        log.warn "Warning: You have selected 'use-gpu' profile, GPU acceleration is only applied to local tracking."
    }
    if (workflow.profile.contains('wm') && (workflow.profile.contains('standard') || workflow.profile.contains('tumour'))) {
        exit 1, "You have selected 'wm' profile, which is incompatible with 'standard' or 'tumour' profiles. 'Wm' uses white matter mask for seeding and seeding while 'standard' and 'tumour' profiles use FA thresholding mask for seeding and tracking."
    }

    /* TRACTOFLOW */

    TRACTOFLOW(
        inputs.dwi,         // channel : [required] meta, dwi, bval, bvec
        inputs.t1,          // channel : [required] meta, t1
        inputs.b0,          // channel : [optional] meta, sbref
        inputs.rev_dwi,     // channel : [optional] meta, rev_dwi, rev_bval, rev_bvec
        inputs.rev_b0,      // channel : [optional] meta, rev_sbref
        inputs.aparc_aseg,  // channel : [optional] meta, aparc_aseg
        inputs.wmparc,      // channel : [optional] meta, wmparc
        inputs.topup,       // channel : [optional] topup config file
        ch_bet_template,    // channel : [optional] meta, bet_template
        ch_bet_probability, // channel : [optional] meta, bet_probability_map
        inputs.lesion,      // channel : [optional] meta, lesion_mask
        ch_fs_license       // channel : path(fs_license)
    )

    /* BUNDLE SEGMENTATION */

    //
    // SUBWORKFLOW: Run BUNDLE_SEG
    //

if ( params.run_local_tracking) {

    BUNDLE_SEG( 
        TRACTOFLOW.out.dti_fa,              // channel: [ val(meta), [ fa ] ]
        TRACTOFLOW.out.local_tractogram,    // channel: [ val(meta), [ tractogram ] ]
        ch_fs_license
        )
}

if ( params.run_pft ) {
    BUNDLE_SEG( 
        TRACTOFLOW.out.dti_fa,              // channel: [ val(meta), [ fa ] ]
        TRACTOFLOW.out.pft_tractogram,      // channel: [ val(meta), [ tractogram ] ]
        ch_fs_license
        )     
}

    /* NIFTI TO DICOM CONVERSION */

    if ( params.run_nii_to_dicom ) {

    //
    // MODULE: Run REGISTRATION_CONVERT
    //

        NII_TO_DICOM(
            TRACTOFLOW.out.t1,                              // channel: [ val(meta), [ t1 ] ]
            TRACTOFLOW.out.anatomical_to_diffusion,         // channel: [ val(meta), [ warp ], [ affine ] ]
            BUNDLE_SEG.out.bundles,                         // channel: [ val(meta), [ bundles ] ]
            Channel.empty()                                 // channel: [ val(meta), [ dicom ] ], optional
        )
    }
/* END OF WORKFLOW */
}
