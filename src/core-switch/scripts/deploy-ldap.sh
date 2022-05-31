#!/usr/bin/bash

set -euo pipefail

OLD_PWD=$(pwd)

echo "ensure ~/ldap-admin-passphrase.txt and ~/ldap-admin-passphrase-verify.txt exist and match"
if [[ ! -f ~/ldap-admin-passphrase.txt ]]; then
  echo "  ie:"
  echo "  $ echo -n \"passphrase\" > ~/ldap-admin-passphrase.txt"
  exit 1
fi
sha256sum ~/ldap-admin-passphrase.txt | sed s/passphrase/passphrase-verify/ | sha256sum -c --quiet

sudo apt-get -y install slapd ldap-utils

ADMIN_PASSPHRASE=$(cat ~/ldap-admin-passphrase.txt)
echo "configuring ldap basedn, users and groups"
sudo ldapadd -x -D cn=admin,dc=homelab -w $ADMIN_PASSPHRASE -f ~/install/ldap/basedn.ldif
sudo ldapadd -x -D cn=admin,dc=homelab -w $ADMIN_PASSPHRASE -f ~/install/ldap/ldap-users.ldif
sudo ldapadd -x -D cn=admin,dc=homelab -w $ADMIN_PASSPHRASE -f ~/install/ldap/ldap-groups.ldif
echo "deleting ~/ldap-admin-passphrase.txt to ensure security"
rm ~/ldap-admin-passphrase.txt ~/ldap-admin-passphrase-verify.txt
echo "generating ldap server key/cert"
echo -n passphrase > passphrase.tmp
sudo openssl genrsa -aes128 -out /etc/ssl/private/ldap_server.key -passout file:passphrase.tmp 4096
sudo openssl rsa -in /etc/ssl/private/ldap_server.key -out /etc/ssl/private/ldap_server.key  -passin file:passphrase.tmp
rm passphrase.tmp
sudo openssl req -new -days 3650 -key /etc/ssl/private/ldap_server.key -out /etc/ssl/private/ldap_server.csr
sudo openssl x509 -in /etc/ssl/private/ldap_server.csr -out /etc/ssl/private/ldap_server.crt -req -signkey /etc/ssl/private/ldap_server.key -days 3650
sudo cp /etc/ssl/private/ldap_server.{key,crt} /etc/ssl/certs/ca-certificates.crt /etc/ldap/sasl2/
sudo chown -R openldap:openldap /etc/ldap/sasl2
echo "installing ldap tls/sasl"
sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f ~/install/ldap/ldapssl.ldif
sudo echo "TLS_REQCERT allow" >> /etc/ldap/ldap.conf
echo "disabling anonymous ldap binding"
sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f ~/install/ldap/disableanonymous.ldif
echo "disabling cleartexty ldap binding"
sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f ~/install/ldap/disablecleartextbind.ldif

echo "restarting slapd"
sudo systemctl restart slapd

cd $OLD_PWD
