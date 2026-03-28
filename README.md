# Automated System Configuration Script

![Version](https://img.shields.io/badge/version-v2026.03.28-informational)
![Last Commit](https://img.shields.io/github/last-commit/mews-se/startchanges)
![License](https://img.shields.io/github/license/mews-se/startchanges)

This Bash script automates post-install system configuration on  
Debian-based systems and DietPi installations. It provides secure  
defaults, shell customization, Docker, SNMPD & PiVPN setup, Wake-on-LAN,  
and NAS backup --- all through an interactive menu.

The script supports multiple machine profiles (x64 servers and Raspberry  
Pi systems) using **one unified script**, making maintenance and updates  
significantly easier.

Designed for quick deployment or repeatable provisioning of servers,  
work machines, and home lab environments.

------------------------------------------------------------------------

## Disclaimer

This script is provided as-is for my personal and educational use and is  
based on my personal needs. While it includes safeguards such as backups  
and confirmation prompts, you should always review the code before  
running it --- especially on production systems.

Use at your own risk. The author assumes no liability for system damage,  
data loss, or misconfiguration.

------------------------------------------------------------------------

## Features

-   🔧 System Update & Upgrade
-   🔐 Secure SSH configuration  
    -   Disables root login  
    -   Whitelist-based SSH access  
-   ⚙️ Passwordless sudo configuration for the `sudo` group
-   🔑 Automatic Ed25519 SSH key generation
-   🧠 Smart shell configuration  
    -   Recreates `.bashrc`  
    -   Interactive `.bash_aliases` merge  
    -   Preserves custom aliases when desired  
-   🐳 Docker CE installation (official repository + plugins)
-   🧹 Docker removal task (full cleanup option)
-   📡 SNMPD installation with custom monitoring configuration
-   🔐 PiVPN installation with automated client setup
-   🚀 Fastfetch repository cloning
-   🔄 DietPi upgrade helpers  
    -   Bullseye → Bookworm  
    -   Bookworm → Trixie  
-   🌐 Wake-on-LAN installation
-   💾 NAS backup script generator (SMB/CIFS-based)  
    -   Uses secure credential storage (`/root/.nas-credentials`)  
    -   Incremental backups with rotation (current / previous_1 / previous_2)  
    -   DietPi-style exclusions  
-   🗂️ Automatic backups before modifying system files
-   🧾 Timestamped logging
-   🖥️ Interactive menu-driven interface

------------------------------------------------------------------------

## Supported Profiles

The script replaces multiple machine-specific scripts with **profile  
selection at runtime**.

Available profiles:

  Profile     Description
  ----------- -----------------------------------------------------
  `x64`       Standard x64 server/home lab systems
  `x64-brk`   x64 systems used in work environment (BRK)
  `pi`        Raspberry Pi systems
  `pi-brk`    Raspberry Pi systems used in work environment (BRK)

Each profile automatically applies:

-   Correct SNMP configuration
-   Profile-specific aliases
-   Hardware-specific adjustments (Pi vs x64)

------------------------------------------------------------------------

## Usage

### 1. Clone the repository

    git clone https://github.com/mews-se/startchanges.git
    cd startchanges

### 2. Run the script

    sudo ./startchanges.sh

### 3. Select a profile

You will be prompted to choose:

    x64
    x64-brk
    pi
    pi-brk

### 4. Choose tasks from the interactive menu

You may:

-   Run tasks individually
-   Or select **Run all tasks** for full provisioning

------------------------------------------------------------------------

## Important Notes

### Docker permissions

After Docker installation:

    logout

(or start a new shell session)

------------------------------------------------------------------------

### Shell configuration

After `.bashrc` and `.bash_aliases` changes:

    source ~/.bashrc && source ~/.bash_aliases

or log out and back in.

------------------------------------------------------------------------

### PiVPN Setup

The menu includes:

    Install PiVPN

This will:

-   Run the official PiVPN installer
-   Handle interactive installer correctly
-   Optionally create client configurations

If selected, the script will automatically create:

    <hostname>-tb7
    <hostname>-mbp
    <hostname>-iph
    <hostname>-len

------------------------------------------------------------------------

### NAS Backup

The menu includes:

    Create NAS backup script

This will:

-   Generate `~/nas-backup.sh`
-   Store credentials securely in:

    /root/.nas-credentials

-   Mount NAS via SMB/CIFS
-   Perform rsync-based backup with rotation:

    current  
    previous_1  
    previous_2  

⚠️ Credentials are **never stored in the repository or main script**.

------------------------------------------------------------------------

## What This Script Does

-   Hardens SSH configuration
-   Enables passwordless sudo
-   Generates SSH keys
-   Installs Docker and plugins
-   Installs PiVPN
-   Configures SNMP monitoring
-   Standardizes shell environment
-   Installs Wake-on-LAN tools
-   Creates NAS backup system
-   Ensures consistent system setup

------------------------------------------------------------------------

## Support

For questions or issues, please open an issue:

https://github.com/mews-se/startchanges/issues

------------------------------------------------------------------------

## Contributing

Contributions are welcome.

1.  Fork the repository  
2.  Create a feature branch  
3.  Submit a pull request  

------------------------------------------------------------------------

## License

Licensed under **The Unlicense**:

https://github.com/mews-se/startchanges/blob/main/LICENSE
