#!/bin/bash
###############################################################################
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
###############################################################################

set -euo pipefail

###############################################################################
# Trap signals for a graceful exit
###############################################################################
trap 'echo "Script interrupted. Exiting..."; exit 1' SIGINT SIGTERM

###############################################################################
# Validate environment: SUDO_USER must be set.
###############################################################################
if [ -z "${SUDO_USER:-}" ]; then
    echo "Error: SUDO_USER is not set. Please run this script with sudo." >&2
    exit 1
fi

###############################################################################
# LOG FUNCTION
###############################################################################
log() {
    # Usage: log "Message" ["LEVEL"]
    # LEVEL can be INFO, WARN, ERROR, etc. Defaults to INFO.
    local message="$1"
    local level="${2:-INFO}"
    if [ "$level" = "ERROR" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message" >&2
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message"
    fi
}

###############################################################################
# OPTIONAL: CHECK_COMMAND FUNCTION
###############################################################################
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log "Command '$cmd' not found. Please install it before proceeding." "ERROR"
        return 1
    else
        log "Command '$cmd' is available." "INFO"
        return 0
    fi
}

###############################################################################
# INSTALL REQUIRED PACKAGES
# (Uses parallel installation with fallback to one-by-one)
###############################################################################

# List of required commands and corresponding packages (using apt-get consistently)
declare -A required_commands=(
    [sudo]="sudo"
    [apt-get]="apt-get"
    [sed]="sed"
    [ssh-keygen]="openssh-client"
    [systemctl]="systemd"
    [dpkg]="dpkg"
    [curl]="curl"
    [git]="git"
    [nc]="netcat-traditional"
)

# Find missing commands
missing_packages=()
for cmd in "${!required_commands[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        missing_packages+=("${required_commands[$cmd]}")
    else
        log "$cmd is already installed."
    fi
done

# If we have any missing packages, install them
if [ "${#missing_packages[@]}" -gt 0 ]; then
    log "Installing missing packages: ${missing_packages[*]}"

    # Update apt-get before installation
    if ! sudo apt-get update; then
        log "Error updating package lists. Please check your sources and network." "ERROR"
        exit 1
    fi

    # Attempt parallel installation first
    failed_packages=()
    if ! echo "${missing_packages[@]}" | xargs -n1 -P9 sudo apt-get install -y; then
        log "Parallel installation failed. Retrying packages one by one..." "WARN"

        # Fallback: Install packages one by one
        for pkg in "${missing_packages[@]}"; do
            if ! sudo apt-get install -y "$pkg"; then
                failed_packages+=("$pkg")
                log "Error: Failed to install $pkg even after retry." "ERROR"
            else
                log "Successfully installed $pkg after retry."
            fi
        done

        # Final check for any packages that still failed
        if [ "${#failed_packages[@]}" -gt 0 ]; then
            log "The following packages could not be installed: ${failed_packages[*]}" "ERROR"
            exit 1
        fi
    else
        log "Parallel installation successful."
    fi
else
    log "All required packages are already installed."
fi

# Double-check installation
for cmd in "${!required_commands[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        log "Critical Error: $cmd is still not available after all installation attempts. Exiting." "ERROR"
        exit 1
    fi
done

log "All required commands are now available."

###############################################################################
# MAIN SCRIPT FUNCTIONS
###############################################################################
log "Script execution started."

###############################################################################
# FUNCTION: system_update_upgrade
###############################################################################
system_update_upgrade() {
    log "Running system update and upgrade."

    # Proxy configuration file path
    local proxy_config="/etc/apt/apt.conf.d/02proxy"

    # Check if the proxy server is reachable
    if nc -w1 -z 10.0.0.20 3142; then
        log "Proxy server is reachable. Configuring proxy for APT."
        # Add or update proxy configuration
        if [ ! -f "$proxy_config" ] || ! grep -q "10.0.0.20:3142" "$proxy_config"; then
            log "Adding proxy configuration to $proxy_config."
            sudo tee "$proxy_config" > /dev/null <<EOF
Acquire::http::Proxy "http://10.0.0.20:3142";
Acquire::https::Proxy "http://10.0.0.20:3142";
EOF
        else
            log "Proxy configuration already exists in $proxy_config."
        fi
    else
        log "Warning: Proxy server is not reachable. Commenting out proxy configuration." "WARN"
        if [ -f "$proxy_config" ]; then
            sudo sed -i 's|^Acquire::http::Proxy|# Acquire::http::Proxy|' "$proxy_config"
            sudo sed -i 's|^Acquire::https::Proxy|# Acquire::https::Proxy|' "$proxy_config"
        fi
    fi

    # Update package lists (using apt-get)
    if ! sudo apt-get update; then
        log "Error: Failed to update package lists." "ERROR"
        exit 1
    fi

    # Perform a full upgrade (using dist-upgrade for apt-get)
    if ! sudo apt-get dist-upgrade -y; then
        log "Error: Failed to perform full upgrade." "ERROR"
        exit 1
    fi

    log "apt-get update and dist-upgrade completed successfully."
}

