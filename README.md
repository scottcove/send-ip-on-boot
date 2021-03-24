# Send the IP Address of a device on boot

This set of scripts is designed to run on boot of a device, and send an email to a specified email address, with the device's IP.  Based on ssmtp, and comes with some instructions on using this with a gmail address to send from.

This is handy for situations such as on headless dhcp-enabled raspberry-pi's running on unfamiliar networks.  The inspiration for creating this script finally came from [this video](https://www.youtube.com/watch?v=J-rfC84xdOE), but I can see use in things like nmap enabled scanners on new networks, or anywhere you need a headless dhcp-enabled machine you wish to interact with, without having to resort to switch configs or arp pings and the like.

At present, this will only run on Debian Based Linux systems.  On a Raspberry Pi, this includes the official Raspberry Pi OS, and Ubuntu, among others.

Nonetheless, use at your own risk.

## Installation

Installation is simple.  On a git enabled device (`sudo apt install git -y` if not installed) Run the following commands to get started:

- `sudo cd /opt`
- `git clone https://github.com:scottcove/send-ip-on-boot.git`
- `cd send-ip-on-boot`
- `chmod +x install.sh`
- `./install.sh`
- Follow the prompts.

That's it!  Happy testing.

## Uninstalling

To uninstall:

Uninstalling is easy, too.  you simply remove the crontab (as root), and remove the script directory.  I would also recommend you remove /etc/ssmtp/ssmtp.conf unless you plan on sending mail from the command line after uninstallation.
