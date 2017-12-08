# Override the arch with `make ARCH=i386`
VERSION = 0.1
ARCH   ?= $(shell flatpak --default-arch)
REPO   ?= repo

# Canned recipe for generating metadata
#   $1 = the input file to substitute
#   $2 = the output to create
define subst-metadata
	@echo -n "Generating ${2}... ";		\
	sed -e 's/@@ARCH@@/${ARCH}/g'		\
	    -e 's/@@VERSION@@/${VERSION}/g'	\
	   ${1} > ${2}.tmp && mv ${2}.tmp ${2} || exit 1;
	@echo "Done.";
endef

srcdir = $(CURDIR)
builddir = $(CURDIR)
NULL=
HASH:=$(shell git rev-parse HEAD)
IMAGEDIR=images/${ARCH}
SDK_MANIFEST=${IMAGEDIR}/debian-contents-sdk-${VERSION}-${ARCH}-${HASH}.manifest
PLATFORM_MANIFEST=${IMAGEDIR}/debian-contents-platform-${VERSION}-${ARCH}-${HASH}.manifest
SDK_IMAGE=${IMAGEDIR}/debian-contents-sdk-${VERSION}-${ARCH}-${HASH}.tar.gz
PLATFORM_IMAGE=${IMAGEDIR}/debian-contents-platform-${VERSION}-${ARCH}-${HASH}.tar.gz
IMAGES= ${SDK_IMAGE} ${PLATFORM_IMAGE}
REF_PLATFORM=runtime/org.debian.BasePlatform/${ARCH}/${VERSION}
REF_SDK=runtime/org.debian.BaseSdk/${ARCH}/${VERSION}
FILE_REF_PLATFORM=${REPO}/refs/heads/${REF_PLATFORM}
FILE_REF_SDK=${REPO}/refs/heads/${REF_SDK}

all: ${FILE_REF_PLATFORM} ${FILE_REF_SDK}

COMMIT_ARGS=--repo=${REPO} # not supported on Debian 9: --canonical-permissions

${IMAGES} allimages:
	rm -f ${IMAGEDIR}/debian-contents-*.tar.gz # Remove all old images to make space
	mkdir -p build/${ARCH}
	./scripts/package-debian ${srcdir}/ ${builddir}/build/ ${ARCH} ${HASH} ${VERSION}

.PHONY: sdk platform sandboxed export bundles

sdk: ${FILE_REF_SDK}

${FILE_REF_SDK}: metadata.sdk.in ${SDK_IMAGE}
	if [ !  -d ${REPO} ]; then  ostree  init --mode=archive-z2 --repo=${REPO};  fi
	rm -rf sdk
	mkdir sdk
	(cd sdk; tar --transform 's,^./usr,files,S' --transform 's,^./etc,files/etc,S' --exclude="./[!eu]*" -xvf ../${SDK_IMAGE}  > /dev/null)
	cp ${SDK_MANIFEST} sdk/files/manifest.base
	echo "Removing stale python files"
	find sdk -type f -name '*.pyc' -exec sh -c 'test "$$1" -ot "$${1%c}"' -- {} \; -print -delete # Remove stale 2.7 .pyc files
	find sdk -type f -name '*.pyo' -exec sh -c 'test "$$1" -ot "$${1%o}"' -- {} \; -print -delete # Remove stale 2.7 .pyc files
	$(call subst-metadata,metadata.sdk.in,sdk/metadata)
	ostree commit ${COMMIT_ARGS} ${GPG_ARGS} --branch=${REF_SDK}  -s "build of ${HASH}" sdk
	flatpak build-update-repo ${GPG_ARGS} ${REPO}
	rm -rf sdk

platform: ${FILE_REF_PLATFORM}

${FILE_REF_PLATFORM}: metadata.platform.in ${PLATFORM_IMAGE}
	if [ !  -d ${REPO} ]; then  ostree  init --mode=archive-z2 --repo=${REPO};  fi
	rm -rf platform
	mkdir platform
	(cd platform; tar --transform 's,^./usr,files,S' --transform 's,^./etc,files/etc,S' --exclude="./[!eu]*" -xvf ../${PLATFORM_IMAGE}  > /dev/null)
	cp ${PLATFORM_MANIFEST} platform/files/manifest.base
	echo "Removing stale python files"
	find platform -type f -name '*.pyc' -exec sh -c 'test "$$1" -ot "$${1%c}"' -- {} \; -print -delete # Remove stale 2.7 .pyc files
	find platform -type f -name '*.pyo' -exec sh -c 'test "$$1" -ot "$${1%o}"' -- {} \; -print -delete # Remove stale 2.7 .pyc files
	$(call subst-metadata,metadata.platform.in,platform/metadata)
	ostree commit ${COMMIT_ARGS} ${GPG_ARGS} --branch=${REF_PLATFORM}  -s "build of ${HASH}" platform
	flatpak build-update-repo ${GPG_ARGS} ${REPO}
	rm -rf platform

sandboxed:
	flatpak-builder --repo=$(REPO) --force-clean ${GPG_ARGS} app org.debian.Stress.json
	flatpak build-bundle $(REPO) debian-stress.bundle org.debian.Stress master

export: platform sdk
	flatpak build-update-repo $(REPO) ${EXPORT_ARGS} --generate-static-deltas

bundles: export
	flatpak build-bundle --runtime $(REPO) debian-platform.bundle org.debian.BasePlatform $(VERSION)
	flatpak build-bundle --runtime $(REPO) debian-sdk.bundle org.debian.BaseSdk $(VERSION)
