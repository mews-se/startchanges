#!/bin/bash
###############################################################################
# Author: mews_se
# Description:
#   Unified multi-profile system bootstrap script for Debian/DietPi systems.
#
#   Profiles:
#     - x64
#     - x64-brk
#     - pi
#     - pi-brk
#
#   Features:
#     - Required package bootstrap
#     - System update & upgrade
#     - SSH hardening
#     - Passwordless sudo
#     - .bashrc recreation
#     - Interactive .bash_aliases merge/update
#     - SNMPD install (profile-aware)
#     - Docker install & removal
#     - PiVPN install + auto client configs + QR
#     - DietPi upgrade helpers
#     - Fastfetch repo clone
#     - Wake-on-LAN install
#     - NAS backup script generator
#     - Interactive menu
###############################################################################

set -euo pipefail

###############################################################################
# Trap signals for graceful exit
###############################################################################
trap 'echo "Script interrupted. Exiting..."; exit 1' SIGINT SIGTERM

###############################################################################
# Validate environment: SUDO_USER must be set
###############################################################################
if [ -z "${SUDO_USER:-}" ]; then
    echo "Error: SUDO_USER is not set. Please run this script with sudo." >&2
    exit 1
fi

###############################################################################
# FUNCTION: log
# Description: Timestamped log helper
###############################################################################
log() {
    local message="$1"
    local level="${2:-INFO}"
    if [ "$level" = "ERROR" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message" >&2
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message"
    fi
}

###############################################################################
# FUNCTION: check_command
# Description: Optional command existence check helper
###############################################################################
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log "Command '$cmd' not found. Please install it before proceeding." "ERROR"
        return 1
    else
        log "Command '$cmd' is available."
        return 0
    fi
}

###############################################################################
# FUNCTION: detect_default_profile
# Description: Detect a sensible default profile from CPU architecture
###############################################################################
detect_default_profile() {
    local arch
    arch="$(uname -m || true)"
    case "$arch" in
        arm*|aarch64) echo "pi" ;;
        *) echo "x64" ;;
    esac
}

###############################################################################
# FUNCTION: select_profile
# Description: Original interactive profile selection UI
###############################################################################
PROFILE=""

select_profile() {
    local default_profile
    default_profile="$(detect_default_profile)"

    clear
    echo "#####################################"
    echo "#         Profile Selection         #"
    echo "#####################################"
    echo "Detected default: $default_profile"
    echo ""
    echo "Select which machine type this is:"
    echo "  1) x64"
    echo "  2) x64-brk"
    echo "  3) pi"
    echo "  4) pi-brk"
    echo "  5) Use detected default ($default_profile)"
    echo ""

    read -rp "Enter your choice: " pchoice
    case "$pchoice" in
        1) PROFILE="x64" ;;
        2) PROFILE="x64-brk" ;;
        3) PROFILE="pi" ;;
        4) PROFILE="pi-brk" ;;
        5|"") PROFILE="$default_profile" ;;
        *) log "Invalid profile choice. Using detected default: $default_profile" "WARN"; PROFILE="$default_profile" ;;
    esac

    log "Profile selected: $PROFILE"
}

###############################################################################
# PROFILE VARIABLES
# Description: Variables that differ between profile types
###############################################################################
SNMP_ROCOMMUNITY=""
SNMP_HARDWARE_EXTENDS=""