###############################################################################
# FUNCTION: update_sudoers
###############################################################################
update_sudoers() {
    log "Updating sudoers."

    local sudoers_file="/etc/sudoers"
    # Backup sudoers file before modification
    sudo cp "$sudoers_file" "${sudoers_file}.bak_$(date +%F_%T)"

    # Check if the line already exists in sudoers
    if sudo grep -q '^%sudo ALL=(ALL) NOPASSWD: ALL$' "$sudoers_file"; then
        log "sudoers entry already exists. No changes needed."
    else
        # Replace the existing line
        if sudo sed -E -i '/^%sudo/s/.*/%sudo ALL=(ALL) NOPASSWD: ALL/' "$sudoers_file"; then
            log "sudoers entry updated successfully."
        else
            log "Failed to update sudoers entry. Check configuration manually." "ERROR"
            return 1
        fi
    fi
}

###############################################################################
# FUNCTION: configure_ssh
###############################################################################
configure_ssh() {
    log "Configuring SSH."

    local sshd_config="/etc/ssh/sshd_config"
    # Backup sshd_config before modification
    sudo cp "$sshd_config" "${sshd_config}.bak_$(date +%F_%T)"

    # Check if AllowUsers line already exists
    if sudo grep -q '^AllowUsers dietpi mews$' "$sshd_config"; then
        log "AllowUsers already configured. No changes needed."
    else
        # Ensure PermitRootLogin is set to no
        if sudo sed -E -i '/PermitRootLogin/s/^#?(PermitRootLogin).*/\1 no/' "$sshd_config"; then
            log "PermitRootLogin set to no."
        else
            log "Failed to set PermitRootLogin to no. Check configuration manually." "ERROR"
            return 1
        fi

        # Add AllowUsers line directly below PermitRootLogin if it doesn't exist
        if sudo sed -E -i '/PermitRootLogin/a AllowUsers dietpi mews' "$sshd_config"; then
            log "AllowUsers line added directly below PermitRootLogin."
        else
            log "Failed to add AllowUsers line. Check configuration manually." "ERROR"
            return 1
        fi

        # Restart SSH service only if changes were made
        if sudo systemctl is-active --quiet sshd && sudo systemctl restart sshd; then
            log "SSH service restarted successfully."
        else
            log "Failed to restart SSH service. Check the service manually." "ERROR"
            return 1
        fi

        log "SSH configuration updated successfully."
    fi
}

###############################################################################
# FUNCTION: generate_ssh_key
###############################################################################
generate_ssh_key() {
    log "Generating SSH key."

    local SSH_DIR="/home/$SUDO_USER/.ssh"
    local KEY_FILE="$SSH_DIR/id_ed25519"

    # Check if an SSH key already exists
    if [ -f "$KEY_FILE" ]; then
        log "SSH key already exists for $SUDO_USER. Skipping generation."
    else
        # Force create .ssh folder
        sudo -u "$SUDO_USER" mkdir -p "$SSH_DIR"

        # Generate a new Ed25519 SSH key without passphrase
        sudo -u "$SUDO_USER" ssh-keygen -t ed25519 -f "$KEY_FILE" -N ""
        log "Ed25519 SSH key generated successfully."
    fi

    # Ensure proper permissions on the SSH key file and directory
    sudo -E chmod 600 "$KEY_FILE"
    sudo -E chmod 700 "$SSH_DIR"
}

