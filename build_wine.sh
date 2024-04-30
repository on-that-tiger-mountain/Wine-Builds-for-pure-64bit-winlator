cd /opt
wget -q --show-progress "https://dl.winehq.org/wine/source/9.x/wine-9.7.tar.xz"

tar xf "wine-9.7.tar.xz"
mv "wine-9.7" wine97
rm -f wine-9.7.tar.xz

mkdir /opt/wine97/build
cd /opt/wine97/build
/opt/wine97/configure --enable-archs=i386,x86_64 --prefix /opt/wine97/build/wine-9.7-exp-amd64
make install

cp /opt/wine97/build/wine-9.7-exp-amd64/bin/wine-preloader /opt/wine97/build/wine-9.7-exp-amd64/bin/wine64-preloader

cp /opt/wine97/build/wine-9.7-exp-amd64/bin/wine /opt/wine97/build/wine-9.7-exp-amd64/bin/wine64

tar -Jcf wine-9.7-exp-amd64.tar.xz wine-9.7-exp-amd64
mv wine-9.7-exp-amd64.tar.xz /opt/

rm -rf /opt/wine97

echo
echo "Done"

