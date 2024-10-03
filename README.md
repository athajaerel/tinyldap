# tinyldap

As a podman container:
Connect to container and run /opt/install.bash

As a Helm chart:
Connect to container and run helm_postinstall.bash (copy and paste)

To test database:
ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config olcDatabase=\*
slaptest -u

Show layers in image: podman history tinyldap:latest
Show layer IDs in image: podman history -q tinyldap:latest
Show number of layer IDs in image: podman history -q tinyldap:latest | wc -l

Show size of images /MB: podman images tinyldap:latest
Show size of images /MB: echo $(( $(podman images --format=json tinyldap:latest | jq -r .[0].Size) / 1024 / 1024 ))

250MB across 7000-odd files? Think we can improve it a bit...
50MB across 577 files, that's a bit better. Could improve but I like bash, procps and the iproute2 tools.

