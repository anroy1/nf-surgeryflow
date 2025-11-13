include { REGISTRATION_TRACTOGRAM } from '../../../modules/nf-neuro/registration/tractogram/main'
include { TRACTOGRAM_DENSITYMAP } from '../../../modules/nf-neuro/tractogram/densitymap/main'
include { IMAGE_BURNVOXELS } from '../../../modules/nf-neuro/image/burnvoxels/main'
include { IO_NII2DCM } from '../../../modules/nf-neuro/io/nii2dcm/main'

workflow NII_TO_DICOM {

    take:
    ch_t1_native    // channel: meta, t1
    ch_transforms   // channel: meta, anatomical_to_dwi
    ch_bundles      // channel: meta, bundles
    ch_dicom        // channel: meta, dicom

    main:

    ch_versions = Channel.empty()

    ch_register_bundles = ch_t1_native
        .join(ch_transforms)
        .join(ch_bundles)
        .map { meta, t1, transforms, bundles -> [ meta, t1, transforms[1], bundles, [], transforms[0] ] }
    REGISTRATION_TRACTOGRAM(ch_register_bundles)
    ch_versions = ch_versions.mix(REGISTRATION_TRACTOGRAM.out.versions.first())

    ch_bundles_native = REGISTRATION_TRACTOGRAM.out.warped_tractogram
        .map { meta, bundles -> bundles.collect { bundle -> [meta, bundle] } }
        .flatMap()
    TRACTOGRAM_DENSITYMAP(ch_bundles_native)
    ch_versions = ch_versions.mix(TRACTOGRAM_DENSITYMAP.out.versions.first())

    ch_density_map = TRACTOGRAM_DENSITYMAP.out.density_map
        .groupTuple()
        .join(ch_t1_native)
    IMAGE_BURNVOXELS(ch_density_map)

    ch_nii2dcm = IMAGE_BURNVOXELS.out.all_masks_burned
        .concat(IMAGE_BURNVOXELS.out.each_mask_burned)
        .groupTuple()
        .map { meta, masks -> [meta, masks.flatten()] }
        .join(ch_dicom)
    IO_NII2DCM(ch_nii2dcm)

    emit:
    dicom = IO_NII2DCM.out.dicom_directory      // channel: [ val(meta), [ dicom_directory ] ]

    versions = ch_versions                      // channel: [ versions.yml ]
}