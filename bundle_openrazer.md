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

### 2. Choose a non-DKMS kernel module source

Likely files:
- new `build_files/scripts/openrazer.sh`
- optional repo/source configuration under `build_files/etc/...`

Tasks:
- Find or provide a prebuilt OpenRazer kernel module package that matches the
  Bazzite OGC kernel.
- Preferred option: reuse a Bazzite / `ublue-os/akmods` style prebuilt
  `kmod-openrazer` flow if it is still available for the target kernel.
- Fallback option: build or vendor your own `akmod-openrazer` /
  `kmod-openrazer` artifacts for this image.
- Reject any dependency chain that resolves to DKMS.

Acceptance criteria:
- A known package path exists that provides `razerkbd` for the exact kernel
  family this image ships.

### 3. Choose a daemon/userspace source that does not pull DKMS

Likely files:
- new `build_files/scripts/openrazer.sh`
- packaging metadata if RPMs need to be rebuilt or patched

Tasks:
- Install `openrazer-daemon` without pulling
  `openrazer-kernel-modules-dkms`.
- If the upstream daemon RPM hard-requires DKMS, either:
  - rebuild/package a patched daemon RPM with the DKMS dependency removed, or
  - source the daemon from a packaging path that is compatible with immutable
    images.
- Account for any required group, udev, or service setup such as `plugdev`.

Acceptance criteria:
- `openrazer-daemon` can be installed in the image build without any DKMS
  dependency chain.

### 4. Add a dedicated image-side installer

Files:
- new `build_files/scripts/openrazer.sh`
- `build_files/build.sh` or `build_files/build-system.sh`
- `build_files/scripts/laptop.sh`

Tasks:
- Add an `openrazer.sh` script responsible for:
  - installing the chosen prebuilt kernel module package
  - installing `openrazer-daemon`
  - creating or verifying required groups
  - enabling any required service if appropriate
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
- Either:
  - install the chosen kmod package with plain `dnf5` in `openrazer.sh`, or
  - add a dedicated helper that only relaxes the package guard for the specific
    OpenRazer packages.
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
  - `modinfo razerkbd`
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
  - `systemctl status openrazer-daemon`
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

Acceptance criteria:
- Future maintenance of the feature is understandable from repo docs alone.

## Suggested Execution Order

1. Keep the broken DKMS-based path disabled.
2. Pick the non-DKMS kernel module source.
3. Pick the daemon/userspace source.
4. Implement `build_files/scripts/openrazer.sh`.
5. Integrate it behind `BUILD_LAPTOP_OPENRAZER=1`.
6. Add build-time verification.
7. Add README updates for deployment verification and maintenance notes.

## Recommended Strategy

Short term:
- Keep OpenRazer disabled in this repo.

Medium term:
- Implement a full image-side OpenRazer installer using prebuilt kmods plus the
  userspace daemon.

Explicit non-goal:
- Do not attempt to rescue the old DKMS path on an immutable system.

## Decision Still Needed Before Full Implementation

There are two ways to complete the future work:

1. Reuse an existing prebuilt `kmod-openrazer` source compatible with the
   Bazzite OGC kernel.
2. Vendor or rebuild the required OpenRazer kernel-module and daemon RPMs for
   this image if no suitable upstream non-DKMS source exists.

The first option is preferable. If it is not available, the second option is
the realistic path to shipping the feature in this repo.
