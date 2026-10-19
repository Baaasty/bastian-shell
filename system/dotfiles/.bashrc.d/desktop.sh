# ~/.bashrc.d/desktop.sh – eigene Bash-Teile (Symlink aus ~/Workspace/bastian-shell/system/dotfiles).
# Fedoras ~/.bashrc lädt ~/.bashrc.d/* von selbst, die .bashrc bleibt Standard.
# Der Starship-Prompt steht NICHT hier: den setzt/entfernt `scripts/rice theme on|off` als Block in ~/.bashrc.

# Podman statt Docker (docker compose, Testcontainers …): rootless User-Socket
export DOCKER_HOST="unix:///run/user/$UID/podman/podman.sock"
