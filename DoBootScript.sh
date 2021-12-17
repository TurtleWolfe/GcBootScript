#!/bin/bash

# End the script immediately if any command or pipe exits with a non-zero status.
# I don't usually use these two flags, but if you're just getting started shell scripting,
# this would be like turning on warnings or strict mode in other languages.
set -euo pipefail

########################
### SCRIPT VARIABLES ###
########################

# Name of the user to create and grant sudo privileges
USERNAME=janeDOE

# IP Address for accessing SSH
IP_ADDRESS=0.0.000.000

# cidr block for accessing SSH via Virtual Private Cloud
# aws_VPC=10.0.0.0/24
aws_VPC=10.0.0.0/24

# Port for accessing SSH
SSH_PORT=22

# Port for DEVelopment; ReAct :3000
# DEV_PORT=3000
DEV_PORT=3000

# Port for DEVelopment; ReAct StoryBook :9009
# STORY_PORT=9009
STORY_PORT=9009

# MariaDB password
# SECRET=secret
SECRET=secret

# set TimeZone
timedatectl set-timezone America/New_York

# Whether to copy root user's `authorized_keys` file to the new sudo user.
COPY_AUTHORIZED_KEYS_FROM_ROOT=true

# Additional public keys to add to the new sudo user
OTHER_PUBLIC_KEYS_TO_ADD=(
"ssh-rsa AAAAB..."
)

####################
### SCRIPT LOGIC ###
####################

# customize TTY prompt
sed -i 's/#force_color_prompt=yes/ force_color_prompt=yes/' /etc/skel/.bashrc
sed -i 's/\\\[\\033\[01;32m\\\]\\u@\\h\\\[\\033\[00m\\\]:\\\[\\033\[01;34m\\\]\\w\\\[\\033\[00m\\\]\\\$ /\\n\\@ \\\[\\e\[32;40m\\\]\\u\\\[\\e\[m\\\] \\\[\\e\[32;40m\\\]@\\\[\\e\[m\\\]\\n \\\[\\e\[32;40m\\\]\\H\\\[\\e\[m\\\] \\\[\\e\[36;40m\\\]\\w\\\[\\e\[m\\\] \\\[\\e\[33m\\\]\\\\\$\\\[\\e\[m\\\] /' /etc/skel/.bashrc
# PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Add sudo user and grant privileges
useradd --create-home --shell "/bin/bash" --groups sudo "${USERNAME}"

# Check whether the root account has a real password set
encrypted_root_pw="$(grep root /etc/shadow | cut --delimiter=: --fields=2)"

if [ "${encrypted_root_pw}" != "*" ]; then
    # Transfer auto-generated root password to user if present
    # and lock the root account to password-based access
    echo "${USERNAME}:${encrypted_root_pw}" | chpasswd --encrypted
    passwd --lock root
else
    # Delete invalid password for user if using keys so that a new password
    # can be set without providing a previous value
    passwd --delete "${USERNAME}"
fi

# Expire the sudo user's password immediately to force a change
chage --lastday 0 "${USERNAME}"

# Create SSH directory for sudo user
home_directory="$(eval echo ~${USERNAME})"
mkdir --parents "${home_directory}/.ssh"

# Copy `authorized_keys` file from ubuntu before deleting it
if [ "${COPY_AUTHORIZED_KEYS_FROM_ROOT}" = true ]; then
    # DigitalOcean does not have an ubuntu user
    # cp /home/ubuntu/.ssh/authorized_keys "${home_directory}/.ssh"
    # cp /home/.ssh/authorized_keys "${home_directory}/.ssh"
    cp ~/.ssh/authorized_keys "${home_directory}/.ssh"
fi
# userdel -r ubuntu
# deluser --remove-home john
# deluser --backup --remove-home john
# chage --lastday 0 ubuntu
# passwd --lock ubuntu

# Add additional provided public keys
for pub_key in "${OTHER_PUBLIC_KEYS_TO_ADD[@]}"; do
    echo "${pub_key}" >> "${home_directory}/.ssh/authorized_keys"
done

# Adjust Home permissions
# chmod 0750 "${home_directory}"
chmod 0700 "${home_directory}/.ssh"
chmod 0600 "${home_directory}/.ssh/authorized_keys"

# Adjust SSH configuration ownership and permissions
chown --recursive "${USERNAME}":"${USERNAME}" "${home_directory}/.ssh"

# Chapter 2, Users
# install PAM (Pluggable Authentication Modules)

apt-get install -y libpam-cracklib
# apt-get install -y libpam-pwquality
# apt-get -y install libpam-cracklib
# module-type	control		module-path	arguments

