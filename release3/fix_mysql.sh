#!/bin/bash

GEAR_BASE_DIR=/var/lib/openshift

cd $GEAR_BASE_DIR
for i in *; do

	pushd $i
	if [ -d "$GEAR_BASE_DIR/$i/mysql" ]; then
		echo "mysql found in $GEAR_BASE_DIR/$i/mysql"
		oo-admin-ctl-gears stopgear $i
		rm -f $GEAR_BASE_DIR/$i/mysql/data/ib_logfile*
		oo-admin-ctl-gears startgear $i
	fi
	popd
done
