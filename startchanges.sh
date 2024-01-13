#!/bin/bash

# Author: mews_se
# Description: This script automates the configuration of sudoers, SSH settings, and generates an SSH key pair without passphrase.
# It also creates or updates .bashrc and .bash_aliases files with custom configurations and aliases.
# Interesting Fact: Ed25519 is an elliptic curve public-key signature algorithm named after the curve25519 elliptic curve.

log() {
    local message="$(date '+%Y-%m-%d %H:%M:%S') $1"
    echo "$message"
}

log "Script execution started."

# Function to update sudoers
update_sudoers() {
    log "Updating sudoers."

    # Check if the line already exists in sudoers
    if sudo grep -q '^%sudo ALL=(ALL) NOPASSWD: ALL$' /etc/sudoers; then
        log "sudoers entry already exists. No changes needed."
    else
        # Replace the existing line
        sudo sed -E -i '/^%sudo/s/.*/%sudo ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
        log "sudoers entry updated successfully."
    fi
}

# Function to configure SSH settings and restart SSH service
configure_ssh() {
    log "Configuring SSH."

    # Check if AllowUsers line already exists
    if sudo grep -q '^AllowUsers dietpi mews$' /etc/ssh/sshd_config; then
        log "AllowUsers already configured. No changes needed."
    else
        # Ensure PermitRootLogin is set to no
        sudo sed -E -i '/PermitRootLogin/s/^#?(PermitRootLogin).*/\1 no/' /etc/ssh/sshd_config

        # Add AllowUsers line if it doesn't exist
        if sudo grep -q '^#AllowUsers' /etc/ssh/sshd_config; then
            sudo sed -i '/^#AllowUsers/s/^#//' /etc/ssh/sshd_config
        else
            echo "AllowUsers dietpi mews" | sudo tee -a /etc/ssh/sshd_config > /dev/null
        fi

        # Restart SSH service
        sudo systemctl restart sshd

        log "SSH configuration updated successfully."
    fi
}

# Function to generate a new Ed25519 SSH key pair without passphrase
generate_ssh_key() {
    log "Generating SSH key."

    SSH_DIR="/home/$SUDO_USER/.ssh"
    KEY_FILE="$SSH_DIR/id_ed25519"

    # Check if an SSH key already exists
    if [ -f "$KEY_FILE" ]; then
        log "SSH key already exists for $SUDO_USER. Skipping generation."
    else
        # Force create .ssh folder
        sudo -u $SUDO_USER mkdir -p "$SSH_DIR"
        
        # Generate a new Ed25519 SSH key without passphrase
        sudo -u $SUDO_USER ssh-keygen -t ed25519 -f "$KEY_FILE" -N ""
        log "Ed25519 SSH key generated successfully."
    fi
}

# Function to create or update .bashrc file
create_bashrc() {
    log "Creating/updating .bashrc file."
    BASHRC_FILE="/home/$SUDO_USER/.bashrc"

    # Clear existing content
    echo -n > "$BASHRC_FILE"

    {
        # .bashrc content
        cat <<'EOL'
case $- in
    *i*) ;;
    *) return;;
esac

HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize

if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w \$\[\033[00m\] '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
EOL
        log ".bashrc file created/updated successfully for user: $SUDO_USER."
    } | sudo -u $SUDO_USER tee -a "$BASHRC_FILE" > /dev/null
}

## Function to create or update .bash_aliases file
create_bash_aliases() {
    log "Creating/updating .bash_aliases file."
    BASH_ALIASES_FILE="/home/$SUDO_USER/.bash_aliases"

    # Check if .bash_aliases file already exists
    if [ -f "$BASH_ALIASES_FILE" ]; then
        # Clear existing content
        sudo -u $SUDO_USER echo -n > "$BASH_ALIASES_FILE"
        log ".bash_aliases file cleared for user: $SUDO_USER."
    fi

    {
        # .bash_aliases content
        cat <<'EOL'
alias apta="sudo apt update && sudo apt full-upgrade && sudo apt autoremove -y && sudo apt clean"
alias kodipi="ssh dietpi@10.0.0.7"
alias sen="watch -n 1 sensors"
alias brkpi="ssh dietpi@192.168.1.3"
alias optiplex="ssh mews@192.168.1.6"
alias reb="sudo reboot"
alias dcupd="docker compose up -d"
alias dcupdlog="docker compose up -d && docker compose logs -f"
alias dclog="docker compose logs -f"
alias dcpull="docker compose pull"
alias dcstop="docker compose stop"
alias dcdown="docker compose down"
alias mm="ssh martin@10.0.0.11"
alias flight="ssh -p 2222 root@flight.rymdfartstyrelsen.se"
alias prox="ssh root@10.0.0.99"
alias fanoff="sudo systemctl stop fancontrol.service"
alias fanon="sudo systemctl start fancontrol.service"
alias tb="ssh 10.0.0.97"
EOL
    } | sudo -u $SUDO_USER tee -a "$BASH_ALIASES_FILE" > /dev/null
    log ".bash_aliases file created/updated successfully for user: $SUDO_USER."
}


# Call the functions
update_sudoers
configure_ssh
generate_ssh_key
create_bashrc
create_bash_aliases

# Source .bashrc and .bash_aliases to apply changes immediately
source "/home/$SUDO_USER/.bashrc"
source "/home/$SUDO_USER/.bash_aliases"

log "Script execution completed."
