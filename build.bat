docker run --rm -it -e TZ=Europe/Berlin -v C:\Users\andre\GIT\nodemcu-firmware:/opt/nodemcu-firmware -v C:\Users\andre\GIT\luaNodes\src_lfs:/opt/lua -v C:\Users\andre\GIT\luaNodes\bin:/opt/bin --name nodemcu-build marcelstoer/nodemcu-build bash -c "rm ../lua/LFS*; lfs-image && mv ../lua/LFS* ../bin/lfs.img"