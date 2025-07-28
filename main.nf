#!/usr/bin/env nextflow

//BIDS
include {   IO_READBIDS                                               } from './modules/nf-neuro/io/readbids/main' 

// PREPROCESSING
include {   PREPROC_DWI                                               } from './subworkflows/nf-neuro/preproc_dwi/main'
include {   PREPROC_T1                                                } from './subworkflows/nf-neuro/preproc_t1/main'
include {   REGISTRATION as T1_REGISTRATION                           } from './subworkflows/nf-neuro/registration/main'
include {   REGISTRATION_CONVERT                                      } from './modules/nf-neuro/registration/convert/main'
include {   REGISTRATION_ANTSAPPLYTRANSFORMS as TRANSFORM_WMPARC      } from './modules/nf-neuro/registration/antsapplytransforms/main'
include {   REGISTRATION_ANTSAPPLYTRANSFORMS as TRANSFORM_APARC_ASEG  } from './modules/nf-neuro/registration/antsapplytransforms/main'
include {   ANATOMICAL_SEGMENTATION                                   } from './subworkflows/nf-neuro/anatomical_segmentation/main'

// RECONSTRUCTION
include {   RECONST_FRF        } from './modules/nf-neuro/reconst/frf/main'
include {   RECONST_MEANFRF    } from './modules/nf-neuro/reconst/meanfrf/main'
include {   RECONST_DTIMETRICS } from './modules/nf-neuro/reconst/dtimetrics/main'
include {   RECONST_FODF       } from './modules/nf-neuro/reconst/fodf/main'

// TRACKING
include {   TRACKING_PFTTRACKING   } from './modules/nf-neuro/tracking/pfttracking/main'
include {   TRACKING_LOCALTRACKING } from './modules/nf-neuro/tracking/localtracking/main'

// BUNDLESEG
include { BUNDLE_SEG } from './subworkflows/nf-neuro/bundle_seg/main'