###############################################################################
# FUNCTION: apply_profile_config
# Description: Apply per-profile SNMP settings
###############################################################################
apply_profile_config() {
    case "$PROFILE" in
        x64)
            SNMP_ROCOMMUNITY="martin"
            SNMP_HARDWARE_EXTENDS=$(cat <<'EOL'
#Regular Linux:
extend .1.3.6.1.4.1.2021.7890.2 hardware /bin/cat /sys/devices/virtual/dmi/id/product_name
extend .1.3.6.1.4.1.2021.7890.3 vendor   /bin/cat /sys/devices/virtual/dmi/id/sys_vendor
extend .1.3.6.1.4.1.2021.7890.4 serial   /bin/cat /sys/devices/virtual/dmi/id/product_serial
# Raspberry Pi:
#extend .1.3.6.1.4.1.2021.7890.2 hardware /bin/cat /proc/device-tree/model
#extend .1.3.6.1.4.1.2021.7890.4 serial   /bin/cat /proc/device-tree/serial-number
EOL
)
            ;;
        x64-brk)
            SNMP_ROCOMMUNITY="brk"
            SNMP_HARDWARE_EXTENDS=$(cat <<'EOL'
#Regular Linux:
extend .1.3.6.1.4.1.2021.7890.2 hardware /bin/cat /sys/devices/virtual/dmi/id/product_name
extend .1.3.6.1.4.1.2021.7890.3 vendor   /bin/cat /sys/devices/virtual/dmi/id/sys_vendor
extend .1.3.6.1.4.1.2021.7890.4 serial   /bin/cat /sys/devices/virtual/dmi/id/product_serial
# Raspberry Pi:
#extend .1.3.6.1.4.1.2021.7890.2 hardware /bin/cat /proc/device-tree/model
#extend .1.3.6.1.4.1.2021.7890.4 serial   /bin/cat /proc/device-tree/serial-number
EOL
)
            ;;
        pi)
            SNMP_ROCOMMUNITY="martin"
            SNMP_HARDWARE_EXTENDS=$(cat <<'EOL'
#Regular Linux:
#extend .1.3.6.1.4.1.2021.7890.2 hardware /bin/cat /sys/devices/virtual/dmi/id/product_name
#extend .1.3.6.1.4.1.2021.7890.3 vendor   /bin/cat /sys/devices/virtual/dmi/id/sys_vendor
#extend .1.3.6.1.4.1.2021.7890.4 serial   /bin/cat /sys/devices/virtual/dmi/id/product_serial
# Raspberry Pi:
extend .1.3.6.1.4.1.2021.7890.2 hardware /bin/cat /proc/device-tree/model
extend .1.3.6.1.4.1.2021.7890.4 serial   /bin/cat /proc/device-tree/serial-number
EOL
)
            ;;
        pi-brk)
            SNMP_ROCOMMUNITY="brk"
            SNMP_HARDWARE_EXTENDS=$(cat <<'EOL'
#Regular Linux:
#extend .1.3.6.1.4.1.2021.7890.2 hardware /bin/cat /sys/devices/virtual/dmi/id/product_name
#extend .1.3.6.1.4.1.2021.7890.3 vendor   /bin/cat /sys/devices/virtual/dmi/id/sys_vendor
#extend .1.3.6.1.4.1.2021.7890.4 serial   /bin/cat /sys/devices/virtual/dmi/id/product_serial
# Raspberry Pi:
extend .1.3.6.1.4.1.2021.7890.2 hardware /bin/cat /proc/device-tree/model
extend .1.3.6.1.4.1.2021.7890.4 serial   /bin/cat /proc/device-tree/serial-number
EOL
)
            ;;
        *)
            log "Unknown profile '$PROFILE'. Valid: x64, x64-brk, pi, pi-brk" "ERROR"
            exit 1
            ;;
    esac
}

###############################################################################
# REQUIRED COMMANDS / PACKAGE MAP
# Description: Commands to verify/install before running functions
###############################################################################
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
    [script]="bsdextrautils"
)

###############################################################################
# FUNCTION: install_missing_packages
# Description: Ensure all required commands/packages are available
###############################################################################
install_missing_packages() {
    local missing_packages=()
    local failed_packages=()
    local cmd pkg

    for cmd in "${!required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_packages+=("${required_commands[$cmd]}")
        else
            log "$cmd is already installed."
        fi
    done

    if [ "${#missing_packages[@]}" -gt 0 ]; then
        log "Installing missing packages: ${missing_packages[*]}"

        if ! sudo apt-get update; then
            log "Error updating package lists. Please check your sources and network." "ERROR"
            exit 1
        fi

        if ! echo "${missing_packages[@]}" | xargs -n1 -P9 sudo apt-get install -y; then
            log "Parallel installation failed. Retrying packages one by one..." "WARN"
            for pkg in "${missing_packages[@]}"; do
                if ! sudo apt-get install -y "$pkg"; then
                    failed_packages+=("$pkg")
                    log "Failed to install $pkg even after retry." "ERROR"
                else
                    log "Successfully installed $pkg after retry."
                fi
            done

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

    for cmd in "${!required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log "Critical Error: $cmd is still not available after installation attempts." "ERROR"
            exit 1
        fi
    done

    log "All required commands are now available."
}

