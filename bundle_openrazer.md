# OpenRazer Bundling Plan

## Goal

Make `BUILD_LAPTOP_OPENRAZER=1` work in this image without relying on
`ujust install-openrazer` or any DKMS package path.

## Current State

- `ujust install-openrazer` pulls `openrazer-kernel-modules-dkms`.
- DKMS is incompatible with `rpm-ostree` / `bootc` transactions because its
  `%posttrans` writes to `/var/lib/dkms` while that path is read-only in the
  transaction sandbox.
- The affected deployed image also does not currently ship a matching
  `razerkbd` module for the running kernel.
- The package helper in `build_files/scripts/dnf.sh` excludes all `akmod-*`
  and `kmod-*` packages, so any image-side solution needs a dedicated install
  path rather than the generic guarded helper.
- The old repo hook lived in `build_files/scripts/laptop.sh` and called
  `ujust install-openrazer`. That path is now intentionally disabled.

## Constraints

- Do not use DKMS.
- Keep Bazzite's kernel and graphics stack aligned with the base image.
- Prefer a reproducible image-side install that is verified during the build.
- Avoid silently building an image that advertises OpenRazer support but does
  not actually contain the matching kernel module.
- Support Secure Boot by installing a signed module and documenting the required
  MOK enrollment.

## Full Feature Path

### 1. Remove the old runtime install path permanently

Files:
- `build_files/scripts/laptop.sh`
- `README.md`

Tasks:
- Keep `ujust install-openrazer` out of this repo.
- Replace it with a dedicated image-side installer once the rest of the plan is
  ready.
- Keep the docs explicit that the previous DKMS-based path is unsupported.

Acceptance criteria:
- No build or runtime hook in this repo invokes `ujust install-openrazer`.

### 2. Use a prebuilt, exact-kernel module source

Likely files:
- new `build_files/scripts/openrazer.sh`
- optional repo/source configuration under `build_files/etc/...`

Tasks:
- Copy `openrazer-kmod-common`, `kmod-openrazer`, and
  `ublue-os-akmods-addons` RPMs from the Fedora 44 OGC `common` image published
  by `ublue-os/akmods`. The image is built daily and currently builds OpenRazer
  for this kernel flavor.
- Track the latest Fedora 44 OGC artifact alongside the latest Bazzite base
  image. Force each build to pull both images and reject mismatched kernels.
- Install the UBlue akmods addons RPM with the kmod. It provides the signing
  key and package configuration required by the signed module.
- Fallback option: publish exact, prebuilt and signed `kmod-openrazer` RPMs for
  the same `VERSION-RELEASE.ARCH` as the base image. Do not ship an
  `akmod-openrazer` source package as a fallback: it needs a target-side build.
- Reject an installed DKMS package. A legacy virtual
  `openrazer-kernel-modules-dkms` capability is acceptable only when it is
  provided by the prebuilt OpenRazer kmod package itself.

Acceptance criteria:
- The selected kmod is built for the exact installed `kernel-core`
  `VERSION-RELEASE.ARCH`, not only the same kernel flavor.
- The kmod matches the exact kernel installed by the freshly pulled base image.

### 3. Choose a daemon/userspace source that does not pull DKMS

Likely files:
- new `build_files/scripts/openrazer.sh`
- packaging metadata if RPMs need to be rebuilt or patched

Tasks:
- Install the pinned `openrazer-daemon` RPM from the signed
  `hardware:razer` repository without installing `dkms`.
- The daemon RPM's legacy `openrazer-kernel-modules-dkms` requirement is
  provided by `openrazer-kmod-common`, which in turn requires the prebuilt
  `kmod-openrazer`; verify that package relationship and reject an installed
  `dkms` package.
- Verify the udev rule from `openrazer-kmod-common` and the daemon's user
  service unit.

Acceptance criteria:
- `openrazer-daemon` can be installed in the image build without installing
  `dkms` or a DKMS module package.

### 4. Add a dedicated image-side installer

Files:
- new `build_files/scripts/openrazer.sh`
- `build_files/build.sh` or `build_files/build-system.sh`
- `build_files/scripts/laptop.sh`

