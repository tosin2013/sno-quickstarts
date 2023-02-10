#!/bin/bash 

pvcreate /dev/vdb

vgcreate vgmcg /dev/vdb

lvcreate -n lv-vgmcg -l 100%FREE vgmcg
mkfs.xfs /dev/vgmcg/lv-vgmcg
vgdisplay 
mkdir lv-vgmcg
