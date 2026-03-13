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
apt install -y sudo network-manager network-manager-gnome \
    gnome-terminal gnome-text-editor git curl wget

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
    apt install -y gnome-core gdm3
elif [ "$DESKTOP" = "xfce4" ]; then
    echo ">>> Installing XFCE4 minimal..."
    apt install -y xfce4 xfce4-goodies lightdm
    echo ">>> Setting LightDM as default display manager..."
    echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
fi

# --- Install ZSH environment from GitHub ---
echo ">>> Installing ZSH environment from GitHub..."
sudo -u "$USERNAME" bash -c "
    cd /home/$USERNAME
    git clone https://github.com/x86david/install-zsh
    cd install-zsh
    chmod +x install-zsh.sh
    sudo ./install-zsh.sh
"

# --- Configure GRUB to use terminal mode ---
echo ">>> Configuring GRUB to use terminal (text-only) mode..."

# Remove conflicting lines
sed -i '/GRUB_GFXMODE/d' /etc/default/grub
sed -i '/GRUB_GFXPAYLOAD_LINUX/d' /etc/default/grub
sed -i '/GRUB_TERMINAL/d' /etc/default/grub

# Add new settings
cat <<EOF >> /etc/default/grub

# Force GRUB into pure terminal mode
GRUB_TERMINAL=console
GRUB_GFXMODE=text
GRUB_GFXPAYLOAD_LINUX=text
EOF

echo ">>> Updating GRUB..."
update-grub

echo ">>> Cleaning up..."
apt autoremove -y
apt clean

echo ">>> Setup complete. Rebooting in 5 seconds..."
sleep 5
reboot
