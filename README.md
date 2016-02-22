#staticator
###Puts a static site on vultr

Only works for go-beyond.org now. Also makes the box a 1Mbit/sec tor relay *and* hidden service host. Since this makes three nodes and key copying isn't automated, that has to be done by hand and the service needs to be started manually afterward.

You'll need to get the IPv4s and IPv6s from all three boxes and make nameserver glue at your registrar for all three.

Failover handling:

There's a chance that the client's DNS server can reach a box, but it can't. We don't handle that scenario.

Client DNS picks a random DNS server (same as the web host). If it's up, DNS goes further and matches the domain to the same box it hit for DNS. It only serves A/AAAA reocrds for itself.

If a server is down, DNS is good about moving on to the next server in a sort of timely fashion.

With multiple nodes on the hidden service, if one is down the other should eventually take its place. Seems to handle that for us.

You'll need to make `/usr/local/etc/tor/hidden_service/`'s files match on all three nodes. One of them should have the onion hostname you can reach your site in.

Your site should probably be using relative paths for the onion site to work. Also, no www -> not redirection is immediately supported for now. Your site should also spit out a version number so you can verify what nodes are running which code via HTTP.

# TODO

## Orchestration:

Move to Python. Make useful for other repos.

Use:
* https://github.com/spry-group/python-vultr - https://github.com/spry-group/python-vultr/issues/31
* https://github.com/kolanos/namesilo - dns.py in progress

Figure out better update procedure. Can be deleting and creating servers (not super great as these are dns servers...), currently fetches content every five minutes and overwrites it. It is atomic at the file level. Folder level may not work given the nature of the webserver chdir()'ed to the directory, or even chroot()'ed.

## Server itself:

* Simpler DNS server, currently has HTTP port 3506 listening among other things
* HTTP server that supports precompressed gzip transfers
* Make tor not run as root

# Prerequisites

Needs Golang installed. Also set a GOPATH, like:

```
$ mkdir $HOME/golang
$ export GOPATH=$HOME/golang
```

# Steps

0. `$ go get github.com/JamesClonk/vultr`
0. Create account on http://vultr.com
0. Go under settings and enable the API
0. `git clone` this repo and `cd` into it.
0. `$ VULTR_API_KEY=(APIKEY) ./deploy`

# License

[Public domain / Unlicense](LICENSE)
