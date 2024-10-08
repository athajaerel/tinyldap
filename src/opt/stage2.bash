#!/bin/bash
#set -xuo pipefail

# $1: item to check/add
# $2: file for the adding
add_dest_if_symlink() {
	# if it's a symlink, recursively add dests to final list
	TYPE=$(file $1 | cut -d: -f2 | cut -c 2-)
	<<<${TYPE} grep -q "^symbolic link to " ; IS_LINK=$?
	if [ ${IS_LINK} -eq 0 ]; then
		DEST=$(readlink -m $1)
		echo "Adding linked: ${DEST}"
		<<<${DEST} tee -a $2 >/dev/null
		add_dest_if_symlink "${DEST}" "$2"
	fi
}

# $1: item to check/add
# $2: file for the adding
add_deps_if_binary() {
	# not sure how recursive this can go...
	TYPE=$(file $1 | cut -d: -f2 | cut -c 2-)
	<<<${TYPE} grep -q "^ELF 64-bit " ; IS_BINARY=$?
	if [ ${IS_BINARY} -eq 0 ]; then
		DEPS=$(ldd $1 | grep -v linux-vdso.so.1)
		while read DEP
		do
			<<<"${DEP}" grep -q " => " ; HAS_ARROW=$?
			FILE=""
			if [ ${HAS_ARROW} -eq 0 ]; then
				# grab what's on the right
				FILE=$(<<<"${DEP}" awk '{print $3}')
			else
				# take the first item
				FILE=$(<<<"${DEP}" awk '{print $1}')
			fi
			echo "Dep: ${FILE}"
			<<<${FILE} tee -a $2 >/dev/null
		done <<<${DEPS}
	fi
}

mkdir -p /stage2

cd /stage2
mkdir bin lib usr var
ln -s ../bin usr/bin
ln -s bin sbin
ln -s ../bin usr/sbin
ln -s ../lib usr/lib
ln -s ../lib usr/lib64
ln -s lib lib64
cd /

# add empty dirs needed later
EMPTYDIRS="
/var/lib/ldap/accesslog
/var/run/slapd
"

for DIR in ${EMPTYDIRS}
do
	echo "Create empty dir: /stage2${DIR}"
	mkdir -p /stage2${DIR}
done

# add package files
FILEFILE="/tmp/filefile"
for PKG in ${STAGE_PKGS}
do
	echo "Parse package ${PKG}..."
	apt-file list ${PKG} | cut -d: -f2- | tr -d ' ' | tee -a ${FILEFILE} >/dev/null
done

# add deps
UNIQFILES=$(<${FILEFILE} sort -u)
#rm ${FILEFILE}
for FILE in ${UNIQFILES}
do
	add_deps_if_binary "${FILE}" "${FILEFILE}"
done

# dereference symlinks and add dests
UNIQFILES=$(<${FILEFILE} sort -u)
#rm ${FILEFILE}
for FILE in ${UNIQFILES}
do
	# build final copy list in ${FILEFILE}
	echo "Adding: ${FILE}"
	<<<${FILE} tee -a ${FILEFILE} >/dev/null
	add_dest_if_symlink "${FILE}" "${FILEFILE}"
done

# copy files
UNIQFILES=$(<${FILEFILE} sort -u)
#rm ${FILEFILE}
for FILE in ${UNIQFILES}
do
	DIR=/stage2$(dirname ${FILE})
	echo "Create dir: ${DIR}"
	mkdir -p ${DIR}
	echo "Add file: ${FILE}"
	cp -pr ${FILE} /stage2${FILE}
done

# add extra files needed later
#/lib64/ld-linux-x86-64.so.2
#/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
EXTRAFILES="
/etc/ldap/ldap.conf
/etc/ldap/slapd.d
/etc/tls/ldaps.crt
/etc/tls/ldaps.key
/opt/install.bash
/opt/basic_infra.ldif
/opt/config.ldif
/opt/first_user.ldif
/opt/tls.ldif
"

for FILE in ${EXTRAFILES}
do
	DIR=/stage2$(dirname ${FILE})
	echo "Create dir: ${DIR}"
	mkdir -p ${DIR}
	echo "Extra file: ${FILE}"
	cp -pr ${FILE} /stage2${FILE}
done

# remove unneeded files and directories to trim image size
PRUNEFILES="
/usr/share/doc
/usr/share/examples
/usr/share/man
/usr/lib/systemd
/lib/systemd
/etc/systemd
/etc/skel
/etc/sysctl.d
"

for FILE in ${PRUNEFILES}
do
	echo "Prune file: ${FILE}"
	rm -rf /stage2${FILE}
done

