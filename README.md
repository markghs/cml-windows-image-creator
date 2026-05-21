
# CML Windows Image Creator

CML Windows Image Creator is a bash script made to run on the Cisco Modeling Labs (CML) host to automate the end-to-end process of creating Windows 11 and Windows Server 2025 custom images for use in CML topologies. The image is finalized with sysprep so the nodes will have unique SID's to avoid duplicate SID issues if the images are used to create a Windows Active Directory domain for the topology.

The script will create a custom Windows 11 or Windows Server 2025 ISO image with the autounattend.xml files and sysprep scripts, which is then used with qemu-system-x86_64 to install the custom ISO to a qcow2 disk image to be used with the custom image definition. After the installation to the qcow2 image is complete, the CML API is used to upload the qcow2 image and create the node and image definitions.

## How it works

1. Checks for the Windows Server 2025 or Windows 11 evalution ISO file in /var/tmp/. If not present, it downloads the ISO from Microsoft.
2. Mounts the ISO and copies its contents to a working directory.
3. Creates required directories for Windows setup automation files.
   <br>sources/\$OEM\$/\$\$/System32/Sysprep/ <br>sources/\$OEM\$/\$\$/Setup/Scripts/
5. Copies custom configuration files (autounattend.xml, unattend.xml, SetupComplete.cmd) into the ISO structure.
6. Unmounts the ISO and removes the mount directory.
7. Creates a new ISO with mkisofs, with the sysprep and Setup/Scripts folders and custom autounattend.xml and sysprep config files.
8. Creates a 160GB qcow2 disk image if it doesn’t exist.
9. Launches a VM using qemu-system-x86_64 using the qcow2 disk image and the custom ISO file.
10. The Windows 11 or Server 2025 OS is auto-installed using the autounattend process to the qcow2 disk
11. The image is finalized with sysprep and the qemu VM is shutdown.
12. The CML API is used to upload the qcow2 image to be used with the image definition.
13. The CML API is used to create the node and image definitions. The image definition uses the qcow2 disk image.

## Prerequisites

<br> The script must be run from the Cisco CML controller terminal
<br>This CML host must be able to connect to the internet to download the Windows ISO
<br>The script has only been tested on a standalone baremetal CML installation version 2.9.1

## Installation

1. Download from github
```
git clone https://github.com/markghs/cml-windows-image-creator
```

2. Change directory
```
cd cml-windows-image-creator
```

## Usage

1. Run cml_image_creator.sh with sudo
```
sudo bash cml_image_creator.sh
```

2. Select which image to create or test the CML API connection

<img width="986" height="751" alt="cwic_menu" src="https://github.com/user-attachments/assets/8bc6a4c3-a276-458c-a363-bcdf3d1bce1a" />


3. After selecting the option you must enter the username and password for the CML API connection

```
Please select an option:
  1) Create Windows 11 image
  2) Create Windows Server 2025 image
  3) Test Connection to CML API
  4) Exit

Enter your choice [1-4]: 2
Enter the username and password for the CML API
Enter username: admin
Enter password:

```
The Windows evaluation ISO will be downloaded from Microsoft if it is not already in /var/tmp

```
Connecting to software-static.download.prss.microsoft.com (software-static.download.prss.microsoft.com)|199.232.214.172|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 7736125440 (7.2G) [application/octet-stream]
Saving to: ‘/var/tmp/26200.6584.250915-1905.25h2_ge_release_svc_refresh_CLIENT_CONSUMER_x64FRE_en-us.iso’

6200.6584.250915-1905.25h2_ge_release_svc_refresh_CLIENT_C  40%[======================================================>                  ] 2.92G  91.6MB/s    eta 51s
```

4. Windows will auto-install to the qcow2 disk image and then finalize the image with sysprep. You can view the installation progress by connecting to the CML host on VNC port 5901

```
ISO creation process completed.
Creating disk image...
Formatting '/var/tmp/WIN25_IMG.qcow2', fmt=qcow2 cluster_size=65536 extended_l2=off compression_type=zlib size=171798691840 lazy_refcounts=off refcount_bits=16
#######################################################
#   Creating VM this may take several minutes         #
#######################################################
```

<img width="1072" height="845" alt="cml_vnc" src="https://github.com/user-attachments/assets/46e326d2-5d7b-4d67-9803-760caeb68b79" />

<img width="1066" height="893" alt="cml_vnc_sysprep" src="https://github.com/user-attachments/assets/03a3e5bb-d8c9-4450-8e8f-19bf2c123508" />

5. When the image is complete you see will Image Creation Finished

```
#######################################################
#         Server 2025 Image Creation Finished         #
#######################################################
sysadmin@cml-controller:~/cml-windows-image-creator$
```
6. Confirm the node and image definitions are created and ready for use in the CML interface

<img width="2136" height="968" alt="cml_nd" src="https://github.com/user-attachments/assets/fb7f2867-14b7-49b7-b03b-4c8438924075" />

7. Login

The autounattend.xml file configures the Administror and labuser accounts with the following passwords;

```
Username: Administrator
Password: lab123

Username: labuser
Password: lab123

```

8. Each node will have a unique SID

<img width="2152" height="1230" alt="cml_sid" src="https://github.com/user-attachments/assets/8d177d37-0668-4190-bcee-e99e6da109cb" />


## Acknowledgments

<br>The idea to use qemu-system-x86_64 to create the image and the config is from https://github.com/rschmied/MakeWindowsQCOW2
<br>The autounattend.xml file for Windows 11 was created using https://schneegans.de/windows/unattend-generator/
