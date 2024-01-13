#!/bin/bash

# Author: mews_se
# Description: This script automates the configuration of sudoers, SSH settings, and generates an SSH key pair without passphrase.
# It also creates or updates .bashrc and .bash_aliases files with custom configurations and aliases.
# Interesting Fact: Ed25519 is an elliptic curve public-key signature algorithm named after the curve25519 elliptic curve.

# -----------------------------------------------------------------------------
# Script Purpose:
# This script automates the configuration of system settings, SSH, and user environment.
# It ensures secure configurations, updates sudoers, and customizes user profiles.
# Additionally, it installs and configures SNMP service with specific settings.
#
# Usage:
#   - Ensure you have the necessary privileges to execute the script (e.g., via sudo).
#   - Execute the script in a terminal: ./script_name.sh
#
# Important Notes:
#   - Review and customize the aliases in the create_bash_aliases function to fit your preferences.
#   - Ensure proper testing in a controlled environment before deploying in production.
#   - Consider potential security implications, especially when generating SSH keys without passphrases.
#
# -----------------------------------------------------------------------------

log() {
    local message="$(date '+%Y-%m-%d %H:%M:%S') $1"
    echo "$message"
}

log "Script execution started."

# Function to run apt update and full-upgrade
run_apt_update_upgrade() {
    log "Running apt update and full-upgrade."

    # Update package lists
    if ! sudo apt-get update; then
        log "Error: Failed to update package lists."
        exit 1
    fi

    # Perform a full upgrade
    if ! sudo apt-get full-upgrade -y; then
        log "Error: Failed to perform full upgrade."
        exit 1
    fi

    log "Apt update and full-upgrade completed successfully."
}

# Function to check and install required packages
check_install_dependencies() {
    log "Checking and installing required packages."

    # List of required packages
    required_packages=("openssh-server")

    for package in "${required_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii.*${package}"; then
            log "Installing $package..."
            sudo -E apt-get install -y "$package"
            log "$package installed successfully."
        else
            log "$package is already installed. No changes needed."
        fi
    done

    log "Dependency check completed."
}

# Function to update sudoers
update_sudoers() {
    log "Updating sudoers."

    # Check if the line already exists in sudoers
    if sudo -E grep -q '^%sudo ALL=(ALL) NOPASSWD: ALL$' /etc/sudoers; then
        log "sudoers entry already exists. No changes needed."
    else
        # Replace the existing line
        sudo -E sed -E -i '/^%sudo/s/.*/%sudo ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
        log "sudoers entry updated successfully."
    fi
}

# Function to configure SSH settings and restart SSH service
configure_ssh() {
    log "Configuring SSH."

    # Check if AllowUsers line already exists
    if sudo -E grep -q '^AllowUsers dietpi mews$' /etc/ssh/sshd_config; then
        log "AllowUsers already configured. No changes needed."
    else
        # Ensure PermitRootLogin is set to no
        if sudo -E sed -E -i '/PermitRootLogin/s/^#?(PermitRootLogin).*/\1 no/' /etc/ssh/sshd_config; then
            log "PermitRootLogin set to no."
        else
            log "Failed to set PermitRootLogin to no. Check the configuration manually."
            return 1
        fi

        # Add AllowUsers line if it doesn't exist
        if sudo -E grep -q '^#AllowUsers' /etc/ssh/sshd_config; then
            if sudo -E sed -i '/^#AllowUsers/s/^#//' /etc/ssh/sshd_config; then
                log "AllowUsers line added."
            else
                log "Failed to uncomment AllowUsers line. Check the configuration manually."
                return 1
            fi
        else
            if echo "AllowUsers dietpi mews" | sudo tee -a /etc/ssh/sshd_config > /dev/null; then
                log "AllowUsers line added."
            else
                log "Failed to add AllowUsers line. Check the configuration manually."
                return 1
            fi
        fi

        # Restart SSH service only if changes were made
        if sudo -E systemctl is-active --quiet sshd && sudo -E systemctl restart sshd; then
            log "SSH service restarted successfully."
        else
            log "Failed to restart SSH service. Check the service manually."
            return 1
        fi

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

    # Ensure proper permissions on the SSH key file
    sudo -E chmod 600 "$KEY_FILE"
    sudo -E chmod 700 "$SSH_DIR"
}

