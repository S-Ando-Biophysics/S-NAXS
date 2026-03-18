# P-NATS
P-NAXS = <ins>**P**</ins>urifier of <ins>**N**</ins>ucleic <ins>**A**</ins>cid <ins>**T**</ins>hree dimensional <ins>**S**</ins>tructures

## About S-NAXS
X-ray crystallographers encounter the phase problem when determining the three-dimensional structures of biological macromolecules. The phase problem arises because X-ray diffraction experiments measure only the intensities of diffracted X-rays, whereas the phase information required to reconstruct an electron density map is not directly observed. Without phase information, the electron density map, which reveals the positions of atoms in the crystal, cannot be calculated from the diffraction data.

One of the most widely used methods for solving the phase problem is molecular replacement. In this approach, a previously determined structure that is expected to be similar to the target molecule is identified in the Protein Data Bank, a public repository of experimentally determined three-dimensional structures of biological macromolecules. The known structure is used as a search model to determine the orientation and position of the molecule in the crystal and to provide initial phase estimates for the diffraction data of the unknown structure. In essence, molecular replacement exploits structural similarity to obtain phase information.

Before performing molecular replacement, it is often desirable to prepare a refined search model derived from the known structure. For example, ligands and crystallographic water molecules may be removed, and irregular features in the structure may be corrected in order to obtain a simplified and well-behaved model. **P-NATS** is a tool designed specifically for nucleic acid structures that automatically performs these preprocessing steps.

## How to install

    cd ~
    git clone https://github.com/S-Ando-Biophysics/P-NATS
    cd P-NATS
    bash install.sh

## Preparation
Please install and set up the following external software in advance.

| Name | Website |
| :----- | :----- |
| Ubuntu | https://apps.microsoft.com/search?query=Ubuntu |
| 3DNA | http://forum.x3dna.org/site-announcements/download-instructions/ |

### Ubuntu
This is required only for Windows. It is necessary to turn on "Windows Subsystem for Linux (WSL)" and "Virtual Machine Platform" in the Windows settings to be able to use shell scripts. Furthermore, run `sudo apt update` and `sudo apt upgrade` on Ubuntu.

### 3DNA
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

