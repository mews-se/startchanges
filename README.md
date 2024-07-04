# Automated System Configuration Script

## Description

This Bash script automates several system configuration tasks to enhance user experience and bolster security. It includes the following functionalities:

- Updates system packages to ensure the latest security patches and software enhancements are applied.
- Configures sudo permissions for optimized user management and system administration.
- Adjusts SSH settings to restrict root login and define specific users allowed SSH access.
- Generates an SSH key pair without a passphrase for secure authentication.
- Customizes the `.bashrc` and `.bash_aliases` files for streamlined command-line interactions.
- Installs and configures SNMPD (Simple Network Management Protocol Daemon) for network monitoring.
- Sets up Docker repository and installs Docker CE for containerized application deployment.

## Disclaimer

This script is authored and maintained for personal use by the author. Users are encouraged to review the code and understand its operations before executing any commands. It is advisable to test the script in a controlled, non-production environment to evaluate its impact and functionality specific to your system configuration.

The author assumes no responsibility for any unintended consequences, including but not limited to data loss, system downtime, or security breaches, resulting from the use of this script. By executing the script, users acknowledge and accept these risks.

For critical systems or environments with unique configurations, consider adapting the script to suit specific requirements and conducting thorough testing prior to deployment.

## Usage

1. Clone the repository or download the script.
2. Make sure to run the script with appropriate permissions (`sudo`).
3. Review the menu options and select the desired tasks to automate system configuration.
4. Follow any on-screen instructions for manual steps like sourcing `.bashrc` and `.bash_aliases`.

## Support

For questions or issues related to this script, please [open an issue](https://github.com/mews-se/startup-script/issues) on GitHub.

## Contributing

Contributions are welcome! If you find a bug or have an enhancement in mind, please fork the repository and submit a pull request.

## License

This script is licensed under the [The Unlicense](https://github.com/mews-se/startup-script/blob/test/LICENSE).
