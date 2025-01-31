#!/usr/bin/env nextflow

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
            log.info "                           |   └-- *t1.nii.gz"
            log.info "                           |   └-- *lesion.nii.gz" 
            log.info "                           └-- S2"
            log.info "                               ├-- *dwi.nii.gz"
            log.info "                               ├-- *dwi.bval"
            log.info "                               ├-- *dwi.bvec"
            log.info "                               └-- *t1.nii.gz"
            log.info "                           |   └-- *lesion.nii.gz"
            log.info ""
            log.info "        --atlas=/path/to/[atlas]             Input Atlas directory"
            log.info ""
            error "Please resubmit your command with the previous file structure."
        }
        input = file(params.input)
        atlas = file(params.atlas)

        // ** Loading all files. ** //
        dwi_channel = Channel.fromFilePairs("$input/**/*dwi.{nii.gz,bval,bvec}", size: 3, flat: true)
            { it.parent.name }
            .map{ sid, bvals, bvecs, dwi -> [ [id: sid], dwi, bvals, bvecs ] } // Reordering the inputs.
        t1_channel = Channel.fromFilePairs("$input/**/*t1.nii.gz", size: 1, flat: true)
            { it.parent.name }
            .map{ sid, t1 -> [ [id: sid], t1 ] }
        atlas_channel = Channel.fromPath("$atlas", type: 'dir')

    emit: // Those three lines below define your named output, use those labels to select which file you want.
        dwi = dwi_channel
        t1 = t1_channel
        atlas = atlas_channel
}

workflow {
    inputs = get_data()

    /* Load bet template */
    ch_bet_template = params.run_synthbet ? Channel.empty() : Channel.fromPath(params.t1_bet_template_t1, checkIfExists: true)
    ch_bet_probability = params.run_synthbet ? Channel.empty() : Channel.fromPath(params.t1_bet_template_probability_map, checkIfExists: true)

    // ** Fetch license file ** //
    ch_fs_license = params.fs_license
        ? Channel.fromPath(params.fs_license, checkIfExists: true, followLinks: true)
        : Channel.empty().ifEmpty { error "No license file path provided. Please specify the path using --fs_license parameter." }

    /* PREPROCESSING */

    //
    // SUBWORKFLOW: Run PREPROC_DWI
    //
    PREPROC_DWI(
        inputs.dwi,          // channel: [ val(meta), dwi, bval, bvec ]
        Channel.empty(),    // channel: [ val(meta), rev-dwi, bval, bvec ], optional
        Channel.empty(),    // Channel: [ val(meta), b0 ], optional
        Channel.empty(),    // channel: [ val(meta), rev-b0 ], optional
        Channel.empty()     // channel: [ 'topup.cnf' ], optional
    )

    //
    // SUBWORKFLOW: Run PREPROC_T1
    //

    ch_t1_meta = inputs.t1.map{ it[0] }
    PREPROC_T1(
        inputs.t1,                           // channel: [ val(meta), image ]
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

    ch_dti_metrics = PREPROC_DWI.out.dwi_resample
        .join(PREPROC_DWI.out.bval)
        .join(PREPROC_DWI.out.bvec)
        .join(PREPROC_DWI.out.b0_mask)

    RECONST_DTIMETRICS( ch_dti_metrics )

    //
    // MODULE: Run RECONST/FRF
    //
    ch_reconst_frf = PREPROC_DWI.out.dwi_resample
        .join(PREPROC_DWI.out.bval)
        .join(PREPROC_DWI.out.bvec)
        .join(PREPROC_DWI.out.b0_mask)

    RECONST_FRF( ch_reconst_frf )

    /* Run fiber response averaging over subjects */
    ch_fiber_response = RECONST_FRF.out.frf
    if ( params.dwi_fodf_fit_use_average_frf ) {
        RECONST_MEANFRF( RECONST_FRF.out.frf.map{ it[1] }.flatten() )
        ch_fiber_response = RECONST_FRF.out.map{ it[0] }
            .combine( RECONST_MEANFRF.out.meanfrf )
    }

    //
    // MODULE: Run RECONST/FODF
    //
    ch_reconst_fodf = PREPROC_DWI.out.dwi_resample
        .join(PREPROC_DWI.out.bval)
        .join(PREPROC_DWI.out.bvec)
        .join(PREPROC_DWI.out.b0_mask)
        .join(RECONST_DTIMETRICS.out.fa)
        .join(RECONST_DTIMETRICS.out.md)
        .join(ch_fiber_response)
    RECONST_FODF( ch_reconst_fodf )


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

    //
    // MODULE: Run REGISTRATION_CONVERT
    //
    ch_convert = T1_REGISTRATION.out.transfo_image
        .join(PREPROC_T1.out.t1_final)
        .join(PREPROC_DWI.out.b0, remainder: true)
        .map{ it[0..3] + [it[4] ?: []] }
        .combine(ch_fs_license)

    REGISTRATION_CONVERT( ch_convert )

    /* SEGMENTATION */

    //
    // SUBWORKFLOW: Run ANATOMICAL_SEGMENTATION
    //
    ANATOMICAL_SEGMENTATION(
        T1_REGISTRATION.out.image_warped,   // channel: [ val(meta), [ image ] ]
            Channel.empty(),                // channel: [ val(meta), [ aparc_aseg, wmparc ] ], optional
            Channel.empty(),                // channel: [ val(meta), [ lesion ] ], optional
            ch_fs_license                   // channel: [ val[meta], [ fs_license ] ], optional
    )

    //
    // MODULE: Run TRACKING/PFTTRACKING
    //
    ch_pft_tracking = ANATOMICAL_SEGMENTATION.out.wm_mask
        .join(ANATOMICAL_SEGMENTATION.out.gm_mask)
        .join(ANATOMICAL_SEGMENTATION.out.csf_mask)
        .join(RECONST_FODF.out.fodf)
        .join(RECONST_DTIMETRICS.out.fa)
    TRACKING_PFTTRACKING( ch_pft_tracking )

    //
    // MODULE: Run TRACKING/LOCALTRACKING
    //
    ch_local_tracking = ANATOMICAL_SEGMENTATION.out.wm_mask
        .join(RECONST_FODF.out.fodf)
        .join(RECONST_DTIMETRICS.out.fa)
    TRACKING_LOCALTRACKING( ch_local_tracking )

    /* BUNDLE SEGMENTATION */

    /* Tractogram input prep */

    ch_tractogram = TRACKING_PFTTRACKING.out.trk.mix(TRACKING_LOCALTRACKING.out.trk)

    //
    // SUBWORKFLOW: Run BUNDLE_SEG
    //

    BUNDLE_SEG( 
        RECONST_DTIMETRICS.out.fa,  // channel: [ val(meta), [ fa ] ]
        ch_tractogram)              // channel: [ val(meta), [ tractogram ] ]
}