Tasks:
- Add an `openrazer.sh` script responsible for:
  - installing the chosen prebuilt kernel module package
  - installing `openrazer-daemon`
- Verify the package-provided udev rule and D-Bus/user-service activation
  paths rather than modifying user accounts or manually enabling a service.
- Keep it behind `BUILD_LAPTOP_OPENRAZER=1`.

Acceptance criteria:
- Setting `BUILD_LAPTOP_OPENRAZER=1` produces an image with both the kernel
  module and daemon path in place.

### 5. Handle the repo's package guard correctly

Files:
- `build_files/scripts/dnf.sh`
- `build_files/scripts/openrazer.sh`

Tasks:
- Do not use `dnf5_guarded()` for OpenRazer kernel packages unless a narrowly
  scoped exception path is added.
- Install exact local RPM paths copied from the current OCI artifact. Limit any
  dependency resolution to the required OpenRazer packages and do not allow it
  to upgrade or replace the base kernel, NVIDIA, Mesa, or DRM packages.
- Keep the generic guard intact for the rest of the image.

Acceptance criteria:
- OpenRazer packages can be installed without accidentally reopening general
  kernel/graphics drift.

### 6. Add build-time verification

Files:
- `build_files/scripts/openrazer.sh`
- optional verification helper script

Tasks:
- Fail the build if OpenRazer is enabled but the module is not present.
- Suggested checks:
  - query the installed `kernel-core` release and use `modinfo -k <release>`
    for `razerkbd`; do not use the container host's `uname -r`
  - confirm the module file is under `/usr/lib/modules/<release>` and owned by
    the selected kmod RPM
  - check `modinfo -F signer` and retain the UBlue signing-key package
  - package presence for the chosen kmod
  - package presence for `openrazer-daemon`

Acceptance criteria:
- A broken OpenRazer image fails during build instead of only on the deployed
  machine.

### 7. Add deployed-image verification steps

Files:
- `README.md`

Tasks:
- Document how to confirm the feature works after deployment:
  - `modinfo razerkbd`
  - `lsmod | grep razer`
   - `systemctl --user status openrazer-daemon`
  - on Secure Boot systems, check `mokutil --sb-state` and verify that the
    signer reported by `modinfo -F signer razerkbd` is enrolled before trying
    to load the module
  - verify device behavior through the daemon/frontend

Acceptance criteria:
- Users can tell whether OpenRazer support is actually working after boot.

### 8. Document version-coupling risk

Files:
- `README.md`

Tasks:
- Record that the OpenRazer kernel module version and daemon version must stay
  compatible.
- Note that newer devices may fail if daemon and kmod support diverge.
- Document the chosen package source and why it was selected.
- Document the latest-tracking OCI artifact tag, its exact-kernel coupling, and
  the build failure expected while upstream images are temporarily out of sync.
- Document the Secure Boot enrollment requirement and recovery steps when a
  module is rejected.

Acceptance criteria:
- Future maintenance of the feature is understandable from repo docs alone.

## Suggested Execution Order

1. Keep the broken DKMS-based path disabled.
2. Pick the non-DKMS kernel module source.
3. Pick the daemon/userspace source.
4. Implement `build_files/scripts/openrazer.sh`.
5. Integrate it behind `BUILD_LAPTOP_OPENRAZER=1`.
6. Add an enabled OpenRazer build variant to CI.
7. Add exact-kernel and signing verification.
8. Add README updates for deployment verification and maintenance notes.

## Recommended Strategy

Implemented:
- Use the latest UBlue OGC artifact for the prebuilt signed modules.
- Install the guarded, version-pinned daemon after the actual kmod package
  satisfies its legacy virtual DKMS capability.
- Build and verify an OpenRazer-enabled CI variant.

Explicit non-goal:
- Do not attempt to rescue the old DKMS path on an immutable system.

## Selected Sources

The UBlue Fedora 44 OGC `common` artifact is the selected primary kmod source.
The selected daemon is `openrazer-daemon` 3.12.4-1.1 from the signed
`hardware:razer` repository. If either source stops carrying compatible
packages, publish and pin replacement prebuilt, signed kmod RPMs rather than
falling back to an akmod or DKMS install.
