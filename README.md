# Automated System Configuration Script

This Bash script automates post-install system configuration on  
Debian-based systems and DietPi installations. It provides secure  
defaults, shell customization, Docker, SNMPD & PiVPN setup, and  
repeatable provisioning --- all through an interactive menu.

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
    -   Optional client creation after install
    -   Automatic hostname-based naming (short hostname)
    -   QR code generation for mobile devices
-   🚀 Fastfetch repository cloning
-   🔄 DietPi upgrade helpers:
    -   Bullseye → Bookworm
    -   Bookworm → Trixie
-   🗂️ Automatic backups before modifying system files
-   🧾 Timestamped logging
-   📋 Summary report after execution
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

``` bash
git clone https://github.com/mews-se/startchanges.git
cd startchanges
```

### 2. Run the script

``` bash
sudo ./startchanges.sh
```

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

``` bash
logout
```

(or start a new shell session)

This activates membership in the `docker` group.

------------------------------------------------------------------------

### Shell configuration

After `.bashrc` and `.bash_aliases` changes:

``` bash
source ~/.bashrc && source ~/.bash_aliases
```

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

Where:

-   `<hostname>` is automatically shortened  
    (e.g. sub.domain.com → sub)
-   Names are kept within PiVPN’s 15-character limit

You will also be prompted to display a QR code for mobile setup:

    Show QR for <hostname>-iph? [Y/n]

Default is **Yes**.

⚠️ PiVPN installation is interactive and **NOT included** in "Run all tasks".

------------------------------------------------------------------------

### DietPi Upgrades

Two optional upgrade helpers are included:

-   **Update DietPi Bullseye → Bookworm**
-   **Update DietPi Bookworm → Trixie**

These launch the official DietPi upgrade scripts.

⚠️ These upgrades are **interactive** and intentionally **NOT included**  
in "Run all tasks".

They should be executed manually and monitored.  
All credits goes to the creator of DietPi, Micha - https://github.com/MichaIng/DietPi

------------------------------------------------------------------------

### Docker Removal

The menu includes:

    Remove Docker and relevant tools

This will:

-   Purge Docker packages
-   Remove Docker repositories and keys
-   Delete Docker and containerd data directories

This task is **not executed automatically** by "Run all tasks".

------------------------------------------------------------------------

## What This Script Does

-   Hardens SSH configuration
-   Enables passwordless sudo for administration
-   Generates SSH keys if missing
-   Installs Docker and Compose plugins
-   Installs and configures PiVPN with optional client setup
-   Configures SNMP monitoring
-   Standardizes shell environments
-   Installs required dependencies automatically
-   Provides consistent system setup across multiple machine types

------------------------------------------------------------------------

## Support

For questions or issues, please open an issue:

https://github.com/mews-se/startup-script/issues

------------------------------------------------------------------------

## Contributing

Contributions are welcome.

If you find a bug or want to improve functionality:

1.  Fork the repository
2.  Create a feature branch
3.  Submit a pull request

------------------------------------------------------------------------

## License

Licensed under **The Unlicense**:

https://github.com/mews-se/startup-script/blob/test/LICENSE
