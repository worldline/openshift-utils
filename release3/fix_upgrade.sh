#!/bin/bash

yum install -y rubygem-openshift-origin-node \
               rubygem-passenger-native \
               openshift-origin-port-proxy \
               openshift-origin-node-util \
               rubygem-openshift-origin-container-selinux

yum install -y augeas
yum install -y rubygem-openshift-origin-frontend-apache-mod-rewrite.noarch rubygem-openshift-origin-frontend-nodejs-websocket.noarch rubygem-openshift-origin-frontend-apachedb.noarch

service openshift-node-web-proxy enable
service openshift-node-web-proxy start

iptables -N rhc-app-comm
iptables -I INPUT 4 -m tcp -p tcp --dport 35531:65535 -m state --state NEW -j ACCEPT
iptables -I INPUT 5 -j rhc-app-comm
iptables -I OUTPUT 1 -j rhc-app-comm
/sbin/service iptables save

rm -fr /usr/libexec/openshift/cartridges/v2/nodejs

/usr/sbin/oo-admin-cartridge -l |sed 's/(//g' |sed 's/)//g' |sed 's/,//g' | awk '{print "/usr/sbin/oo-admin-cartridge -a erase -n " $2 " -v " $3 " -c " $4 }' |xargs -0 bash -c

/usr/sbin/oo-admin-cartridge --recursive -a install -s /usr/libexec/openshift/cartridges/
/usr/sbin/oo-admin-cartridge --recursive -a install -s /usr/libexec/openshift/cartridges/v2/


lokkit --service=ssh
lokkit --service=https
lokkit --service=http
lokkit --port=8000:tcp
lokkit --port=8443:tcp
chkconfig httpd on
chkconfig network on
chkconfig sshd on
chkconfig oddjobd on
chkconfig openshift-node-web-proxy on


