#!/bin/bash
read -p "Recipient email address to test the email relay: " TEST_EMAIL
read -p "From address for the sending account: " SMTP_EMAIL
docker exec greenbone-community-edition-gvmd-1 /bin/bash -c 'echo "This is a test email" | mail -s "SMTP Auth Relay Is Working" ${TEST_EMAIL} -a "FROM:${SMTP_EMAIL}"'