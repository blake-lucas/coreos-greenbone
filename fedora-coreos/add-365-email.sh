#!/bin/bash
# This script will create another storing the email credentials under /var/local/365-email-setup-creds
# Each time greenbone.service is started, /var/local/365-email-setup-creds will be called to ensure the gvmd container is setup with the postfix relay
# This is to make sure updates to the gvmd container upstream don't break the postfix config
# Yeah this is not the best solution I know

clear
# Get the Office365 smtp authentication credentials
echo
read -p "Enter M365 SMTP auth enabled email: " SMTP_EMAIL
echo
read -s -p "Enter the 365 account's app password: " APP_PWD
echo
sudo cat <<EOF > ~/365-email-setup-creds
#!/bin/bash
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c "apt-get update"
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'DEBIAN_FRONTEND="noninteractive" apt-get install postfix -y'
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c "apt-get install nano nsis libsasl2-modules mailutils -y"
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c "service postfix restart"
# Remove some default Postfix config items that conflict with new entries
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'sed -i "/relayhost/d" /etc/postfix/main.cf'
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'sed -i "/smtp_tls_security_level=may/d" /etc/postfix/main.cf'
# For simple relay outbound only, limit Postfix to just loopback and IPv4
#docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'sed -i "s/inet_interfaces = all/inet_interfaces = loopback-only/g" /etc/postfix/main.cf'
#docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'sed -i "s/inet_protocols = all/inet_protocols = ipv4/g" /etc/postfix/main.cf'
# Add the new Office365 SMTP auth with TLS settings
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'cat <<EOF | tee -a /etc/postfix/main.cf
relayhost = [smtp.office365.com]:587
smtp_use_tls = yes
smtp_always_send_ehlo = yes
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_sasl_tls_security_options = noanonymous
smtp_tls_security_level = encrypt
smtp_generic_maps = hash:/etc/postfix/generic
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
EOF'

# Setup the password file and postmap
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'touch /etc/postfix/sasl_passwd'
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'cat <<EOF | tee -a /etc/postfix/sasl_passwd
[smtp.office365.com]:587 ${SMTP_EMAIL}:${APP_PWD}
EOF'

docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'chown root:root /etc/postfix/sasl_passwd'
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'chmod 0600 /etc/postfix/sasl_passwd'
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'postmap /etc/postfix/sasl_passwd'

# Setup the generic map file
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'touch /etc/postfix/generic'
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'cat <<EOF | tee -a /etc/postfix/generic
root@localhost ${SMTP_EMAIL}
@${DOMAIN_SEARCH_SUFFIX} ${SMTP_EMAIL}
EOF'
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'chown root:root /etc/postfix/generic'
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'chmod 0600 /etc/postfix/generic'
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'postmap /etc/postfix/generic'

echo "Email has been configured. You can send a test message using: test-email"
EOF

sudo mv ~/365-email-setup-creds /var/local/365-email-setup-creds
sudo chmod +x /var/local/365-email-setup-creds
sudo bash /var/local/365-email-setup-creds