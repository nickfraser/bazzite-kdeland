# Custom Bazzite Image with KDE Plasma & Hyprland

This repository contains a set of scripts to install all the prerequisites for a custom [bazzite](https://bazzite.gg/) image to run on my Razer Blade 14 laptop. It targets the `bazzite-nvidia-open` base image and includes laptop-specific configuration for a hybrid AMD/NVIDIA system.
It's organised in a configurable way so that it should be simple to modify it to create your own image.

This repository is not meant to create some new "base" image that others should build upon.
Instead, if you want to customize this build, I suggest you fork this repo and make the necessary changes.
Otherwise, please see the excellent [upstream repo](https://github.com/ublue-os/image-template) if you want to create your own custom bazzite image.

## Use This Image

The recommended way to install this image is to rebase from another [Fedora Atomic](https://fedoraproject.org/atomic-desktops/) installation (e.g., bazzite KDE).
This can be done as follows (sources:
[1](https://bazzite.gg/#image-picker),
[2](https://docs.bazzite.gg/Installing_and_Managing_Software/Updates_Rollbacks_and_Rebasing/rebase_guide/)):

```bash
sudo rpm-ostree reset
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/nickfraser/bazzite-kdeland-razer:latest
# Reboot
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/nickfraser/bazzite-kdeland-razer:latest # Only works if you get the cosign to work?
ujust _install-system-flatpaks # Optional, but recommended
# Reboot
```

After installation, update with:

```bash
ujust update
```

## Environment Variables

In order to control what packages are installed you can modify the following variables. The defaults below match the published workflow and `build-local.sh`.

 - `BUILD_FROM_IMAGE=<base_image>` the base image, default: `ghcr.io/ublue-os/bazzite-nvidia-open:stable-44`
 - `BUILD_UPDATE=<0|1>` update Fedora packages in the base image before installing anything else while keeping Bazzite's kernel and graphics stack on the base-image versions, default=0
 - `BUILD_SHELL=<0|1>` add various commandline utilities, default=1
 - `BUILD_HYPRLAND=<0|1>` add [hyprland](https://hypr.land/) and some other utils to get my preferred configuration running, default=1
 - `BUILD_LAPTOP=<0|1>` add various features which only makes sense on laptops, default=1
 - `BUILD_LAPTOP_CLAMSHELL=<0|1>` do not suspend when laptop lid is closed in the Plasma Login Manager. Only has an effect if `BUILD_LAPTOP=1`, default=1
 - `BUILD_LAPTOP_OPENRAZER=<0|1>` bundle the signed OpenRazer kernel module and daemon. It tracks the latest OGC akmods artifact and fails the build unless it matches the base image's exact kernel release, default=0
 - `BUILD_CITRIX=<0|1>` install Citrix Workspace, default=0
 - `BUILD_CITRIX_DEPS_ONLY=<0|1>` install dependencies without installing Citrix Workspace itself. Only has an effect if `BUILD_CITRIX=1`, default=0
 - `BUILD_DOCKER=<0|1>` install Docker, default=1
 - `BUILD_WINE=<0|1>` install Wine, default=1
 - `BUILD_KVM=<0|1>` install KVM, default=1

## Build Locally

In order to debug various issues, `build-local.sh` is setup to build the image
with the published profile: updates, Citrix, and OpenRazer are disabled; the
shell, Hyprland, laptop, Docker, Wine, and KVM options are enabled. It defaults
to `ghcr.io/ublue-os/bazzite-nvidia-open:stable-44` as the base image.

## build.sh

The [build.sh](./build_files/build.sh) file is called from your Containerfile.
It is the entry-point for installing all other applications.

## User-Home Integration

The image supplies packages and system configuration, but it does not modify a
specific user's home directory. The opt-in files under
[`user_home/`](./user_home) provide the Hyprland integration required for KDE
apps, XDG Desktop Portals, and graphical polkit prompts.

After installing or rebasing to the image, install those files for the current
user and add the source directive to the user's Hyprland configuration:

```bash
cp -a user_home/. "$HOME/"
systemctl --user daemon-reload
```

```ini
source = ~/.config/hypr/bazzite-kdeland.conf
```

Log out and back in to Hyprland after adding the directive. The module starts
the Plasma polkit agent and imports the graphical-session environment before
restarting `xdg-desktop-portal`. The portal user unit is a full replacement
because systemd dependency directives cannot be cleared in a drop-in.

The template intentionally does not include personal Hyprland settings such
as monitor layout, key bindings, themes, application launchers, or hardware
scripts.

## build.yml

The [build.yml](./.github/workflows/build.yml) is configured to build the image with the [defaults specified](#environment-variables), including the `ghcr.io/ublue-os/bazzite-nvidia-open:stable-44` base image, and publishes it to the Github Container Registry (GHCR).

## Post-Installation Steps

I still need to install:

  - [ ] Citrix (rebuild with `BUILD_CITRIX=1`)

### OpenRazer

Set `BUILD_LAPTOP=1` and `BUILD_LAPTOP_OPENRAZER=1` to include OpenRazer. The
image uses the latest Fedora 44 OGC `ublue-os/akmods` artifact for prebuilt,
signed modules and installs `openrazer-daemon` 3.12.4-1.1. It does not install
DKMS.

After reboot, verify the deployed image with:

```bash
kernel_release=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)
modinfo -k "$kernel_release" razerkbd
lsmod | grep razer
systemctl --user status openrazer-daemon
```

On Secure Boot systems, enroll the UBlue akmods key before loading the module,
then reboot and complete enrollment in MokManager:

```bash
sudo mokutil --import /etc/pki/akmods/certs/akmods-ublue.der
mokutil --sb-state
modinfo -F signer razerkbd
```

The kmod artifact is coupled to the exact Bazzite OGC kernel release. Both the
base image and akmods image are refreshed for every build; the build fails if
their kernel releases differ.

## TODO:

Some outstanding items:
 - [ ] Revisit OpenRazer image-side packaging if the latest Bazzite and akmods images repeatedly drift; see [bundle_openrazer.md](./bundle_openrazer.md)
 - [x] Add option to install Citrix dependencies only
 - [x] Consider installing `hyprland` from COPR repositories, see [this example](https://github.com/gabeklavans/bazzite-hyprland/blob/8b94252b52317ba45f834b70d2abfba1ab4d4b15/build_files/build.sh#L15-L30)
 - [ ] `grimshot` (`hyprland`) installs `sway` as a dependency, consider alternative (flameshot?)
 - [x] "Idle" state missing from `hyprland` install (install `hypridle` and/or `hyprlock`? COPR Repos?)
   - `hypridle` is now installed from the ashbuk/Hyprland-Fedora COPR; `hyprlock` is not available in that COPR, but `swaylock` is already installed for locking.
 - [x] `docker` installation
 - [x] Consider install all `libvirt` tools via the commandline, instead of some with `ujust` post-installation
 - [x] Install wine natively
 - [ ] Install `gparted` on image
 - [ ] Re-check whether the current portal workaround can be replaced later with cleaner session integration (`graphical-session.target` / UWSM).
 - [ ] Re-test `KWIN_FORCE_SW_CURSOR=1` after Plasma Login Manager, KWin, NVIDIA driver, or base-image updates; scope or remove it if upstream resolves the cursor handoff issue.
 - [ ] Test `KWIN_DRM_DEVICES=/dev/dri/card1:/dev/dri/card0` only as a fallback if the software-cursor workaround regresses.
 - [ ] Evaluate a dedicated systemd user target for `plasma-polkit-agent.service` instead of the current Hyprland `exec-once` startup.

## Acknowledgements

 - [bootc](https://github.com/bootc-dev/bootc) - the underlying technology
 - [bazzite](https://bazzite.gg/) - the base image
 - bazzite's [image-template](https://github.com/ublue-os/image-template) - the excellent upstream that allowed me to put together a PoC in an afternoon
 - [bazzite-dx](https://github.com/ublue-os/bazzite-dx) - the developer image that shows how to get docker/virtualization installed.

## Community Examples

These are images derived from this template (or similar enough to this template). Reference them when building your image!

- [m2Giles' OS](https://github.com/m2giles/m2os)
- [bOS](https://github.com/bsherman/bos)
- [Homer](https://github.com/bketelsen/homer/)
- [Amy OS](https://github.com/astrovm/amyos)
- [VeneOS](https://github.com/Venefilyn/veneos)