###############################################################################
# FUNCTION: system_update_upgrade
# Description: Update package lists and perform full upgrade
###############################################################################
system_update_upgrade() {
    log "Running system update and upgrade."
    sudo apt-get update
    sudo apt-get dist-upgrade -y
    log "System update and upgrade completed successfully."
}

###############################################################################
# FUNCTION: dietpi_bullseye_to_bookworm
# Description: Run DietPi Bullseye -> Bookworm upgrade in a PTY
###############################################################################
dietpi_bullseye_to_bookworm() {
    log "DietPi upgrade: Bullseye -> Bookworm"
    script -qec "sudo bash -c \"\$(curl -sSf 'https://raw.githubusercontent.com/MichaIng/DietPi/dev/.meta/dietpi-bookworm-upgrade')\"" /dev/null
    log "DietPi upgrade Bullseye -> Bookworm finished."
}

###############################################################################
# FUNCTION: dietpi_bookworm_to_trixie
# Description: Run DietPi Bookworm -> Trixie upgrade in a PTY
###############################################################################
dietpi_bookworm_to_trixie() {
    log "DietPi upgrade: Bookworm -> Trixie"
    script -qec "sudo bash -c \"\$(curl -sSf 'https://raw.githubusercontent.com/MichaIng/DietPi/dev/.meta/dietpi-trixie-upgrade')\"" /dev/null
    log "DietPi upgrade Bookworm -> Trixie finished."
}

###############################################################################
# FUNCTION: update_sudoers
# Description: Enable passwordless sudo for the sudo group
###############################################################################
update_sudoers() {
    log "Updating sudoers."
    local sudoers_file="/etc/sudoers"
    sudo cp "$sudoers_file" "${sudoers_file}.bak_$(date +%F_%T)"

    if sudo grep -q '^%sudo ALL=(ALL) NOPASSWD: ALL$' "$sudoers_file"; then
        log "sudoers entry already exists. No changes needed."
    else
        sudo sed -E -i '/^%sudo/s/.*/%sudo ALL=(ALL) NOPASSWD: ALL/' "$sudoers_file"
        log "sudoers entry updated successfully."
    fi
}

###############################################################################
# FUNCTION: configure_ssh
# Description: Disable root SSH login and restrict allowed users
###############################################################################
configure_ssh() {
    log "Configuring SSH."
    local sshd_config="/etc/ssh/sshd_config"
    sudo cp "$sshd_config" "${sshd_config}.bak_$(date +%F_%T)"

    if sudo grep -q '^AllowUsers dietpi mews$' "$sshd_config"; then
        log "AllowUsers already configured. No changes needed."
        return 0
    fi

    sudo sed -E -i '/PermitRootLogin/s/^#?(PermitRootLogin).*/\1 no/' "$sshd_config"
    log "PermitRootLogin set to no."

    sudo sed -E -i '/PermitRootLogin/a AllowUsers dietpi mews' "$sshd_config"
    log "AllowUsers line added directly below PermitRootLogin."

    if sudo systemctl is-active --quiet sshd; then
        sudo systemctl restart sshd
        log "SSH service restarted successfully."
    else
        log "SSH service 'sshd' is not active (or service name differs). Restart manually if needed." "WARN"
    fi

    log "SSH configuration updated successfully."
}

###############################################################################
# FUNCTION: generate_ssh_key
# Description: Generate ed25519 SSH key for invoking sudo user
###############################################################################
generate_ssh_key() {
    log "Generating SSH key."

    local SSH_DIR="/home/$SUDO_USER/.ssh"
    local KEY_FILE="$SSH_DIR/id_ed25519"

    if [ -f "$KEY_FILE" ]; then
        log "SSH key already exists for $SUDO_USER. Skipping generation."
    else
        sudo -u "$SUDO_USER" mkdir -p "$SSH_DIR"
        sudo -u "$SUDO_USER" ssh-keygen -t ed25519 -f "$KEY_FILE" -N ""
        log "Ed25519 SSH key generated successfully."
    fi

    sudo chmod 600 "$KEY_FILE"
    sudo chmod 700 "$SSH_DIR"
}

