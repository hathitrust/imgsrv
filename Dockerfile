FROM hathitrust/feed_base:buster

RUN apt-get install -y libtest-class-perl libswitch-perl libtest-spec-perl libtest-mockobject-perl

RUN wget -O /tmp/netpbm-sf-10.73.32_amd64.deb https://sourceforge.net/projects/netpbm/files/super_stable/10.73.32/netpbm-sf-10.73.32_amd64.deb/download
RUN dpkg --force-all -i /tmp/netpbm-sf-10.73.32_amd64.deb

RUN ln -s /tmp /ram

RUN mkdir -p /l/local/bin
RUN ln -s /usr/bin/unzip /l/local/bin/unzip
RUN ln -s /usr/bin/convert /l/local/bin/convert
RUN ln -s /usr/local/bin/kdu_expand /l/local/bin/kdu_expand
RUN ln -s /usr/local/bin/kdu_compress /l/local/bin/kdu_compress
RUN /bin/bash -c 'for cmd in pamflip jpegtopnm tifftopnm bmptopnm pngtopam ppmmake pamcomp pnmscalefixed pamscale pnmrotate pnmpad pamtotiff pnmtotiff pnmtojpeg pamrgbatopng ppmtopgm pnmtopng; do ln -s /usr/bin/$cmd /l/local/bin; done'

WORKDIR /htapps/babel/imgsrv
RUN ln -s /htapps/babel /htapps/test.babel
RUN cd /htapps/babel; git clone https://github.com/hathitrust/mdp-web.git

COPY . /htapps/babel/imgsrv
RUN ln -s imgsrv/vendor/common-lib/lib ../mdp-lib


CMD ["/htapps/babel/imgsrv/bin/startup_imgsrv"]
