#!/bin/bash

apt-get update
apt-get install -qq -y curl gpg apt-utils git sudo wget

# Workaround for OS specific python pip install syntax
source /etc/os-release
if [[ $VERSION_CODENAME = "bookworm" ]] || [[ $VERSION_CODENAME = "some_other" ]]; then
    PIP_OPTIONS="--no-warn-script-location --break-system-packages"
  else
    PIP_OPTIONS="--no-warn-script-location"
fi

#PostgreSQL install
apt-get -y install lsb-release
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    apt-key export ACCC4CF8 | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/greenbone.gpg
apt update
apt-get install -y \
    libglib2.0-dev libgnutls28-dev libpq-dev libical-dev postgresql-15 postgresql-server-dev-15 xsltproc rsync libbsd-dev libgpgme-dev

# Import the Greenbone Community Signing key
curl -f -L https://www.greenbone.net/GBCommunitySigningKey.asc -o /tmp/GBCommunitySigningKey.asc
gpg --import /tmp/GBCommunitySigningKey.asc
echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" | gpg --import-ownertrust

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq 
apt-get upgrade -qq -y
apt-get install --no-install-recommends --assume-yes \
    build-essential curl cmake pkg-config python3 python3-pip gnupg wget sudo gnupg2 ufw htop
    sudo DEBIAN_FRONTEND="noninteractive" apt-get install postfix mailutils -y
    # sudo service postfix restart
    # Fix annoying "error: externally-managed-environment" message error with Python installs
    python_version_dir=$(python3 --version 2>&1 | grep -oP '\d+\.\d+' | head -n 1)
    sudo rm -rf /usr/lib/python${python_version_dir}/EXTERNALLY-MANAGED
    sudo pip3 install --upgrade pip
DEBIAN_FRONTEND="noninteractive" apt-get install -y --assume-yes \
    libglib2.0-dev libgpgme-dev libgnutls28-dev uuid-dev libssh-gcrypt-dev libhiredis-dev libxml2-dev libpcap-dev libnet1-dev \
    libpaho-mqtt-dev libldap2-dev libradcli-dev doxygen xmltoman graphviz libldap2-dev libradcli-dev

# Install optional dependencies for gvmd
apt-get install -y --no-install-recommends \
    texlive-latex-extra texlive-fonts-recommended xmlstarlet zip rpm fakeroot dpkg nsis gnupg gpgsm wget sshpass openssh-client \
    socat snmp python3 smbclient python3-lxml gnutls-bin xml-twig-tools

# gsad deps
apt-get install -y \
    libmicrohttpd-dev libxml2-dev libglib2.0-dev libgnutls28-dev

# openvas-smb deps
apt-get install -y \
    gcc-mingw-w64 libgnutls28-dev libglib2.0-dev libpopt-dev libunistring-dev heimdal-dev perl-base

# openvas-scanner deps
apt-get install -y \
    bison libglib2.0-dev libgnutls28-dev libgcrypt20-dev libpcap-dev libgpgme-dev libksba-dev rsync nmap libjson-glib-dev \
    libbsd-dev python3-impacket libsnmp-dev pandoc pnscan

# ospd-openvas deps
apt-get install -y \
    python3 python3-pip python3-setuptools python3-packaging python3-wrapt python3-cffi python3-psutil python3-lxml \
    python3-defusedxml python3-paramiko python3-redis python3-gnupg python3-paho-mqtt

# notus-scanner deps
apt-get install -y \
    python3 python3-pip python3-setuptools python3-paho-mqtt python3-psutil python3-gnupg

# feed sync
python3 -m pip install ${PIP_OPTIONS} greenbone-feed-sync

# gvm-tools
apt-get install -y \
    python3 python3-pip python3-venv python3-setuptools python3-packaging python3-lxml python3-defusedxml python3-paramiko
python3 -m pip install ${PIP_OPTIONS} gvm-tools