###############################################################################
# FUNCTION: create_bashrc
# Description: Replace ~/.bashrc with curated default
###############################################################################
create_bashrc() {
    log "Creating/updating .bashrc file."

    local BASHRC_FILE="/home/$SUDO_USER/.bashrc"

    if [ -f "$BASHRC_FILE" ]; then
        sudo -u "$SUDO_USER" cp "$BASHRC_FILE" "${BASHRC_FILE}.bak_$(date +%F_%T)"
        sudo -u "$SUDO_USER" rm "$BASHRC_FILE"
        log "Removed existing .bashrc file (backup created)."
    fi

    sudo -u "$SUDO_USER" mkdir -p "$(dirname "$BASHRC_FILE")"

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
# Description: Merge curated aliases with optional retention of custom aliases
###############################################################################
create_bash_aliases() {
    log "Creating/updating .bash_aliases file with interactive review."

    local USER_HOME="/home/$SUDO_USER"
    local ALIASES_FILE="$USER_HOME/.bash_aliases"
    local BACKUP_FILE="$ALIASES_FILE.bak_$(date +%F_%T)"
    local TEMP_FILE
    TEMP_FILE=$(sudo -u "$SUDO_USER" mktemp "$USER_HOME/.bash_aliases.tmp.XXXXXX")

    local RED GREEN YELLOW CYAN NC
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'

    if [ -f "$ALIASES_FILE" ]; then
        sudo -u "$SUDO_USER" cp "$ALIASES_FILE" "$BACKUP_FILE"
        log "Backup created at $BACKUP_FILE"
    fi

    local NEW_ALIASES
    NEW_ALIASES=$(cat <<'EOL'
alias apta="sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get autoremove -y && sudo apt-get clean"
alias brkpi="ssh dietpi@10.0.1.8"
alias dcdown="docker compose down"
alias dclog="docker compose logs -f"
alias dcpull="docker compose pull"
alias dcstop="docker compose stop"
alias dcupd="docker compose up -d"
alias dcupdlog="docker compose up -d && docker compose logs -f"
alias dellpi="ssh dietpi@10.0.0.6"
alias fa="fastfetch"
alias fanoff="sudo systemctl stop fancontrol.service"
alias fanon="sudo systemctl start fancontrol.service"
alias ff="fastfetch -c all.jsonc"
alias flight="ssh root@10.0.1.12"
alias kodipi="ssh dietpi@10.0.0.7"
alias london="ssh dietpi@london.stockzell.se"
alias mm="ssh martin@10.0.0.11"
alias nyc="ssh dietpi@newyork.stockzell.se"
alias nyc2="ssh dietpi@newyork2.stockzell.se"
alias norway="ssh dietpi@norway.stockzell.se"
alias optiplex="ssh mews@10.0.1.6"
alias pfsense="ssh -p 2221 admin@10.0.0.1"
alias pfsensebrk="ssh -p 2221 admin@10.0.1.1"
alias pizerow="ssh dietpi@10.0.0.124"
alias prox="ssh root@10.0.0.99"
alias reb="sudo reboot"
alias sen="watch -n 1 sensors"
alias tb="ssh dietpi@10.0.0.97"
alias teslamate="ssh dietpi@10.0.0.14"
alias testpi="ssh dietpi@10.0.0.8"
alias testpi5="ssh dietpi@10.0.0.17"
alias woldellpi="wakeonlan 70:b5:e8:76:12:8d"
alias wolprox="wakeonlan c0:25:a5:94:75:ee"
alias woltb7="wakeonlan a8:5e:45:cd:db:cb"
alias wolmm="wakeonlan ac:87:a3:38:d0:00"
alias wolnas="wakeonlan 90:09:d0:1f:95:b7"
EOL
)

    declare -A new_aliases
    declare -A final_aliases

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*alias[[:space:]]+([^=]+)= ]]; then
            local name
            name="${BASH_REMATCH[1]}"
            new_aliases["$name"]="$line"
        fi
    done <<< "$NEW_ALIASES"

    local found_custom=false

    if [ -f "$ALIASES_FILE" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            if [[ "$line" =~ ^[[:space:]]*alias[[:space:]]+([^=]+)= ]]; then
                local alias_name existing_line response
                alias_name="${BASH_REMATCH[1]}"
                existing_line="$line"
                if [[ -z "${new_aliases[$alias_name]+exists}" ]]; then
                    found_custom=true
                    echo -e "\n${YELLOW}Found alias not in script: ${CYAN}$alias_name${NC}"
                    echo -e "  ${CYAN}$existing_line${NC}"
                    echo -ne "${YELLOW}Keep this alias? [Y/n]: ${NC}" > /dev/tty
                    read -r response < /dev/tty
                    read -t 0.1 -n 10000 discard < /dev/tty 2>/dev/null || true
                    if [[ -z "$response" || "$response" =~ ^[Yy]$ ]]; then
                        final_aliases["$alias_name"]="$existing_line"
                        echo -e "${GREEN}→ Keeping: $alias_name${NC}"
                    else
                        echo -e "${RED}→ Removed: $alias_name${NC}"
                    fi
                fi
            else
                echo "$line" >> "$TEMP_FILE"
            fi
        done < "$ALIASES_FILE"
    fi

    if [ "$found_custom" = false ]; then
        log "No custom aliases found for review."
    fi

    local alias
    for alias in "${!new_aliases[@]}"; do
        final_aliases["$alias"]="${new_aliases[$alias]}"
    done

    local alias_line
    for alias_line in "${final_aliases[@]}"; do
        echo "$alias_line"
    done | sort >> "$TEMP_FILE"

    sudo mv "$TEMP_FILE" "$ALIASES_FILE"
    sudo chown "$SUDO_USER:$SUDO_USER" "$ALIASES_FILE"
    log ".bash_aliases updated successfully with interactive selections and sorted output."
}

