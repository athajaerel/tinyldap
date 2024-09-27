#!/bin/bash
set -exuo pipefail

ldapmodify -c -Q -Y EXTERNAL -H ldapi:/// -f /opt/config.ldif
ldapmodify -c -Q -Y EXTERNAL -H ldapi:/// -f /opt/tls.ldif
ldapmodify -c -Q -Y EXTERNAL -H ldapi:/// -f /opt/basic_infra.ldif
ldapmodify -c -Q -Y EXTERNAL -H ldapi:/// -f /opt/first_user.ldif