cat <<EOF | augtool
set /files/etc/pam.d/sshd/#comment[.='pam_selinux.so close should be the first session rule'] 'pam_openshift.so close should be the first session rule'
ins 01 before /files/etc/pam.d/sshd/*[argument='close']
set /files/etc/pam.d/sshd/01/type session
set /files/etc/pam.d/sshd/01/control required
set /files/etc/pam.d/sshd/01/module pam_openshift.so
set /files/etc/pam.d/sshd/01/argument close
set /files/etc/pam.d/sshd/01/#comment 'Managed by openshift_origin'

set /files/etc/pam.d/sshd/#comment[.='pam_selinux.so open should only be followed by sessions to be executed in the user context'] 'pam_openshift.so open should only be followed by sessions to be executed in the user context'
ins 02 before /files/etc/pam.d/sshd/*[argument='open']
set /files/etc/pam.d/sshd/02/type session
set /files/etc/pam.d/sshd/02/control required
set /files/etc/pam.d/sshd/02/module pam_openshift.so
set /files/etc/pam.d/sshd/02/argument[1] open
set /files/etc/pam.d/sshd/02/argument[2] env_params
set /files/etc/pam.d/sshd/02/#comment 'Managed by openshift_origin'

rm /files/etc/pam.d/sshd/*[module='pam_selinux.so']

set /files/etc/pam.d/sshd/03/type session
set /files/etc/pam.d/sshd/03/control required
set /files/etc/pam.d/sshd/03/module pam_namespace.so
set /files/etc/pam.d/sshd/03/argument[1] no_unmount_on_close
set /files/etc/pam.d/sshd/03/#comment 'Managed by openshift_origin'

set /files/etc/pam.d/sshd/04/type session
set /files/etc/pam.d/sshd/04/control optional
set /files/etc/pam.d/sshd/04/module pam_cgroup.so
set /files/etc/pam.d/sshd/04/#comment 'Managed by openshift_origin'

set /files/etc/pam.d/runuser/01/type session
set /files/etc/pam.d/runuser/01/control required
set /files/etc/pam.d/runuser/01/module pam_namespace.so
set /files/etc/pam.d/runuser/01/argument[1] no_unmount_on_close
set /files/etc/pam.d/runuser/01/#comment 'Managed by openshift_origin'

set /files/etc/pam.d/runuser-l/01/type session
set /files/etc/pam.d/runuser-l/01/control required
set /files/etc/pam.d/runuser-l/01/module pam_namespace.so
set /files/etc/pam.d/runuser-l/01/argument[1] no_unmount_on_close
set /files/etc/pam.d/runuser-l/01/#comment 'Managed by openshift_origin'

set /files/etc/pam.d/su/01/type session
set /files/etc/pam.d/su/01/control required
set /files/etc/pam.d/su/01/module pam_namespace.so
set /files/etc/pam.d/su/01/argument[1] no_unmount_on_close
set /files/etc/pam.d/su/01/#comment 'Managed by openshift_origin'

set /files/etc/pam.d/system-auth-ac/01/type session
set /files/etc/pam.d/system-auth-ac/01/control required
set /files/etc/pam.d/system-auth-ac/01/module pam_namespace.so
set /files/etc/pam.d/system-auth-ac/01/argument[1] no_unmount_on_close
set /files/etc/pam.d/system-auth-ac/01/#comment 'Managed by openshift_origin'
save
EOF
cat <<EOF > /etc/security/namespace.d/sandbox.conf
# /sandbox        \$HOME/.sandbox/      user:iscript=/usr/sbin/oo-namespace-init       root,adm,apache
EOF

cat <<EOF > /etc/security/namespace.d/tmp.conf
/tmp        \$HOME/.tmp/      user:iscript=/usr/sbin/oo-namespace-init root,adm,apache
EOF

cat <<EOF > /etc/security/namespace.d/vartmp.conf
/var/tmp    \$HOME/.tmp/   user:iscript=/usr/sbin/oo-namespace-init root,adm,apache
EOF

chkconfig cgconfig on
chkconfig cgred on
service cgconfig restart
service cgred restart

sed -i 's#usrjquota=aquota.user,jqfmt=vfsv0#usrquota#g' /etc/fstab

mount -o remount /

ln -s /var/lib/openshift/.httpd.d /etc/httpd/conf.d/openshift
setsebool -P httpd_unified=on httpd_can_network_connect=on httpd_can_network_relay=on \
             httpd_read_user_content=on httpd_enable_homedirs=on httpd_run_stickshift=on \
             allow_polyinstantiation=on httpd_run_stickshift=on httpd_execmem=on
restorecon -rv /var/run
restorecon -rv /var/lib/openshift /etc/openshift/node.conf /etc/httpd/conf.d/openshift

cat <<EOF | augtool
set /files/etc/sysctl.conf/kernel.sem "250  32000 32  4096"
set /files/etc/sysctl.conf/net.ipv4.ip_local_port_range "15000 35530"
set /files/etc/sysctl.conf/net.netfilter.nf_conntrack_max "1048576"
save
EOF

sysctl -p /etc/sysctl.conf

cat <<EOF >> /etc/ssh/sshd_config
AcceptEnv GIT_SSH
EOF

cat <<EOF | augtool
set /files/etc/ssh/sshd_config/MaxSessions 40
save
EOF

chkconfig openshift-tc on

lokkit --port=35531-65535:tcp
chkconfig openshift-port-proxy on
service openshift-port-proxy start

chkconfig openshift-gears on

cat <<EOF >> /etc/openshift/node.conf
EXTERNAL_ETH_DEV="eth0"
EOF


cat <<EOF | augtool
set /files/etc/login.defs/UID_MIN 500
set /files/etc/login.defs/GID_MIN 500
save
EOF

/etc/cron.minutely/openshift-facts

chkconfig haproxy off

set -e

./fix_deployment.sh
./fix_gear_registry.sh
./migrate_port_proxy.sh all
./fix_rewrite.sh
