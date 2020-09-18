#!/bin/bash

wget -O netpbm-sf-10.73.32_amd64.deb https://sourceforge.net/projects/netpbm/files/super_stable/10.73.32/netpbm-sf-10.73.32_amd64.deb/download
dpkg --force-all -i netpbm-sf-10.73.32_amd64.deb

# put tools where expected
mkdir -p /l/local/bin
ln -s /usr/bin/unzip /l/local/bin/unzip
ln -s /usr/bin/convert /l/local/bin/convert

for cmd in pamflip jpegtopnm tifftopnm bmptopnm pngtopam ppmmake pamcomp pnmscalefixed pamscale pnmrotate pnmpad pamtotiff pnmtotiff pnmtojpeg pamrgbatopng ppmtopgm pnmtopng cat docker/netpbm.txt
do
  ln -s /usr/bin/$cmd /l/local/bin
done

# ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts


# should be removed
apt-get install nano

# make the environment

# mkdir /sdr1/obj/loc
ln -s /tmp /ram
# git clone git@github.com:hathitrust/imgsrv-sample-data.git /tmp
if [ ! -d /sdr1 ] 
then
  mkdir /sdr1
fi
ln -s /tmp/imgsrv-sample-data/sdr1/obj /sdr1/obj
ln -s /tmp/imgsrv-sample-data/watermarks /htapps/babel/watermarks

mkdir /htapps/babel/etc
cat <<EOF > /htapps/babel/etc/ht_web.conf
db_server = mariadb
db_name   = ht
db_user   = ht_web
db_passwd = ht_web
EOF

ln -s imgsrv/vendor/common-lib/lib ../mdp-lib
ln -s /htapps/babel /htapps/test.babel

echo "Hello."