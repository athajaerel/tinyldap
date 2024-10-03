#!/bin/bash
set -euo pipefail

# run on each of the replicas (actually inside)
# then bounce the pod kill -HUP 1

# TODO: add SANs for IPs
# TODO: automate this in Helm chart
# TODO: Check apparmor isn't causing problems for slapd, specifically preventing it reading files in /etc/tls
# TODO: add god user pw
# TODO: change replicator user type (and access? and dn?)
# TODO: check the replication actually works, looks duff to me

# test: $ ldapsearch -x -H ldap://ldap.k3s.lab/ -b dc=admin,dc=k3s,dc=lab -D "cn=admin,dc=k3s,dc=lab" -W

GOD='zeus'
GODPWHASH='{SSHA}JWA/xti9Me/iEt8hKqFBV6JcO6BWTKlV'
GODHOME='/mnt/olympus'
GODSHELL='/bin/bash'
GODGECOS='The Almighty'

SUFFIX='dc=k3s,dc=lab'
G="users serviceaccounts groups hosts"
USERGROUPDN="ou=users,${SUFFIX}"

# slightly magical settings
UNIQUE_POD_ID=1
UNIQUE_REP_ID="002"
# other replica IP
REP_PROVIDER="ldap://10.20.0.202"
REP_BINDDN="cn=replicator,dc=k3s,dc=lab"
REP_BINDPW="wibble"

# make TLS work
<<<"dn: cn=config
changetype: modify
add: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/tls/ca.crt

dn: cn=config
changetype: modify
add: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/tls/tls.key

dn: cn=config
changetype: modify
add: olcTLSCertificateFile
olcTLSCertificateFile: /etc/tls/tls.crt
" ldapmodify -c -Q -Y EXTERNAL -H ldapi:///

# add rootmost DIT object
<<<"dn: ${SUFFIX}
changetype: add
objectClass: top
objectClass: dcObject
objectclass: organization
o: K3S Amethyst
dc: k3s
description: Our company
" ldapmodify -c -Q -Y EXTERNAL -H ldapi:///

## restrict accepted TLS ciphers --- GnuTLS format
#dn: cn=config
#changetype: modify
#add: olcTLSCipherSuite
#olcTLSCipherSuite: SECURE256:+SECURE128:-VERS-TLS-ALL:+VERS-TLS1.2:+VERS-DTLS1.2:-RSA:-DHE-DSS:-CAMELLIA-128-CBC:-CAMELLIA-256-CBC

## allow client verification (huh?)
#dn: cn=config
#changetype: modify
#add: olcTLSVerifyClient
#olcTLSVerifyClient: allow

for X in $G
do
	<<<"dn: ou=${X},${SUFFIX}
changetype: add
objectClass: organizationalUnit
objectClass: top
" ldapmodify -c -Q -Y EXTERNAL -H ldapi:///
done

# add admin user
<<<"dn: uid=${GOD},${USERGROUPDN}
changetype: add
objectClass: account
objectClass: top
objectClass: shadowAccount
objectClass: posixAccount
cn: ${GOD}
gidNumber: 100000
uidNumber: 100000
homeDirectory: ${GODHOME}
loginShell: ${GODSHELL}
gecos: ${GODGECOS}
shadowLastChange: 0
shadowMax: 0
shadowWarning: 0
" ldapmodify -c -Q -Y EXTERNAL -H ldapi:///

# add replicator user
<<<"dn: uid=${REP_BINDDN}
changetype: add
objectClass: account
objectClass: top
objectClass: shadowAccount
objectClass: posixAccount
cn: ${REP_BINDDN}
gidNumber: 100001
uidNumber: 100001
userPassword: ${REP_BINDPW}
homeDirectory: /var/empty
loginShell: /sbin/nologin
gecos: Replication user
shadowLastChange: 0
shadowMax: 0
shadowWarning: 0
" ldapmodify -c -Q -Y EXTERNAL -H ldapi:///

# load multi-master replication modules
<<<"dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: syncprov.la
olcModuleLoad: accesslog.la
" ldapmodify -Q -Y EXTERNAL -H ldapi:///

# add accesslog database
<<<"dn: olcDatabase={2}mdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcMdbConfig
olcDatabase: {2}mdb
olcDbDirectory: /var/lib/ldap/accesslog
olcSuffix: cn=accesslog
olcRootDN: cn=admin,cn=accesslog
olcRootPW:: e1NTSEF9Z1NJdURWWUxBUW1iYW1haGxJTEJ1Z2FiZFdFN1E1bGQK
olcDbIndex: default eq
olcDbIndex: entryCSN,entryUUID eq
" ldapadd -Q -Y EXTERNAL -H ldapi:///

# this overlays on the actual database
<<<"dn: cn=config
changetype: modify
replace: olcServerID
# unique numeric id
olcServerID: ${UNIQUE_POD_ID}

dn: olcOverlay=syncprov,olcDatabase={1}mdb,cn=config
changetype: add
objectClass: olcOverlayConfig
objectClass: olcSyncProvConfig
olcOverlay: syncprov

dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcSyncRepl
olcSyncRepl: rid=${UNIQUE_REP_ID}
  provider=${REP_PROVIDER}
  bindmethod=simple
  binddn=\"${REP_BINDDN}\"
  credentials=${REP_BINDPW}
  searchbase=\"${SUFFIX}\"
  scope=sub
" ldapmodify -Q -Y EXTERNAL -H ldapi:///

