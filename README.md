# P-NATS
P-NATS = <ins>**P**</ins>urifier of <ins>**N**</ins>ucleic <ins>**A**</ins>cid <ins>**T**</ins>hree-dimensional <ins>**S**</ins>tructures

## About P-NATS
### X-ray crystallography
X-ray crystallographers encounter the phase problem when determining the three-dimensional structures of biological macromolecules. The phase problem arises because X-ray diffraction experiments measure only the intensities of diffracted X-rays, whereas the phase information required to reconstruct an electron density map is not directly observed. Without phase information, the electron density map, which reveals the positions of atoms in the crystal, cannot be calculated from the diffraction data.

### Molecular replacement
One of the most widely used methods for solving the phase problem is molecular replacement. In this approach, a previously determined structure that is expected to be similar to the target molecule is identified in the Protein Data Bank (PDB), a public repository of experimentally determined three-dimensional structures of biological macromolecules. The known structure is used as a search model to determine the orientation and position of the molecule in the crystal and to provide initial phase estimates for the diffraction data of the unknown structure. In essence, molecular replacement exploits structural similarity to obtain phase information.

### P-NATS
Before performing molecular replacement, it is often desirable to prepare a refined search model derived from the known structure. For example, ligands and crystallographic water molecules may be removed, and irregular features in the structure may be corrected in order to obtain a simplified and well-behaved model. **P-NATS** is a tool designed specifically for nucleic acid structures that automatically performs these preprocessing steps.

### P-NATS DataBase
P-NATS has already been applied to all nucleic acid structures deposited in the PDB, and the processed models are compiled in the **P-NATS Database**. This database is automatically updated in accordance with updates to the PDB, ensuring that the latest structures are always available. Users are encouraged to make use of this resource as well.　Please access the following URL: https://s-ando-biophysics.github.io/P-NATS-DB.

## How to install
Please run the following commands in order in your environment where `bash` can be executed.

    cd ~
    git clone https://github.com/S-Ando-Biophysics/P-NATS.git
    cd P-NATS
    bash install.sh

## Dependencies
P-NATS uses the software "3DNA" and the Python library "GEMMI".

||3DNA|GEMMI|
|:---|:---|:---|
|Homepage|https://x3dna.org/|https://github.com/project-gemmi/gemmi|
|Citation|https://doi.org/10.1038/nprot.2008.104|https://doi.org/10.21105/joss.04200|
|License|Original citation-ware (the below described)|MPL-2.0|

### 3DNA
If you do not have **3DNA**, please install it beforehand by following the instructions below.

After registering on the official website (forum) and receiving approval, you will be able to download the installer. For details, please refer to the instructions on the official website. Once you have downloaded the installer, run the following commands in order. The following steps are for Windows (WSL, Ubuntu). The procedure for macOS and Linux is similar.

    # Please change the directory name and 3DNA version as appropriate.
    # Assume that "x3dna-v2.4-linux-64bit.tar.gz" has been downloaded to "C:\Users\name\Downloads".
    sudo apt update
    sudo apt install ruby
    sudo su
    cd /usr/local
    mv /mnt/c/Users/name/Downloads/x3dna-v2.4-linux-64bit.tar.gz .
    tar pzxvf x3dna-v2.4-linux-64bit.tar.gz
    cd x3dna-v2.4/bin
    ./x3dna_setup
    exit
    echo 'export X3DNA=/usr/local/x3dna-v2.4' >> ~/.bashrc
    echo 'export PATH="$X3DNA/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc

#### Original citation-ware of 3DNA (https://x3dna.org/highlights/3dna-c-source-code-is-available)
3DNA is a suite of software programs for the analysis, rebuilding and visualization of 3-Dimensional Nucleic Acid structures. Permission to use, copy, modify, and distribute this suite for any purpose, with or without fee, is hereby granted, and subject to the following conditions:

At least one of the 3DNA papers must be cited, including the following two primary ones:

   1. Lu, X. J., & Olson, W. K. (2003). "3DNA: a software package for the analysis, rebuilding and visualization of three‐dimensional nucleic acid structures." Nucleic Acids Research, 31(17), 5108-5121.

   2. Lu, X. J., & Olson, W. K. (2008). "3DNA: a versatile, integrated software system for the analysis, rebuilding and visualization of three-dimensional nucleic-acid structures." Nature Protocols, 3(7), 1213-1227.

THE 3DNA SOFTWARE IS PROVIDED "AS IS", WITHOUT EXPRESSED OR IMPLIED WARRANTY OF ANY KIND.

Any 3DNA-related questions, comments, and suggestions are welcome and should be directed to the open 3DNA Forum (http://forum.x3dna.org/).
