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
 - `BUILD_HYPRLAND=<0|1>` add [hyprland](https://hypr.land/) and some other utils to get my preferred configuration running, default=1
 - `BUILD_LAPTOP=<0|1>` add various features which only makes sense on laptops, default=1
 - `BUILD_LAPTOP_CLAMSHELL=<0|1>` do not suspend when laptop lid is closed in the Plasma Login Manager. Only has an effect if `BUILD_LAPTOP=1`, default=1
 - `BUILD_LAPTOP_OPENRAZER=<0|1>` validate the signed OpenRazer kernel modules supplied by Bazzite and add the userspace daemon. The build fails unless the modules match the base image's exact kernel release, default=1
 - `BUILD_CITRIX=<0|1>` install Citrix Workspace, default=0
 - `BUILD_CITRIX_DEPS_ONLY=<0|1>` install dependencies without installing Citrix Workspace itself. Only has an effect if `BUILD_CITRIX=1`, default=0
 - `BUILD_DOCKER=<0|1>` install Docker, default=1
 - `BUILD_WINE=<0|1>` install Wine, default=1
 - `BUILD_KVM=<0|1>` install KVM, default=1

## Build Locally

In order to debug various issues, `build-local.sh` is setup to build the image
with the published profile: updates and Citrix are disabled; Hyprland, laptop,
OpenRazer, Docker, Wine, and KVM options are enabled. It defaults to
`ghcr.io/ublue-os/bazzite-nvidia-open:stable-44` as the base image.

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

The published image uses the signed OpenRazer kernel modules bundled with
Bazzite and adds an exact-version `openrazer-daemon` from the Terra repository
configured by the base image. The daemon transaction cannot replace the base
image's OpenRazer packages and does not install DKMS. Both components update
when the image is rebuilt and published.

After rebasing, add the desktop user to the group used by the installed udev
rule, then log out and back in or reboot:

```bash
sudo usermod -aG plugdev "$USER"
```

Install the optional Polychromatic frontend:

```bash
flatpak install --user flathub app.polychromatic.controller
```

Opening Polychromatic activates the daemon through the user D-Bus service. It
is normal for `systemctl --user status openrazer-daemon` to show inactive until
a frontend connects; do not manually enable the service.

To start the optional Polychromatic tray applet in Hyprland, add this to the
user's `hyprland.conf`:

```ini
exec-once = flatpak run --command=polychromatic-tray-applet app.polychromatic.controller
```

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

OpenRazer kernel modules are installed alongside the OGC kernel when Bazzite
builds the base image. This image validates every OpenRazer module, its package
ownership, kernel compatibility, signature, udev rules, and daemon activation
files. The build fails rather than publishing an incomplete installation.

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
