#!/usr/bin/bash

set -euo pipefail

sudo apt-get -y install --no-install-recommends build-essential fakeroot
sudo apt-get -y build-dep linux

mkdir -p ~/kernel
cd ~/kernel

rm -rf linux-* linux_*
apt source linux
cd linux-*

cat > debian/config/amd64/config.sme << EOF
CONFIG_AMD_MEM_ENCRYPT=y
CONFIG_MODULE_ALLOW_MISSING_NAMESPACE_IMPORTS=n
CONFIG_MODULE_COMPRESS_ZSTD=y
CONFIG_MODULE_SIG=y
CONFIG_MODULE_SIG_ALL=n
CONFIG_MODULE_SIG_FORCE=n
CONFIG_SYSTEM_TRUSTED_KEYS="/var/lib/shim-signed/mok/MOK.pem"
EOF

cat >> debian/config/amd64/defines << EOF

[sme-amd64_description]
hardware: 64-bit sme servers
hardware-long: AMD EPYC servers capable of SME
EOF

cat > debian/config/amd64/none/defines << EOF
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
EOF

debian/bin/gencontrol.py
fakeroot make -f debian/rules.gen binary-arch_amd64_none_sme-amd64 -j$(nproc)

cd ~
rm kernel/*dbg*.deb

tar czvf kernel.tgz kernel/linux-image-*-sme-amd64_*_amd64.deb kernel/linux-headers-*-sme-amd64_*_amd64.deb
