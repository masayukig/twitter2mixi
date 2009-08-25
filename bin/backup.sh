#!/bin/sh

APPDIR = /var/www/sinatra/twitter2mixi

tar cvzf $APPDIR/backup/db_`date +%Y%m%d`.tar.gz $APPDIR/db/t2m_*.db

if test -f $APPDIR/backup/db_`date +%Y%m%d -d '30day ago'`.tar.gz then
  rm -f $APPDIR/backup/db_`date +%Y%m%d -d '30day ago'`.tar.gz
fi
