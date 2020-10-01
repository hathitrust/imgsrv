FROM hathitrust/feed_base:buster

RUN apt-get install -y libtest-class-perl libswitch-perl libtest-spec-perl libtest-mockobject-perl

WORKDIR /htapps/babel/imgsrv
COPY . /htapps/babel/imgsrv

RUN git config --global url."https://github.com/".insteadOf git@github.com:
RUN git config --global url."https://".insteadOf git://

RUN git submodule init
RUN git submodule update
RUN ln -s imgsrv/vendor/common-lib/lib ../mdp-lib
RUN ln -s /htapps/babel /htapps/test.babel
RUN cd ./sql; ln -s ../vendor/common-lib/lib/sql/*.sql .

RUN wget -O /tmp/netpbm-sf-10.73.32_amd64.deb https://sourceforge.net/projects/netpbm/files/super_stable/10.73.32/netpbm-sf-10.73.32_amd64.deb/download
RUN dpkg --force-all -i /tmp/netpbm-sf-10.73.32_amd64.deb

# # for now
# RUN apt-get update; apt-get -y install mariadb-client

RUN mkdir -p /l/local/bin
RUN ln -s /usr/bin/unzip /l/local/bin/unzip
RUN ln -s /usr/bin/convert /l/local/bin/convert
RUN ln -s /usr/local/bin/kdu_expand /l/local/bin/kdu_expand
RUN ln -s /usr/local/bin/kdu_compress /l/local/bin/kdu_compress
RUN /bin/bash -c 'for cmd in pamflip jpegtopnm tifftopnm bmptopnm pngtopam ppmmake pamcomp pnmscalefixed pamscale pnmrotate pnmpad pamtotiff pnmtotiff pnmtojpeg pamrgbatopng ppmtopgm pnmtopng; do ln -s /usr/bin/$cmd /l/local/bin; done'

RUN cd /htapps/babel; git clone https://github.com/hathitrust/mdp-web.git

# RUN bin/setup_dev.sh
ENV SDRROOT=/htapps/babel
ENV SDRDATAROOT=/sdr1
ENV HT_DEV=
ENV MARIADB_USER=ht_web

COPY entrypoint.sh /usr/bin
RUN chmod +x /usr/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
CMD ["/htapps/babel/imgsrv/bin/startup_imgsrv"]