###############################################################################
# FUNCTION: create_bashrc
###############################################################################
create_bashrc() {
    log "Creating/updating .bashrc file."

    local BASHRC_FILE="/home/$SUDO_USER/.bashrc"

    # Backup existing .bashrc if it exists
    if [ -f "$BASHRC_FILE" ]; then
        sudo -u "$SUDO_USER" cp "$BASHRC_FILE" "${BASHRC_FILE}.bak_$(date +%F_%T)"
        sudo -u "$SUDO_USER" rm "$BASHRC_FILE"
        log "Removed existing .bashrc file (backup created)."
    fi

    # Ensure home directory exists
    sudo -u "$SUDO_USER" mkdir -p "$(dirname "$BASHRC_FILE")"

    # .bashrc content
    cat <<'EOL' | sudo -u "$SUDO_USER" tee -a "$BASHRC_FILE" > /dev/null
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
    source ~/.bash_aliases
fi
EOL

    log ".bashrc file created/updated successfully for user: $SUDO_USER."
}

###############################################################################
# FUNCTION: create_bash_aliases
###############################################################################
create_bash_aliases() {
    log "Creating/updating .bash_aliases file."

    local BASH_ALIASES_FILE="/home/$SUDO_USER/.bash_aliases"

    # Backup existing .bash_aliases if it exists
    if [ -f "$BASH_ALIASES_FILE" ]; then
        sudo -u "$SUDO_USER" cp "$BASH_ALIASES_FILE" "${BASH_ALIASES_FILE}.bak_$(date +%F_%T)"
        sudo -u "$SUDO_USER" rm "$BASH_ALIASES_FILE"
        log "Removed existing .bash_aliases file (backup created)."
    fi

    # List of aliases to be added (duplicate alias for 'prox' removed)
    local aliases_to_add=$(cat <<'EOL'
alias apta="sudo apt-get update && sudo apt-get full-upgrade && sudo apt-get autoremove -y && sudo apt-get clean"
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
alias brkpi="ssh dietpi@10.0.1.8"
alias optiplex="ssh mews@192.168.1.6"
alias pfsensebrk="ssh -p 2221 admin@192.168.1.1"
alias pfsense="ssh -p 2221 admin@10.0.0.1"
alias pfsensebrk2="ssh -p 2221 admin@10.0.1.1"
alias mm="ssh martin@10.0.0.11"
alias prox="ssh root@10.0.0.99"
alias flight="ssh root@192.168.1.123"
alias london="ssh dietpi@london.stockzell.se"
alias nyc="ssh dietpi@nyc.stockzell.se"
alias tb="ssh dietpi@10.0.0.97"
alias brk2="ssh dietpi@10.0.1.7"
alias teslamate="ssh dietpi@10.0.0.14"
alias testpi="ssh dietpi@10.0.0.8"
alias testpi5="ssh dietpi@10.0.0.17"
alias ff="fastfetch -c all.jsonc"
alias fa="fastfetch"
alias barseback="ssh dietpi@barseback.karnkraft.org"
alias wolnas="wakeonlan 90:09:d0:1f:95:b7"
alias docker-clean=' \
  docker container prune -f ; \
  docker image prune -f ; \
  docker network prune -f ; \
  docker volume prune -f '
EOL
)

    # Create/append the .bash_aliases file
    echo "$aliases_to_add" | sudo -u "$SUDO_USER" tee "$BASH_ALIASES_FILE" > /dev/null

    log ".bash_aliases file created/updated successfully for user: $SUDO_USER."
}

