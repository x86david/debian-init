#!/bin/bash

# Abort on error
set -e

# --- Validate parameters ---
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <username> <gnome|xfce4>"
    exit 1
fi

USERNAME="$1"
DESKTOP="$2"

if [[ "$DESKTOP" != "gnome" && "$DESKTOP" != "xfce4" ]]; then
    echo "Error: second parameter must be 'gnome' or 'xfce4'"
    exit 1
fi

echo ">>> Updating system..."
apt update
apt upgrade -y

echo ">>> Installing essential utilities..."
apt install -y sudo network-manager network-manager-gnome git curl wget

echo ">>> Adding user '$USERNAME' to sudo group..."
usermod -aG sudo "$USERNAME"

echo ">>> Enabling NetworkManager..."
systemctl enable NetworkManager
systemctl start NetworkManager

echo ">>> Ensuring NetworkManager manages all interfaces..."
cat <<EOF >/etc/NetworkManager/NetworkManager.conf
[main]
plugins=ifupdown,keyfile

[ifupdown]
managed=true
EOF

echo ">>> Restarting NetworkManager..."
systemctl restart NetworkManager

# --- Desktop selection ---
if [ "$DESKTOP" = "gnome" ]; then
    echo ">>> Installing GNOME minimal (gnome-core)..."
    apt install -y gnome-core

elif [ "$DESKTOP" = "xfce4" ]; then
    echo ">>> Installing XFCE4 minimal..."
    apt install -y xfce4 xfce4-goodies lightdm
    echo ">>> Setting LightDM as default display manager..."
    echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
fi

# --- Install ZSH environment from GitHub ---
echo ">>> Installing ZSH environment from GitHub..."

sudo -u "$USERNAME" bash <<EOF
cd /home/$USERNAME

# Remove old clone if exists
[ -d install-zsh ] && rm -rf install-zsh

git clone https://github.com/x86david/install-zsh install-zsh
cd install-zsh

chmod +x install-zsh.sh

echo "ℹ️  Only users who currently use /bin/bash will be switched to Zsh."

# Patch installer to change shell ONLY for users with /bin/bash
sed -i 's/for u in .*/for u in \$(awk -F: '\''\$7 == "\/bin\/bash" {print \$1}'\'' \/etc\/passwd); do/' install-zsh.sh

./install-zsh.sh
EOF

# --- Configure GRUB to use simple console mode ---
echo ">>> Configuring GRUB to use simple console mode..."

sed -i '/GRUB_GFXMODE/d' /etc/default/grub
sed -i '/GRUB_GFXPAYLOAD_LINUX/d' /etc/default/grub
sed -i '/GRUB_TERMINAL/d' /etc/default/grub

cat <<EOF >> /etc/default/grub

# Simple, clean GRUB console mode
GRUB_TERMINAL=console
EOF

echo ">>> Updating GRUB..."
update-grub

echo ">>> Cleaning up..."
apt autoremove -y
apt clean

echo ">>> Setup complete. Rebooting in 5 seconds..."
sleep 5
reboot