# Function to create or update .bashrc file
create_bashrc() {
    log "Creating/updating .bashrc file."
    BASHRC_FILE="/home/$SUDO_USER/.bashrc"

    # Ensure home directory exists
    sudo -u $SUDO_USER mkdir -p $(dirname "$BASHRC_FILE")

    # .bashrc content
    cat <<'EOL' | sudo -u $SUDO_USER tee -a "$BASHRC_FILE" > /dev/null
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
}

create_bash_aliases() {
    log "Creating/updating .bash_aliases file."
    BASH_ALIASES_FILE="/home/$SUDO_USER/.bash_aliases"

    # List of aliases to be added
    aliases_to_add=$(cat <<'EOL'
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
)

    # Check if .bash_aliases file already exists
    if [ -f "$BASH_ALIASES_FILE" ]; then
        # Read existing content
        existing_content=$(sudo -u $SUDO_USER cat "$BASH_ALIASES_FILE")

        # Add aliases only if not present
        while read -r alias_line; do
            if ! grep -q "$alias_line" <<< "$existing_content"; then
                echo "$alias_line" | sudo -u $SUDO_USER tee -a "$BASH_ALIASES_FILE" > /dev/null
            fi
        done <<< "$aliases_to_add"

        log ".bash_aliases file updated successfully for user: $SUDO_USER."
    else
        # If .bash_aliases file doesn't exist, create it with the provided content
        echo "$aliases_to_add" | sudo -u $SUDO_USER tee "$BASH_ALIASES_FILE" > /dev/null

        log ".bash_aliases file created successfully for user: $SUDO_USER."
    fi
}

# Function to install snmpd package and create snmpd.conf file
install_snmpd() {
    log "Installing snmpd package."

    # Install snmpd package only if not already installed
    if ! dpkg -l | grep -q "^ii.*snmpd"; then
        sudo apt-get install -y snmpd
        log "Snmpd package installed successfully."
    else
        log "Snmpd package is already installed. No changes needed."
    fi

    # Create snmpd.conf file with specified content
    SNMPD_CONF_FILE="/etc/snmp/snmpd.conf"
    SNMPD_CONF_CONTENT=$(cat <<'EOL'
sysLocation    Sitting on the Dock of the Bay
sysContact     Me <me@example.org>
sysServices    72
master  agentx
agentaddress  udp:161
view   systemonly  included   .1.3.6.1.2.1.1
view   systemonly  included   .1.3.6.1.2.1.25.1
rocommunity martin
rouser authPrivUser authpriv -V systemonly
includeAllDisks  10%
extend uptime /bin/cat /proc/uptime
extend .1.3.6.1.4.1.2021.7890.1 distro /usr/local/bin/distro
#Regular Linux:
extend .1.3.6.1.4.1.2021.7890.2 hardware /bin/cat /sys/devices/virtual/dmi/id/product_name
extend .1.3.6.1.4.1.2021.7890.3 vendor   /bin/cat /sys/devices/virtual/dmi/id/sys_vendor
extend .1.3.6.1.4.1.2021.7890.4 serial   /bin/cat /sys/devices/virtual/dmi/id/product_serial
# Raspberry Pi:
#extend .1.3.6.1.4.1.2021.7890.2 hardware /bin/cat /proc/device-tree/model
#extend .1.3.6.1.4.1.2021.7890.4 serial   /bin/cat /proc/device-tree/serial-number
EOL
)

    if [ -f "$SNMPD_CONF_FILE" ]; then
        log "snmpd.conf file already exists. Overwriting with the new content."
        echo "$SNMPD_CONF_CONTENT" | sudo tee "$SNMPD_CONF_FILE" > /dev/null
    else
        echo "$SNMPD_CONF_CONTENT" | sudo tee "$SNMPD_CONF_FILE" > /dev/null
        log "snmpd.conf file created successfully at $SNMPD_CONF_FILE."
    fi

    # Ensure proper ownership of snmpd.conf file
    sudo chown root:root "$SNMPD_CONF_FILE"
    log "Ownership of $SNMPD_CONF_FILE set to root:root."
}

# Call the functions
run_apt_update_upgrade
update_sudoers
configure_ssh
generate_ssh_key
create_bashrc
create_bash_aliases
install_snmpd

# Source .bashrc and .bash_aliases to apply changes immediately
source "/home/$SUDO_USER/.bashrc"
source "/home/$SUDO_USER/.bash_aliases"

log "Script execution completed."
