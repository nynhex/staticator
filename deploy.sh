#!/bin/sh

DOMAIN=go-beyond.org

set -e

# Will need to renew every week~ at this rate. Should do it a day early.

DAYS=8

# Need to make this US-AUTO or just AUTO at some point when I add that in...
DCID1=1 # New Jersey
DCID2=5 # Los Angeles

WALLET_COMMAND="walkingliberty send $(cat bip32)"

# Returns hostname
node1=$(sporestack spawn --wallet_command="$WALLET_COMMAND" --startupscript deploy/startup.sh --group $DOMAIN --osid 230 --dcid $DCID1 --days $DAYS)
node2=$(sporestack spawn --wallet_command="$WALLET_COMMAND" --startupscript deploy/startup.sh --group $DOMAIN --osid 230 --dcid $DCID2 --days $DAYS)


for node in $node1 $node2; do
    tar -czf - .  | sporestack ssh $node --command 'mkdir /root/staticator; tar -xzvf - -C /root/staticator'
    sporestack ssh $node --command 'pip install -r /root/staticator/requirements.txt'
    sporestack ssh $node --command 'cp -r /root/staticator/hidden_service /usr/local/etc/tor; cp /root/staticator/id_rsa /root/.ssh/id_rsa; chmod 400 /root/.ssh/id_rsa; chown root /root/.ssh/id_rsa'
    sporestack ssh $node --command 'cp /root/staticator/id_rsa.pub /root/.ssh/id_rsa.pub'
    sporestack ssh $node --command 'chmod 700 /usr/local/etc/tor/hidden_service; chown -R _tor:_tor /usr/local/etc/tor/hidden_service; echo tor_enable=\"YES\" >> /etc/rc.conf'
    sporestack ssh $node --command '/root/audit.sh'
    # Start tor last to be sure the audit succeeded.
    sporestack ssh $node --command 'service tor start'

    # We do this last in case this is a 0 day server. Risk of it breaking audit.
    # Also stop tor since this is a "hidden" service.
    echo 'service gdnsd stop; service tor stop' | sporestack ssh $node --command 'at -t $(date -j -f %s '$(($(sporestack node_info $node --attribute end_of_life) - 3700))' +%Y%m%d%H%M)'
done

# Only on node1 for now. Bad if node1 dies.
echo 'cd /root/staticator; ./deploy.sh' | sporestack ssh $node1 --command 'at -t $(date -j -f %s '$(($(sporestack node_info $node1 --attribute end_of_life) - 85000))' +%Y%m%d%H%M)'

# Set nameserver record accordingly. This overwrites all.

echo python nameserver.py $DOMAIN $node1.node.sporestack.com $node2.node.sporestack.com
python nameserver.py $DOMAIN $node1.node.sporestack.com $node2.node.sporestack.com

# We want to make it obvious that the last command failed, in case it did.
echo Finished.
echo $DOMAIN: $node1 $node2
