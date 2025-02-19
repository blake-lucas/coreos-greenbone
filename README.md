# CoreOS-Greenbone

[![build-coreos](https://github.com/blake-lucas/coreos-greenbone/actions/workflows/build.yml/badge.svg)](https://github.com/blake-lucas/coreos-greenbone/actions/workflows/build.yml)

## What is this?

This is a [Fedora CoreOS](https://getfedora.org/coreos/) image that is preconfigured to pull down and start Greenbone Community Edition via their container images.

## How to Install

### Prerequsites

This image is not currently available for direct install. You will need to download the latest stable [CoreOS ISO](https://fedoraproject.org/coreos/download/?stream=stable) and run the coreos-installer CLI utility.

Hardware/VM requirements are the same as Greenbone's recommendations [here](https://greenbone.github.io/docs/latest/22.4/source-build/index.html#hardware-requirements)

All CoreOS installation methods require the user to [produce an Ignition file](https://docs.fedoraproject.org/en-US/fedora-coreos/producing-ign/). This Ignition file should, at mimimum, set a password and SSH key for the default user (default username is `core`). This repo contains an ignition file that can be used as a template. Feel free to copy it, update the password hash, and host it on your own web server/repo. If you are fine updating the password yourself after each install, then you can skip to step 5 and use the provided coreos-installer command.

### Installation with ignition file

1. If you would like to customize the default password, feel free to use [fedora-coreos/autorebase.bu](fedora-coreos/autorebase.bu) as the starting point for your CoreOS ignition file.
2. The only item you are required to change is the default username/password. This can be done using the CoreOS mkpasswd tool:

```bash
podman run -ti --rm quay.io/coreos/mkpasswd --method=yescrypt
```

3. Once you have your finished Butane file, you'll need to use Butane to create the ignition file from it. This can be done with:

```bash
podman run --interactive --rm quay.io/coreos/butane:release --pretty --strict < butane-file.bu > ignition-file.ign
```

4. This ignition file will need to be stored on a web server somewhere for CoreOS to download. Either upload it to your own repo/webserver or other means of retrieving the file during install.
5. Once the ignition file has been created and is available online, we can run the CoreOS install itself. Boot the [latest stable ISO.](https://fedoraproject.org/coreos/download/?stream=stable) and run the coreos-installer utility. In this example I'll use the public ignition example:

```bash
sudo coreos-installer install /dev/sda --ignition-url https://raw.githubusercontent.com/blake-lucas/coreos-greenbone/main/fedora-coreos/autorebase.ign && reboot
```

6. Once the install is finished, the system should reboot once, rebase to the coreos-greenbone OCI image, reboot again, then pull the Greenbone containers and start them.
7. The default username for this ignition file is core, and the default password is 1changethis2. Once the 2 reboots have finished, login and update the password to something else. If you are planning on deploying this image a lot, create your own ignition file with the credentials you need.
8. The Greenbone containers are controlled by a custom service unit "greenbone.service". You can check the status of the containers with:
```bash
systemctl status greenbone.service
```
8. Once all the containers have been downloaded and are starting, a message will be sent to the TTY for confirmation. After a few seconds Greenbone should be accessible at the default port of 9392. CoreOS will list the IP it DHCPs to the TTY.
9. If a static IP address is needed, login and run "set-ip" to trigger a script to manually enter IP info. Note that with the set-ip script, both the old DHCP IP and the static address you set will be accessible until after a reboot.
10. If email reporting is needed, run "add-365-email" to add support for emailing from a Microsoft 365 account to the GVMD container. Once configured, you can test sending from the account with "test-email".
11. Greenbone's default login is admin:admin. Make sure to change this.
12. For easier management, password based SSH authentication is enabled on this image. Be sure to set a good password!

## Verification

These images are signed with sigstore's [cosign](https://docs.sigstore.dev/cosign/overview/). You can verify the signature by downloading the `cosign.pub` key from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/blake-lucas/coreos-greenbone
```