###############################################################################
# FUNCTION: install_configure_snmpd
# Description: Install SNMPD and write profile-specific configuration
###############################################################################
install_configure_snmpd() {
    log "Installing and configuring SNMPD."

    if ! dpkg -l | grep -q "^ii.*lm-sensors"; then
        sudo apt-get install -y lm-sensors
        log "lm-sensors package installed successfully."
    else
        log "lm-sensors package is already installed. No changes needed."
    fi

    if ! dpkg -l | grep -q "^ii.*snmpd"; then
        sudo apt-get install -y snmpd
        log "snmpd package installed successfully."
    else
        log "snmpd package is already installed. No changes needed."
    fi

    local SNMPD_CONF_FILE="/etc/snmp/snmpd.conf"
    if [ -f "$SNMPD_CONF_FILE" ]; then
        sudo cp "$SNMPD_CONF_FILE" "${SNMPD_CONF_FILE}.bak_$(date +%F_%T)"
        log "Existing snmpd.conf backed up."
    fi

    local SNMPD_CONF_CONTENT
    SNMPD_CONF_CONTENT=$(cat <<EOF
sysLocation    Sitting on the Dock of the Bay
sysContact     Me <me@example.org>
sysServices    72
master  agentx
agentaddress  udp:161
view   systemonly  included   .1.3.6.1.2.1.1
view   systemonly  included   .1.3.6.1.2.1.25.1
rocommunity ${SNMP_ROCOMMUNITY}
rouser authPrivUser authpriv -V systemonly
includeAllDisks  10%
extend uptime /bin/cat /proc/uptime
extend .1.3.6.1.4.1.2021.7890.1 distro /usr/local/bin/distro
${SNMP_HARDWARE_EXTENDS}
EOF
)

    echo "$SNMPD_CONF_CONTENT" | sudo tee "$SNMPD_CONF_FILE" > /dev/null
    log "snmpd.conf file created/overwritten successfully at $SNMPD_CONF_FILE."

    sudo chown root:root "$SNMPD_CONF_FILE"
    log "Ownership of $SNMPD_CONF_FILE set to root:root."

    if sudo systemctl is-active --quiet snmpd; then
        sudo systemctl reload snmpd
        log "SNMPD service reloaded successfully."
    else
        log "SNMPD service is not active; start/restart manually if needed." "WARN"
    fi
}

###############################################################################
# FUNCTION: install_docker_repository
# Description: Add Docker official repository
###############################################################################
install_docker_repository() {
    log "Installing Docker repository."

    sudo apt-get update
    sudo apt-get install -y ca-certificates curl

    sudo install -m 0755 -d /etc/apt/keyrings

    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    log "Docker repository installed successfully."
}

