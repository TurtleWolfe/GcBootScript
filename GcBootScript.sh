# set TimeZone
timedatectl set-timezone America/New_York

# customize TTY prompt
sed -i 's/#force_color_prompt=yes/ force_color_prompt=yes/' /etc/skel/.bashrc

sed -i 's/\\\[\\033\[01;32m\\\]\\u@\\h\\\[\\033\[00m\\\]:\\\[\\033\[01;34m\\\]\\w\\\[\\033\[00m\\\]\\\$ /\\n\\@ \\\[\\e\[32;40m\\\]\\u\\\[\\e\[m\\\] \\\[\\e\[32;40m\\\]@\\\[\\e\[m\\\]\\n \\\[\\e\[32;40m\\\]\\H\\\[\\e\[m\\\] \\\[\\e\[36;40m\\\]\\w\\\[\\e\[m\\\] \\\[\\e\[33m\\\]\\\\\$\\\[\\e\[m\\\] /' /etc/skel/.bashrc

# customize TTY prompt
sed -i 's/#force_color_prompt=yes/ force_color_prompt=yes/' /home/dev_turtlewolfe/.bashrc

sed -i 's/\\\[\\033\[01;32m\\\]\\u@\\h\\\[\\033\[00m\\\]:\\\[\\033\[01;34m\\\]\\w\\\[\\033\[00m\\\]\\\$ /\\n\\@ \\\[\\e\[32;40m\\\]\\u\\\[\\e\[m\\\] \\\[\\e\[32;40m\\\]@\\\[\\e\[m\\\]\\n \\\[\\e\[32;40m\\\]\\H\\\[\\e\[m\\\] \\\[\\e\[36;40m\\\]\\w\\\[\\e\[m\\\] \\\[\\e\[33m\\\]\\\\\$\\\[\\e\[m\\\] /' /home/dev_turtlewolfe/.bashrc

apt update
# Chapter 15, Fail2Ban
apt-get -y install fail2ban
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

userdel -r ubuntu

# apt-get install -y git

# apt-get install  -y nano

# sudo apt install -y nginx