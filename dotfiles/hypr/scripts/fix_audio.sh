#!/usr/bin/env bash

echo "Stopping user-space audio infrastructure..."
systemctl --user stop easyeffects pipewire pipewire-pulse wireplumber

echo "Forcefully killing lingering sound processes..."
fuser -k /dev/snd/* >/dev/null 2>&1
sleep 1

echo "Reloading ALSA/Intel kernel sound modules..."
sudo modprobe -r snd_hda_intel snd_soc_avs 2>/dev/null
sudo modprobe snd_hda_intel

echo "Reinitializing sound daemons..."
systemctl --user start pipewire pipewire-pulse wireplumber
sleep 2

echo "Syncing EasyEffects equalizer pipeline..."
systemctl --user start easyeffects
~/nix/dotfiles/hypr/scripts/quickshell/music/equalizer.sh --init

echo "Audio stack successfully recovered!"