###############################################################################
# FUNCTION: install_pivpn
# Description: Install PiVPN via PTY and optionally create default clients
###############################################################################
install_pivpn() {
    log "Installing PiVPN."

    local tmp
    tmp="$(mktemp)"

    curl -fsSL https://install.pivpn.io -o "$tmp"
    script -qec "sudo bash '$tmp'" /dev/null
    rm -f "$tmp"

    log "PiVPN installation completed."

    echo
    read -rp "Create PiVPN configs? [Y/n]: " ans < /dev/tty
    if [[ -z "$ans" || "$ans" =~ ^[Yy]$ ]]; then
        create_pivpn_clients
    else
        log "Skipping PiVPN client creation."
    fi
}

###############################################################################
# FUNCTION: create_pivpn_clients
# Description: Create hostname-based clients and optionally show iPhone QR code
###############################################################################
create_pivpn_clients() {
    log "Creating PiVPN client configurations."

    local HOST
    HOST="$(hostname -s)"

    local CLIENTS=(
        "${HOST}-tb7"
        "${HOST}-mbp"
        "${HOST}-iph"
        "${HOST}-len"
    )

    local client
    for client in "${CLIENTS[@]}"; do
        if pivpn list | grep -q "$client"; then
            log "Exists: $client"
        else
            log "Creating client: $client"
            pivpn add -n "$client" -ip auto
        fi
    done

    echo
    read -rp "Show QR for ${HOST}-iph? [Y/n]: " qr < /dev/tty
    if [[ -z "$qr" || "$qr" =~ ^[Yy]$ ]]; then
        pivpn -qr "${HOST}-iph" < /dev/tty > /dev/tty 2>/dev/tty
    fi
}

###############################################################################
# FUNCTION: install_docker_ce
# Description: Install Docker Engine and related tools
###############################################################################
install_docker_ce() {
    log "Installing Docker CE and related tools."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
                           docker-buildx-plugin docker-compose-plugin \
                           docker-ce-rootless-extras
    sudo usermod -aG docker "$SUDO_USER"
    log "Docker CE and tools installed successfully. User added to group 'docker'."
}

###############################################################################
# FUNCTION: remove_docker_and_tools
# Description: Remove Docker packages, repo files, keys, and data directories
###############################################################################
remove_docker_and_tools() {
    log "Removing Docker CE and related tools."

    sudo apt purge -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin \
        docker-ce-rootless-extras

    sudo rm -f /etc/apt/sources.list.d/docker.sources
    sudo rm -f /etc/apt/sources.list.d/docker.list
    sudo rm -f /etc/apt/keyrings/docker.asc

    sudo rm -rf /var/lib/docker
    sudo rm -rf /var/lib/containerd

    log "Docker packages, repository configuration, and data directories removed."
}

###############################################################################
# FUNCTION: clone_fastfetch_repository
# Description: Clone update-fastfetch into the invoking user's home directory
###############################################################################
clone_fastfetch_repository() {
    log "Cloning GitHub repository update-fastfetch."

    local REPO_URL="https://github.com/mews-se/update-fastfetch.git"
    local DEST_DIR="/home/$SUDO_USER/update-fastfetch"

    if [ -d "$DEST_DIR" ]; then
        log "Repository already exists at $DEST_DIR. Skipping cloning."
    else
        sudo -u "$SUDO_USER" git clone "$REPO_URL" "$DEST_DIR"
        log "Repository cloned successfully to $DEST_DIR."
    fi
}

###############################################################################
# FUNCTION: install_wakeonlan
# Description: Install Wake-on-LAN tools
###############################################################################
install_wakeonlan() {
    log "Installing Wake-on-LAN tools."

    if dpkg -l | grep -q "^ii.*wakeonlan"; then
        log "wakeonlan is already installed. No changes needed."
    else
        if sudo apt-get install -y wakeonlan; then
            log "wakeonlan installed successfully."
        else
            log "Failed to install wakeonlan." "ERROR"
            return 1
        fi
    fi

    if command -v wakeonlan &>/dev/null; then
        log "wakeonlan command is available."
    else
        log "wakeonlan command not found after installation." "ERROR"
        return 1
    fi

    log "Wake-on-LAN setup completed."
}

