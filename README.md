# Overview

debian-sdk-base is a set of build scripts to generate a Debian-based
runtime (and sdk) for Flatpak-enabled Linux distributions. Scripts
were changed from freedesktop-sdk-base to use debootstrap instead of
Yocto to populate the runtime and sdk. The runtime is based on the
minbase variant. The sdk is copy of the runtime with several packages
added.

# Pre-requisites

The runtime and sdk should be built from a Debian 9 host and with the
following packages installed:

   * flatpak
   * flatpak-builder
   * ostree

You will also need sudo access to run debootstrap (called from the
package-debian script).

# Instructions

Run the following commands to build the platform and sdk bundles:

```
make bundles
```

A sample application is provided with this distribution, install
the previously generated bundles and build the application with:

```
flatpak install --user --bundle --runtime debian-platform.bundle
flatpak install --user --bundle --runtime debian-sdk.bundle
make sandboxed
flatpak install --user --bundle debian-stress.bundle
```

You may then run the stress application with:

```
flatpak run org.debian.Stress -c 1
```
