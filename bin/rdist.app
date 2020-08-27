#
# RDIST Application Distribution File
#
# PURPOSE: deploy application from test.babel.hathitrust.org to
# production. rdist.timestamp is in the except_pat and is rdist'd
# AFTER app rdist has completed so it's the NEW code that is restarted
# by plack.
#
# Destination Servers
#
NASMACC = ( nas-macc.umdl.umich.edu )
NASICTC = ( nas-ictc.umdl.umich.edu )

#
# File Directories to be released (source) and (destination)
#
APP_src  = ( /htapps/test.babel/imgsrv )
APP_dest = ( /htapps/babel/imgsrv )

#
# Release instructions
#
( ${APP_src} ) -> ( ${NASMACC} ${NASICTC} )
        install -oremove ${APP_dest};
        except_pat ( \\.git rdist.timestamp );
        notify hathitrust-release@umich.edu ;

