#!/bin/bash

# Author: mews_se
# Description:
#   This Bash script automates several system configuration tasks
#   to enhance user experience and bolster security. It begins by updating
#   system packages to ensure the latest security patches and software
#   enhancements are applied. The script then proceeds to configure sudo
#   permissions, optimizing user management and system administration.
#   
#   SSH settings are adjusted to restrict root login and define
#   specific users allowed SSH access, improving overall system security.
#   Additionally, the script generates an SSH key pair without a passphrase,
#   facilitating secure authentication between systems.
#   
#   To streamline command-line interactions, the script customizes the .bashrc
#   and .bash_aliases files. These configurations include personalized prompts,
#   command history settings, and useful aliases for frequently used commands.
#   
#   Beyond basic system setup, the script extends its functionality to include
#   the installation and configuration of SNMPD (Simple Network Management
#   Protocol Daemon) and Docker. SNMPD facilitates network monitoring by
#   providing access to system metrics, while Docker simplifies application
#   deployment through containerization technology.
# 
# Disclaimer:
#   This script is authored and maintained for personal use by the author. Users
#   are encouraged to carefully review the code and comprehend its operations
#   before executing any commands. It is advisable to test the script in a
#   controlled, non-production environment to evaluate its impact and
#   functionality specific to your system configuration.
#   
#   The author assumes no responsibility for any unintended consequences,
#   including but not limited to data loss, system downtime, or security
#   breaches, resulting from the use of this script. By executing the script,
#   users acknowledge and accept these risks.
#   
#   For critical systems or environments with unique configurations, consider
#   adapting the script to suit specific requirements and conducting thorough
#   testing prior to deployment.

# List of required commands
required_commands=("sudo" "apt" "sed" "ssh-keygen" "systemctl" "dpkg" "curl")

# Check if all required commands are available
for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd command not found. Please make sure it's installed and in your PATH." >&2
        exit 1
    fi
done

# Function log: Logs messages with timestamp
log() {
    local message="$(date '+%Y-%m-%d %H:%M:%S') $1"
    echo "$message"
}

log "Script execution started."

# Function to perform system update and upgrade
system_update_upgrade() {
    log "Running system update and upgrade."

    # Update package lists
    if ! sudo apt update; then
        log "Error: Failed to update package lists."
        exit 1
    fi

    # Perform a full upgrade
    if ! sudo apt full-upgrade -y; then
        log "Error: Failed to perform full upgrade."
        exit 1
    fi

    log "Apt update and full-upgrade completed successfully."
}

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

# Function to configure SSH settings
configure_ssh() {
    log "Configuring SSH."

    # Check if AllowUsers line already exists
    if sudo grep -q '^AllowUsers dietpi mews$' /etc/ssh/sshd_config; then
        log "AllowUsers already configured. No changes needed."
    else
        # Ensure PermitRootLogin is set to no
        if sudo sed -E -i '/PermitRootLogin/s/^#?(PermitRootLogin).*/\1 no/' /etc/ssh/sshd_config; then
            log "PermitRootLogin set to no."
        else
            log "Failed to set PermitRootLogin to no. Check the configuration manually."
            return 1
        fi

        # Add AllowUsers line directly below PermitRootLogin if it doesn't exist
        if sudo sed -E -i '/PermitRootLogin/a AllowUsers dietpi mews' /etc/ssh/sshd_config; then
            log "AllowUsers line added directly below PermitRootLogin."
        else
            log "Failed to add AllowUsers line. Check the configuration manually."
            return 1
        fi

        # Restart SSH service only if changes were made
        if sudo systemctl is-active --quiet sshd && sudo systemctl restart sshd; then
            log "SSH service restarted successfully."
        else
            log "Failed to restart SSH service. Check the service manually."
            return 1
        fi

        log "SSH configuration updated successfully."
    fi
}

# Function to generate SSH key
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

    # Remove .bashrc if it exists
    if [ -f "$BASHRC_FILE" ]; then
        sudo -u $SUDO_USER rm "$BASHRC_FILE"
        log "Removed existing .bashrc file."
    fi

    # Ensure home directory exists
    sudo -u $SUDO_USER mkdir -p "$(dirname "$BASHRC_FILE")"

    # .bashrc content
    cat <<EOL | sudo -u $SUDO_USER tee -a "$BASHRC_FILE" > /dev/null
case \$- in
    *i*) ;;
    *) return;;
esac

HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize

if [ -z "\${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=\$(cat /etc/debian_chroot)
fi

case "\$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

force_color_prompt=yes

if [ -n "\$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "\$color_prompt" = yes ]; then
    PS1='\${debian_chroot:+(\$debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w \$\[\033[00m\] '
else
    PS1='\${debian_chroot:+(\$debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

case "\$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;\${debian_chroot:+(\$debian_chroot)}\u@\h: \w\a\]\$PS1"
    ;;
*)
    ;;
esac

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "\$(dircolors -b ~/.dircolors)" || eval "\$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

if [ -f ~/.bash_aliases ]; then
    source ~/.bash_aliases
fi
EOL

    log ".bashrc file created/updated successfully for user: $SUDO_USER."
}

