#!/bin/bash
#######################################################################################################################
# Greenbone Vulnerability Manager install script
# For Fedora CoreOS
# Blake Lucas
# October 2023
#######################################################################################################################

# Exit on error
set -ouex pipefail

# Select GVM install versions           (check below links for latest release versions)
export GVM_LIBS_VERSION=22.7.1          # https://github.com/greenbone/gvm-libs
export GVMD_VERSION=22.9.0              # https://github.com/greenbone/gvmd
export PG_GVM_VERSION=22.6.1            # https://github.com/greenbone/pg-gvm
export GSA_VERSION=22.7.0               # https://github.com/greenbone/gsa
export GSAD_VERSION=22.6.0              # https://github.com/greenbone/gsad
export OPENVAS_SMB_VERSION=22.5.3       # https://github.com/greenbone/openvas-smb
export OPENVAS_SCANNER_VERSION=22.7.5   # https://github.com/greenbone/openvas-scanner
export OSPD_OPENVAS_VERSION=22.6.0      # https://github.com/greenbone/ospd-openvas
export NOTUS_VERSION=22.6.0             # https://github.com/greenbone/notus-scanner

# Set global variables and paths
export INSTALL_PREFIX=/usr/local
export PATH=$PATH:$INSTALL_PREFIX/sbin
export SOURCE_DIR=/tmp/greenbone/source
export INSTALL_DIR=/tmp/install
export BUILD_DIR=$HOME/build