// NII TO DICOM
include { NII_TO_DICOM } from './subworkflows/local/nii_to_dicom/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow get_data {
    main:
        if ( !params.input ) {
            log.info "You must provide an input directory containing all images using:"
            log.info ""
            log.info "        --input=/path/to/[input]             Input directory containing your subjects"
            log.info ""
            log.info "                         [input]"
            log.info "                           ├-- S1"
            log.info "                           |   ├-- *dwi.nii.gz"
            log.info "                           |   ├-- *dwi.bval"
            log.info "                           |   ├-- *dwi.bvec"
            log.info "                           |   ├-- *t1.nii.gz"
            log.info "                           |   ├-- *b0.nii.gz         (optional)"
            log.info "                           |   ├-- *rev_dwi.nii.gz    (optional)"
            log.info "                           |   ├-- *rev_dwi.bval      (optional)"
            log.info "                           |   ├-- *rev_dwi.bvec      (optional)"
            log.info "                           |   ├-- *rev_b0.nii.gz     (optional)"
            log.info "                           |   ├-- *wmparc.nii.gz     (optional)"
            log.info "                           |   ├-- *aparc_aseg.nii.gz (optional)"
            log.info "                           |   ├-- *topup_config.cnf  (optional)"
            log.info "                           |   └-- *lesion.nii.gz     (optional)"
            log.info "                           └-- S2"
            log.info "                               ├-- *dwi.nii.gz"
            log.info "                               ├-- *dwi.bval"
            log.info "                               ├-- *dwi.bvec"
            log.info "                               ├-- *t1.nii.gz"
            log.info "                               ├-- *b0.nii.gz         (optional)"
            log.info "                               ├-- *rev_dwi.nii.gz    (optional)"
            log.info "                               ├-- *rev_dwi.bval      (optional)"
            log.info "                               ├-- *rev_dwi.bvec      (optional)"
            log.info "                               ├-- *rev_b0.nii.gz     (optional)"
            log.info "                               ├-- *wmparc.nii.gz     (optional)"
            log.info "                               ├-- *aparc_aseg.nii.gz (optional)"
            log.info "                               ├-- *topup_config.cnf  (optional)"
            log.info "                               └-- *lesion.nii.gz     (optional)"
            log.info ""
            log.info "        --atlas_directory=/path/to/[atlas]                Input Atlas directory   (optional)"
            log.info "        --fs_license=/path/to/[fs_license]                Freesurfer license file"
            log.info ""
            log.info "        **nf-surgeryflow is still a WIP. We recommend using only with --profile docker for now.**"
            log.info ""
            error "Please resubmit your command with the previous file structure."
        }
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

    /* PREPROCESSING */

    //
    // SUBWORKFLOW: Run PREPROC_DWI
    //
    PREPROC_DWI(
        inputs.dwi,         // channel: [ val(meta), dwi, bval, bvec ]
        inputs.rev_dwi,     // channel: [ val(meta), rev-dwi, bval, bvec ], optional
        inputs.b0,          // Channel: [ val(meta), b0 ], optional
        inputs.rev_b0,      // channel: [ val(meta), rev-b0 ], optional
        inputs.topup        // channel: [ 'topup.cnf' ], optional
    )

    //
    // SUBWORKFLOW: Run PREPROC_T1
    //

    ch_t1_meta = inputs.t1.map{ it[0] }
    PREPROC_T1(
        inputs.t1,                              // channel: [ val(meta), image ]
        ch_t1_meta.combine(ch_bet_template),    // channel: [ val(meta), template ]                              , optional
        ch_t1_meta.combine(ch_bet_probability), // channel: [ val(meta), probability-map, mask, initial-affine ] , optional
        Channel.empty(),                        // channel: [ val(meta), mask ]                                  , optional
        Channel.empty(),                        // channel: [ val(meta), ref, ref-mask ]                         , optional
        Channel.empty(),                        // channel: [ val(meta), ref ]                                   , optional
        Channel.empty()                         // channel: [ val(meta), weights ]                               , optional
    )

    

    //
    // MODULE: Run RECONST_DTIMETRICS
    //

    ch_dti_metrics = PREPROC_DWI.out.dwi
        .join(PREPROC_DWI.out.bval)
        .join(PREPROC_DWI.out.bvec)
        .join(PREPROC_DWI.out.b0_mask)

    RECONST_DTIMETRICS( ch_dti_metrics )

    //
    // SUBWORKFLOW: Run REGISTRATION
    //
    T1_REGISTRATION(
        PREPROC_T1.out.t1_final,        // channel: [ val(meta), [ image ] ]
        PREPROC_DWI.out.b0,             // channel: [ val(meta), [ ref ] ]
        RECONST_DTIMETRICS.out.fa,      // channel: [ val(meta), [ metric ] ], optional
        PREPROC_T1.out.mask_final,      // channel: [ val(meta), [ mask ] ], optional
        Channel.empty(),                // channel: [ val(meta), [ flo_segmentation ] ], optional
        Channel.empty()                 // channel: [ val(meta), [ ref_segmentation ] ], optional
    )

    /* SEGMENTATION */

    //
    // SUBWORKFLOW: Run ANATOMICAL_SEGMENTATION
    //
    ANATOMICAL_SEGMENTATION(
        T1_REGISTRATION.out.image_warped,   // channel: [ val(meta), [ image ] ]
            Channel.empty(),                // channel: [ val(meta), [ aparc_aseg, wmparc ] ], optional
            inputs.lesion,                  // channel: [ val(meta), [ lesion ] ], optional
            ch_fs_license                   // channel: [ val[meta], [ fs_license ] ], optional
    )

    //
    // MODULE: Run RECONST/FRF
    //
    ch_reconst_frf = PREPROC_DWI.out.dwi
        .join(PREPROC_DWI.out.bval)
        .join(PREPROC_DWI.out.bvec)
        .join(PREPROC_DWI.out.b0_mask)
        .join(ANATOMICAL_SEGMENTATION.out.wm_mask)
        .join(ANATOMICAL_SEGMENTATION.out.gm_mask)
        .join(ANATOMICAL_SEGMENTATION.out.csf_mask)

    RECONST_FRF( ch_reconst_frf )

    /* Run fiber response averaging over subjects */
    ch_single_frf = RECONST_FRF.out.frf
        .map{ it + [[], []] }

    ch_fiber_response = RECONST_FRF.out.wm_frf
        .join(RECONST_FRF.out.gm_frf)
        .join(RECONST_FRF.out.csf_frf)
        .mix(ch_single_frf)
    if ( params.run_mean_frf ) {
        RECONST_MEANFRF( RECONST_FRF.out.frf.map{ it[1] }.flatten() )
        ch_fiber_response = RECONST_FRF.out.map{ it[0] }
            .combine( RECONST_MEANFRF.out.meanfrf )
    }

    //
    // MODULE: Run RECONST/FODF
    //
    ch_reconst_fodf = PREPROC_DWI.out.dwi
        .join(PREPROC_DWI.out.bval)
        .join(PREPROC_DWI.out.bvec)
        .join(PREPROC_DWI.out.b0_mask)
        .join(RECONST_DTIMETRICS.out.fa)
        .join(RECONST_DTIMETRICS.out.md)
        .join(ch_fiber_response)
    RECONST_FODF( ch_reconst_fodf )

    /* TRACKING */

    // Check for mutually exclusive tracking methods
    if (params.run_local_tracking && params.run_pft) {
        exit 1, "SurgeryFlow doesn't support running both tracking methods at the moment. Please select either 'run_local_tracking' or 'run_pft'."
    }

    // Check profile compatibility with parameters
    if (params.profile.contains('tractoflow')&& (params.run_synthbet || params.run_synthbet || params.run_synthseg)) {
        exit 1, "The 'tractoflow' profile is incompatible with Freesurfer's synth tools."
    }

    if (params.profile.contains('standard') && params.profile.contains('tumour')) {
        exit 1, "You have selected 'standard' and 'tumour' profile. Select only one profile to avoid conflicts."
    }

    if (params.profile.contains('use-gpu') && !params.run_local_tracking) {
        log.warn "Warning: You have selected 'use-gpu' profile, GPU acceleration is only applied to local tracking."
    }
    if (params.profile.contains('wm') && (params.profile.contains('standard') || params.profile.contains('tumour'))) {
        exit 1, "You have selected 'wm' profile, which is incompatible with 'standard' or 'tumour' profiles. 'Wm' uses white matter mask for seeding and seeding while 'standard' and 'tumour' profiles use FA thresholding mask for seeding and tracking."
    }
    
    // Initialize empty tractogram channel
    ch_tractogram = Channel.empty()

    //
    // MODULE: Run TRACKING/PFTTRACKING
    //
    ch_pft_tracking = Channel.empty()
    if ( params.run_pft ) {
        ch_pft_tracking = ANATOMICAL_SEGMENTATION.out.wm_mask
            .join(ANATOMICAL_SEGMENTATION.out.gm_mask)
            .join(ANATOMICAL_SEGMENTATION.out.csf_mask)
            .join(RECONST_FODF.out.fodf)
            .join(RECONST_DTIMETRICS.out.fa)
        TRACKING_PFTTRACKING( ch_pft_tracking )
        
        ch_tractogram = TRACKING_PFTTRACKING.out.trk
    }

    //
    // MODULE: Run TRACKING/LOCALTRACKING
    //
    ch_local_tracking = Channel.empty()
    if ( params.run_local_tracking ) {
        ch_local_tracking = ANATOMICAL_SEGMENTATION.out.wm_mask
            .join(RECONST_FODF.out.fodf)
            .join(RECONST_DTIMETRICS.out.fa)
        TRACKING_LOCALTRACKING( ch_local_tracking )
        
        ch_tractogram = TRACKING_LOCALTRACKING.out.trk
    }

    /* BUNDLE SEGMENTATION */

    //
    // SUBWORKFLOW: Run BUNDLE_SEG
    //
    BUNDLE_SEG( 
        RECONST_DTIMETRICS.out.fa,  // channel: [ val(meta), [ fa ] ]
        ch_tractogram)              // channel: [ val(meta), [ tractogram ] ]

    /* NIFTI TO DICOM CONVERSION */

    // if ( params.run_nii_to_dicom ) {

    // //
    // // MODULE: Run REGISTRATION_CONVERT
    // //

    //     FIXME: 
    //     if ( params.run_synthmorph) {
            
    //         ch_convert = T1_REGISTRATION.out.transfo_image
    //             .join(PREPROC_T1.out.t1_final)
    //             .join(PREPROC_DWI.out.b0, remainder: true)
    //             .map{ it[0..3] + [it[4] ?: []] }
    //             .combine(ch_fs_license)

    //         REGISTRATION_CONVERT(ch_convert)

    //         } //Conversion is required only for synthmorph

    //     NII_TO_DICOM(
    //         PREPROC_T1.out.t1_final,
    //         REGISTRATION_CONVERT.out.affine_transform,      // channel: [ val(meta), [ affine ] ]
    //         REGISTRATION_CONVERT.out.deform_transform,      // channel: [ val(meta), [ deform ] ]
    //         BUNDLE_SEG.out.bundles,                         // channel: [ val(meta), [ bundles ] ]
    //         Channel.empty()                                 // channel: [ val(meta), [ dicom ] ], optional
    //     )
    // }
/* END OF WORKFLOW */
}
