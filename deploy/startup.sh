#!/bin/sh

DOMAIN=go-beyond.org
HOSTMASTER=sega01

progress() {
	EPOCH=$(date +%s)
	echo "deploy: $EPOCH: $*" > /dev/console
	echo "deploy: $EPOCH: $*"
}

# This runs at the top of cloud-init. We don't even have SSHD running without
# this.

export ASSUME_ALWAYS_YES=yes

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

# FreeBSD upgrades..
freebsd-update fetch --not-running-from-cron
freebsd-update install --not-running-from-cron

progress 'Starting pkg upgrade'
pkg upgrade

progress 'Starting pkg install'
pkg install ca_root_nss thttpd gdnsd2 pwgen tor rsync py27-pip git
chmod 700 /root

# Random root password, resetting what vultr set.
pwgen -s 20 1 | pw user mod root -h 0 -s /bin/sh

IP4=$(ifconfig vtnet0 | grep 'inet ' | awk '{print $2}')
IP6=$(ifconfig vtnet0 | grep inet6 | grep -v 'inet6 fe80' | awk '{print $2}')

echo "\$ORIGIN $DOMAIN.
\$TTL 300

@       SOA     $DOMAIN. $HOSTMASTER.$DOMAIN. (
                1337
                300
                300
                300
                300 )

        NS      $DOMAIN.
        MX      10 mx.mythic-beasts.com.
        TXT     \"v=spf1 include:_spf.mythic-beasts.com -all\"
        AAAA    $IP6
        A       $IP4
www     CNAME   $DOMAIN.
" > /usr/local/etc/gdnsd/zones/$DOMAIN


mkdir /var/tmp/deploy

progress 'Putting updater in cron'

echo '#!/bin/sh

set -e

rm -rf /var/tmp/predeploy || true
mkdir /var/tmp/predeploy

# rsync is atomic per-file but tar is not, so we do this.
# Only rsync if at least tar exited cleanly.
TEMP=/tmp/tar.gz
REPO=https://github.com/teran-mckinney/teran-mckinney.github.io/archive/master.tar.gz
STRIPCOMPONENTS=1
fetch -qo $TEMP $REPO
tar xzf $TEMP -C /var/tmp/predeploy --strip-components $STRIPCOMPONENTS
rm $TEMP

rsync --delete-after -r /var/tmp/predeploy/ /var/tmp/deploy/
' > /root/updater

chmod 700 /root/updater
/root/updater

echo "SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
STRIPCOMPONENTS=1

*/5 * * * * /root/updater" > /root/cron

crontab /root/cron

echo '#!/bin/sh

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
export HOME=/root

thttpd -r -d /var/tmp/deploy -p 80' > /etc/rc.local

# We start the dns server down here because DNS being up
# might signal the server as ready, and it really only is
# if at least the content and webserver are there first.
# This is probably overkill.
#FIXME: disable gdnsd port 3506 service, maybe? Or use simpler DNS server.
echo 'gdnsd_enable="YES"' >> /etc/rc.conf
# Doesn't seem to start otherwise.
service gdnsd start

# Don't let syslogd listen for security reasons.
echo 'syslogd_flags="-ss"' >> /etc/rc.conf

service syslogd restart

## Tor

# This is for hidden services that aren't so hidden...

mkdir -p /usr/local/etc/tor/hidden_service/
chmod 700 /usr/local/etc/tor/hidden_service/

# HiddenServicePort 80 [::1]:80 didn't seem to work?
# https://bugs.torproject.org/18357 ^
# Should be fixed now.
echo 'HiddenServiceDir /usr/local/etc/tor/hidden_service/
HiddenServicePort 80 127.0.0.1:80' > /usr/local/etc/tor/torrc

chmod 500 /etc/rc.local

echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDTk8+TAjM63utj5APw9B9KVwd//MWMez90glb1Q4IV7M56Odcuqb93egFw/K4Oe5gQEQd8kGugAq/IubQFnHeUn9TMMnTs5v0G6emFXqQHChwUvS7XGq2R7cIgkMoYJW2EM4anFtkIE/dX3oPKugb885FoCl61hAQSjmZtIZRdgfAfP3D34QqUqgF2snVZOj+ADWESoW+nb9En91ywDDyjJ9le+3y0ZYKWG6Wmp3HdP+cRbcbxGwrCCvrpYbtmGetKgPguhs8myjQv8Js1cIwDjb6VKFyoSoRarjmiUrG5Ij/mIfVQEzPKaTiBju1hsIpmHm7OaS4DQWGvERByGOZh
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCiYjZwP8fIYenOZj2IrM4ikDFlsLyB8iWX1SgHmZoF4sF/VvjwqfzfqTM0e21bWmg7MWSbG6fXvMOrv+uDXrHv2QO9nzgDEM9bDc+YviOF350P8qgcl8WKpbDiFBKRQM92w14vPznRmCIYC0xmiIx67su/5rBPhdrt03chKt9++o0zYv/SJBUKugbuC86xSVoYSfk24Pn779DB055KzmlS9bxrRy287lmKmBDxBU+PWbF5b6SOHwOuJJZM9fwZLDPDJ09BEIvF80aYeGHZtfRxW3aQioIArCBAQCWSp4vsAvD9FgQHDrJTqYrKs4yqw5lvwgk3XlDv0SHuC1qCfiiV' > /root/.ssh/authorized_keys

echo '#!/bin/sh
# Self audit script

set -e

# Test DNS
host go-beyond.org 127.0.0.1 | grep "has address"
host go-beyond.org 127.0.0.1 | grep "has IPv6 address"

# Force update.
/root/updater

# Test HTTP
fetch -o - http://127.0.0.1/ | grep Go\ Beyond

' > /root/audit.sh; chmod 500 /root/audit.sh
