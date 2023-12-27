#!/bin/bash
# Variables in local shell can't be passed through to docker exec commands
# The workaround for this is to generate a temporary script that then deletes itself

read -p "Recipient email address to test the email relay: " TEST_EMAIL
read -p "From address for the sending account: " SMTP_EMAIL
cat <<EOF > ~/test-email-temp.sh
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'echo "This is a test email" | mail -s "SMTP Auth Relay Is Working" ${TEST_EMAIL} -a "FROM:${SMTP_EMAIL}"'
rm ~/test-email-temp.sh
EOF

chmod +x ~/test-email-temp.sh
~/test-email-temp.sh
