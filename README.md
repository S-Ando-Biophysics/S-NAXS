# P-NATS
P-NATS = <ins>**P**</ins>urifier of <ins>**N**</ins>ucleic <ins>**A**</ins>cid <ins>**T**</ins>hree-dimensional <ins>**S**</ins>tructures

## How to install
Please run the following commands in order in your environment where `bash` can be executed.

    cd ~
    git clone https://github.com/S-Ando-Biophysics/P-NATS
    cd P-NATS
    bash install.sh

## About P-NATS
X-ray crystallographers encounter the phase problem when determining the three-dimensional structures of biological macromolecules. The phase problem arises because X-ray diffraction experiments measure only the intensities of diffracted X-rays, whereas the phase information required to reconstruct an electron density map is not directly observed. Without phase information, the electron density map, which reveals the positions of atoms in the crystal, cannot be calculated from the diffraction data.

One of the most widely used methods for solving the phase problem is molecular replacement. In this approach, a previously determined structure that is expected to be similar to the target molecule is identified in the Protein Data Bank, a public repository of experimentally determined three-dimensional structures of biological macromolecules. The known structure is used as a search model to determine the orientation and position of the molecule in the crystal and to provide initial phase estimates for the diffraction data of the unknown structure. In essence, molecular replacement exploits structural similarity to obtain phase information.

Before performing molecular replacement, it is often desirable to prepare a refined search model derived from the known structure. For example, ligands and crystallographic water molecules may be removed, and irregular features in the structure may be corrected in order to obtain a simplified and well-behaved model. **P-NATS** is a tool designed specifically for nucleic acid structures that automatically performs these preprocessing steps.

## Dependencies
P-NATS uses the software "3DNA" and the Python library "GEMMI".

||3DNA|GEMMI|
|:---|:---|:---|
|Homepage|https://x3dna.org/|https://github.com/project-gemmi/gemmi|
|Citation|https://doi.org/10.1038/nprot.2008.104|https://doi.org/10.21105/joss.04200|
|License|CC-BY-NC-4.0 & Original citation-ware|MPL-2.0|
