REMOTE := "ghcr.io"
IMAGE := $(shell echo ${REMOTE})/dreamtrack-net/tinyldap
NOW := $(shell date -Iseconds | cut -c 1-19 | tr ' :' '__')Z
TAG_DT := $(shell echo ${NOW} | cut -c 1-10)

.PHONY: tinyldap
tinyldap: BUILD_FLAGS := \
		--http-proxy=false \
		--no-cache=false \
		--compress=true \
		--layers=true \
		--format=oci \
		--build-arg=PKGS="${pkgs} ${temp_pkgs}" \
		--build-arg=STAGE_PKGS="${pkgs}" \
		--tag="$(IMAGE):latest" \
		--tag="$(IMAGE):$(TAG_DT)" \
		--tag="$(IMAGE):$(NOW)" \
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

.PHONY: push
push: tinyldap
	no_proxy=* NO_PROXY=* podman login $(REMOTE)
	no_proxy=* NO_PROXY=* podman push $(IMAGE):latest
	no_proxy=* NO_PROXY=* podman push $(IMAGE):$(TAG_DT)
	no_proxy=* NO_PROXY=* podman push $(IMAGE):$(NOW)

