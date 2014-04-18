#!/bin/bash

ln -s /etc/mcollective/client.cfg /opt/rh/ruby193/root/etc/mcollective/client.cfg
oo-mco find -A openshift

echo "fix rest_url in /opt/rh/ruby193/root/usr/share/gems/gems/openshift-origin-controller-1.18.0.1/lib/openshift/controller/api_behavior.rb"
#  def get_url
#    "https://apps.zone52.org/broker/rest/"
#  end

sed -i 's/AUTH_PRIVKEYFILE/AUTH_PRIV_KEY_FILE/g' /etc/openshift/broker.conf
sed -i 's/AUTH_PRIVKEYPASS/AUTH_PRIV_KEY_PASS/g' /etc/openshift/broker.conf
sed -i 's/AUTH_PUBKEYFILE/AUTH_PUB_KEY_FILE/g' /etc/openshift/broker.conf
sed -i 's/AUTH_RSYNCKEYFILE/AUTH_RSYNC_KEY_FILE/g' /etc/openshift/broker.conf


echo "Add proxy env var in /etc/init.d/openshift-broker"
