FROM hathitrust/feed_base:buster

RUN apt-get install -y libtest-class-perl libswitch-perl libtest-spec-perl libtest-mockobject-perl

# RUN mkdir /htapps/babel/etc
# RUN mkdir /sdr1
# RUN mkdir /sdr1/obj
# RUN mkdir /sdr1/obj/loc
# RUN mkdir -p /l/local/bin

WORKDIR /htapps/babel/imgsrv
COPY . /htapps/babel/imgsrv
# RUN git pull
RUN mkdir -p /root/.ssh
RUN ssh-keyscan -t rsa github.com >> /root/.ssh/known_hosts
RUN ssh-keygen -f /root/.ssh/id_rsa -t rsa -N ''
RUN chmod -R 400 /root/.ssh 
RUN ls -alR /root/.ssh

RUN git config --global url."https://github.com/".insteadOf git@github.com:
RUN git config --global url."https://".insteadOf git://

RUN git submodule init
RUN git submodule update

RUN git clone https://github.com/hathitrust/imgsrv-sample-data.git /tmp/imgsrv-sample-data
RUN mkdir /sdr1

RUN bin/setup_dev.sh
