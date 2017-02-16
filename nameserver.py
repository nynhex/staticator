import argparse

import namesilo
import yaml

CONFIG_FILE = 'config.json'

# Provides NAMESILO_API_KEY
with open(CONFIG_FILE) as config_file:
    config = yaml.safe_load(config_file)

ns = namesilo.NameSilo(config['NAMESILO_API_KEY'], live=True)


def main():
    """
    Should be updated to support more than 2 nameservers...
    """
    parser = argparse.ArgumentParser(description='Update nameserver.')
    parser.add_argument('domain')
    parser.add_argument('ns1')
    parser.add_argument('ns2')
    args = parser.parse_args()

    ns.change_nameservers(domain=args.domain, ns1=args.ns1, ns2=args.ns2)

if __name__ == '__main__':
    main()
