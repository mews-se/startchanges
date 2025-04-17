# Automated System Configuration Script

This Bash script automates post-install system configuration on Debian-based distributions. It includes user management, secure SSH setup, shell customizations, Docker & SNMPD installation, and alias configuration — all accessible through a user-friendly interactive menu.

Designed for quick deployment or repeatable provisioning of servers, development environments, or home lab setups.

## Disclaimer

This script is provided as-is for personal and educational use and based on my personal needs. While it includes safety measures (like backups and prompts), you should review the code before running it, especially on production systems.

Use at your own risk. The author assumes no liability for system damage, data loss, or misconfiguration.

## Features

- 🔧 System Update & Upgrade
- 🔐 Secure SSH configuration:
  - Disables root login
  - Whitelist-based user access
- ⚙️ Sudoers file update with passwordless sudo
- 🔑 SSH key generation (Ed25519)
- 🧠 Smart `.bashrc` & `.bash_aliases` management:
  - Adds predefined aliases
  - Prompts to keep/remove custom ones
  - Sorted final output
- 🐳 Docker CE installation (with plugin support)
- 📱 SNMPD installation & custom `snmpd.conf`
- 🚀 Fastfetch repository clone (for system summary)
- 🗂️ All changes logged with date-stamped backups
- 🧾 Built-in summary report and safe execution via main menu

## Usage

1. Download or clone the repository:
   ```bash
   git clone https://github.com/your-repo/startchanges.git
   cd startchanges
   sudo ./startchanges-x64.sh
   ```

2. Use the interactive menu to choose configuration tasks:
   - Run all tasks at once
   - Or execute them step by step

3. After completing shell configuration, apply changes:
   ```bash
   source ~/.bashrc && source ~/.bash_aliases
   ```

4. For Docker: logout/login to activate group permissions.

## What This Script Does

- Configures a secure SSH environment
- Grants passwordless sudo for the `sudo` group
- Generates an SSH key if missing
- Installs Docker and Docker Compose plugins
- Sets up SNMP monitoring and custom extends
- Replaces `.bashrc` and interactively manages `.bash_aliases`
- Clones personal tools like Fastfetch
- Ensures required system packages are installed

## Support

For questions or issues related to this script, please [open an issue](https://github.com/mews-se/startup-script/issues) on GitHub.

## Contributing

Contributions are welcome! If you find a bug or have an enhancement in mind, please fork the repository and submit a pull request.

## License

This script is licensed under [The Unlicense](https://github.com/mews-se/startup-script/blob/test/LICENSE).

