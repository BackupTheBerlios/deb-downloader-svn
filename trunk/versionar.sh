#!/bin/sh

versio=$1

if [ "$versio" = "" ] ; then
	echo "Fa falta entrar el número de versio"
	exit 1
fi


if [ -d deb-downloader-$versio ] ; then
	echo -n "Generem el tar..."
	tar cvf deb-downloader-$versio.tar deb-downloader-$versio/ > /dev/null
	echo "fet."

	echo -n "Generem el tar.gz..."
	gzip -c deb-downloader-$versio.tar  > deb-downloader-$versio.tar.gz 
	echo "fet."

	echo -n "Generem el tar.bz..."
	bzip2 -c deb-downloader-$versio.tar > deb-downloader-$versio.tar.bz 
	echo "fet."

	echo -n "Esborrem el tar..."
	rm deb-downloader-$versio.tar
	echo "fet."
else
	echo "No existeix el directori de versionat"
	exit 1
fi

exit 0
