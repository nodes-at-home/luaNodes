#!/bin/bash

if [ -n "$(docker container inspect nodemcu-esp8266)" ]; then
    echo "Building LFS for esp8266..."
    docker exec nodemcu-esp8266 bash -c "rm ../lua/LFS*; lfs-image && mv ../lua/LFS* ../bin/lfs_esp8266.img"
fi

if [ -n "$(docker container inspect nodemcu-esp32)" ]; then
    echo "Building LFS for esp32..."
    docker exec nodemcu-esp32 bash -c "rm ../lua/LFS*; lfs-image && mv ../lua/LFS* ../bin/lfs_esp32.img"
fi
