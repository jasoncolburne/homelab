[home](README.md)

# Network Attached Storage

Quantum gates are huge. I cache them in order to improve circuit build times. I need a lot of storage space.

I also want to have a place to store musical recordings, code, and personal documents. I've lost data before and it's no fun. I've processed dead HDDs with `dd` to recover bits and pieces, and it's a garbage task.

## Parts
- [Synology RS3621xs+](https://www.synology.com/en-ca/products/RS3621xs+)
- [Synology RKS-02](https://www.synology.com/en-global/products/RKS-02)
- 12x[4TB Seagate Exos 7E8 (ST4000NM002A)](https://www.seagate.com/ca/en/enterprise-storage/exos-drives/exos-e-drives/exos-7e8/)

## Planned Upgrades
- 4x16gb Crucial 2666Mhz ECC UDIMM CL19 (CT16G4WFD8266)
- Dual 10Gbe SFP+ Networking

## Assembly

This was straightforward, following the supplied. Remember to lock the drives after inserting them.

1. Remove all drive caddies from the RS3621xs+.
1. Mount drives in the caddies.
1. Install rails in rack (seemed confusing but was actually easy)
1. Install the RS3621xs+ on its rails with a friend to ensure you don't accidentally bend something.
1. Slide the RS3621xs+ back and lock it into place.
1. Install and lock drives in RS3621xs+.
1. Connect both power cables (to two distinct circuits, if possible)
