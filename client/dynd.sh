#!/bin/bash

set -e

IP_CHECK='ipchimp.net'
STATE_FILE="$HOME/.dynd-last_ips"
MAX_UPDATE_INTERVAL=86400
SYSLOG='logger -t dynd-client'

function usage() {
  cat >&2 <<EOH
$0 -s server -z zone -r rr -k keyname:keysecret [-t ttl] [-h] [-v] [-D] [-f]

  -s  Server Address (eg, ns1.example.com)
  -z  Zone to update (eg, dyn.example.com)
  -r  RR to update (eg, client1.dyn.example.com)
  -k  Key to authentication with. This is the keyname and the key string
      separated by a colon
  -t  Override the default TTL of the new RR
  -v  Verbose output
  -D  Debug output
  -f  Force update (even if addresses haven't changed)
  -h  This Help

  Example:
  $0 -s ns1.example.com -z dyn.example.com -r client1 -k client1:NdZglC1bVKpuOQsoYE4LAQ==
EOH
}

function file_age_in_secs() {
  local _fname="$1"
  local _file_mtime=$(stat -tc%Y $_fname)
  local _epoch=$(date +%s)
  echo $(($_epoch - $_file_mtime))
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

$SYSLOG "Started"

# do we want to update purely because it's been a while?
if [[ -f $STATE_FILE ]] ; then
  state_file_age=$(file_age_in_secs $STATE_FILE)
  if [[ $state_file_age -gt $MAX_UPDATE_INTERVAL ]] ; then
    # yes
    $SYSLOG "$state_file_age seconds since last update; Forcing update."
    debug "Forcing update because it's been $state_file_age seconds since last update"
    rm -f $STATE_FILE
  fi
fi

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
new_ip4=$(curl --silent --noproxy '*' --ipv4 $IP_CHECK || true)
new_ip6=$(curl --silent --noproxy '*' --ipv6 $IP_CHECK || true)
msg "Current IP Addresses are:"
msg "\tIPv4: $new_ip4"
msg "\tIPv6: $new_ip6"

# did we get data?
if [[ -z $new_ip4 && -z $new_ip6 ]] ; then
  $SYSLOG "Error determining IP Address(es); Aborting"
  bomb "Error determining IP Address(es); No data returned from $IP_CHECK"
fi

# do we need to do anything?
if [[ $old_ip4 == $new_ip4 && $old_ip6 == $new_ip6 ]] ; then
  $SYSLOG "IP Address not changed; Nothing to do"
  msg "IP Address not changed; Nothing to do"
  exit 0
fi

[[ -n "$new_ip4" ]] && $SYSLOG "Updating IPv4 address to $new_ip4"
[[ -n "$new_ip6" ]] && $SYSLOG "Updating IPv6 address to $new_ip6"

# build a temp file with our zone update request
debug "Building temporary file with nsupdate commands"
tfile=$(mktemp dynd-$$.XXX)
cat > $tfile <<EOT
server $_server
key $_key_name $_key_secret
ttl $_ttl
update delete ${_rr}.${_zone}
EOT
# only append an 'update add' for the address(es) we know
#(IPv4/A and/or IPv6/AAAA)
[[ -n "$new_ip4" ]] && \
  echo "update add ${_rr}.${_zone} A $new_ip4" >> $tfile
[[ -n "$new_ip6" ]] && \
  echo "update add ${_rr}.${_zone} AAAA $new_ip6" >> $tfile
# close off by sending the request
echo 'send' >> $tfile

# send the update request to the server
$SYSLOG "Sending update request to server $_server"
msg "Sending update request to server $_server"
nsupdate $tfile

# update our state file
debug "Updating state file"
echo "$new_ip4 $new_ip6" > $STATE_FILE

debug "Removing temp file $tfile"
rm -f $tfile

$SYSLOG "Complete"

exit 0