###############################################################################
# FUNCTION: create_nas_backup_script
# Description: Generate standalone NAS backup script with DietPi-like filters
###############################################################################
create_nas_backup_script() {
    log "Creating NAS backup script."

    local backup_script="/home/$SUDO_USER/nas-backup.sh"
    local credentials_file="/root/.nas-credentials"
    local nas_username=""
    local nas_password=""

    if [ ! -f "$credentials_file" ]; then
        echo
        read -rp "Enter NAS username: " nas_username < /dev/tty
        read -rsp "Enter NAS password: " nas_password < /dev/tty
        echo

        if [ -z "$nas_username" ] || [ -z "$nas_password" ]; then
            log "NAS credentials cannot be empty." "ERROR"
            return 1
        fi

        sudo bash -c "cat > '$credentials_file' <<EOF
username=$nas_username
password=$nas_password
EOF"
        sudo chmod 600 "$credentials_file"
        log "Created credentials file at $credentials_file"
    else
        sudo chmod 600 "$credentials_file"
        log "Credentials file already exists at $credentials_file"
    fi

    cat > "$backup_script" <<'EOF'
#!/bin/bash
set -euo pipefail

NAS_IP="10.0.0.100"
SHARE_NAME="backup"
MOUNT_POINT="/mnt/nas_backup"
CREDENTIALS_FILE="/root/.nas-credentials"
BACKUP_ROOT_DIR="dietpibackup"
SHORT_HOST="$(hostname -s 2>/dev/null || hostname | cut -d. -f1)"
HOST_DIR="$MOUNT_POINT/$BACKUP_ROOT_DIR/$SHORT_HOST"
DIETPI_SERVICES_STOPPED=0

log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] $message"
}

cleanup() {
    if [ "${DIETPI_SERVICES_STOPPED:-0}" -eq 1 ] && [ -x /boot/dietpi/dietpi-services ]; then
        /boot/dietpi/dietpi-services start || true
    fi

    if mountpoint -q "$MOUNT_POINT"; then
        umount "$MOUNT_POINT" || true
    fi
}
trap cleanup EXIT

log "Starting NAS backup script."

apt-get update
apt-get install -y cifs-utils rsync

if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "Missing credentials file: $CREDENTIALS_FILE"
    exit 1
fi

chmod 600 "$CREDENTIALS_FILE"
mkdir -p "$MOUNT_POINT"

if ! mountpoint -q "$MOUNT_POINT"; then
    mount -t cifs "//$NAS_IP/$SHARE_NAME" "$MOUNT_POINT" \
        -o "credentials=$CREDENTIALS_FILE,iocharset=utf8,uid=0,gid=0,file_mode=0600,dir_mode=0700,mfsymlinks,vers=3.0"
    log "Mounted //$NAS_IP/$SHARE_NAME to $MOUNT_POINT"
else
    log "$MOUNT_POINT is already mounted."
fi

mkdir -p "$HOST_DIR"

if [ -d "$HOST_DIR/previous_2" ]; then
    rm -rf "$HOST_DIR/previous_2"
fi

if [ -d "$HOST_DIR/previous_1" ]; then
    mv "$HOST_DIR/previous_1" "$HOST_DIR/previous_2"
fi

if [ -d "$HOST_DIR/current" ]; then
    mv "$HOST_DIR/current" "$HOST_DIR/previous_1"
fi

mkdir -p "$HOST_DIR/current"