# Function to create or update .bash_aliases file
create_bash_aliases() {
    log "Creating/updating .bash_aliases file."
    BASH_ALIASES_FILE="/home/$SUDO_USER/.bash_aliases"

    # Remove .bash_aliases if it exists
    if [ -f "$BASH_ALIASES_FILE" ]; then
        sudo -u $SUDO_USER rm "$BASH_ALIASES_FILE"
        log "Removed existing .bash_aliases file."
    fi

    # List of aliases to be added
    aliases_to_add=$(cat <<'EOL'
alias apta="sudo apt update && sudo apt full-upgrade && sudo apt autoremove -y && sudo apt clean"
alias sen="watch -n 1 sensors"
alias reb="sudo reboot"
alias dcupd="docker compose up -d"
alias dcupdlog="docker compose up -d && docker compose logs -f"
alias dclog="docker compose logs -f"
alias dcpull="docker compose pull"
alias dcstop="docker compose stop"
alias dcdown="docker compose down"
alias fanoff="sudo systemctl stop fancontrol.service"
alias fanon="sudo systemctl start fancontrol.service"
alias kodipi="ssh dietpi@10.0.0.7"
alias dellpi="ssh dietpi@10.0.0.6"
alias brkpi="ssh dietpi@192.168.1.3"
alias optiplex="ssh mews@192.168.1.6"
alias pfsensebrk="ssh -p 2221 admin@192.168.1.1"
alias pfsense="ssh -p 2221 admin@10.0.0.1"
alias newyork="ssh dietpi@newyork.stockzell.se"
alias flight="ssh root@192.168.1.123"
alias london="ssh dietpi@london.stockzell.se"
alias nyc="ssh dietpi@nyc.stockzell.se"
alias ned="ssh dietpi@ned.stockzell.se"
alias tb="ssh dietpi@10.0.0.97"
alias prox="ssh root@10.0.0.99"
alias proxtor="ssh dietpi@10.0.0.97"
alias teslamate="ssh dietpi@10.0.0.14"
alias testpi="ssh dietpi@10.0.0.8"
alias ff="fastfetch -c all.jsonc"
alias docker-clean=' \
  docker container prune -f ; \
  docker image prune -f ; \
  docker network prune -f ; \
  docker volume prune -f '
EOL
)

    # If .bash_aliases file doesn't exist, create it with the provided content
    echo "$aliases_to_add" | sudo -u $SUDO_USER tee "$BASH_ALIASES_FILE" > /dev/null

    log ".bash_aliases file created/updated successfully for user: $SUDO_USER."
}

# Function to install and configure SNMPD
install_configure_snmpd() {
    log "Installing and configuring SNMPD."

    # Install lm-sensors package if not already installed
    if ! dpkg -l | grep -q "^ii.*lm-sensors"; then
        sudo apt-get install -y lm-sensors
        log "lm-sensors package installed successfully."
    else
        log "lm-sensors package is already installed. No changes needed."
    fi

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
#extend .1.3.6.1.4.1.2021.7890.2 hardware /bin/cat /sys/devices/virtual/dmi/id/product_name
#extend .1.3.6.1.4.1.2021.7890.3 vendor   /bin/cat /sys/devices/virtual/dmi/id/sys_vendor
#extend .1.3.6.1.4.1.2021.7890.4 serial   /bin/cat /sys/devices/virtual/dmi/id/product_serial
# Raspberry Pi:
extend .1.3.6.1.4.1.2021.7890.2 hardware /bin/cat /proc/device-tree/model
extend .1.3.6.1.4.1.2021.7890.4 serial   /bin/cat /proc/device-tree/serial-number
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

    # Reload SNMPD service
    if sudo systemctl is-active --quiet snmpd && sudo systemctl reload snmpd; then
        log "SNMPD service reloaded successfully."
    else
        log "Failed to reload SNMPD service. Check the service manually."
        return 1
    fi
}

# Function to install Docker repository
install_docker_repository() {
    log "Installing Docker repository."

    # Add Docker's official GPG key:
    sudo apt update
    sudo apt install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update

    log "Docker repository installed successfully."
}

# Function to install Docker CE and related tools
install_docker_ce() {
    log "Installing Docker CE and related tools."

    # Install Docker CE and tools
    sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras -y
    sudo usermod -aG docker $SUDO_USER

    log "Docker CE and tools installed successfully. User added to the group docker"
}

# Function to run all tasks
run_all_tasks() {
    system_update_upgrade
    update_sudoers
    configure_ssh
    generate_ssh_key
    create_bashrc
    create_bash_aliases
    install_configure_snmpd
    install_docker_repository
    install_docker_ce
}

# Main menu function
main_menu() {
    while true; do
        clear
        echo "#####################################"
        echo "#   Automated System Configuration  #"
        echo "#####################################"
        echo "Please select an option:"
        echo "  1) System Update and Upgrade"
        echo "  2) Update sudoers"
        echo "  3) Configure SSH"
        echo "  4) Generate SSH Key"
        echo "  5) Create/Update .bashrc"
        echo "  6) Create/Update .bash_aliases"
        echo "  7) Install and Configure SNMPD"
        echo "  8) Install Docker official repo"
        echo "  9) Install Docker and relevant tools"
        echo "  10) Run all tasks"
        echo "  11) Exit"

        read -rp "Enter your choice: " choice

        case $choice in
            1) system_update_upgrade ;;
            2) update_sudoers ;;
            3) configure_ssh ;;
            4) generate_ssh_key ;;
            5) create_bashrc ;;
            6) create_bash_aliases ;;
            7) install_configure_snmpd ;;
            8) install_docker_repository ;;
            9) install_docker_ce ;;
            10) run_all_tasks ;;
            11)
                log "Script execution completed."
                log "Please apply the following command manually to source both .bashrc and .bash_aliases files:"
                echo " . /home/$SUDO_USER/.bashrc && . /home/$SUDO_USER/.bash_aliases"
                echo "Alternatively, you can log out and log back in to start a new shell session."
                exit 0
                ;;
            *)
                echo "Invalid choice. Please select a valid option."
                ;;
        esac

        read -rp "Press Enter to continue..."
    done
}

# Execute the main menu function
main_menu
