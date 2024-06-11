#!/bin/bash 

pvcreate /dev/vdb

vgcreate vgmcg /dev/vdb

lvcreate -n lv-vgmcg -l 100%FREE vgmcg
mkfs.xfs /dev/vgmcg/lv-vgmcg
vgdisplay 
mkdir lv-vgmcg



sudo wipefs -af /dev/vdb
sudo sgdisk --zap-all /dev/vdb
sudo dd if=/dev/zero of=/dev/vdb bs=1M count=100 oflag=direct,dsync
sudo blkdiscard /dev/vdb