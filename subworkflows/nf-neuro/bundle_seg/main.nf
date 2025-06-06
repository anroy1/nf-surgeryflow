include { REGISTRATION_ANTS                 } from '../../../modules/nf-neuro/registration/ants/main'
include { BUNDLE_RECOGNIZE                  } from '../../../modules/nf-neuro/bundle/recognize/main'

def fetch_bundleseg_atlas(atlasUrl, configUrl, dest) {

    def atlas = new File("$dest/atlas.zip").withOutputStream { out ->
        new URL(atlasUrl).withInputStream { from -> out << from; }
    }

    def config = new File("$dest/config.zip").withOutputStream { out ->
        new URL(configUrl).withInputStream { from -> out << from; }
    }

    def atlasFile = new java.util.zip.ZipFile("$dest/atlas.zip")
    atlasFile.entries().each { it ->
        def path = java.nio.file.Paths.get("$dest/atlas/" + it.name)
        if(it.directory){
            java.nio.file.Files.createDirectories(path)
        }
        else {
            def parentDir = path.getParent()
            if (!java.nio.file.Files.exists(parentDir)) {
                java.nio.file.Files.createDirectories(parentDir)
            }
            java.nio.file.Files.copy(atlasFile.getInputStream(it), path)
        }
    }

    def configFile = new java.util.zip.ZipFile("$dest/config.zip")
    configFile.entries().each { it ->
        def path = java.nio.file.Paths.get("$dest/config/" + it.name)
        if(it.directory){
            java.nio.file.Files.createDirectories(path)
        }
        else {
            def parentDir = path.getParent()
            if (!java.nio.file.Files.exists(parentDir)) {
                java.nio.file.Files.createDirectories(parentDir)
            }
            java.nio.file.Files.copy(configFile.getInputStream(it), path)
        }
    }
}

workflow BUNDLE_SEG {

    take:
        ch_fa               // channel: [ val(meta), [ fa ] ]
        ch_tractogram       // channel: [ val(meta), [ tractogram ] ]

    main:

        ch_versions = Channel.empty()

        // ** Setting up Atlas reference channels. ** //
        if ( params.atlas_directory ) {
            atlas_anat = Channel.fromPath("$params.atlas_directory/atlas/mni_masked.nii.gz", checkIfExists: true, relative: true)
            atlas_config = Channel.fromPath("$params.atlas_directory/config/config_fss_1.json", checkIfExists: true, relative: true)
            atlas_average = Channel.fromPath("$params.atlas_directory/atlas/atlas/", checkIfExists: true, relative: true)
        }
        else {
            if ( !file("$workflow.workDir/atlas/mni_masked.nii.gz").exists() ) {
            fetch_bundleseg_atlas(  "https://zenodo.org/records/10103446/files/atlas.zip?download=1",
                                    "https://zenodo.org/records/10103446/files/config.zip?download=1",
                                    "${workflow.workDir}/")
            }
            atlas_anat = Channel.fromPath("$workflow.workDir/atlas/mni_masked.nii.gz")
            atlas_config = Channel.fromPath("$workflow.workDir/config/config_fss_1.json")
            atlas_average = Channel.fromPath("$workflow.workDir/atlas/atlas/")
        }

        // ** Register the atlas to subject's space. Set up atlas file as moving image ** //
        // ** and subject anat as fixed image.                                         ** //
        ch_register =  ch_fa.combine(atlas_anat)
                            .map{ it + [[]] }

        REGISTRATION_ANTS ( ch_register )
        ch_versions = ch_versions.mix(REGISTRATION_ANTS.out.versions.first())

        // ** Perform bundle recognition and segmentation ** //
        ch_recognize_bundle = ch_tractogram
            .join(REGISTRATION_ANTS.out.affine)
            .combine(atlas_config)
            .combine(atlas_average)

        BUNDLE_RECOGNIZE ( ch_recognize_bundle )
        ch_versions = ch_versions.mix(BUNDLE_RECOGNIZE.out.versions.first())


    emit:
        bundles = BUNDLE_RECOGNIZE.out.bundles              // channel: [ val(meta), [ bundles ] ]

        versions = ch_versions                              // channel: [ versions.yml ]
}
