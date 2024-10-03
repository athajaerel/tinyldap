# Stage 1 - get OS, update, add packages
FROM bitnami/minideb:bookworm AS stage1

ARG PKGS

RUN apt-get -y update
RUN apt-get -y install ${PKGS}
RUN apt-file update

# Stage 2 - app build
FROM scratch AS stage2
COPY --from=stage1 . /

ARG STAGE_PKGS

ENV PATH="/usr/bin:/bin:/usr/sbin:/sbin"

COPY src/ /

RUN mkdir -p /etc/tls
RUN botan keygen >/etc/tls/ldaps.key
RUN botan gen_self_signed /etc/tls/ldaps.key localhost \
	--dns=localhost \
	--dns=ldap.k3s.lab \
	>/etc/tls/ldaps.crt

COPY slapd.d /etc/ldap/

COPY --chmod=0755 src/opt/stage2.bash /opt/
RUN /opt/stage2.bash

# Stage 3 - make tiny scratch build
FROM scratch
COPY --from=stage2 /stage2/. ./

ENV LD_LIBRARY_PATH="/usr/lib:/usr/lib/x86_64-linux-gnu:/lib:/lib/x86_64-linux-gnu:/lib64:/usr/lib64"
ENV PATH="/usr/bin:/bin:/usr/sbin:/sbin"

EXPOSE 10389/tcp 10636/udp
ENTRYPOINT ["/usr/sbin/slapd", "-d255", "-s255", "-4", "-h", "ldap://0.0.0.0:10389/ ldaps://0.0.0.0:10636/ ldapi:///"]
