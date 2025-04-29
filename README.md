# NF-SurgeryFlow

NF-SurgeryFlow is a Nextflow pipeline for processing neuroimaging data. This pipeline includes various preprocessing, reconstruction, tracking, and segmentation steps.

## Table of Contents
- [NF-SurgeryFlow](#nf-surgeryflow)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Installation](#installation)
  - [Usage](#usage)
  - [Citations](#citations)

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

**Configurations profiles**

1. `-profile docker`: Each process will be run using docker containers.
2. `-profile apptainer` or `-profile singularity`: Each process will be run using apptainer/singularity images.

**Using either `-profile docker` or `-profile apptainer` is highly recommended, as it controls the version of the software used and avoids the installation of all the required softwares.**

To run the pipeline, use the following command:

```sh
nextflow run main.nf --input /path/to/input --atlas /path/to/atlas --fs_license /path/to/license.txt
```

## Citations

```
Tractoflow:

Theaud, G., Houde, J.-C., Boré, A., Rheault, F., Morency, F., Descoteaux, M.,TractoFlow: A robust, efficient and reproducible diffusion MRI pipeline leveraging Nextflow & Singularity, NeuroImage, https://doi.org/10.1016/j.neuroimage.2020.116889.

Kurtzer GM, Sochat V, Bauer MW Singularity: Scientific containers for mobility of compute. PLoS ONE 12(5) (2017): e0177459. https://doi.org/10.1371/journal.pone.0177459

Garyfallidis, E., Brett, M., Amirbekian, B., Rokem, A., Van Der Walt, S., Descoteaux, M., Nimmo-Smith, I., 2014. Dipy, a library for the analysis of diffusion mri data. Frontiers in neuroinformatics 8, 8.

Tournier, J. D., Smith, R. E., Raffelt, D. A., Tabbara, R., Dhollander, T., Pietsch, M., … & Connelly, A. (2019). MRtrix3: A fast, flexible and open software framework for medical image processing and visualisation. bioRxiv, 551739.

Avants, B.B., Tustison, N., Song, G., 2009. Advanced normalization tools (ants). Insight j 2, 1–35.

Jenkinson, M., Beckmann, C.F., Behrens, T.E., Woolrich, M.W., Smith, S.M., 2012. Fsl. Neuroimage 62, 782–790.

Hoffmann M, Hoopes A, Greve DN, Fischl B, Dalca AV, 2024, Imaging Neuroscience, 2, pp 1-33.

Andrew Hoopes, Jocelyn S. Mora, Adrian V. Dalca, Bruce Fischl, Malte Hoffmann, 2022, SynthStrip: Skull-Stripping for Any Brain Image, NeuroImage 260, https://doi.org/10.1016/j.neuroimage.2022.119474.

B Billot, DN Greve, O Puonti, A Thielscher, K Van Leemput, B Fischl, AV Dalca, JE Iglesias, 2023, SynthSeg: Segmentation of brain MRI scans of any contrast and resolution without retraining, Medical Image Analysis, 83, 102789.

BundleSeg:

St-Onge, Etienne, Kurt G. Schilling, and Francois Rheault. "BundleSeg: A versatile, 
reliable and reproducible approach to white matter bundle segmentation." International 
Workshop on Computational Diffusion MRI. Cham: Springer Nature Switzerland, (2023)

Rheault, Francois. Analyse et reconstruction de faisceaux de la matière blanche.
page 137-170, (2020), https://savoirs.usherbrooke.ca/handle/11143/17255

Kurtzer GM, Sochat V, Bauer MW Singularity: Scientific containers for
mobility of compute. PLoS ONE 12(5): e0177459 (2017)
https://doi.org/10.1371/journal.pone.0177459

P. Di Tommaso, et al. Nextflow enables reproducible computational workflows.
Nature Biotechnology 35, 316–319 (2017) https://doi.org/10.1038/nbt.3820
```