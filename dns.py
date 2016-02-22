# WIP

import namesilo

ns = namesilo.NameSilo('api key', live=False)

ns.add_registered_nameserver(domain='go-beyond.org', new_host='ns1', ip1='ip4', ip2='ip6')
ns.list_registered_nameservers(domain='go-beyond.org')

ns.delete_registered_nameserver(domain='go-beyond.org', current_host='ns1')

ns.change_nameservers(domain='go-beyond.org', ns1='ns1.go-beyond.org', ns2='ns2.go-beyond.org')
