#!/bin/sh
sync \
&& sudo sysctl -w vm.drop_caches=3 \
    && sudo swapoff -a \
    && sudo swapon -a \
    && printf '\n%s\n' 'RAM-cache and Swap were cleared.' \
    && free
sudo rm -rf /var/lib/pacman/db.l* \
    $HOME/.cache/* \
    /tmp/makepkg/* \
    /var/cache/pacman/pkg
sudo mkdir -p /var/cache/pacman/pkg
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman-key --refresh-keys
sudo pacman -Scc --noconfirm
sudo pacman -Rns --noconfirm $(pacman -Qtdq)
sudo rm -rf /var/lib/pacman/db.l* \
    $HOME/.cache/* \
    /tmp/makepkg/* \
    /var/cache/pacman/pkg
sudo mkdir -p /var/cache/pacman/pkg
sudo pacman-key --refresh-keys
yay -Syu --noanswerdiff --noanswerclean --noconfirm
sudo rm -rf /var/lib/pacman/db.l* \
    $HOME/.cache/* \
    /tmp/makepkg/* \
    /var/cache/pacman/pkg
sudo mkdir -p /var/cache/pacman/pkg
sudo pacman -Scc --noconfirm
sudo pacman -Rns --noconfirm $(sudo pacman -Qtdq)
sudo rm -rf /var/lib/pacman/db.lck
sudo paccache -ruk0
sync \
&& sudo sysctl -w vm.drop_caches=3 \
    && sudo swapoff -a \
    && sudo swapon -a \
    && printf '\n%s\n' 'RAM-cache and Swap were cleared.' \
    && free
