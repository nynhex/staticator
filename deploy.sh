#!/bin/sh

DOMAIN=go-beyond.org

set -e

# Will need to renew every week~ at this rate. Should do it a day early.

DAYS=8

DCID1=1 # New Jersey
DCID2=5 # Los Angeles

# Returns hostname
node1=$(sporestack spawn --startupscript deploy/startup.sh --group $DOMAIN --osid 230 --dcid $DCID1 --days $DAYS $1 $2)
node2=$(sporestack spawn --startupscript deploy/startup.sh --group $DOMAIN --osid 230 --dcid $DCID2 --days $DAYS $1 $2)

for node in $node1 $node2; do
    tar -czf - hidden_service  | sporestack ssh $node --command 'tar -xzvf - -C /usr/local/etc/tor'
    sporestack ssh $node --command 'chmod 700 /usr/local/etc/tor/hidden_service; chown -R _tor:_tor /usr/local/etc/tor/hidden_service; echo tor_enable=\"YES\" >> /etc/rc.conf'
    sporestack ssh $node --command '/root/audit.sh'
    # Start tor last to be sure the audit succeeded.
    sporestack ssh $node --command 'service tor start'

    # We do this last in case this is a 0 day server. Risk of it breaking audit.
    # Also stop tor since this is a "hidden" service.
    echo 'service gdnsd stop; service tor stop' | sporestack ssh $node --command 'at -t $(date -j -f %s '$(($(sporestack node_info $node --attribute end_of_life) - 3700))' +%Y%m%d%H%M)'
done

# Set nameserver record accordingly. This overwrites all.

python nameserver.py $DOMAIN $node1.node.sporestack.com $node2.node.sporestack.com

# We want to make it obvious that the last command failed, in case it did.
echo Finished.
echo $DOMAIN: $node1 $node2
