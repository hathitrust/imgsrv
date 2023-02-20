# FROM hathitrust/feed_base:bullseye

FROM debian:bullseye

RUN sed -i 's/main.*/main contrib non-free/' /etc/apt/sources.list

RUN apt-get update && apt-get install -y \
  autoconf \
  bison \
  build-essential \
  cpanminus \
  curl \
  file \
  git \
  imagemagick \
  libalgorithm-diff-xs-perl \
  libany-moose-perl \
  libapache-session-perl \
  libarchive-zip-perl \
  libclass-accessor-perl \
  libclass-c3-perl \
  libclass-data-accessor-perl \
  libclass-data-inheritable-perl \
  libclass-errorhandler-perl \
  libclass-load-perl \
  libcommon-sense-perl \
  libcompress-raw-zlib-perl \
  libconfig-auto-perl \
  libconfig-inifiles-perl \
  libconfig-tiny-perl \
  libcrypt-openssl-random-perl \
  libcrypt-openssl-rsa-perl \
  libcrypt-ssleay-perl \
  libdata-optlist-perl \
  libdata-page-perl \
  libdate-calc-perl \
  libdate-manip-perl \
  libdbd-mock-perl \
  libdbd-mysql-perl \
  libdbd-sqlite3-perl \
  libdevel-cover-perl \
  libdevel-globaldestruction-perl \
  libdigest-sha-perl \
  libemail-date-format-perl \
  libencode-locale-perl \
  liberror-perl \
  libeval-closure-perl \
  libexcel-writer-xlsx-perl \
  libfcgi-perl \
  libfcgi-procmanager-perl \
  libffi-dev \
  libfile-listing-perl \
  libfile-slurp-perl \
  libfilesys-df-perl \
  libgdbm-dev \
  libgeo-ip-perl \
  libhtml-parser-perl \
  libhtml-tree-perl \
  libhttp-browserdetect-perl \
  libhttp-cookies-perl \
  libhttp-daemon-perl \
  libhttp-date-perl \
  libhttp-dav-perl \
  libhttp-message-perl \
  libhttp-negotiate-perl \
  libimage-exiftool-perl \
  libimage-info-perl \
  libimage-size-perl \
  libinline-perl \
  libio-html-perl \
  libio-socket-ssl-perl \
  libio-string-perl \
  libipc-run-perl \
  libjson-perl \
  libjson-pp-perl \
  libjson-xs-perl \
  liblist-compare-perl \
  liblist-moreutils-perl \
  liblog-log4perl-perl \
  liblwp-authen-oauth2-perl \
  liblwp-mediatypes-perl \
  libmail-sendmail-perl \
  libmailtools-perl \
  libmarc-record-perl \
  libmarc-xml-perl \
  libmime-lite-perl \
  libmime-types-perl \
  libmodule-implementation-perl \
  libmodule-runtime-perl \
  libmoose-perl \
  libmouse-perl \
  libmro-compat-perl \
  libncurses5-dev \
  libnet-dns-perl \
  libnet-http-perl \
  libnet-libidn-perl \
  libnet-oauth-perl \
  libnet-ssleay-perl \
  libpackage-deprecationmanager-perl \
  libpackage-stash-perl \
  libparse-recdescent-perl \
  libperl-critic-perl \
  libplack-perl \
  libpod-simple-perl \
  libproc-processtable-perl \
  libreadline6-dev \
  libreadonly-perl \
  libreadonly-xs-perl \
  libroman-perl \
  libsoap-lite-perl \
  libspreadsheet-writeexcel-perl \
  libssl-dev \
  libsqlite3-dev \
  libsub-exporter-progressive-perl \
  libsub-name-perl \
  libswitch-perl \
  libtest-class-perl \
  libtest-spec-perl \
  libtest-mockobject-perl \
  libtemplate-perl \
  libterm-readkey-perl \
  libterm-readline-gnu-perl \
  libtest-requiresinternet-perl \
  libtest-simple-perl \
  libtie-ixhash-perl \
  libtimedate-perl \
  libtry-tiny-perl \
  libuniversal-require-perl \
  liburi-encode-perl \
  libuuid-perl \
  libuuid-tiny-perl \
  libversion-perl \
  libwww-perl \
  libwww-robotrules-perl \
  libxerces-c3-dev \
  libxerces-c3.2 \
  libxml-dom-perl \
  libxml-libxml-perl \
  libxml-libxslt-perl \
  libxml-sax-perl \
  libxml-simple-perl \
  libxml-writer-perl \
  libyaml-appconfig-perl \
  libyaml-dev \
  libyaml-libyaml-perl \
  libyaml-perl \
  netcat \
  perl \
  procps \
  sqlite3 \
  starman \
  unzip \
  vim-tiny \
  zip \
  zlib1g-dev

RUN curl https://hathitrust.github.io/debian/hathitrust-archive-keyring.gpg -o /usr/share/keyrings/hathitrust-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/hathitrust-archive-keyring.gpg] https://hathitrust.github.io/debian/ bullseye main" > /etc/apt/sources.list.d/hathitrust.list

RUN apt-get update && apt-get install -y grokj2k-tools

RUN cpan \
  File::Pairtree \
  URI::Escape \
  CGI::PSGI \
  IP::Geolocation::MMDB


RUN curl -L -o /tmp/netpbm-sf-10.73.32_amd64.deb https://sourceforge.net/projects/netpbm/files/super_stable/10.73.32/netpbm-sf-10.73.32_amd64.deb/download
RUN dpkg --force-all -i /tmp/netpbm-sf-10.73.32_amd64.deb

RUN ln -s /tmp /ram

RUN mkdir -p /l/local/bin
RUN ln -s /usr/bin/unzip /l/local/bin/unzip
RUN ln -s /usr/bin/convert /l/local/bin/convert
RUN ln -s /usr/local/bin/kdu_expand /l/local/bin/kdu_expand
RUN ln -s /usr/local/bin/kdu_compress /l/local/bin/kdu_compress
RUN ln -s /usr/bin/plackup /l/local/bin/plackup
RUN /bin/bash -c 'for cmd in pamflip jpegtopnm tifftopnm bmptopnm pngtopam ppmmake pamcomp pnmscalefixed pamscale pnmrotate pnmpad pamtotiff pnmtotiff pnmtojpeg pamrgbatopng ppmtopgm pnmtopng; do ln -s /usr/bin/$cmd /l/local/bin; done'

WORKDIR /htapps/babel/imgsrv

RUN mkdir /htapps/babel/cache
RUN chmod 4777 /htapps/babel/cache

RUN mkdir /htapps/babel/logs
RUN chmod 4777 /htapps/babel/logs

RUN ln -s /htapps/babel /htapps/test.babel
RUN cd /htapps/babel; git clone https://github.com/hathitrust/mdp-web.git

COPY . /htapps/babel/imgsrv
RUN ln -s imgsrv/vendor/common-lib/lib ../mdp-lib


CMD ["/htapps/babel/imgsrv/bin/startup_imgsrv"]
