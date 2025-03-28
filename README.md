# NF-SurgeryFlow

NF-SurgeryFlow is a Nextflow pipeline for processing neuroimaging data. This pipeline includes various preprocessing, reconstruction, tracking, and segmentation steps.

## Table of Contents
- [NF-SurgeryFlow](#nf-surgeryflow)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Installation](#installation)
  - [Usage](#usage)

## Introduction

**nf-SurgeryFlow** is an end-to-end tractography pipeline dedicated to clinicians in a pre-surgical setting. It performs preprocessing, T1 segmentation, DTI and fODF metrics computations, tractography and virtual dissection. 

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

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow.

**Configurations profiles**

1. `-profile docker`: Each process will be run using docker containers.
1. `-profile apptainer` or `-profile singularity`: Each process will be run using apptainer/singularity images.

**Using either `-profile docker` or `-profile apptainer` is highly recommended, as it controls the version of the software used and avoids the installation of all the required softwares.**

To run the pipeline, use the following command:

```sh
nextflow run main.nf --input /path/to/input --atlas /path/to/atlas --fs_license /path/to/license.txt