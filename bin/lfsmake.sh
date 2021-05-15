#!/bin/bash
# junand 13.05.2021

#set -x # -o errexit -o xtrace -o verbose

LUADIR=/opt/lua
BINDIR=/opt/bin
LFSIMAGE=lfs-image
###LFSIMAGE=${BINDIR}/lfs-image.sh
LFSIMAGE=lfs-image

rm ${LUADIR}/LFS_float_*.img

if [ -z "$1" ]
then
    ${LFSIMAGE} __all.lst
    mv ${LUADIR}/LFS_float_*.img ${BINDIR}/lfs.img
else
    m=$1
    cp ${BINDIR}/core.lst ${LUADIR}/__${m}.lst
    echo "${m}.lua" >> ${LUADIR}/__${m}.lst
    ${LFSIMAGE} __${m}.lst
    mkdir -p ${BINDIR}/${m}
    mv ${LUADIR}/LFS_float_*.img ${BINDIR}/${m}/lfs.img
fi