cat > /tmp/nas-backup-excludes.txt <<'_EXC_'
- /mnt/nas_backup/
+ /mnt/dietpi_userdata/
- /mnt/*
- /media/*
- /dev/
- /proc/
- /run/
- /sys/
- /tmp/
- /var/swap
- /.swap*
- /etc/fake-hwclock.data
- /lost+found/
- /var/cache/apt/*
_EXC_

if [ -x /boot/dietpi/dietpi-services ]; then
    log "Stopping DietPi services for backup consistency."
    /boot/dietpi/dietpi-services stop || true
    DIETPI_SERVICES_STOPPED=1
fi

log "Running rsync backup."
rsync -aH --delete-excluded \
    --info=progress2 \
    --info=name0 \
    --filter="merge /tmp/nas-backup-excludes.txt" \
    / "$HOST_DIR/current"

log "Saving metadata."
dpkg --get-selections > "$HOST_DIR/current/package-list.txt" 2>/dev/null || true
crontab -l > "$HOST_DIR/current/root-crontab.txt" 2>/dev/null || true
systemctl list-unit-files > "$HOST_DIR/current/systemd-unit-files.txt" 2>/dev/null || true
hostname > "$HOST_DIR/current/hostname.txt" 2>/dev/null || true
uname -a > "$HOST_DIR/current/uname.txt" 2>/dev/null || true
date > "$HOST_DIR/current/backup-date.txt" 2>/dev/null || true

if command -v docker >/dev/null 2>&1; then
    docker ps -a > "$HOST_DIR/current/docker-ps.txt" 2>/dev/null || true
    docker images > "$HOST_DIR/current/docker-images.txt" 2>/dev/null || true
fi

rm -f /tmp/nas-backup-excludes.txt

log "Backup completed successfully to $HOST_DIR/current"
EOF

    chmod +x "$backup_script"
    chown "$SUDO_USER:$SUDO_USER" "$backup_script"

    log "NAS backup script created at $backup_script"
    echo
    echo "Created files:"
    echo "  Backup script: $backup_script"
    echo "  Credentials:   $credentials_file"
    echo
    echo "NAS layout will be:"
    echo "  //10.0.0.100/backup/dietpibackup/<short-hostname>/current"
    echo "  //10.0.0.100/backup/dietpibackup/<short-hostname>/previous_1"
    echo "  //10.0.0.100/backup/dietpibackup/<short-hostname>/previous_2"
    echo
    echo "Included DietPi rule:"
    echo "  /mnt/dietpi_userdata/ is included"
    echo "Excluded DietPi rules:"
    echo "  /mnt/*, /media/*, /dev/, /proc/, /run/, /sys/, /tmp/"
    echo "  /var/swap, /.swap*, /etc/fake-hwclock.data, /lost+found/"
    echo "  /var/cache/apt/*"
}

###############################################################################
# FUNCTION: summary_report
# Description: Print completion summary for run_all_tasks
###############################################################################
summary_report() {
    log "Summary Report:"
    log "--------------"
    log "Profile: $PROFILE"
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
# FUNCTION: run_all_tasks
# Description: Run standard setup tasks only (excludes DietPi upgrades,
#              Docker removal, PiVPN, Wake-on-LAN, and NAS backup generator)
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
# FUNCTION: menu
# Description: Original interactive menu layout
###############################################################################
menu() {
    while true; do
        clear
        echo "#####################################"
        echo "#   Automated System Configuration  #"
        echo "#####################################"
        echo "Profile: $PROFILE"
        echo "-------------------------------------"
        echo "Please select an option:"
        echo "  1) System Update and Upgrade"
        echo "  2) DietPi: Bullseye -> Bookworm"
        echo "  3) DietPi: Bookworm -> Trixie"
        echo "  4) Update sudoers"
        echo "  5) Configure SSH"
        echo "  6) Generate SSH Key"
        echo "  7) Create/Update .bashrc"
        echo "  8) Create/Update .bash_aliases"
        echo "  9) Install and Configure SNMPD"
        echo "  10) Install Docker official repo"
        echo "  11) Install PiVPN"
        echo "  12) Install Docker and relevant tools"
        echo "  13) Remove Docker and relevant tools"
        echo "  14) Clone the update-fastfetch repo"
        echo "  15) Run all tasks"
        echo "  16) Install Wake-on-LAN tools"
        echo "  17) Create NAS backup script (DietPi-style filters)"
        echo "  18) Exit"

        read -rp "Enter your choice: " choice

        case "$choice" in
            1) system_update_upgrade ;;
            2) dietpi_bullseye_to_bookworm ;;
            3) dietpi_bookworm_to_trixie ;;
            4) update_sudoers ;;
            5) configure_ssh ;;
            6) generate_ssh_key ;;
            7) create_bashrc ;;
            8) create_bash_aliases ;;
            9) install_configure_snmpd ;;
            10) install_docker_repository ;;
            11) install_pivpn ;;
            12) install_docker_ce ;;
            13) remove_docker_and_tools ;;
            14) clone_fastfetch_repository ;;
            15) run_all_tasks ;;
            16) install_wakeonlan ;;
            17) create_nas_backup_script ;;
            18)
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

###############################################################################
# START
###############################################################################
select_profile
apply_profile_config
install_missing_packages
menu
