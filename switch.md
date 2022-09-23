[home](README.md)

# Hand-Built Multi-Purpose Switch

In this document I walk through the steps required to build and configure a secure server. I demonstrate:

- How to build an AMD [EPYC](https://en.wikipedia.org/wiki/Epyc) server from parts
- How to install [Debian](https://en.wikipedia.org/wiki/Debian) 11
- How to configure AMD [SME](https://developer.amd.com/sev/)
- How to configure AMD [SEV](https://developer.amd.com/sev/)
- How to configure [Secure Boot](https://en.wikipedia.org/wiki/Unified_Extensible_Firmware_Interface#SECURE-BOOT) on an AsRock Rack EPYCD8-2T
- How to take advantage of [Trusted Computing](https://en.wikipedia.org/wiki/Trusted_Computing#Sealed_storage) to enable automatic decryption of storage devices
- How to configure, build and [sign](https://en.wikipedia.org/wiki/Digital_signature) a custom Debian kernel
- How to install a kernel and [UEFI](https://en.wikipedia.org/wiki/Unified_Extensible_Firmware_Interface) image for boot

In further walkthroughs, I plan to show how to setup [OpenStack](https://www.openstack.org/) from source behind [nginx](https://en.wikipedia.org/wiki/Nginx), on top of [Kafka](https://en.wikipedia.org/wiki/Apache_Kafka) and [PostgreSQL](https://en.wikipedia.org/wiki/PostgreSQL) (not at all stock).

I believe the root CA for the MS key that is the basis for most secure boot has actually been shown to have been compromised. Luckily, my motherboard supports loading custom keys and chains of trust so I may eventually get around to figuring out if I can revoke it without major surgery on the linux boot process (there is a shim signed with an MS key, from reading).

Disambiguation: The term `ECC` may be used in this document to represent either of two concepts: [Error Correction Code](https://en.wikipedia.org/wiki/Error_correction_code) Memory, or [Elliptic Curve Cryptography](https://en.wikipedia.org/wiki/Elliptic-curve_cryptography). Use context to determine which.

## Motivation and Overview

I wanted a way to network a NAS and a workstation for high throughput while providing NAS access to
other devices. To accomplish this, I designed a switch with 10x10gbe ports and 8x1gbe ports. I decided
to go with 6x[RJ45](https://en.wikipedia.org/wiki/Modular_connector#8P8C) and
4x[SFP+](https://en.wikipedia.org/wiki/Small_form-factor_pluggable_transceiver)
for the 10gbe ports, since I was able to procure a 4-port SFP+ card. In total, I required 5 network
cards for 16 ports, leveraging 2 onboard 10gbe ports for the full 18.

For the server itself, I decided to overdo it with the intent of dedicating some resources to
switching while allowing the device to also host VMs/containers in the homelab infrastructure. In particular, I want to be able to compile and simulate quantum circuits.

When I received the motherboard I didn't immediately see the SATA port, and thought the board had only SAS and M.2 connectors. I then decided to purchase the SN570s. As it turns out, there was a SATADOM connector so now I can use that (not powered) to run the 120gb drive for hosting the OS, and the two 500GB drives in mirrored configuration to boost read times. The 500gb drives can be used for caching container/vm images and quantum gates that are hosted on the NAS.

Don't forget to grab an anti-static wrist strap for this build, they are cheaply priced.

## Parts
- 2x[StarTech ST10GPEXNDPI](https://www.startech.com/en-ca/networking-io/st10gpexndpi) (~Intel X550-AT2)
- [10Gtek XL710-10G-4S-X8](https://www.10gtek.com/10gnic) (~Intel X710-DA4)
- 2x[Intel I350-T4V2](https://ark.intel.com/content/www/us/en/ark/products/84805/intel-ethernet-server-adapter-i350t4v2.html)
- ~AMD 7551P~ [AMD 7401P](https://www.amd.com/en/products/cpu/amd-epyc-7401p) (I ordered a 7551P on eBay from a distant seller, received a 7401P, and was swayed by the power savings and hassle of return to keep it. I was refunded the difference in price.)
- [AsRock Rack EPYCD8-2T](http://asrockrack.com/general/productdetail.asp?Model=EPYCD8-2T#Specifications)
- [AsRock Rack TPM2-S Nuvoton NPCT650](https://www.asrockrack.com/general/productdetail.asp?Model=TPM2-S#Specifications)
- ~4x32gb~ 8x32gb Crucial 2666Mhz ECC RDIMM CL19 (~`CT32G4RFD4266`~ <- I originally ordered four of this part number, and received `CT32G4RFD4266.36FB1`, but it turns out the [QVL](https://www.asrockrack.com/general/productdetail.asp?Model=EPYCD8-2T#Memory) for the EPYCD8-2T is even more specific and requires `CT32G4RFD4266.2G6H1.001`. I was sent `CT32G4RFD4266.36FD1` after ordering the QVL part, and this RAM worked.)
- ~2x[Western Digital SN570 500GB M.2](https://www.westerndigital.com/en-ca/products/internal-drives/wd-blue-sn570-nvme-ssd#WDS500G3B0C)~ 2x[Crucial P5 Plus 1TB M.2](https://www.crucial.com/ssd/p5-plus/ct1000p5pssd8)
- [Kingston A400 120GB 2.5"](https://www.kingston.com/en/ssd/a400-solid-state-drive)
- 3.5" to 2.5" drive tray
- [Dynatron A26](https://www.dynatron.co/product-page/a26)
- PLink 2U Enclosure w/Rails (can be found on eBay)
- [Seasonic 750W Prime-TX](https://seasonic.com/prime-tx)
- IEC 320 90 Degree C13 3 Pin Female to C14 3 Pin Male PDU Adapter (this is a short 10A power cable)
- [Arctic Silver 5](http://www.arcticsilver.com/as5.htm)

## Planned Parts
- [Thales Luna PCIe HSM](https://cpl.thalesgroup.com/encryption/hardware-security-modules/pcie-hsms)

I feel like I need to explain this one for those who don't know. An HSM ([Hardware Security Module](https://en.wikipedia.org/wiki/Hardware_security_module)) provides [fail-secure](https://en.wikipedia.org/wiki/Fail-safe#Fail_safe_and_fail_secure) tamper-evident storage and cryptographic acceleration. When I worked with them in the past, I was able to provision the device with custom code to provide a security boundary for the most critical pieces of my applications. These units of code (in Eracom and Safenet terms) were called FMs (Functionality Modules). It's the same for Thales.

## Special Tools

- T20 Torx Head
- Torque Screw Driver capable of measuring 14 in-lbs of torque

## Peak Power Consumption

For power I chose the platinum Seasonic offering boasting 94% efficiency and minimal DC ripple. It's worth noting the enclosure sold by p_link doesn't house a server power supply, but instead a typical ATX PSU. I used the peak numbers from all components and added over 50W for good measure, in case every component peaks at once (this is probably impossible given system constraints). I also chose the Seasonic for the 12 year warranty.

- 26.0W 2x[X550-AT2](https://www.intel.ca/content/www/ca/en/products/docs/network-io/ethernet/network-adapters/ethernet-x550-brief.html)
- 7.4W [X710-DA4](https://www.intel.ca/content/dam/www/public/us/en/documents/product-briefs/ethernet-x710-brief.pdf)
- 10.0W 2x[I350-T4V2](https://www.zayntek.com/product/i350t4v2-intel-ethernet-server-adapter-i350-t4-network-adapter-pcie-2-1-x4-low-profile-gigabit-ethernet)
- 344W [7401P](https://www.servethehome.com/amd-epyc-7401p-linux-benchmarks-and-review-something-special/3/)
- 180W [EPYCD8-T2](https://www.anandtech.com/show/14171/the-asrock-rack-epycd8-2t-motherboard-review/5)
- 110W 8x32gb [RAM](https://www.crucial.com/support/articles-faq-memory/how-much-power-does-memory-use)
- 8.0W 2x[SN570](https://documents.westerndigital.com/content/dam/doc-library/en_us/assets/public/western-digital/product/internal-drives/wd-blue-nvme-ssd/product-brief-wd-blue-sn570-nvme-ssd.pdf)
- 1.535W [A400](https://www.kingston.com/en/ssd/a400-solid-state-drive)
- 7.2W [A26](https://aerocooler.com/dynatron-a26-amd-epyc-sp3-socket-2u-active-cpu-cooler/)

Total: 694 Watts (peak), 56 Watts padding.

## Preparation

1. Equip your wrist strap and ground yourself.
![Wrist Strap](assets/switch/wrist-strap.jpg)
1. Replace brackets on network cards with low-profile variants. Be careful not to damage the delicate ports of the SFP+ card.
![Bracket Replacement](assets/switch/bracket-replacement.jpg)
1. Mount the A400 in the drive adapter tray.
![SSD Adapted](assets/switch/ssd-adapter-tray.jpg)
1. Clean the top surface of the CPU with isopropyl alcohol on a folded paper towel (I used 99%).
![CPU Cleaned](assets/switch/cleaned-cpu.jpg)
1. At this point I considered cleaning the heatsink of the stock paste, but decided to try it and see what the results are like first. It is spread well, so it  may do a better job that I could.

## Assembly

### Rails
1. Install the mounting brackets on your rail guides (I'm just going to make up terms here, go with it).
![Brackets and Guides](assets/switch/brackets-and-guides.jpg)
1. Install the guides on your rack.
![Rail Guide Installed](assets/switch/rail-guide-installed.jpg)
1. Install the outer rails in the guides. The instructions indicate one should use screws and nuts, but the nuts were not required in my case.
![Outer Rails Installed](assets/switch/outer-rails-installed.jpg)

### Server
1. Start by removing the handles. They are attached with 2 screws each.
![Handles Detached](assets/switch/handles.jpg)
1. Next remove the faceplate. Three more screws on the bottom.
![Faceplate Removed](assets/switch/faceplate-removed.jpg)
1. I chose this point to install the inner rails. (I wanted to try the rails out before loading everything up). Were I to do it again I'd likely wait until the end.
![Inner Rails Installed](assets/switch/inner-rails-installed.jpg)
1. Replace the riser slots with low profile slots in the configuration of your choice.
![Low Profile Slots](assets/switch/low-profile-slots.jpg)
1. Remove the top of the case (4 screws) and install the three required mounting posts for the motherboard (most are already present) and place the plastic insulating mat.
![Mounting Posts](assets/switch/motherboard-mounts.jpg)
1. With access to the front of the unit thanks to the freshly removed faceplate, install the power supply.
![Power Supply Installed](assets/switch/power-supply.jpg)
1. It was here that I realized there was not enough room to connect the power cable to the power supply, due to the proximity of the case and the direction of the angled connector. I had to order a 16cm 10A adapter that directs the cable up, where there is more space, rather than to the side.
1. Install the adapter.
![PDU Adapter Installer](assets/switch/adapter-installed.jpg)
1. Remove the 8 screws holding the fan assembly to the forward position of the chassis and push it out of the way so you can install the required power cables. You'll need the ATX power cable, two CPU cables, and a 3 molex connector with a SATA adapter attached to the end. This allows us to power both the fan assembly and A400 with a single cable.
![Fans and Power Cables](assets/switch/fans-removed-cables-installed.jpg)
1. Replace the fan assembly in the rear position so there is space for the cables you just attached and connect the molex power cable to the fan control unit. Replace the front panel and handles.
![Fans Replaced](assets/switch/fans-replaced.jpg)
1. If you live in an older home, I recommend testing your outlet now to see if you actually have a grounded circuit or if you simply have GFCI breakers. We'll be relying on the ground, so use an outlet tester to find an outlet that is correctly configured.
![Outlet Tester](assets/switch/outlet-tester.jpg)
1. Connect your server to your outlet by using the rear port, and use the power supply testing cap included with your Seasonic power supply to verify it works correctly. Once you are done, switch the power supply off and remove the testing cap.
![PSU Testing Cap](assets/switch/psu-testing-cap.jpg)
1. Ground yourself.
![Ground Yourself](assets/switch/ground-yourself.jpg)
1. Ensuring the power supply is switched off, the power cable is connected, and you are grounded, install the motherboard using the mounting screws provided with the case. Do not over-tighten them and crush the wafer or strip the screws.
![Motherboard Installed](assets/switch/motherboard-installed.jpg)
1. Connect the front panel to the motherboard using the pinout guide in the motherboard manual.
![Front Panel Connection](assets/switch/front-panel-connection.jpg)
1. Consult the motherboard manual and verify the position of all jumpers. In my case, the manual indicated the SATADOM port would not be powered by default, but this was not the case and it was shipped in the powered configuration. I moved the jumper to cut power to the port (I believe pin 7), as the A400 will not require this and it has the potential to cause damage.
1. Connect the power cables to the motherboard. Note: You should probably wait to do this until after installing the CPU and RAM. I trusted my power supply's switch not to fail, and I'm not sure if it can fail in a bad way or not.
![Motherboard Power](assets/switch/motherboard-power-connection.jpg)
1. Now you'll want to release the CPU carrier frame with your T20 Torx head driver, in the order specified (In my case this is 3->2->1). Slide your CPU into the carrier and tighten, in the correct order, to 14 in-lbs of torque.
![CPU Installed](assets/switch/cpu-installed.jpg)
1. Now, you have the option of cleaning the heat sink and using the thermal paste or applying the 
heat sink with the stock paste. I did both, during this process (I removed the heatsink a couple times). You can get an idea of how much paste is required (it's not that much) from the stock paste on the heat sink. Watch some videos online to see how to do this. Tighten the heat sink in a diagonal, alternating, pattern - as if you are replacing a wheel on a car. Though there are 6 pins on the motherboard for the fan power connector, you can easily connect the 4-pin A26 and there is even a plastic guide on the board that should help you orient the pins. Basically, the black wire sits near the edge of the board.
![Heat Sink Installed](assets/switch/heatsink-installed.jpg)
1. Install your RAM. The motherboard manual explains how to install different numbers of modules and how to ensure dual channel activation.
![RAM Installed](assets/switch/ram-installed.jpg)
1. Finally, we are ready to test a minimum system configuration. Make sure nothing is touching your soon to be powered components, and turn on the power supply. You should see a couple LEDS come to life. The one near the front panel connectors is the power availability indicator, it should always be on if the PSU is on and the cables are connected. The one near the PCI slots is the BMC heartbeat controller. It will start pulsing when the BMC (board management controller) boots up. You can connect to the BMC via a web UI on the IPMI port, where you can control the board and launch a virtual KVM to interact with the host once it POSTs. Check it out.
![Motherboard LEDS](assets/switch/motherboard-leds.jpg)
1. Once you are ready, use the BMC UI or the physical power button on the faceplate to power the motherboard.
![Dr Debug 0x16](assets/switch/dr-debug-0x16.jpg)
1. You may be wondering what the last photo is all about. This is Dr. Debug, an onboard diagnostic unit that displays hex codes during the POST process. There is a breakdown of what might be wrong in section 2.8 of the motherboard manual. In this case, it is indicating my RAM is not recognized. There is another note in the manual that says some RAM sticks configured with 16 1 gb modules won't work correctly in this motherboard. I speculate this is the difference (though my searches did not yield confirmation) between the first set of ram I purchased and the second set. The first set has 36 modules per stick - at 32gb, with 1 ECC parity bit per 8 data bits (I assume this is how it works), this means each module is 1gb. I will be able to visually inspect when I receive the second set.
![Bad RAM](assets/switch/bad-ram.jpg)
1. The second set of RAM I received was nearly identical to the first by model number - though I had ordered a very specific part I received `CT32G4RFD4266.36FD1`. The configuration of the modules appeared the same as before, so I was fairly certain this RAM would not work. I installed a single stick, and luckily, I was incorrect! The system POSTed and the new RAM worked fine!
![Successful Single Stick RAM Test](assets/switch/single-memory-stick-successful.jpg)
1. I next installed the remaining RAM and did a quick test to ensure we could POST and it was detected. I could have run [Memtest86](https://en.wikipedia.org/wiki/Memtest86) here, and would recommend you do so, but I was pretty excited to have a working machine so I kept building.
![All RAM Installed](assets/switch/all-ram-perspective.jpg)
![All RAM Top Down](assets/switch/all-ram-top-down.jpg)
![All RAM Detected](assets/switch/all-ram-detected.jpg)
1. With the system booting, it's time to start installing the remaining devices. First, we'll focus on the hard drives and ensure they are detected properly. The A400 was a bit of a pain to install and required removing the mounting bracket, but the NVMe drives were painless.
![SATA Installed](assets/switch/kingston-installed.jpg)
![NVMe Installed](assets/switch/nvme-installed.jpg)
![Drives Detected](assets/switch/hard-drives-detected.jpg)
1. Next up, and finally, are the network cards. Plug them in in your desired configuration. I had to reorganize things to avoid the heatsink with the SFP+ card.
![Networking Installed](assets/switch/networking-top.jpg)
![Networking Rear](assets/switch/networking-rear.jpg)
1. Congratulations! If all was successful, your server should POST and you can use the BMC's KVM to load a bootable image. Check out the configuration section for further setup instructions. **Note: I later realized that if you do not use the IPMI KVM to load the installation image _before_ powering on the server, the UEFI cannot recognize the UEFI installation media and you may be tempted to boot the image from legacy mode. If you do this, the installer will likely partition the disk using an MBR and without a GPT/UEFI image, meaning that you can't take full advantage of some boot features.**

## Configuration

I chose to install Debian Bullseye for my host operating system on this server. I have used Gentoo, Debian, Ubuntu, Redhat, CentOS, OpenBSD, slackware and some others that escape me, and I appreciate Debian's simplicity of configuration, availability of documentation, and availability of binary packages.

### Basic UEFI Firmware Configuration

Now that we can access the UEFI firmware menu, let's ensure that SVM and SMEE are enabled and IOMMU is set to Auto.

![IOMMU](assets/switch/firmware-iommu.jpg)

One other annoying thing about the Startech cards is that the onboard ROM tries to do a network PXE boot for each nic, sequentially. This adds quite a bit of time to the boot process. To disable, navigate to the Boot/CSM menu and disable all the OpROMs. I left the M.2 ones on in this photo, but they weren't necessary.

![Disable PXE](assets/switch/firmware-disable-pxe.jpg)

### OS Installation

Use the BMC KVM to load your OS installer. Set up the OS as per usual (make sure you disallow root login and create a user account).

Ensure all your network cards are detected. I believe the final NIC is the BMC, and we don't want our host controlling that so it's okay that it isn't detected and configured by our OS.

![Networking Detected](assets/switch/networking-detected.jpg)

Configure the filesystem as you like. Here is what I did:

![File System Configuration](assets/switch/debian-install-filesystems.jpg)

![Encryption Selection](assets/switch/debian-install-encrypted-devices.jpg)

![Encrypted File System Configuration](assets/switch/debian-install-filesystems-encrypted.jpg)

Edit: After realizing I wasn't using UEFI, I went back and reinstalled everything. Now, there are 4 partitions on the Kingston drive, the first being the EFI image.

I left the `/boot` partition in the clear, and encrypted everything else. In my final deployment, I only allocated 250mb to the /boot partition as it is unlikely I'll need more. I used passphrases to create the encrypted partitions (there seems to be a problem formatting the encrypted devices with anything but `ext2` if you choose `random key`), and this means that at first I'll need to enter them through the KVM every time the system boots. I plan to perform the derivation process manually to grab the keys used for encryption, encrypt them with the TPM on the motherboard, and manage the keys during the boot process. I hope to also be able to use the TPM to verify the integrity of the boot partition before handing control to the boot loader. To do this securely, I'll need to disallow custom booting in grub (configure it such that only a single kernel boots with fixed parameters). I should be able to automate loading the OS this way.

This way, in the worst case I can derive the keys again.

I selected minimal packages:
![Package Selection](assets/switch/debian-install-packages.jpg)

### Convenience

It's nice to not have to constantly type your password when you are setting up a server. This is your choice, I find it helpful. You can remove it after configuration is complete, if you are worried.

```sh
sudo visudo -f /etc/sudoers.d/10-default
```

Add the following line (substituting your username):
```
username     ALL=(ALL) NOPASSWD:ALL
```

For convenience, I rolled this process up into some [scripts](src/core-switch/scripts) so I could easily try out different deployment configurations. Here's what I need to do to get my system up and running, after setting up the operating system, which was the most painful part of the iterative process.

```
# in KVM
sudo visudo -f /etc/sudoers.d/10-default # update to nopasswd

# from local
scp install.tgz username@remote_host:.

# in KVM
tar xzvf install.tgz
~/install/scripts/provision.sh
sudo reboot

# in KVM
# enable secure boot

# via ssh
# configure clevis
```

You can deconstruct the scripts and see what I did - I am aware I could have plucked all the files into a single tar file and extracted them together from `/`. That wasn't how it evolved, and here we are. I may make some .deb files in the future to do all this.

### NVMe Instability

This needs to go first, since it could cause problems at any time. After about a week of uptime, the software raid array fell over due to failures with the NVMe drives and APST.

This problem can be eliminated by adding `nvme_core.default_ps_max_latency_us=0` to your grub command line to disable APST.

Edit: Unfortunately the problems persisted:

```
[ 1751.036859] {1}[Hardware Error]: Hardware error from APEI Generic Hardware Error Source: 4
[ 1751.036929] {1}[Hardware Error]: event severity: info
[ 1751.036963] {1}[Hardware Error]:  Error 0, type: fatal
[ 1751.036994] {1}[Hardware Error]:  fru_text: PcieError
[ 1751.037026] {1}[Hardware Error]:   section_type: PCIe error
[ 1751.037078] {1}[Hardware Error]:   port_type: 4, root port
[ 1751.037133] {1}[Hardware Error]:   version: 0.2
[ 1751.037181] {1}[Hardware Error]:   command: 0x0407, status: 0x0010
[ 1751.037242] {1}[Hardware Error]:   device_id: 0000:40:01.3
[ 1751.037296] {1}[Hardware Error]:   slot: 34
[ 1751.037339] {1}[Hardware Error]:   secondary_bus: 0x42
[ 1751.037390] {1}[Hardware Error]:   vendor_id: 0x1022, device_id: 0x1453
[ 1751.037455] {1}[Hardware Error]:   class_code: 060400
[ 1751.037504] {1}[Hardware Error]:   bridge: secondary_status: 0x2000, control: 0x0012
[ 1751.037577] {1}[Hardware Error]:   aer_uncor_status: 0x00000000, aer_uncor_mask: 0x04500000
[ 1751.037656] {1}[Hardware Error]:   aer_uncor_severity: 0x004e2030
[ 1751.037717] {1}[Hardware Error]:   TLP Header: 00000000 00000000 00000000 00000000
[ 1751.040164] pcieport 0000:40:01.3: AER: aer_status: 0x00000000, aer_mask: 0x04500000
[ 1751.040242] pcieport 0000:40:01.3: AER: aer_layer=Transaction Layer, aer_agent=Receiver ID
[ 1751.040295] pcieport 0000:40:01.3: AER: aer_uncor_severity: 0x004e2030
[ 1751.040340] nvme nvme1: frozen state error detected, reset controller
[ 1752.124836] pcieport 0000:40:01.3: AER: Root Port link has been reset
[ 1752.124951] pcieport 0000:40:01.3: AER: device recovery successful
```

Though the device recovered, the fact that it was encrypted raid made it less than usable:

```
❯ sudo umount /var
umount: /var: target is busy.
```

I am now trying the setting `pcie_aspm=off` in addition to the other kernel flag.

Edit: Since making the above change to the `pcie_aspm` flag, I have had an uptime of over
10 days. I'll make another edit if things break down again, but it looks like this resolved the issue.

Edit: This did not resolve the issue, which actually ended up being a BTRFS Copy-on-Write interaction
with the Linux kernel. Many of my use cases cause this undesired behaviour, so I'm reinstalling the
whole system with ext4.

Edit: The problem persisted with ext4, and I'm now wondering whether the issue is simply that after
a reset of the device and failed bridge, dmcrypt required a password to remount the device. I
believe this is complicated by the fact that I was using software encryption, with RAID layered on
top. I ordered two crucial drives to see if the controller resets disappear. They are self-encrypting,
so I should be able to omit one of the software layers. I'll update this after a week of uptime or
a failure. I also had not enabled `clevis-luks-askpass.path` so it's possible that now that I have,
the system can recover without intervention.

Edit: Well this was quite a chore. Read the next, new, section for details. Right now the system
has been up for about 12 hours, and it typically fails under small loads (like it is) with many
IO operations on the RAID array in a couple days. I'll post again after a failure or a substantial
uptime.

```
❯ uptime
 12:14:14 up 11:34,  1 user,  load average: 2.14, 1.97, 1.98
```

Edit: New drives appear to have fixed things..

```
❯ uptime
 01:52:24 up 19 days,  1:28,  1 user,  load average: 0.48, 1.98, 1.79
```

### SED Passwordless Boot via `dracut`, `clevis` and `sedutil-cli`

It turns out that using a TPM to unlock both SEDs and LUKS drives in an automated way with secure
boot active is fairly tricky. To see how I accomplished this, read on.

I hammered my way through this in about 12 hours. The reason it took so long is that several times,
to get out of an unbootable situation, I needed to (this morphed as I made progress with
`unlock-sed.sh`):

1. Turn off secure boot
1. Install a basic OS on the LUKS drive
1. Use the basic OS to mess with the SED using `sedutil-cli`, unlocking the drives until power off
1. Install the full OS over the all drives
1. Adjust scripts
1. Build a new UEFI image
1. Turn on secure boot
1. Power down
1. Boot and most likely, repeat

I had this process down to about 10 minutes in the end. The reboots were the time killer. 2 minutes
every time. Once I had a fairly stable basic OS, I was able to use a LiveCD recovery console to
mount the existing LUKS partitions to gain access to the tools I needed to fix my issues. Once I had
the majority of the script working, I was able to repeatedly boot into the system via password and
fix up the remaining bit (automated entry).

Here is how the solution works:

- I used `dracut` modules to [install](./src/core-switch/scripts/security/sedutil/setup.sh) custom
logic at boot.
- The [module](./src/core-switch/scripts/security/sedutil/module-setup.sh) I created includes
`sedutil-cli`, `argon2`, `clevis-tpm2` and associated libraries. It also includes tpm2-encrypted
HDD passphrases for SEDs.
- The [script](./src/core-switch/scripts/security/sedutil/unlock-sed.sh) that is invoked at boot
follows this logic:
  - Check lock status.
    - Locked
      - Attempt to decrypt encrypted passkey
        - Success
          - Unlock SED
          - Done
        - Failure
          - Use `systemd-ask-password` to prompt the user for the user passphrase
          - Derive the HDD passkey using `argon2`
          - Unlock SED
          - Done
    - Unlocked
      - Done

[This](./src/core-switch/scripts/store-hdd-passphrases.sh) is the script I use to regenerate LUKS
and SED encrypted keys, any time the PCR values in the TPM change (when you upgrade the kernel or
change a BIOS setting, for example).

It works! I had to adjust the TPM registers I was measuring to get it to consistently boot, I
believe because I'm changing the UEFI image itself. I am considering putting the encrypted keys
on the boot partition and mounting it during this process to see if I can include another PCR value.
I changed from PCRs 0,1,2,3,4,5,6,7 to 0,2,3,4,6,7,8. I am having trouble finding a definitive
answer on what these values represent, but through trial and error found a consistent set to
measure. Edit: I moved the encrypted keys to `/boot` and the PCR values became more stable. I was
able to use 0,1,4,6,7,8,9,14 which appeared to be unique. 2, 3, and 6 were the same value, and every
other register was populated with all ones or all zeros. I omitted 2 and 3 because the maximum
number of registers a policy supports is 8, and I wanted all the unique, stable values.

About this solution: We use a null salt for the `argon2` extension, since we want to be able to
recover from passphrase alone. The argon2 params run in about 10 seconds on my system, which is a
bit much, but I am okay with it since passwordless boot just needs to TPM-decrypt the passphrase
and unlock, there is no derivation necessary. To make the dracut module a bit nicer, one could add
real checks in the `check` method of `module-setup.sh`. In reality, this module not firing in
my system would render it unbootable - so check merely provides feedback that everything expected is
present when building the image - it doesn't guarantee you didn't forget to add something you
needed. As such, it was kind of useless during development. Anyway, `check()` should be populated.

### Networking Setup

I made some changes to the basic networking config in `/etc/default/networking`:

```
WAIT_ONLINE_METHOD=route
WAIT_ONLINE_IFACE=veth0
```

And here is how I configured the switch in `/etc/network/interfaces`:

```
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

########################
# CPU Side I350 (1Gbe)
########################

allow-hotplug enp98s0f0
iface enp98s0f0 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

allow-hotplug enp98s0f1
iface enp98s0f1 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

allow-hotplug enp98s0f2
iface enp97s0f2 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

allow-hotplug enp98s0f3
iface enp98s0f3 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

########################
# HD Side I350 (1Gbe)
########################

allow-hotplug enp34s0f0
iface enp34s0f0 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

allow-hotplug enp34s0f1
iface enp34s0f1 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

allow-hotplug enp34s0f2
iface enp34s0f2 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

allow-hotplug enp34s0f3
iface enp34s0f3 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

########################
# CPU Side X550T (10Gbe)
########################

allow-hotplug enp33s0f0
iface enp33s0f0 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

allow-hotplug enp33s0f1
iface enp33s0f1 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

########################
# HD Side X550T (10Gbe)
########################

allow-hotplug enp1s0f0
iface enp1s0f0 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

allow-hotplug enp1s0f1
iface enp1s0f1 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

########################
# Onboard X550T (10Gbe)
########################

allow-hotplug enp99s0f0
iface enp99s0f0 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

allow-hotplug enp99s0f1
iface enp99s0f1 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

########################
# X710 (10Gbe SFP+)
########################

allow-hotplug enp97s0f0
iface enp97s0f0 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

allow-hotplug enp97s0f1
iface enp97s0f1 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

allow-hotplug enp97s0f2
iface enp97s0f2 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

allow-hotplug enp97s0f3
iface enp97s0f3 inet manual
  pre-up   ip link set dev $IFACE up
  pre-down ip link set dev $IFACE down

######################
# Bridge
######################

auto br-ext
iface br-ext inet static
  bridge_ports enp1s0f0 enp1s0f1 enp33s0f0 enp33s0f1 enp34s0f0 enp34s0f1 enp34s0f2 enp34s0f3 enp97s0f0 enp97s0f1 enp97s0f2 enp97s0f3 enp98s0f0 enp98s0f1 enp98s0f2 enp98s0f3 enp99s0f0 enp99s0f1 veth0-p
  address 192.168.1.250
  netmask 255.255.255.0
  pre-up    ip link add veth0 type veth peer name veth0-p && ip link set veth0 address 01:01:01:01:01:01
  up        brctl stp $IFACE on
  post-down ip link delete veth0

######################
# Primary Interface
######################

auto veth0
iface veth0 inet dhcp
```

The most important bits are the pre-up and post-down hooks in the bridge, they are responsible for creating the [veth](https://man7.org/linux/man-pages/man4/veth.4.html) pair that allows the host to access the network through the switch. Change the MAC address of the veth device to something a bit more sensible than `01:01:01:01:01:01`. I simply used the first random MAC the OS assigned, and fixed it to that so that my DHCP server can assign a static IP to the host.

I plan to set up bonding on 2 10Gbe channels between the NAS and switch. Stay tuned for those modifications.

After configuring the network, plug a cable in to any port, and restart networking:
```sh
sudo systemctl restart networking
```

I also configured sshd to disallow password login, as I can use the BMC if I need. I [set up public key access](https://www.digitalocean.com/community/tutorials/how-to-configure-ssh-key-based-authentication-on-a-linux-server) before I did this. I used an existing key but you can [generate a key pair](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) if you need to.

Generating new keys (this step happens on your local machine, not the KVM):
```sh
[[ -f ~/.ssh/id_ed25519.pub ]] || ssh-keygen -t ed25519 -C "your_email@example.com"
```

Copying your public key to the server (again, on your local machine):
```sh
cat ~/.ssh/id_ed25519.pub | ssh username@remote_host "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

Now we can stop using the KVM. SSH in to your server and ensure public key authentication is working correctly (from your local machine):
```sh
ssh username@remote_host
```

Finally, we can edit the `sshd` config and disable password based login.

`/etc/ssh/sshd_config`
```
...
PasswordAuthentication no
...
```

Reboot or restart your ssh daemon after doing this.

#### Firmware

I noticed while examining `dmesg` that the stock SEV firmware (build 1) was loading. During boot, the system was unable to find AMD firmware as requested. I grabbed it from two places, [linux-firmware](https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git) and the AMD [developer SEV page](https://developer.amd.com/sev/) in the Links and Downloads section (`amd_sev_fam17h_model01h_xxxxx.zip`).

After fully acknowledging any potential implications, drop the appropriate files in `/lib/firmware/amd/`.

Next, run this command to update things:
```sh
sudo update-initramfs -c -k all
```

Upon reboot, you should see this pleasing message:
```
[    8.488939] ccp 0000:04:00.2: firmware: direct-loading firmware amd/amd_sev_fam17h_model01h.sbin
[    8.492186] ccp 0000:04:00.2: SEV firmware update successful
```

and something like (anything but build:1):

```
[    8.592787] ccp 0000:04:00.2: SEV API:0.17 build:48
```

### AMD SEV Setup

[AMD SEV](https://developer.amd.com/sev/) is a cool feature for virtualization. From what I can tell, it prevents a VM from reading memory and registers that weren't wiped by another VM. SME will also protect against physical/ram freezing attacks. I found out about it after I built the server, and being a security buff I decided to try it out immediately.

Using [this guide](https://docs.ovh.com/ca/en/dedicated/enable-and-use-amd-sme-sev/) I was able to get it up and running. Here is how I did it.

I started by grabbing [sev-tool](https://github.com/AMDESE/sev-tool). I used this to verify things seemed normal, did a factory reset, uploaded a custom OCA, and exported my cert chain for use by guest VMs.

Next, I needed to enable some kernel parameters in `/etc/default/grub`:
```
...
GRUB_CMDLINE_LINUX_DEFAULT="mem_encrypt=on kvm_amd.sev=1"
...
```

As you can see, I also removed the `quiet` parameter. Next, I ran:

```sh
sudo update-grub
```

Upon reboot, however, I tried to [grep](https://en.wikipedia.org/wiki/Grep) (I prefer [ripgrep](https://blog.burntsushi.net/ripgrep/)) for the indicators that things were okay in syslog/dmesg, and found that SME was not enabled.

```sh
sudo dmesg | rg SEV
```
This output `SEV supported`.

```sh
sudo dmesg | rg SME
```
This, on the other hand, output nothing.

I then used [this guide](https://randomsecurity.dev/posts/secure-memory-encryption/) and the [debian documentation](https://kernel-team.pages.debian.net/kernel-handbook/ch-common-tasks.html) to build a kernel module to check whether SME was functional, and found it wasn't. After building the kernel module, I realized the symbols for setting encrypted and decrypted memory were not present in the kernel. It turns out that due to some incompatibility issues, this feature was disabled in the default debian kernel at the time of this writing. To enable it, we merely need to update the kernel config (`CONFIG_AMD_MEM_ENCRYPT=y`) and re-build it.

First, run these commands:
```sh
sudo apt install build-essential fakeroot
sudo apt build-dep linux
mkdir -p ~/kernel
cd ~/kernel
apt source linux
cd linux-VERSION
echo "CONFIG_AMD_MEM_ENCRYPT=y" > debian/config/amd64/config.sme
```

Edit `debian/config/amd64/none/defines`:
```
[base]
flavours:
 amd64
 cloud-amd64
 sme-amd64
default-flavour: sme-amd64

[cloud-amd64_image]
configs:
 config.cloud
 amd64/config.cloud-amd64

[sme-amd64_image]
configs:
 amd64/config.sme

[sme-amd64_build]
signed-code: false
```

Edit `debian/config/amd64/defines`:
```
...

[sme-amd64_description]
hardware: 64-bit sme servers
hardware-long: AMD EPYC servers capable of SME
```

Now, regenerate your `Makefile`:
```sh
debian/bin/gencontrol.py
```

Finally, build the kernel:
```sh
fakeroot make -f debian/rules.gen binary-arch_amd64_none_sme-amd64 -j$(nproc)
```

After this finishes, install the kernel and its headers so we can try out that module that tests SME.
```sh
cd ..
sudo apt install \
  linux-image-sme-amd64_5.10.113-1_amd64.deb \
  linux-image-5.10.0-14-sme-amd64_5.10.113-1_amd64.deb \
  linux-headers-sme-amd64_5.10.113-1_amd64.deb \
  linux-headers-5.10.0-14-sme-amd64_5.10.113-1_amd64.deb
```

Reboot to launch your new kernel.
```sh
sudo reboot
```

After a reboot, try this again:
```sh
sudo dmesg | rg SME
```

This time, you should see something like `AMD Memory Encryption Features active: SME`.

Now, we can try launching a virtual machine.
```sh
sudo apt install \
  libvirt-daemon-system \
  virtinst \
  qemu-utils \
  cloud-image-utils
mkdir -p ~/sev-test
cd ~/sev-test
wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
sudo qemu-img convert focal-server-cloudimg-amd64.img /var/lib/libvirt/images/sev-guest.img
cat >cloud-config <<EOF
#cloud-config

password: terrible-password
chpasswd: { expire: False }
ssh_pwauth: False
EOF
sudo cloud-localds /var/lib/libvirt/images/sev-guest-cloud-config.iso cloud-config
```

We must next tweak the permissions to add `rw` access for `/dev/sev` (as of the time of this writing) in `/etc/apparmor.d/abstractions/libvirt-qemu`:
```
...
  /dev/ptmx rw,
  /dev/sev rw,
  @{PROC}/*/status r,
...
```

Finally, we can launch our VM:
```sh
sudo virsh net-start default
sudo virt-install \
              --name sev-guest \
              --memory 4096 \
              --memtune hard_limit=4563402 \
              --boot uefi \
              --disk /var/lib/libvirt/images/sev-guest.img,device=disk,bus=scsi \
              --disk /var/lib/libvirt/images/sev-guest-cloud-config.iso,device=cdrom \
              --os-type linux \
              --os-variant ubuntu20.04 \
              --import \
              --controller type=scsi,model=virtio-scsi,driver.iommu=on \
              --controller type=virtio-serial,driver.iommu=on \
              --network network=default,model=virtio,driver.iommu=on \
              --memballoon driver.iommu=on \
              --graphics none \
              --launchSecurity sev
```

Inside the VM, we can check that SEV is enabled:
```sh
dmesg | grep SEV
```
Should output `[    0.179686] AMD Secure Encrypted Virtualization (SEV) active`.

To exit your VM, just run the command `sudo poweroff`.

### Trusted, Password-less Decrypting Boot

As I began investigating [this guide](https://fit-pc.com/wiki/index.php?title=Linux:_Full_Disk_Encryption) I realized my motherboard did not come with an embedded TPM, but instead one can optionally be added. My motherboard can secure boot, so that in combination with TPM-encrypted HDD keys, it provides a chain of trust as the system boots. Here is how it works:

As this process occurs, controlling code (whatever is in control at the time) checks various system components and configurations and creates running [digests](https://en.wikipedia.org/wiki/Cryptographic_hash_function) in some hidden registers in the TPM. It does this by extending similar to any other update portion of a hash function. If at each step, the appropriate registers are verified and extended with say, a digest of the next block of code to execute, and the initial code verifies system configuration, we can rest assured nothing has changed since the system was configured (there is a miniscule chance of a collision here but it is unlikely that the source data/code required to create a colliding digest would be valid). Additionally, the tpm contains some random data that can be reset at whim. This data is combined with requested PCR values to generate a key within the TPM that can encrypt and decrypt data at various stages of boot using keys bound to the state of execution. More clearly, the TPM can help unlock data and code during the boot process based on expected system state, without requiring user intervention.

1. The system UEFI firmware is loaded into memory and the system POSTs and performs basic initialization, updating the registers in the TPM.
1. The system UEFI firmware uses a set of certificates to validate signatures on any boot code that is to be run.
1. If the signatures are valid, the firmware hands control to the UEFI boot loader.
1. The boot loader is configured to not accept command line input, and is configured to use the TPM to recover the keys for the other partitions (the encrypted keys will live on the EFI image with the kernel). If you want to get really hardcore, you can try to turn off module loading in the kernel and include your drivers etc in the kernel directly. I am not sure disabling module loading really buys us much, given the other lengths we are going to. Edit: With module signing, there is no problem.
1. The filesystem keys are recovered and used to load the relevant parts of the OS into memory by the kernel.
1. The kernel continues to run, but all partitions excluding boot are encrypted and impervious to observation. Since we have SME and Secure Virtualization enabled, we aren't worried about observation of memory. If the network ports are locked down and filesystem permissions are configured correctly, we should be in as good a position as we can be.
1. If we want to go further, we can continue to use the applciation TPM registers to ensure that any software that is sequentially loaded is authorized to run. I am going to investigate wiring up AppArmor to the TPM. Maybe I'll post about that in the future.

Bonus (HSM):
If we then needed to generate and store some more keys (or maybe even data) securely, an HSM is a much more versatile device than a TPM. A TPM can do a few things, but an HSM can do pretty much anything and comes with storage. The real benefit is in the fail-secure mode of operation. If someone tries to physically access/observe your keys, the HSM's hardware sensors instruct it to erase itself.

The TPM itself:

![TPM](assets/switch/tpm.jpg)

After installation, check that it is recognized in the UEFI firmware. It's best to perform the clear action (which I can only presume generates new, unique, keying material). I don't trust that it isn't some default value coming from the factory, and that protected keys could be accessed if another stock TPM was fed my system configuration. Maybe I'm paranoid.

![TPM in Firmware](assets/switch/tpm-firmware.jpg)

At this point, I tried a reinstallation of the entire system to see if the `random key` option during filesystem provisioning would work out of the box and use the TPM. It did not, and again constrained me to ext2 if I selected `random key`. I chose to again use passphrases, which I will convert to keys and encrypt using the TPM. These encrypted keys can be used during boot instead of having to type passphrases in.

This turned out to be easier than expected.

```
sudo apt install clevis-tpm2 clevis-luks clevis-dracut
sudo clevis luks bind -d /dev/sda2 tpm2 '{"pcr_bank":"sha256","pcr_ids":"0,1,2,3,4,5,6,7"}'
sudo clevis luks bind -d /dev/sda3 tpm2 '{"pcr_bank":"sha256","pcr_ids":"0,1,2,3,4,5,6,7"}'
sudo clevis luks bind -d /dev/md0 tpm2 '{"pcr_bank":"sha256","pcr_ids":"0,1,2,3,4,5,6,7"}'
```

Reboot and watch while your password prompts are bypassed...

For some reason, `dracut` didn't copy one of the SEV firmware files into the initrd images. I had to create this file:

/etc/dracut.conf.d/20-sev.conf
```
install_items+=" /lib/firmware/amd/amd_sev_fam17h_model01h.sbin "
```

Then I needed to run the dracut command again.

Sigh. Rebooting stopped working automatically with all the PCR registers specified above. What this means is that something about the configuration of the machine is dynamic in one of those registers, and it can't be used for this purpose. I need to narrow down correct set of registers to use. I checked out [this](https://trustedcomputinggroup.org/wp-content/uploads/PC-ClientSpecific_Platform_Profile_for_TPM_2p0_Systems_v51.pdf) document.

This turned into a whole thing. I realized at this point that I wasn't booting a UEFI image using a GPT but instead from a legacy MBR. This wasn't permitting me to take full advantage of trusted boot (I plan to enable secure boot next). I reinstalled the entire system using UEFI.

I dumped the PCR values with this command:
```
sudo tpm2_pcrread sha256:0,1,2,3,4,5,6,7+sha1:0,1,2,3,4,5,6,7
```

I saved them to a file and I'll be able to see which ones change, breaking passwordless boot. I'll iterate until it is stable and document my results here.

Re-reading what I did - I realize that re-running dracut to add that firmware probably changed the PCR values. The system seems to boot fine at present.

I may write further TPM2 enabled software to measure code before launch, if I can't find any.

### Secure Boot

Check [this guide](https://wiki.debian.org/SecureBoot).

```
❯ sudo mokutil --sb-state
SecureBoot disabled
Platform is in Setup Mode
```
This seems legit.

```
❯ sudo ls /var/lib/shim-signed/mok/
ls: cannot access '/var/lib/shim-signed/mok/': No such file or directory
```
Okay.

```
❯ sudo mkdir -p /var/lib/shim-signed/mok/
❯ cd /var/lib/shim-signed/mok/
❯ sudo openssl req -new -x509 -newkey rsa:2048 -keyout MOK.priv -outform DER -out MOK.der -days 36500 -subj "/CN=$(hostname)/"
❯ sudo openssl x509 -inform der -in MOK.der -out MOK.pem
```
Great!

```
❯ sudo mokutil --import MOK.der
❯ sudo mokutil --list-new

# reboot and enroll MOK

❯ sudo dmesg | rg cert
```
Hmm, my cert didn't show up.

At this point I spent a few hours troubleshooting so I'll cut to the solution. I needed to rebuild my kernel and sign all my modules and it with the MOK. 

```
❯ cd ~/kernel/linux-VERSION
```

Updated `debian/config/amd64/config.sme`
```
CONFIG_AMD_MEM_ENCRYPT=y
CONFIG_MODULE_ALLOW_MISSING_NAMESPACE_IMPORTS=n
CONFIG_MODULE_COMPRESS_ZSTD=y
CONFIG_MODULE_SIG=y
CONFIG_MODULE_SIG_ALL=y
CONFIG_MODULE_SIG_FORCE=n
CONFIG_MODULE_SIG_HASH="sha256"
CONFIG_MODULE_SIG_KEY="/var/lib/shim-signed/mok/MOK.bundle.pem"
CONFIG_MODULE_SIG_KEY_TYPE_RSA=y
CONFIG_MODULE_SIG_SHA256=y
CONFIG_SYSTEM_TRUSTED_KEYS="/var/lib/shim-signed/mok/MOK.pem"
```
Note: The Debian guide used this RSA 2048 key, I plan to try upgrading to a stronger, ECC key.

Updated `debian/config/amd64/none/defines`
```
...

[sme-amd64_build]
signed-code: true
```

Now, the only way I was able to get the kernel to build successfully without taking it apart to understand what was going on was to remove passphrase protection on the signing key, temporarily. If you can disconnect your machine from networking while doing this, I'd advise that. I tried using KBUILD_SIGN_PIN, and tweaking permissions.

```
❯ cd /var/lib/shim-signed/mok/
❯ sudo bash -c "openssl rsa -in MOK.priv -text > MOK.priv.pem"
❯ sudo bash -c "cat MOK.pem MOK.priv.pem > MOK.bundle.pem"
```

Now rebuild.
```
❯ cd ~/kernel/linux-VERSION
❯ debian/bin/gencontrol.py
❯ fakeroot make -f debian/rules.gen binary-arch_amd64_none_sme-amd64 -j$(nproc)
```

Remove exposed key.
```
❯ sudo rm /var/lib/shim-signed/mok/MOK.{priv,bundle}.pem
```

Install.
```
❯ cd ..
❯ sudo apt -y install ./linux-image-IDENTIFYING-DETAILS.deb
```

Sign your kernel so that secure boot will trust it.
```
❯ sudo apt install sbsigntool
❯ VERSION="$(uname -r)"
❯ cd /var/lib/shim-signed/mok/
❯ sudo sbsign --key MOK.priv --cert MOK.pem "/boot/vmlinuz-$VERSION" --output "/boot/vmlinuz-$VERSION.tmp"
❯ sudo mv "/boot/vmlinuz-$VERSION.tmp" "/boot/vmlinuz-$VERSION"
❯ sudo dracut -f
```

That's it! Now reboot and enable secure boot!

Test results after reboot:
```
❯ sudo mokutil --sb-state
SecureBoot enabled
❯ sudo dmesg | rg Secure
[    0.000000] Kernel is locked down from EFI Secure Boot; see man kernel_lockdown.7
[    0.000000] secureboot: Secure boot enabled
❯ sudo dmesg | rg SME
[    0.122980] AMD Memory Encryption Features active: SME
❯ sudo dmesg | rg SEV
[    3.242403] ccp 0000:04:00.2: SEV firmware update successful
[    3.314387] ccp 0000:04:00.2: SEV API:0.17 build:48
[   13.245230] SEV supported
```

Now that our PCR values won't be changing - let's destroy and re-enable our clevis keys so the system can boot without intervention.

Unbind existing, dead keys (your setup likely differs, so use your wits, fstab and clevis to determine the correct device and key slot).
```
sudo clevis luks unbind -d /dev/sda3 -s 1
sudo clevis luks unbind -d /dev/sda4 -s 1
sudo clevis luks unbind -d /dev/md0 -s 1
```

Bind shiny, new keys.
```
sudo clevis luks bind -d /dev/sda3 tpm2 '{"pcr_bank":"sha256","pcr_ids":"0,1,2,3,4,5,6,7"}'
sudo clevis luks bind -d /dev/sda4 tpm2 '{"pcr_bank":"sha256","pcr_ids":"0,1,2,3,4,5,6,7"}'
sudo clevis luks bind -d /dev/md0 tpm2 '{"pcr_bank":"sha256","pcr_ids":"0,1,2,3,4,5,6,7"}'
```

Reboot one more time, do some grepping and bask in the glory of soon to be broken RSA secured boot!

I'll post details here if I manage to upgrade to ECC.

### Sanity check

At some point I ran some tests using `sysbench`, and tried out my Quantum Computer simulator, attempting to build a complex 15-[qubit](https://en.wikipedia.org/wiki/Qubit) circuit. Each gate in such a circuit is ~16gb when using 64 bit precision. Shortly after I took this photo, the simulator blew up due to a lack of memory. I plan to refactor the way in which the circuit is built, and type the simulator to allow 32 bit precision as an option.
![Shor's Algorithm](assets/switch/shor-running.jpg)