# Copy built files to root fs
rsync -Lav --exclude "sbin" /tmp/greenbone/install/gsad/* /
rsync -Lav --exclude "sbin" /tmp/greenbone/install/gvmd/* /
rsync -Lav --exclude "sbin" /tmp/greenbone/install/openvas-scanner/* /
cp -v /tmp/greenbone/install/gsad/usr/local/sbin/gsad /usr/bin/gsad
cp -v /tmp/greenbone/install/gvmd/usr/local/sbin/gvmd /usr/bin/gvmd
cp -v /tmp/greenbone/install/gsad/usr/local/sbin/openvas-scanner /usr/bin/openvas

which gsad
which gvmd
which openvas

rsync -av /tmp/greenbone/install/openvas-smb/* /
rsync -av /tmp/greenbone/install/gvm-libs/* /
rsync -av /tmp/greenbone/install/pg-gvm/* /

ls -la /tmp/greenbone/install/
ls -la /tmp/greenbone/install/gvmd/usr/local/sbin

sleep 30

# Create gvm user
useradd -r -M -U -G sudo -s /usr/sbin/nologin gvm

# Create gvmd service unit
cat <<EOF >/etc/systemd/system/gvmd.service
[Unit]
Description=Greenbone Vulnerability Manager daemon (gvmd)
After=network.target networking.service postgresql.service ospd-openvas.service
Wants=postgresql.service ospd-openvas.service
Documentation=man:gvmd(8)
ConditionKernelCommandLine=!recovery

[Service]
Type=exec
User=gvm
Group=gvm
PIDFile=/run/gvmd/gvmd.pid
RuntimeDirectory=gvmd
RuntimeDirectoryMode=2775
ExecStart=/usr/local/sbin/gvmd --foreground --osp-vt-update=/run/ospd/ospd-openvas.sock --listen-group=gvm
Restart=always
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create gsad service unit
cat <<EOF >/etc/systemd/system/gsad.service
[Unit]
Description=Greenbone Security Assistant daemon (gsad)
Documentation=man:gsad(8) https://www.greenbone.net
After=network.target gvmd.service
Wants=gvmd.service

[Service]
Type=exec
User=gvm
Group=gvm
RuntimeDirectory=gsad
RuntimeDirectoryMode=2775
PIDFile=/run/gsad/gsad.pid
ExecStart=/usr/local/sbin/gsad --foreground --listen=127.0.0.1 --port=9392 --http-only
Restart=always
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
Alias=greenbone-security-assistant.service
EOF

# Create ospd-openvas service unit
cat <<EOF >/etc/systemd/system/ospd-openvas.service
[Unit]
Description=OSPd Wrapper for the OpenVAS Scanner (ospd-openvas)
Documentation=man:ospd-openvas(8) man:openvas(8)
After=network.target networking.service redis-server@openvas.service mosquitto.service
Wants=redis-server@openvas.service mosquitto.service notus-scanner.service
ConditionKernelCommandLine=!recovery

[Service]
Type=exec
User=gvm
Group=gvm
RuntimeDirectory=ospd
RuntimeDirectoryMode=2775
PIDFile=/run/ospd/ospd-openvas.pid
ExecStart=/usr/local/bin/ospd-openvas --foreground --unix-socket /run/ospd/ospd-openvas.sock --pid-file /run/ospd/ospd-openvas.pid --log-file /var/log/gvm/ospd-openvas.log --lock-file-dir /var/lib/openvas --socket-mode 0o770 --mqtt-broker-address localhost --mqtt-broker-port 1883 --notus-feed-dir /var/lib/notus/advisories
SuccessExitStatus=SIGKILL
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

# Create notus-scanner service units
cat <<EOF >/etc/systemd/system/notus-scanner.service
[Unit]
Description=Notus Scanner
Documentation=https://github.com/greenbone/notus-scanner
After=mosquitto.service
Wants=mosquitto.service
ConditionKernelCommandLine=!recovery

[Service]
Type=exec
User=gvm
RuntimeDirectory=notus-scanner
RuntimeDirectoryMode=2775
PIDFile=/run/notus-scanner/notus-scanner.pid
ExecStart=/usr/local/bin/notus-scanner --foreground --products-directory /var/lib/notus/products --log-file /var/log/gvm/notus-scanner.log
SuccessExitStatus=SIGKILL
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

# systemctl daemon-reload
systemctl enable gsad gvmd ospd-openvas notus-scanner

echo -e "Setting up redis"

ls -la /etc/selinux/targeted/active


# selinux stuff doesn't seem to fully work with OCI images
# setenforce 0 >/dev/null

# semanage fcontext -a -f a -t redis_var_run_t -r s0 '/var/run/redis-openvas(/.*)?'

# sh -c 'cat << EOF > /etc/tmpfiles.d/redis-openvas.conf
# d       /var/lib/redis/openvas   0750 redis redis - -
# z       /var/lib/redis/openvas   0750 redis redis - -
# d       /run/redis-openvas       0750 redis redis - -
# z       /run/redis-openvas       0750 redis redis - -
# EOF'

# systemd-tmpfiles --create

sh -c 'cat << EOF > /etc/systemd/system/redis-server@.service
[Unit]
Description=Redis persistent key-value database
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=/var/lib/redis/%i
ExecStart=/usr/bin/redis-server /etc/redis/redis-%i.conf --daemonize no --supervised systemd
ExecStop=/usr/libexec/redis-shutdown
Type=notify
User=redis
Group=redis
RuntimeDirectory=%i
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOF'

sudo cp $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION/config/redis-openvas.conf /etc/redis/
sudo chown redis:redis /etc/redis/redis-openvas.conf
echo "db_address = /run/redis-openvas/redis.sock" | sudo tee -a /etc/openvas/openvas.conf
# sudo systemctl daemon-reload
# sudo systemctl start redis-server@openvas.service
sudo systemctl enable redis-server@openvas.service
sudo usermod -aG redis gvm

echo -e "#############################################################################"
echo -e " Setting up the postgres db, gvm permissions & update feed digital signature."
echo -e "#############################################################################"

which gvmd
sleep 30

# Set directory permissions
sudo mkdir -p /var/lib/notus
sudo mkdir -p /run/gvmd
sudo mkdir -p /var/lib/gvm
sudo mkdir -p /var/lib/openvas
sudo mkdir -p /var/lib/notus
sudo mkdir -p /var/log/gvm
sudo chown -R gvm:gvm /var/lib/gvm
sudo chown -R gvm:gvm /var/lib/openvas
sudo chown -R gvm:gvm /var/lib/notus
sudo chown -R gvm:gvm /var/log/gvm
sudo chown -R gvm:gvm /run/gvmd
sudo chmod -R g+srw /var/lib/gvm
sudo chmod -R g+srw /var/lib/openvas
sudo chmod -R g+srw /var/log/gvm
sudo chown gvm:gvm /usr/local/sbin/gvmd
sudo chmod 6750 /usr/local/sbin/gvmd

# Feed validation
curl -f -L https://www.greenbone.net/GBCommunitySigningKey.asc -o /tmp/GBCommunitySigningKey.asc
export GNUPGHOME=/tmp/openvas-gnupg
mkdir -p $GNUPGHOME
gpg --homedir /tmp/openvas-gnupg --import /tmp/GBCommunitySigningKey.asc
echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" | gpg --homedir /tmp/openvas-gnupg --import-ownertrust
export OPENVAS_GNUPG_HOME=/etc/openvas/gnupg
sudo mkdir -p $OPENVAS_GNUPG_HOME
sudo cp -r /tmp/openvas-gnupg/* $OPENVAS_GNUPG_HOME/
sudo chown -R gvm:gvm $OPENVAS_GNUPG_HOME

# Set sudo permissions for scanner #####################################################
sudo sh -c "echo '%gvm ALL = NOPASSWD: /usr/local/sbin/openvas' >> /etc/sudoers"

# # Set up PostgreSQL user and database ##################################################
# sudo -Hiu postgres createuser -DRS gvm
# sudo -Hiu postgres createdb -O gvm gvmd
# sudo -Hiu postgres psql gvmd -c "create role dba with superuser noinherit; grant dba to gvm;"
# sudo ldconfig

# Install greenbone-feed-sync and update feed
PIP_OPTIONS="--no-warn-script-location --prefix=/usr"
python3 -m pip install ${PIP_OPTIONS} greenbone-feed-sync 
/usr/bin/greenbone-feed-sync greenbone-feed-sync

echo -e "Installation finished"