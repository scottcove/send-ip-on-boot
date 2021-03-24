#!/bin/bash

### This installs ssmtp if not installed, configures it, then adds a cron job to run the send-ip script on boot.
# This script is designed for, and tested on Debian based systems.
# Scott Cove - 2021.

RED=$(tput setaf 1)
NOCOL=$(tput sgr0)



# Find the true path of the script.  This is important for adding the cronjob.
# The explanation for this can be found here:  https://stackoverflow.com/a/246128/7831034
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# Check for root user
currusr=$(whoami)
if [[ $currusr != "root" ]]; then
    echo
    echo "${RED}This script must be run as root, or via sudo.${NOCOL}"
    echo "Please run \"sudo ${DIR}/install.sh\" or drop to root with \"sudo -i\" and try again"
    echo
    exit 1
fi

ssmtp_config=${DIR}/ssmtp.conf
email_config=${DIR}/email.conf

# Validate any Yes/No Questions, and pass a default Answer.
# USAGE: validate-yesno-input "Question " [DEFAULT y/n]
validate-yesno-input() {
  default_value="$2"
  unset user_input
  while [[ ! ${user_input} =~ (^[yY]$|^[yY][eE][sS]$|^[nN]$|^[nN][oO]$) ]]; do
    read -p "$1" user_input
    user_input=${user_input:="${default_value}"}
    if [[ ! ${user_input} =~ (^[yY]$|^[yY][eE][sS]$|^[nN]$|^[nN][oO]$) ]]; then
      echo -n "${RED}Invalid Input.${NOCOL} "
      unset user_input
    elif [[ ${user_input} =~ (^[yY]$|^[yY][eE][sS]$) ]]; then
      user_input=y
    elif [[ ${user_input} =~ (^[nN]$|^[nN][oO]$) ]]; then
      user_input=n
    fi
  done
}

# Make sure apt is available before we go any further.
if [ -z "$(command -v apt-get)" ]; then
    echo "${RED}apt-get not found!${NOCOL}"
    echo "This script is designed to run on Debian based systems only."
    echo "This is completely untested on other systems."
    echo
    echo "Cannot continue, as your experience may vary."
    echo "Exiting."
    exit 1
fi

# Create the ssmtp and application config to write to, after removing any old configs
[ -f "$ssmtp_config" ] && rm "$ssmtp_config"
[ -f "$email_config" ] && rm "$email_config"
touch $ssmtp_config
touch "$email_config"

echo "hostname=$(hostname)" >> $email_config
echo "root=postmaster" >> $ssmtp_config
echo "hostname=$(hostname)" >> $ssmtp_config

echo
echo "Send an email on IP aquisition."
echo "This will install a script that will send an email of the IP Addresses upon first obtaining them."
echo
echo "Note: The Scripts will only run once.  Once the email has been sent, you will either need to reboot your device, or rerun $DIR/send-ip.sh manually."
echo
echo
echo "Let's get this set up."
echo
echo "----------------- Setting up the email addresses -----------------"
echo
echo "The next section will set up the mail server to send from.  This should be an account that actually exists, to stop these emails from going to spam, i.e. a gmail account."

while [[ -z "$smtp_server" ]]; do
    echo 
    echo "Please enter the outgoing (smtp) server, including the port number."
    echo "For the case of gmail, this is smtp.gmail.com:465"
    echo "Leave blank for the default"
    read -pr "Mail Server [smtp.gmail.com:465]: " smtp_server
    smtp_server=${smtp_server:="smtp.gmail.com:465"}
done
echo "mailhub=$smtp_server" >> $ssmtp_config


echo
echo "Please enter the email address, or username you send email from."
echo "For Gmail, this will be your full email address"
while [[ -z "$username" ]]; do
    read -pr "Email address or username: " username
    if [[ -z "$username" ]]; then
        echo "${RED}Cannot be blank!"
    fi
done
echo "AuthUser=$username" >> $ssmtp_config

echo
echo "Please enter the password for the account"
echo "NOTE: This is stored in plain-text in a document, even though it is obscured in the prompt."
echo "It is recommended you use an application password."
echo "If using gmail, this can be set, and obtained by following this guide: https://support.google.com/accounts/answer/185833?hl=en-GB#zippy="
echo

while [[ -z "$password" ]]; do
    read -prs "Password: " password
    if [[ -z "$password" ]]; then
        echo "${RED}Cannot be blank!"
    fi
done
echo "AuthPass=$password" >> "$ssmtp_config"

echo
echo "Do you want to use STARTTLS?"
echo "The default for gmail is no, but your email provider may need it."
echo "Leave blank for the default value"
validate-yesno-input "Use STARTTLS [y/N]: " "n"
if [[ "$user_input" == "y" ]]; then
     echo "UseSTARTTLS=YES" >> "$ssmtp_config"
fi

echo
echo "Do you want to use TLS?"
echo "This is highly recommended, unless your mailserver specifically does not support it."
validate-yesno-input "Use TLS [Y/n]: " "y"
if [[ "$user_input" == "y" ]]; then
     echo "UseTLS=YES" >> "$ssmtp_config"
fi

echo
echo "Where do you want to send these notifications to?"
echo "Please enter an email address that will be receiving these notifications.  This can be the same as the from address."
while [[ -z "$to_email_address" ]]; do
    read -prs "email address to send to: " to_email_address
    if [[ -z "$to_email_address" ]]; then
        echo "${RED}Cannot be blank!"
    fi
done
echo "to_email_address=\"$to_email_address\"" >> "$email_config"

echo
echo "Thanks."

# Install ssmtp
if [[ -z "$(command -v ssmtp)" ]]; then
    echo "----------------- Installing ssmtp -----------------"
    sudo apt-get -y ssmtp
fi

# Configure ssmtp
mv /etc/ssmtp/ssmtp.conf{,.bak}
mv ${DIR}ssmtp.conf /etc/ssmtp/ssmtp.conf

echo "----------------- Installing cronjob -----------------"
#See here for the Explanation of this:  https://stackoverflow.com/a/17975418
  croncmd="${DIR}/send-ip > /dev/null 2>&1"
  cronjob="@reboot $croncmd"

  # To add it to the crontab, with no duplication:
  ( crontab -l | grep -v -F "$croncmd" ; echo "$cronjob" ) | crontab -

echo "Done."

echo "----------------- Cleaning up -----------------"
rm -f ${DIR}/ssmtp.conf
chmod 644 ${DIR}/email.conf
chmod 755 ${DIR}/send-ip.sh
sleep 1

echo "Finished installing.  It is highly recommended you run this once to test.  If the test fails, you can simply rerun this script"
echo " or manually edit the /etc/ssmtp/ssmtp.conf and ${DIR}/email.conf files manually to troubleshoot."
validate-yesno-input "Run the send-ip script once [Y/n]: "
if [[ "$user_input" == "yes" ]]; then
    ${DIR}/send-ip
fi
exit 0