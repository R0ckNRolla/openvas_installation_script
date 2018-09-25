#!/bin/bash

BASE=openvas
ASTERIKS="*"
NOCERT=--no-check-certificate

declare -a _package_list=("-smb-" "-libraries-" "-scanner-" "-manager-" "-cli-" "greenbone-security-assistant-")

function _install_prerequisites() {
	apt install -y build-essential cmake gcc-mingw-w64 libgnutls28-dev perl-base heimdal-dev lippopt-dev libglib2.0-dev libssh-dev libpcap-dev libgpgme11-dev uuid-dev bison libksba-dev libhiredis-dev libsnmp-dev libcrypt20-dev libldap2-dev libfreeradius-client-dev dpxygen xmltoman sqlfairy sqlite3 redis-server gnutls-bin libsqlite3-dev texlive texlive-lang-german texlive-lang-english texlive-latex-recommended texlive-latex-extra libmicrohttpd-dev libxml2-dev libxslt1.1 xsltproc flexclang nmap rpm nsis alien
}

function _get_sources() {
	wget http://wald.intevation.org/frs/download.php/2420/openvas-libraries-9.0.1.tar.gz ${NOCERT}
	wget http://wald.intevation.org/frs/download.php/2423/openvas-scanner-5.1.1.tar.gz ${NOCERT}
	wget http://wald.intevation.org/frs/download.php/2426/openvas-manager-7.0.2.tar.gz
	wget http://wald.intevation.org/frs/download.php/2429/greenbone-security-assistant-7.0.2.tar.gz ${NOCERT}
	wget http://wald.intevation.org/frs/download.php/2397/openvas-cli-1.4.5.tar.gz ${NOCERT}
	wget http://wald.intevation.org/frs/download.php/2377/openvas-smb-1.0.4.tar.gz ${NOCERT}
	wget http://wald.intevation.org/frs/download.php/2401/ospd-1.2.0.tar.gz ${NOCERT}
	wget http://wald.intevation.org/frs/download.php/2405/ospd-debsecan-1.2b1.tar.gz ${NOCERT}
	
	find . -name \*.gz -exec tar zxvfp {} \;
}

function _install_sources() {
	echo "-- BUILDING SOURCES"
	DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null && pwd)"
	
	for p in "${_package_list[@]}"
	do
		if ["$p" = "greenbone-security-assistant"]; then
			G="greenbone-security-assistant"
			cd ${DIR}/${BASE}$G${ASTERIKS}/
			mkdir source && cd source
			cmake ..
			make
			#make doc-full
			make install && cd ../../
		else
			cd ${DIR}/${BASE}$p${ASTERIKS}/
			mkdir source && cd source
			cmake ..
			make
			#make doc-full
			make install && cd ../../
		fi
		echo �[OK] - $p installed�
	done
}

function _start_configuration() {
	echo "-- CONFIGURATION"
	echo "		-- configure redis-server"
	cp /etc/redis/redis.conf /etc/redis/redis.orig
	echo �unixsocket /tmp/redis.sock� >> /etc/redis/redis.conf
	echo �unixsocketperm 700� >> /etc/redis/redis.conf
	service redis-server restart
	
	echo "		-- manage certificates"
	openvas-manage-certs �a
	echo "		-- create, udpate and remove symbolic links"
	ldconfig
	echo "CONFIGURATION COMPLETE"
}

function _create_user() {
	echo "-- CREATE USER"
	openvasmd --create-user=root --role=Admin
	openvasmd --user=root --new-password=toor
}

function _update_base() {
	echo "-- UPDATINE DATA"
	echo "		-- Run nvt sync"
	/usr/local/sbin/greenbone-nvt-sync
	echo "		-- Run scapdata sync"
	/usr/local/sbin/greenbone-scapdata-sync
	echo "		-- Run certdata sync"
	/usr/local/sbin/greenbone-certdata-sync
	
}

function _killing_services() {
	echo "-- KILLING PROCESSES"
	echo "		-- openvas"
	echo "		-- gsad"
	echo "		-- redis"
	ps aux | egrep "(openvas|gsad|redis-server)" | awk '{print $2}' | xargs -i kill -9 '{}'
	service redis-server stop
}

function _launch_services() {
	echo "-- LAUNCHING SERVICES"
	echo "		-- Reload config for redis-server"
	redis-server /etc/redis/redis.conf
	echo "		-- Start redis-server"
	/etc/init.d/redis-server start
	echo "		-- Start openvasmd"
	/usr/local/sbin/openvasmd
	echo "		-- Start openvassd"
	/usr/local/sbin/openvassd
	echo "		-- Start gsad"
	/usr/local/sbin/gsad
	
}

echo " "
_install_prerequisites
_intall_sources
_start_configuration
_create_user
_update_data
echo "-- REBUILDING NVT'S"
/usr/local/sbin/openvasmd --rebuild �progress
_restart_services
echo "INSTALLATION COMPLETE"