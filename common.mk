.PHONY: tinyldap
tinyldap: BUILD_FLAGS := \
		--http-proxy=false \
		--no-cache=false \
		--compress=true \
		--layers=true \
		--format=oci \
		--build-arg=PKGS="${pkgs} ${temp_pkgs}" \
		--build-arg=STAGE_PKGS="${pkgs}" \
		--log-level=info

tinyldap:
	podman build $(BUILD_FLAGS) \
		-f=Containerfile \
		--tag=tinyldap \
		.

.PHONY: clean
clean: prune

.PHONY: prune
prune:
	podman rmi -a || true

