# Stage 1 - get OS, update, add packages
FROM bitnami/minideb:bookworm AS stage1

ARG PKGS

RUN apt-get -y update
RUN apt-get -y install ${PKGS}
RUN apt-file update

# Stage 2 - app build
FROM scratch AS stage2
COPY --from=stage1 . /

RUN mkdir -p /etc/ldap/slapd.d /etc/ldap

ARG STAGE_PKGS

ENV PATH="/usr/bin:/bin:/usr/sbin:/sbin"

COPY src/ /

#ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f /opt/config.ldif

# Test database:
#ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config olcDatabase=\*
#slaptest -u

#RUN mkdir -p /stage2
#RUN /opt/install.bash
#RUN /opt/create_stage2.bash
#RUN /opt/test_stage2.bash

# Stage 3 - copy in selected files
#FROM scratch
#COPY --from=stage2 /stage2/. ./

#ENV LD_LIBRARY_PATH="/usr/lib:/usr/lib/x86_64-linux-gnu:/lib:/lib/x86_64-linux-gnu:/lib64:/usr/lib64"
#ENV PATH="/usr/bin:/bin:/usr/sbin:/sbin"

# Connect to container and run:
# ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f /opt/config.ldif

# TLS https://wiki.debian.org/LDAP/OpenLDAPSetup#Enabling_TLS.2FSSL

EXPOSE 10389/tcp 10636/udp
ENTRYPOINT ["/usr/sbin/slapd", "-d255", "-s255", "-4", "-h", "ldap://0.0.0.0:10389/ ldaps://0.0.0.0:10636/ ldapi:///"]
