#!/bin/bash

###### Send an email on ip address acquisition on a device.
# Inspired by https://www.youtube.com/watch?v=J-rfC84xdOE
# Written By Scott Cove.

temp_file=/tmp/email_body

# Find the true path of the script.  This is important for adding the cronjob.
# The explanation for this can be found here:  https://stackoverflow.com/a/246128/7831034
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

if [[ ! -f "${DIR}/email.conf" ]]; then
    echo "No config file found."
    echo "${DIR}/email.conf does not exist.  Please make sure that the install script has been run."
    echo "If you're sure you know what you're doing, please create an email.conf file with the following:"
    echo "to_email_address="
    echo "hostname="
    echo 
    echo "Then rerun this script."
    exit 1
fi

# Let's get the IP Address(es) of the device first, discarding loopback.
ip_addresses_raw=$(ip a | grep -v "lo:" | grep -A 3 "state UP")

. ${DIR}/email.conf

# Check that there is actually an interface that is declaring itself up, else sleep for a second, and try again
while [[ -z "$ip_addresses_raw" ]]; do
    sleep 1
    ip_addresses_raw=$(ip a | grep -v "lo:" | grep -A 3 "state UP")
done

# Begin the email
cat > $temp_file << EOL
Subject: Your device has an IP Address!
Hi there,

This is your device ${hostname} speaking.

I have just acquired a new IP Address.  The details are below.
EOL


# Let's parse this just in case there's more than one up.  
# This can happen in the case of VPN's or if you're on a known wifi network with an ethernet cable plugged in as well.
while read line; do
    if [[ -n $(echo "$line" | grep "state UP") ]]; then
        device_name=$(echo "$line" | cut -d ':' -f2)
        echo >> $temp_file
        echo "  Device name: $device_name" >> $temp_file
    elif [[ -n $(echo "$line" | grep "inet") ]]; then
        ip_address=$(echo $line | awk '{print $2}')
        echo "  IP Address: $ip_address" >> $temp_file
        echo >> $temp_file
    fi
done < <(echo "$ip_addresses_raw")


echo "Happy testing!" >> $temp_file

# And now we send the email as set up by the install script.
cat $temp_file | ssmtp $to_email_address
if [[ $? -gt 0 ]]; then
    exit_code=1
else
    exit_code=0
fi

# Clean up after ourselves
rm -f $temp_file
exit $exit_code