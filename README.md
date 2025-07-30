# nf-surgeryFlow

nf-surgeryFlow is a Nextflow pipeline for processing neuroimaging data. This pipeline includes various preprocessing, reconstruction, tracking, and segmentation steps.

## Table of Contents
- [NF-SurgeryFlow](#nf-surgeryflow)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Installation](#installation)
  - [Usage](#usage)

## Introduction

**nf-SurgeryFlow** is an end-to-end tractography pipeline dedicated to clinicians in a pre-surgical setting. It performs preprocessing, T1 segmentation, DTI and fODF metrics computations, tractography, virtual dissection and an optional Nifti to DICOM conversion. 

![nf-surgeryflow-schema(/nf-surgeryflow-schema.png)]

## Installation

To install nf-surgeryFlow, you need to have Nextflow and Docker installed. Follow these steps:

1. Install Nextflow:
    ```sh
    curl -s https://get.nextflow.io | bash
    ```

2. Install Docker:
    Follow the instructions on the [Docker website](https://docs.docker.com/get-docker/).

3. Clone the repository:
    ```sh
    git clone https://github.com/yourusername/nf-surgeryflow.git
    cd nf-surgeryflow
    ```

## Usage

This pipeline is still under developpement, therefore has not been tested under all circomstances. Here are the main elements to know to be able to run it:
- Some modules use Freesurfer tools, which require pointing to a valid Freesurfer license. This license should be provided by the user and passed through when calling nf-surgeryflow. Refer to [this page](https://surfer.nmr.mgh.harvard.edu/registration.html).
- BundleSeg uses an atlas-based virtual dissection method, therefore needs a white matter bundles atlas. You can use yours or use [this one](https://zenodo.org/records/10103446) 

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow.

### Input specification

nf-surgeryflow takes the following inputs, passing the /path/to/root at the --input flag:

```bash
             "        --input=/path/to/[root]             Input directory containing your subjects"
             ""
             "                         [root]"
             "                           ├-- S1"
             "                           |   ├-- *dwi.nii.gz"
             "                           |   ├-- *dwi.bval"
             "                           |   ├-- *dwi.bvec"
             "                           |   ├-- *t1.nii.gz"
             "                           |   ├-- *b0.nii.gz         (optional)"
             "                           |   ├-- *rev_dwi.nii.gz    (optional)"
             "                           |   ├-- *rev_dwi.bval      (optional)"
             "                           |   ├-- *rev_dwi.bvec      (optional)"
             "                           |   ├-- *rev_b0.nii.gz     (optional)"
             "                           |   └-- *lesion.nii.gz     (optional)" [WIP]
             "                           └-- S2"
             "                               ├-- *dwi.nii.gz"
             "                               ├-- *dwi.bval"
             "                               ├-- *dwi.bvec"
             "                               ├-- *t1.nii.gz"
             "                               ├-- *b0.nii.gz         (optional)"
             "                               ├-- *rev_dwi.nii.gz    (optional)"
             "                               ├-- *rev_dwi.bval      (optional)"
             "                               ├-- *rev_dwi.bvec      (optional)"
             "                               ├-- *rev_b0.nii.gz     (optional)"
             "                               └-- *lesion.nii.gz     (optional)" [WIP]
```

**Configurations profiles**

1. `-profile docker`: Each process will be run using docker containers (*Recommended*).
2. `-profile apptainer` or `-profile singularity`: Each process will be run using apptainer/singularity images.
3. `-profile use-gpu`: Some processes use GPU acceleration [WIP]
4. `-profile dicom`: Convert output back to DICOM [WIP]


**Processing profiles**

1. `-profile standard`: Base tracking configuration for pre-surgical evaluation
2. `-profile tumour`: Base tracking configuration for tumour evaluation
3. `-profile tractoflow`: Revert processing to standard tractoflow pipeline [WIP]

**Using either `-profile docker` or `-profile apptainer` is highly recommended, as it controls the version of the software used and avoids the installation of all the required softwares.**

To run the pipeline, use the following command:

```sh
nextflow run main.nf --input /path/to/input --atlas /path/to/atlas --fs_license /path/to/license.txt -profile standard,[<docker|apptainer>]
```
**Processing steps**
Diffusion processes
- Preliminary DWI brain extraction (FSL)
- Denoise DWI (Mrtrix3)
- Gibbs correction (Mrtrix3)
- Topup (FSL)
- Eddy (FSL)
- Extract B0 (Scilpy)
- DWI brain extraction (FSL)
- N4 DWI (ANTs)
- Crop DWI (Scilpy)
- Resample DWI (Scilpy)
- Resample B0 (Scilpy)
- extract SH fitted to DWI (Scilpy)

T1 processes
- Denoise T1 (Scilpy)
- N4 T1 (ANTs)
- Resample T1 (Scilpy)
- T1 brain extraction (Freesurfer)
- Crop T1 (Scilpy)
- Registration on diffusion (Freesurfer)
- Tissue segmentation (Freesurfer)

Metrics processes
- Extract DTI shells (Scilpy)
- DTI metrics (Scilpy)
- Extract fODF shells (Scilpy)
- Compute fiber response function (Scilpy)
- Mean fiber response function (Scilpy)
- fODF metrics (scilpy)
- PFT maps (Scilpy)
- Seeding and tracking masks (Scilpy)
- Tracking (local or PFT) (Scilpy)

Bundle segmentation
- Register atlas in diffusion space (ANTs)
- Bundle segmentation and clean (Scilpy)
- Filter_Bundles (Scilpy)
- Bundles_On_Anat (Scilpy)

Nifti to DICOM [WIP]
- Affine matrix conversion (Freesurfer)
- NIFTI to DICOM conversion (nii2dcm)
