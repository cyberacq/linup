# LinUp Multi-Distro
- a cross-distribution system update manager supporting multiple Linux distributions and package managers with intelligent update handling.

Getting start with Multi-Distro:
"chmod +x linup-multi-distro-[version]-installer.sh && sudo ./linup-multi-distro-[version]-installer.sh"

Most dependencies are base linux tools. If you want to check dependencies first: "sudo ./linup-multi-distro-[version]-installer.sh -c"

SUPPORTED DISTRIBUTIONS
       Debian Family
              Ubuntu, Debian, Linux Mint, Pop!_OS, Elementary, Zorin (using apt with --only-upgrade)

# Red Hat Family
-  Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux (using dnf/yum with upgrade-only mode)
# Arch Family
- Arch Linux, Manjaro, EndeavourOS, Garuda (using pacman with targeted upgrades)
# openSUSE
- openSUSE, SLES (using zypper with update mode)
# Alpine Linux
- Alpine (using apk with upgrade mode)
#Void Linux
- Void (using xbps with upgrade mode)
# Gentoo Gentoo (using emerge with update mode)


FEATURES
# Automatic Detection
- Detects your distribution and configures the appropriate package manager automatically Interactive Updates with Selective Upgrades Prompts for each operation with numbered package selection using upgrade-only modes
# Kernel Safety
- Detects kernel updates and offers reboot management
# Package Cleanup
- Intelligent autoremove that only prompts when cleanup is needed
# Comprehensive Logging
- All actions are logged to /var/log/linup.log for audit purposes


# LinUp with swizzin Support
- a comprehensive system update manager for Ubuntu and Debian-based systems with intelligent swizzin update support and upgrade protection during kernel reboots.

Getting started with swizzin Support:
"chmod +x linup-swizzin-support-[version]-installer.sh && sudo ./linup-swizzin-support-[version]-installer.sh"
If you're not running swizzin, use the multi-distro version.

FEATURES
# Interactive Updates with Numbered Selection
- Prompts user for each update operation with the ability to install all updates or specific updates by number
# Swizzin Detection
- Automatically detects swizzin installations and prompts for update support enablement
# Kernel Safety
- Detects pending kernel updates and prevents unsafe swizzin updates, offering to schedule updates after reboot
# Automatic Post-Reboot Updates
- Creates systemd service to automatically update swizzin after kernel reboot
# Reboot Management
- Detects when reboots are required and offers to reboot the system immediately
# Package Cleanup
- Provides autoremove functionality to clean up unnecessary packages
# Comprehensive Logging
- All actions are logged to /var/log/linup.log for audit and troubleshooting