echo 'password required pam_pwhistory.so remember=99 use_authok' >> /etc/pam.d/common-password
# difference ( at least three characters have to be different )
# difok=3
# obscure ( prevents simple passwords from being used )
# obscure
# Chapter 15, Securing SSH
groupadd sshusers
usermod -aG sshusers "${USERNAME}"
echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config
echo 'Protocol 2' >> /etc/ssh/sshd_config
echo 'AllowGroups sudo sshusers' >> /etc/ssh/sshd_config
# Disable root SSH login with password (& key)
sed --in-place 's/^PermitRootLogin.*/PermitRootLogin no/g' /etc/ssh/sshd_config
if sshd -t -q; then
    systemctl restart sshd
fi

# turn off the Message of the Day
sed -i "s/#PrintLastLog yes/PrintLastLog no/" /etc/ssh/sshd_config

# Add exception for SSH and then enable UFW firewall
sed --in-place 's/IPV6=no/IPV6=yes/' /etc/default/ufw
ufw allow proto tcp from "${IP_ADDRESS}" to any port "${SSH_PORT}"
ufw allow proto tcp from "${aws_VPC}" to any port "${SSH_PORT}"
# ufw allow from "${IP_ADDRESS}" proto tcp to any port "${SSH_PORT}"
# ufw allow from "${aws_VPC}" proto tcp to any port "${SSH_PORT}"
ufw allow 80/tcp
ufw allow 8080/tcp
# ufw allow proto tcp from "${IP_ADDRESS}" to any port "${DEV_PORT}"
ufw allow "${DEV_PORT}"/tcp
# ufw allow proto tcp from "${IP_ADDRESS}" to any port "${STORY_PORT}"
ufw allow "${STORY_PORT}"/tcp
ufw allow 443/tcp
# ufw deny ftp
# sudo ufw show added
# sudo ufw status verbose
# sudo ufw reject out ftp
ufw --force enable

apt update

# get the GPG key for docker
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
#    && apt-key add -

# usermod -aG docker "${USERNAME}"

# apt upgrade
# Chapter 15, Fail2Ban
apt-get -y install fail2ban
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sed -i 's/bantime  = 10m/bantime  = 120m/' /etc/fail2ban/jail.local
sed -i 's/maxretry = 5/maxretry = 3/' /etc/fail2ban/jail.local
sed -i "s/logpath = %(sshd_log)s/logpath = %(sshd_log)s\nenabled = true/" /etc/fail2ban/jail.local
# sed -i "s/#ignoreip = 127.0.0.1\/8 ::1/ignoreip = 127.0.0.1\/8 ::1 ${aws_VPC} ${IP_ADDRESS}/" /etc/fail2ban/jail.local

# apt install python3-pip -y
# pip install docker
# pip install docker-compose

# Apache
# sudo apt-get install apache2 -y
################################################################################
# apt-get install lamp-server^
# mysql_secure_installation <<EOF
# y
# $SECRET
# $SECRET
# y
# y
# y
# y
# EOF
################################################################################
#     1  sudo apt update
#     2  sudo apt upgrade
#     3  sudo apt dist-upgrade
#     4  clear
#     5  wget http://nginx.org/keys/nginx_signing.key
#     6  apt-key add nginx_signing.key
#     7  sudo apt-key add nginx_signing.key
#     8  nano /etc/apt/sources.list.d/nginx.list
#     9  sudo nano /etc/apt/sources.list.d/nginx.list
#    10  apt-get update
#    11  sudo apt-get update
#    12  apt-get install nginx
#    13  sudo apt-get install nginx
#    14  /usr/sbin/nginx -t
#    15  sudo /usr/sbin/nginx -t
#    16  history
#    /usr/share/nginx/html 
# apt upgrade -y

# apt autoremove -y
# apt autoclean -y
# reboot

# Install Docker on Ubuntu 18.04
# Install Docker on Ubuntu 20.04
# update apt-get libraries
# apt update

# sudo apt upgrade -y
apt upgrade -y

# install required packages
# sudo apt install apt-transport-https ca-certificates curl software-properties-common
# apt install apt-transport-https ca-certificates curl software-properties-common
# apt install \
#    apt-transport-https \
#    ca-certificates \
#    curl \
#    software-properties-common


# get the GPG key for docker
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \ && sudo apt-key add -

# validating the docker GPG key is installed
# sudo apt-key fingerprint 0EBFCD88
apt-key fingerprint 0EBFCD88

# adding the docker repository
# sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
# add-apt-repository \
#    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
#    $(lsb_release -cs) \
#    stable"


# update apt-get libraries again
# sudo apt update
apt update

# sudo apt-cache policy docker-ce
# apt-cache policy docker-ce

# install docker
# sudo apt install docker-ce
apt install docker-ce
# 406 MB

# validate install with version command
# docker --version

# validating functionality by running a container
# docker run hello-world

# apt-key fingerprint 0EBFCD88

# add the current user to the docker group
# sudo usermod -aG docker "${USERNAME}"
usermod -aG docker "${USERNAME}"
#    17  exit
#    16  id -nG

# validate that sudo is no longer needed
# docker run hello-world

# install docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
# curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
# curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
#    21  sudo chmod +x /usr/local/bin/docker-compose
#    22  docker-compose --version

# reboot