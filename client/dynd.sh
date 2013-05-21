#!/bin/bash

set -e

IP_CHECK='ipchimp.net'
STATE_FILE="$HOME/.dynd-last_ips"

function usage() {
  echo "$0 -s server -z zone -r rr -k keyname:keysecret [-t ttl] [-h]" >&2
}

function msg() {
  [[ -n $verbose ]] && echo -e "$1"
  return 0
}

function debug() {
  [[ -n $debug ]] && echo -e "$1"
  return 0
}

function bomb() {
  local _err="$1"
  echo $_err >&2
  exit 1
}

### defaults
_server=
_zone=
_rr=
_ttl=60
_key_name=
_key_secret=
verbose=
debug=

### handle command line args
while getopts ":s:z:r:t:k:hvDf" opt; do
  case $opt in
    s)
      _server=$OPTARG
      ;;
    z)
      _zone=$OPTARG
      ;;
    r)
      _rr=$OPTARG
      ;;
    t)
      _ttl=$OPTARG
      ;;
    k)
      _key_name=$(cut -d: -f1 <<< $OPTARG)
      _key_secret=$(cut -d: -f2 <<< $OPTARG)
      ;;
    h)
      usage
      exit 0
      ;;
    v)
      verbose=1
      ;;
    D)
      verbose=1
      debug=1
      ;;
    f)
      # force update
      msg "Forcing update"
      rm -f $STATE_FILE
      ;;
    *)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 2
      ;;
  esac
done

### got everything we need?
[[ -z $_server ]]     && bomb "Need to know the server"
[[ -z $_zone ]]       && bomb "Need to know the zone"
[[ -z $_rr ]]         && bomb "Need to know the RR"
[[ -z $_key_name ]]   && bomb "Need to know the key name"
[[ -z $_key_secret ]] && bomb "Need to know the key secret"

# what was our old ip address?
old_ip4='NULL'
old_ip6='NULL'
if [[ -f $STATE_FILE ]] ; then
  debug "Fetching information from state file: $STATE_FILE"
  read old_ip4 old_ip6 < $STATE_FILE
  msg "IP Address(es) at last update was $old_ip4 / $old_ip6"
fi

# get our current ip addresses via external url
debug "Using $IP_CHECK to fetch current IP Address(es)"
new_ip4=$(curl --silent --noproxy '*' --ipv4 $IP_CHECK)
new_ip6=$(curl --silent --noproxy '*' --ipv6 $IP_CHECK)
msg "Current IP Addresses are:"
msg "\tIPv4: $new_ip4"
msg "\tIPv6: $new_ip6"

# do we need to do anything?
if [[ $old_ip4 == $new_ip4 && $old_ip6 == $new_ip6 ]] ; then
  msg "IP Address not changed; Nothing to do"
  exit 0
fi

# build a temp file with our zone update request
debug "Building temporary file with nsupdate commands"
tfile=$(mktemp dynd-$$.XXX)
cat > $tfile <<EOT
server $_server
key $_key_name $_key_secret
ttl $_ttl
update delete ${_rr}.${_zone}
update add ${_rr}.${_zone} A $new_ip4
update add ${_rr}.${_zone} AAAA $new_ip6
send
EOT

# send the update request to the server
msg "Sending update request to server $_server"
nsupdate $tfile

# update our state file
debug "Updating state file"
echo "$new_ip4 $new_ip6" > $STATE_FILE

debug "Removing temp file $tfile"
rm -f $tfile

exit 0