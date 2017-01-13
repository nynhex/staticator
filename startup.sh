#!/bin/sh

DOMAIN=go-beyond.org
HOSTMASTER=sega01
REPO=https://github.com/teran-mckinney/teran-mckinney.github.io/archive/master.tar.gz
STRIPCOMPONENTS=1

progress() {
	EPOCH=$(date +%s)
	echo "deploy: $EPOCH: $*" > /dev/console
	echo "deploy: $EPOCH: $*"
}

progress 'Getting IPv6 address'

# This is rather ugly, I'm sorry. For turning on IPv6 when we don't have it yet.
ifconfig vtnet0 inet6 auto_linklocal
ifconfig vtnet0 inet6 accept_rtadv
ifconfig vtnet0 inet6 -ifdisabled

service rtsold start
rtsold -fd1 vtnet0
sleep 10
rtsold -fd1 vtnet0

# This runs at the top of cloud-init. We don't even have SSHD running without
# this.

export ASSUME_ALWAYS_YES=yes

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

# pkg isn't installed by default on vultr, but this will bootstrap it
# with the above option of ASSUME_ALWAYS_YES=yes

progress 'Starting freebsd-update'

sed -i '' '/sleep/d' "$(which freebsd-update)" # Don't sleep.
freebsd-update cron && freebsd-update instal

progress 'Starting pkg upgrade'
pkg upgrade

progress 'Starting pkg install'
pkg install ca_root_nss thttpd gdnsd2 pwgen tor rsync
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
        TXT     "v=spf1 include:_spf.mythic-beasts.com -all"
        AAAA    $IP6
        A       $IP4
www     CNAME   $DOMAIN.
" > /usr/local/etc/gdnsd/zones/$DOMAIN


mkdir /var/tmp/deploy

progress 'Putting updater in cron'

echo "#!/bin/sh

set -e

rm -rf /var/tmp/predeploy || true
mkdir /var/tmp/predeploy

# rsync is atomic per-file but tar is not, so we do this.
# Only rsync if at least tar exited cleanly.
TEMP=/tmp/tar.gz
fetch -qo $TEMP $REPO
tar xzf $TEMP -C /var/tmp/predeploy --strip-components $STRIPCOMPONENTS
rm $TEMP

rsync --delete-after -r /var/tmp/predeploy/ /var/tmp/deploy/
" > /root/updater

chmod 700 /root/updater
/root/updater

echo "SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

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

echo 'ntpd_enable="YES"' >> /etc/rc.conf
service ntpd start
# Don't let syslogd listen for security reasons.
echo 'syslogd_flags="-ss"' >> /etc/rc.conf

service syslogd restart

## Tor

# This is for hidden services that aren't so hidden...

mkdir /var/run/tor
mkdir -p /usr/local/etc/tor/hidden_service/
chmod 700 /usr/local/etc/tor/hidden_service/

if [ -n "$IP6" ]; then
        echo "ORPort [$IP6]:443" > /usr/local/etc/tor/torrc
fi

# HiddenServicePort 80 [::1]:80 didn't seem to work?
# https://bugs.torproject.org/18357 ^
echo 'ORPort 443
HiddenServiceDir /usr/local/etc/tor/hidden_service/
HiddenServicePort 80 127.0.0.1:80
Nickname BuiltAutomatically
RelayBandwidthRate 1024 KB
RelayBandwidthBurst 1024 KB
ContactInfo IThinkIWasBuiltAutomatically
ExitPolicy reject *:*
ExitPolicy reject6 *:*' >> /usr/local/etc/tor/torrc


# Running tor as root, partly for port 443 use. Since this server hopefully
# only runs tor, it's safe to do.
echo 'ntpd_enable="YES"
tor_enable="YES"
tor_user="root"' >> /etc/rc.conf

chown 0:0 /var/db/tor

#FIXME: Not doing this because the hidden service key needs to be set manually.
#service tor start

##

chmod 500 /etc/rc.local

# Let the boot process start rc.local on its own.
#/etc/rc.local