###############################################################################
# FUNCTION: install_configure_snmpd
###############################################################################
install_configure_snmpd() {
    log "Installing and configuring SNMPD."

    # Install lm-sensors package if not already installed
    if ! dpkg -l | grep -q "^ii.*lm-sensors"; then
        sudo apt-get install -y lm-sensors
        log "lm-sensors package installed successfully."
    else
        log "lm-sensors package is already installed. No changes needed."
    fi

    # Install snmpd package if not already installed
    if ! dpkg -l | grep -q "^ii.*snmpd"; then
        sudo apt-get install -y snmpd
        log "Snmpd package installed successfully."
    else
        log "Snmpd package is already installed. No changes needed."
    fi

    local SNMPD_CONF_FILE="/etc/snmp/snmpd.conf"
    # Backup existing snmpd.conf if it exists
    if [ -f "$SNMPD_CONF_FILE" ]; then
        sudo cp "$SNMPD_CONF_FILE" "${SNMPD_CONF_FILE}.bak_$(date +%F_%T)"
        log "Existing snmpd.conf backed up."
    fi

    # Create snmpd.conf file with specified content
    local SNMPD_CONF_CONTENT
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

    # Ensure proper ownership
    sudo chown root:root "$SNMPD_CONF_FILE"
    log "Ownership of $SNMPD_CONF_FILE set to root:root."

    # Reload SNMPD service
    if sudo systemctl is-active --quiet snmpd && sudo systemctl reload snmpd; then
        log "SNMPD service reloaded successfully."
    else
        log "Failed to reload SNMPD service. Check the service manually." "ERROR"
        return 1
    fi
}

###############################################################################
# FUNCTION: install_docker_repository
###############################################################################
install_docker_repository() {
    log "Installing Docker repository."

    # Update apt-get and install prerequisites
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl

    # Create keyrings directory if needed
    sudo install -m 0755 -d /etc/apt/keyrings

    # Add Docker's GPG key
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the Docker repository to Apt sources
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update package lists after repository addition
    sudo apt-get update

    log "Docker repository installed successfully."
}

###############################################################################
# FUNCTION: install_docker_ce
###############################################################################
install_docker_ce() {
    log "Installing Docker CE and related tools."

    # Install Docker CE and plugins
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
                           docker-buildx-plugin docker-compose-plugin \
                           docker-ce-rootless-extras
    sudo usermod -aG docker "$SUDO_USER"

    log "Docker CE and tools installed successfully. User added to group 'docker'."
}

###############################################################################
# FUNCTION: clone_fastfetch_repository
###############################################################################
clone_fastfetch_repository() {
    log "Cloning GitHub repository update-fastfetch."

    local REPO_URL="https://github.com/mews-se/update-fastfetch.git"
    local DEST_DIR="/home/$SUDO_USER/update-fastfetch"

    # Check if the directory already exists
    if [ -d "$DEST_DIR" ]; then
        log "Repository already exists at $DEST_DIR. Skipping cloning."
    else
        # Clone the repository
        if sudo -u "$SUDO_USER" git clone "$REPO_URL" "$DEST_DIR"; then
            log "Repository cloned successfully to $DEST_DIR."
        else
            log "Failed to clone repository. Check the URL or network connection." "ERROR"
            return 1
        fi
    fi
}

###############################################################################
# FUNCTION: run_all_tasks
###############################################################################
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
    clone_fastfetch_repository

    summary_report
}

###############################################################################
# FUNCTION: summary_report
###############################################################################
summary_report() {
    log "Summary Report:"
    log "--------------"
    log "System Update & Upgrade: Completed"
    log "Sudoers: Updated"
    log "SSH: Configured"
    log "SSH Key: Generated/Verified"
    log ".bashrc & .bash_aliases: Created/Updated"
    log "SNMPD: Installed/Configured"
    log "Docker: Repository Added & Docker CE Installed"
    log "Fastfetch Repo: Cloned (if it didn't already exist)"
    log "--------------"
    log "All tasks completed."
}

###############################################################################
# MAIN MENU
###############################################################################
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
        echo "  10) Clone the update-fastfetch repo"
        echo "  11) Run all tasks"
        echo "  12) Exit"

        read -rp "Enter your choice: " choice

        case "$choice" in
            1) system_update_upgrade ;;
            2) update_sudoers ;;
            3) configure_ssh ;;
            4) generate_ssh_key ;;
            5) create_bashrc ;;
            6) create_bash_aliases ;;
            7) install_configure_snmpd ;;
            8) install_docker_repository ;;
            9) install_docker_ce ;;
            10) clone_fastfetch_repository ;;
            11) run_all_tasks ;;
            12)
                log "Script execution completed."
                log "Please apply the following command manually to source both .bashrc and .bash_aliases files:"
                echo ". /home/$SUDO_USER/.bashrc && . /home/$SUDO_USER/.bash_aliases"
                echo "Alternatively, log out and log back in to start a new shell session."
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
