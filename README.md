# S-NAXS
S-NAXS: Standardizer of Nucleic Acid X-ray Structures

## How to install

    cd ~
    git clone https://github.com/S-Ando-Biophysics/S-NAXS
    cd S-NAXS
    bash install.sh

## Preparation
Please install and set up the following external software in advance.

| Name | Website |
| :----- | :----- |
| Ubuntu | https://apps.microsoft.com/search?query=Ubuntu |
| 3DNA | http://forum.x3dna.org/site-announcements/download-instructions/ |
| Phenix | https://phenix-online.org/download |

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

### Phenix
Please download the command-line installer from the official website. Then please run the following commands in order. The following steps are for Windows (WSL, Ubuntu). The procedure for macOS and Linux is similar.

    # Please change the directory name and Phenix version as appropriate.
    # Assume that "Phenix-2.0-5936-Linux-x86_64.sh" has been downloaded to "C:\Users\name\Downloads".
    sudo su
    cd /usr/local
    mv /mnt/c/Users/name/Downloads/Phenix-2.0-5936-Linux-x86_64.sh .
    bash Phenix-2.0-5936-Linux-x86_64.sh -b -p /usr/local/phenix-2.0-5936
    exit
    echo "source /usr/local/phenix-2.0-5936/phenix_env.sh" >> ~/.bashrc
    source ~/.bashrc
