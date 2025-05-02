# NF-SurgeryFlow

NF-SurgeryFlow is a Nextflow pipeline for processing neuroimaging data. This pipeline includes various preprocessing, reconstruction, tracking, and segmentation steps.

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

To install NF-SurgeryFlow, you need to have Nextflow and Docker installed. Follow these steps:

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

For complete usage instructions, please see the [documentation](/docs/usage.md). **nf-pediatric** aligns with the [BIDS](https://bids-specification.readthedocs.io/en/stable/) specification. To promote the use of standardized data formats and structures, **nf-pediatric** requires a BIDS-compliant folder as its input directories. We encourage users to validate their BIDS layout using the [bids-validator tool](https://hub.docker.com/r/bids/validator). The following example provides a BIDS structure for pediatric data (not infant) containg an acquisition with a reverse phase-encoded B0 image.

```bash
             "        --input=/path/to/[input]             Input directory containing your subjects"
             ""
             "                         [input]"
             "                           ├-- S1"
             "                           |   ├-- *dwi.nii.gz"
             "                           |   ├-- *dwi.bval"
             "                           |   ├-- *dwi.bvec"
             "                           |   ├-- *t1.nii.gz"
             "                           |   └-- *lesion.nii.gz     (optional)"
             "                           └-- S2"
             "                               ├-- *dwi.nii.gz"
             "                               ├-- *dwi.bval"
             "                               ├-- *dwi.bvec"
             "                               ├-- *t1.nii.gz"
             "                               └-- *lesion.nii.gz     (optional)"
```

**Configurations profiles**

1. `-profile docker`: Each process will be run using docker containers.
2. `-profile apptainer` or `-profile singularity`: Each process will be run using apptainer/singularity images.

**Using either `-profile docker` or `-profile apptainer` is highly recommended, as it controls the version of the software used and avoids the installation of all the required softwares.**

To run the pipeline, use the following command:

```sh
nextflow run main.nf --input /path/to/input --atlas /path/to/atlas --fs_license /path/to/license.txt -profile [<docker|apptainer>]
```
