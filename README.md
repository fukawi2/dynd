<!---
Test changes using: http://daringfireball.net/projects/markdown/dingus
-->

# dynd

Your own Dynamic DNS using BIND dynamic updates and a simple bash script

## Overview

dynd is a homebrew dynamic DNS service. We utilize the standard Dynamic DNS
features of ISC BIND to handle the dirty work of dynamic DNS and
authentication, and a simple bash script on the client to detect it's IP
address(es) before sending the update to the server.

### Features

* Simplicity; the documentation is bigger than the scripts and configuration!

* IPv4 and IPv6 Support

* Reuse of existing tools; no reinventing the wheel

## Requirements

* *Server*: A working DNS infrastructure with a BIND master server (tested
with 9.8.4); configuration of this is outside the scope of this readme.

* *Client*: Basic command line tools; bash, curl, cat etc

## Installation and Usage

There are 2 parts to getting dynd running; configuring the server and setting
up the client.

### Server

A sample configuration file is provided that you can copy to your BIND config
directory and then include. On a Debian system:

    # cp server/dyndconf /etc/bind/ 
    # echo 'include "/etc/bind/dynd.conf";' >> /etc/bind/named.conf.local
    # rndc reconfig

#### Authentication and Authorization

Each client needs to be given a key to authenticate with the server. The server
uses this key to determine what authorization that client has. This is to
ensure each client can only update it's own Resource Record (RR).

To generate a new key for a client, follow these steps:

First, use `dnssec-keygen` to create a new key pair; in this example we are
going to create a key for `client1`:

    dnssec-keygen -a HMAC-MD5 -b 128 -n user client1

Once this has completed, 2 files will have been created and the filename for
the files returned to you. You need to examine the `.key` file to find the key
for the client:

    $ dnssec-keygen -a HMAC-MD5 -b 128 -n user client1
    Kclient1.+157+00190
    $ cat Kclient1.+157+00190.key
    client1. IN KEY 0 3 157 NdZglC1bVKpuOQsoYE4LAQ==

The key for this client is `NdZglC1bVKpuOQsoYE4LAQ==`. You can now copy and
paste the key into your `dynd.conf` on the server. Keep the key; you need it
for the client too!

### Client

Installation on the client is as simple as saving the `dynd.sh` script in an
appropriate location. Usually `/usr/local/bin/` is suitable, although the script
does **NOT** require root privileges so can we run from your home directory if
required.

#### Usage

To detect your IP address(es) and update the server, you need to run `dynd.sh`
and supply all the required information:

* Server Address

* Zone

* Resource Record (RR)

* Key

This example will update `client1.dyn.example.com` using the key we generated
above:

    $ dynd.sh -s ns1.example.com -z dyn.example.com -r client1 -k client1:NdZglC1bVKpuOQsoYE4LAQ==

Note the key is the key identity (*client1*) separated from the key itself
by a colon (:)

Use the `-h` flag to see all options available.

The script uses [ipchimp.net](http://ipchimp.net) to determine your IP
addresses, then submits them to the server for update only if they are
different to the last time the script was run.

---

## License

    DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
    Version 2, December 2004

    Copyright (c) 2013 Phillip Smith <fukawi2@gmail.com>

    Everyone is permitted to copy and distribute verbatim or modified
    copies of this license document, and changing it is allowed as long
    as the name is changed.

    DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
    TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

    0. You just DO WHAT THE FUCK YOU WANT TO.
