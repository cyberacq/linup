#!/bin/bash

################################################################################
# Linup Installer
# Version: 2.2
# Description: Installer for Linux Updater with swizzin Update Support
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# UTF-8 Braille spinner
SPINNER_CHARS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPINNER_PID=""

# Installation paths
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/cyberacq/software/linup"
LOG_FILE="/var/log/linup.log"
MANPAGE_DIR="/usr/share/man/man1"

################################################################################
# Helper Functions
################################################################################

start_spinner() {
    local message="$1"
    (
        i=0
        while true; do
            printf "\r\033[K${YELLOW}${SPINNER_CHARS[$i]}${NC} $message"
            i=$(( (i + 1) % ${#SPINNER_CHARS[@]} ))
            sleep 0.1
        done
    ) &
    SPINNER_PID=$!
}

stop_spinner() {
    local status="$1"
    local message="$2"
    
    if [ -n "$SPINNER_PID" ]; then
        kill $SPINNER_PID 2>/dev/null || true
        wait $SPINNER_PID 2>/dev/null || true
        SPINNER_PID=""
    fi
    
    if [ "$status" = "success" ]; then
        printf "\r\033[K${GREEN}✓${NC} $message\n"
    elif [ "$status" = "fail" ]; then
        printf "\r\033[K${RED}✗${NC} $message\n"
    else
        printf "\r\033[K$message\n"
    fi
}

print_header() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

################################################################################
# Detection Functions
################################################################################

detect_swizzin() {
    if [ -f "/install/.swizzin.lock" ] || [ -d "/etc/swizzin" ]; then
        return 0
    fi
    return 1
}

################################################################################
# Configuration Functions
################################################################################

create_config() {
    local swizzin_support="$1"
    local swizzin_detect="$2"
    
    mkdir -p "$CONFIG_DIR"
    
    cat > "$CONFIG_DIR/config" << EOF
# Linup Configuration
# Generated on $(date)

SWIZZIN_SUPPORT=$swizzin_support
SWIZZIN_DETECT=$swizzin_detect
EOF
    
    chmod 600 "$CONFIG_DIR/config"
}

################################################################################
# Installation Functions
################################################################################

install_linup_script() {
    local swizzin_support="$1"
    
    start_spinner "Creating linup executable..."
    sleep 1
    
    cat > "$INSTALL_DIR/linup" << 'LINUP_SCRIPT_EOF'
#!/bin/bash

################################################################################
# Linux Updater with swizzin Update Support and Upgrade Protection 
# Version: 2.2
# Description: Comprehensive system updater for Ubuntu/Debian with swizzin
#              update support and upgrade protection during kernel reboots
################################################################################

set -e

# Script metadata
SCRIPT_VERSION="2.2"
SCRIPT_NAME="linup"
CONFIG_DIR="$HOME/cyberacq/software/linup"
LOG_FILE="/var/log/linup.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Swizzin detection variables
SWIZZIN_DETECTED=false
SWIZZIN_PATH=""
SWIZZIN_DIR="/etc/swizzin"
SWIZZIN_SUPPORT=false
SWIZZIN_DETECT=false

################################################################################
# Logging Function
################################################################################

log_action() {
    # Only log if running as root to avoid permission errors
    if [ "$EUID" -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

################################################################################
# Helper Functions
################################################################################

print_status() {
    echo -e "${BLUE}==>${NC} $1"
    log_action "STATUS: $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    log_action "SUCCESS: $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    log_action "WARNING: $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    log_action "ERROR: $1"
}

print_header() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

################################################################################
# Configuration Loading
################################################################################

load_config() {
    if [ -f "$CONFIG_DIR/config" ]; then
        source "$CONFIG_DIR/config"
    fi
}

save_config() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/config" << EOF
# Linup Configuration
SWIZZIN_SUPPORT=$SWIZZIN_SUPPORT
SWIZZIN_DETECT=$SWIZZIN_DETECT
EOF
}

################################################################################
# Version and Help Functions
################################################################################

show_version() {
    echo "Linux Updater version $SCRIPT_VERSION"
    exit 0
}

show_help() {
    cat << EOF
Linux Updater v$SCRIPT_VERSION - System Update Manager with swizzin Update Support
https://github.com/cyberacq/linup

USAGE:
    $SCRIPT_NAME [OPTIONS]

DESCRIPTION:
    Comprehensive system updater for Ubuntu/Debian systems with intelligent
    swizzin update support and upgrade protection during kernel reboots.

OPTIONS:
    -h, --help              Display this help message
    -v, --version           Display version information
    -l, --log               View the linup log file
    -r, --remove            Uninstall linup from the system

FEATURES:
    • Interactive system package updates with numbered selection
    • Automatic swizzin detection and safe updating
    • Kernel update detection with reboot management
    • Prevents unsafe swizzin updates during kernel reboots
    • Automatic post-reboot swizzin updates via systemd service
    • Package cleanup with autoremove
    • Comprehensive logging

EXAMPLES:
    # Run the updater interactively
    sudo $SCRIPT_NAME

    # View the log file
    $SCRIPT_NAME --log

    # View the manual page
    man $SCRIPT_NAME

    # Uninstall linup
    sudo $SCRIPT_NAME --remove

REQUIREMENTS:
    • Must be run as root or with sudo
    • Ubuntu or Debian-based system
    • Optional: swizzin installation

AUTHOR:
    cyberacq - https://github.com/cyberacq/linup

EOF
    exit 0
}

show_log() {
    if [ -f "$LOG_FILE" ]; then
        less "$LOG_FILE"
    else
        echo "Log file not found at $LOG_FILE"
    fi
    exit 0
}

################################################################################
# Uninstall Function
################################################################################

uninstall_linup() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Uninstalling linup requires root privileges"
        exit 1
    fi
    
    echo ""
    print_header "Uninstall Linup"
    echo ""
    
    print_warning "This will remove linup from your system"
    echo ""
    read -p "Are you sure you want to uninstall linup? (y/N): " confirm
    
    case "${confirm,,}" in
        y|yes)
            ;;
        *)
            echo "Uninstall cancelled"
            exit 0
            ;;
    esac
    
    echo ""
    
    # Remove executable
    if [ -f "/usr/local/bin/linup" ]; then
        rm -f "/usr/local/bin/linup"
        print_success "Removed linup executable"
    fi
    
    # Remove manpage
    if [ -f "/usr/share/man/man1/linup.1.gz" ]; then
        rm -f "/usr/share/man/man1/linup.1.gz"
        if command -v mandb &> /dev/null; then
            mandb -q 2>/dev/null || true
        fi
        print_success "Removed manual page"
    fi
    
    # Remove systemd service if exists
    if [ -f "/etc/systemd/system/swizzin-update-once.service" ]; then
        systemctl disable swizzin-update-once.service 2>/dev/null || true
        rm -f "/etc/systemd/system/swizzin-update-once.service"
        rm -f "/usr/local/bin/swizzin-update-once.sh"
        systemctl daemon-reload
        print_success "Removed swizzin update service"
    fi
    
    # Ask about configuration
    echo ""
    read -p "Delete configuration directory ($CONFIG_DIR)? (y/N): " del_config
    
    case "${del_config,,}" in
        y|yes)
            if [ -d "$CONFIG_DIR" ]; then
                rm -rf "$CONFIG_DIR"
                print_success "Removed configuration directory"
            fi
            ;;
        *)
            echo "Configuration directory preserved"
            ;;
    esac
    
    # Ask about log file
    echo ""
    read -p "Delete log file ($LOG_FILE)? (y/N): " del_log
    
    case "${del_log,,}" in
        y|yes)
            if [ -f "$LOG_FILE" ]; then
                rm -f "$LOG_FILE"
                print_success "Removed log file"
            fi
            ;;
        *)
            echo "Log file preserved"
            ;;
    esac
    
    echo ""
    print_success "Linup has been uninstalled"
    echo ""
    
    exit 0
}

################################################################################
# Swizzin Functions
################################################################################

detect_swizzin() {
    if [ -f "/install/.swizzin.lock" ] || [ -d "$SWIZZIN_DIR" ]; then
        SWIZZIN_DETECTED=true
        if [ -f "/usr/local/bin/box" ]; then
            SWIZZIN_PATH="/usr/local/bin/box"
        elif command -v box &> /dev/null; then
            SWIZZIN_PATH=$(command -v box)
        fi
    fi
}

prompt_enable_swizzin() {
    echo ""
    print_warning "Swizzin installation detected!"
    echo ""
    read -p "Would you like to enable swizzin update support and upgrade protection? (Y/n): " response
    
    case "${response,,}" in
        n|no)
            SWIZZIN_SUPPORT=false
            SWIZZIN_DETECT=true
            print_status "Swizzin support disabled. You can enable it later by editing $CONFIG_DIR/config"
            ;;
        *)
            SWIZZIN_SUPPORT=true
            SWIZZIN_DETECT=true
            print_success "Swizzin support enabled!"
            ;;
    esac
    
    save_config
}

check_kernel_reboot_needed() {
    if [ -f /var/run/reboot-required ]; then
        if grep -q "linux-image" /var/run/reboot-required.pkgs 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

check_reboot_needed() {
    [ -f /var/run/reboot-required ]
}

create_swizzin_update_service() {
    local service_file="/etc/systemd/system/swizzin-update-once.service"
    local script_file="/usr/local/bin/swizzin-update-once.sh"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash
# This script waits for the user to log in before running swizzin update

SWIZZIN_PATH="/usr/local/bin/box"
[ -f "$SWIZZIN_PATH" ] || SWIZZIN_PATH=$(command -v box)

# Function to check if user is logged in
wait_for_user_login() {
    while true; do
        # Check if any user sessions exist (excluding root)
        if who | grep -v "^root " | grep -q .; then
            return 0
        fi
        sleep 10
    done
}

if [ -n "$SWIZZIN_PATH" ] && [ -x "$SWIZZIN_PATH" ]; then
    # Wait for user to log in
    wait_for_user_login
    
    echo "Running swizzin update after kernel update..." | wall
    sudo box update
    
    systemctl disable swizzin-update-once.service
    rm -f /etc/systemd/system/swizzin-update-once.service
    rm -f /usr/local/bin/swizzin-update-once.sh
    systemctl daemon-reload
fi
EOF
    
    chmod +x "$script_file"
    
    cat > "$service_file" << 'SERVICEEOF'
[Unit]
Description=One-time Swizzin Update After Kernel Reboot
After=network-online.target multi-user.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/swizzin-update-once.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
SERVICEEOF
    
    systemctl daemon-reload
    systemctl enable swizzin-update-once.service
    print_success "Swizzin will be updated automatically after you log in following reboot"
    log_action "Created swizzin post-reboot update service"
}

handle_swizzin_update() {
    if [ "$SWIZZIN_SUPPORT" = false ] || [ "$SWIZZIN_DETECTED" = false ] || [ -z "$SWIZZIN_PATH" ]; then
        return
    fi
    
    echo ""
    print_header "Swizzin Update"
    
    if check_kernel_reboot_needed; then
        print_warning "Kernel update detected - reboot pending"
        print_warning "It is not safe to update swizzin with a pending kernel reboot"
        echo ""
        read -p "Update swizzin automatically after you log in following reboot? (Y/n): " response
        
        case "${response,,}" in
            n|no)
                print_status "Swizzin will not be updated after reboot"
                log_action "User declined swizzin post-reboot update"
                ;;
            *)
                create_swizzin_update_service
                ;;
        esac
    else
        print_status "Updating swizzin..."
        if sudo box update; then
            print_success "Swizzin updated successfully"
        else
            print_error "Swizzin update failed"
        fi
    fi
}

offer_reboot() {
    if check_reboot_needed; then
        echo ""
        print_warning "System reboot is required to apply updates"
        
        if [ -f /var/run/reboot-required.pkgs ]; then
            echo "Packages requiring reboot:"
            cat /var/run/reboot-required.pkgs | sed 's/^/  - /'
        fi
        
        echo ""
        read -p "Reboot system now? (Y/n): " response
        
        case "${response,,}" in
            n|no)
                print_status "Reboot postponed. Please reboot manually when convenient."
                log_action "User postponed reboot"
                ;;
            *)
                print_status "Rebooting system in 5 seconds..."
                log_action "System reboot initiated by user"
                sleep 5
                reboot
                ;;
        esac
    fi
}

################################################################################
# Main Update Functions
################################################################################

check_updates() {
    echo ""
    read -p "Do you want to list current updates? (Y/n): " check_updates
    
    case "${check_updates,,}" in
        n|no)
            echo "Skipping update check."
            log_action "User skipped update check"
            return 1
            ;;
        *)
            print_status "Checking for updates..."
            apt update > /dev/null 2>&1
            
            # Capture upgradable packages
            mapfile -t UPDATES < <(apt list --upgradable 2>/dev/null | grep -v "Listing" | grep -v "phased")
            
            if [ ${#UPDATES[@]} -eq 0 ]; then
                print_success "No updates available"
                log_action "No updates available"
                return 1
            fi
            
            echo ""
            echo "Available updates (excluding phased):"
            echo ""
            
            for i in "${!UPDATES[@]}"; do
                printf "%3d) %s\n" $((i+1)) "${UPDATES[$i]}"
            done
            
            log_action "Found ${#UPDATES[@]} updates available"
            return 0
            ;;
    esac
}

apply_updates() {
    # Only offer to apply updates if there are updates available
    if [ ${#UPDATES[@]} -eq 0 ]; then
        return
    fi
    
    echo ""
    read -p "Do you want to apply updates? (A)ll/(S)pecific number/(N)o: " upgrade_prompt
    
    case "${upgrade_prompt,,}" in
        n|no)
            echo "Upgrade cancelled."
            log_action "User cancelled upgrade"
            ;;
        s|specific)
            read -p "Enter update number to install: " update_num
            if [ "$update_num" -ge 1 ] && [ "$update_num" -le ${#UPDATES[@]} ]; then
                local pkg_line="${UPDATES[$((update_num-1))]}"
                local pkg_name=$(echo "$pkg_line" | cut -d'/' -f1)
                print_status "Installing $pkg_name (upgrade only)..."
                apt install --only-upgrade -y "$pkg_name"
                print_success "Update applied successfully"
                log_action "Installed specific package: $pkg_name (--only-upgrade)"
            else
                print_error "Invalid update number"
                log_action "Invalid update number entered: $update_num"
            fi
            ;;
        *)
            print_status "Applying all updates (excluding phased)..."
            apt upgrade -y
            print_success "All updates applied successfully"
            log_action "Applied all available updates"
            ;;
    esac
}

run_autoremove() {
    # Check if there are packages to autoremove
    local autoremove_check=$(apt autoremove --dry-run 2>/dev/null | grep -c "^Remv" || true)
    
    if [ "$autoremove_check" -eq 0 ]; then
        log_action "No packages to autoremove"
        return
    fi
    
    echo ""
    read -p "Do you want to run 'apt autoremove'? (Y/n): " apt_autoremove
    
    case "${apt_autoremove,,}" in
        n|no)
            echo "apt autoremove not selected."
            log_action "User skipped autoremove"
            ;;
        *)
            print_status "Removing unnecessary packages..."
            apt autoremove -y
            print_success "Cleanup completed"
            log_action "Autoremove completed"
            ;;
    esac
}

prompt_swizzin_update() {
    if [ "$SWIZZIN_SUPPORT" = false ]; then
        return
    fi
    
    if [ "$SWIZZIN_DETECTED" = false ]; then
        return
    fi
    
    echo ""
    read -p "Do you want to check for and apply swizzin upgrades? (Y/n): " user_response
    
    case "${user_response,,}" in
        n|no)
            echo "Skipping swizzin update."
            log_action "User skipped swizzin update"
            ;;
        *)
            handle_swizzin_update
            ;;
    esac
}

################################################################################
# Main Function
################################################################################

main() {
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
    
    # Load configuration
    load_config
    
    # Detect swizzin if detection is enabled
    if [ "$SWIZZIN_DETECT" = true ]; then
        detect_swizzin
        
        # If swizzin detected but support not enabled, prompt user
        if [ "$SWIZZIN_DETECTED" = true ] && [ "$SWIZZIN_SUPPORT" = false ]; then
            prompt_enable_swizzin
        fi
    fi
    
    # Initialize log
    log_action "===== Linup session started ====="
    
    # Welcome banner
    echo ""
    print_header "Linux Updater v$SCRIPT_VERSION with swizzin Update Support"
    echo ""
    
    # Run update sequence
    local updates_available=true
    if ! check_updates; then
        updates_available=false
    fi
    
    # Only offer to apply updates if there are updates
    if [ "$updates_available" = true ]; then
        apply_updates
    fi
    
    run_autoremove
    prompt_swizzin_update
    offer_reboot
    
    # Completion message
    echo ""
    print_header "Update Operations Completed"
    echo ""
    
    log_action "===== Linup session completed ====="
}

################################################################################
# Argument Parsing
################################################################################

case "${1,,}" in
    -h|--help)
        show_help
        ;;
    -v|--version)
        show_version
        ;;
    -l|--log)
        show_log
        ;;
    -r|--remove)
        uninstall_linup
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac

exit 0
LINUP_SCRIPT_EOF
    
    chmod +x "$INSTALL_DIR/linup"
    
    stop_spinner "success" "Linup executable created"
}

install_manpage() {
    start_spinner "Installing manual page..."
    sleep 1
    
    mkdir -p "$MANPAGE_DIR"
    
    cat << 'MANPAGE_EOF' | gzip > "$MANPAGE_DIR/linup.1.gz"
.TH linup 1 "March 2026" "Version 2.2" "User Commands"
.SH NAME
linup \- System update manager with swizzin update support and upgrade protection
.SH SYNOPSIS
.B linup
[\fIOPTIONS\fR]
.SH DESCRIPTION
.B linup
is a comprehensive system update manager for Ubuntu and Debian-based systems with intelligent swizzin update support and upgrade protection during kernel reboots.
.PP
The script provides an interactive interface for managing system updates, automatically detects swizzin installations, and ensures safe update procedures when kernel updates are pending.
.SH OPTIONS
.TP
.BR \-h ", " \-\-help
Display help message and exit
.TP
.BR \-v ", " \-\-version
Display version information and exit
.TP
.BR \-l ", " \-\-log
View the linup log file
.TP
.BR \-r ", " \-\-remove
Uninstall linup from the system
.SH FEATURES
.TP
.B Interactive Updates with Numbered Selection
Prompts user for each update operation with the ability to install all updates or specific updates by number
.TP
.B Swizzin Detection
Automatically detects swizzin installations and prompts for update support enablement
.TP
.B Kernel Safety
Detects pending kernel updates and prevents unsafe swizzin updates, offering to schedule updates after reboot
.TP
.B Automatic Post-Reboot Updates
Creates systemd service to automatically update swizzin after kernel reboot
.TP
.B Reboot Management
Detects when reboots are required and offers to reboot the system immediately
.TP
.B Package Cleanup
Provides autoremove functionality to clean up unnecessary packages
.TP
.B Comprehensive Logging
All actions are logged to /var/log/linup.log for audit and troubleshooting
.SH WORKFLOW
.PP
The script follows this workflow:
.IP 1. 3
Optional: List available updates with numbers
.IP 2.
Apply system package updates (all or by number)
.IP 3.
Run autoremove to clean up packages
.IP 4.
Detect and update swizzin (if installed and enabled)
.IP 5.
Handle kernel updates and reboot scheduling
.IP 6.
Offer system reboot if needed
.SH KERNEL UPDATE HANDLING
When a kernel update is detected that requires a reboot:
.IP \(bu 2
The script warns that updating swizzin is unsafe
.IP \(bu
Offers to schedule swizzin update after reboot and user login
.IP \(bu
Creates a one-time systemd service that waits for user login, then runs on next boot
.IP \(bu
The service updates swizzin and then removes itself
.PP
The post-reboot update will only run after a user (non-root) has logged in to ensure proper execution context.
.SH SWIZZIN DETECTION
The script detects swizzin by checking for:
.IP \(bu 2
/etc/swizzin directory
.IP \(bu
/install/.swizzin.lock file
.IP \(bu
box command availability
.PP
If swizzin is detected after installation, the user is prompted to enable swizzin update support.
.SH EXAMPLES
.TP
Run the updater interactively:
.B sudo linup
.TP
View the log file:
.B linup --log
.TP
View version:
.B linup --version
.TP
View this manual:
.B man linup
.SH FILES
.TP
.I /usr/local/bin/linup
Main executable
.TP
.I ~/cyberacq/software/linup/config
User configuration file
.TP
.I /var/log/linup.log
Log file for all linup actions
.TP
.I /etc/swizzin
Swizzin installation directory
.TP
.I /var/run/reboot-required
System reboot requirement flag
.TP
.I /var/run/reboot-required.pkgs
List of packages requiring reboot
.TP
.I /etc/systemd/system/swizzin-update-once.service
One-time swizzin update service
.SH EXIT STATUS
.TP
.B 0
Success
.TP
.B 1
Error (not run as root, command failed, etc.)
.SH REQUIREMENTS
.IP \(bu 2
Must be run as root or with sudo for update operations
.IP \(bu
Ubuntu or Debian-based system
.IP \(bu
apt package manager
.IP \(bu
systemd (for post-reboot updates)
.SH AUTHOR
cyberacq - https://github.com/cyberacq/linup
.SH SEE ALSO
.BR apt (8),
.BR apt-get (8),
.BR systemd (1),
.BR reboot (8)
MANPAGE_EOF
    
    if command -v mandb &> /dev/null; then
        mandb -q 2>/dev/null || true
    fi
    
    stop_spinner "success" "Manual page installed"
}

################################################################################
# Main Installation
################################################################################

main() {
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}✗${NC} This installer must be run as root or with sudo"
        exit 1
    fi
    
    echo ""
    print_header "Linup Installer v2.2"
    echo ""
    
    # Detect swizzin
    local swizzin_installed=false
    local swizzin_support=false
    local swizzin_detect=true
    
    start_spinner "Detecting system configuration..."
    sleep 1
    
    if detect_swizzin; then
        swizzin_installed=true
        stop_spinner "success" "Swizzin installation detected"
    else
        swizzin_installed=false
        stop_spinner "success" "System configuration detected"
    fi
    
    echo ""
    
    # Handle swizzin configuration
    if [ "$swizzin_installed" = true ]; then
        echo -e "${YELLOW}⚠${NC} Swizzin installation detected!"
        echo ""
        read -p "Add swizzin update support and upgrade protection when kernel update is pending reboot? (Y/n): " swizzin_choice
        
        case "${swizzin_choice,,}" in
            n|no)
                swizzin_support=false
                echo -e "${YELLOW}⚠${NC} Swizzin support disabled (not recommended)"
                ;;
            *)
                swizzin_support=true
                echo -e "${GREEN}✓${NC} Swizzin support will be enabled"
                ;;
        esac
    else
        echo -e "${BLUE}ℹ${NC} You're not currently a swizzin admin, but the Linux Updater is not just for swizzin admins!"
        echo "  All other features will work as expected."
        echo ""
        read -p "Continue to detect swizzin when linup is run? (Y/n): " detect_choice
        
        case "${detect_choice,,}" in
            n|no)
                swizzin_detect=false
                echo "Swizzin detection disabled"
                ;;
            *)
                swizzin_detect=true
                echo "Swizzin will be detected silently on each run"
                ;;
        esac
    fi
    
    echo ""
    
    # Create directories
    start_spinner "Creating directories..."
    sleep 1
    mkdir -p "$CONFIG_DIR"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    stop_spinner "success" "Directories created"
    
    # Install linup script
    install_linup_script "$swizzin_support"
    
    # Install manpage
    install_manpage
    
    # Create configuration
    start_spinner "Saving configuration..."
    sleep 1
    create_config "$swizzin_support" "$swizzin_detect"
    stop_spinner "success" "Configuration saved"
    
    echo ""
    print_header "Installation Complete!"
    echo ""
    echo "Linup has been successfully installed to $INSTALL_DIR/linup"
    echo ""
    echo "Configuration: $CONFIG_DIR/config"
    echo "Log file: $LOG_FILE"
    echo ""
    echo "Usage:"
    echo "  sudo linup          - Run the updater"
    echo "  linup --help        - Show help"
    echo "  linup --log         - View log file"
    echo "  linup --remove      - Uninstall linup"
    echo "  man linup           - Read the manual"
    echo ""
    
    if [ "$swizzin_support" = true ]; then
        echo -e "${GREEN}✓${NC} Swizzin update support and upgrade protection enabled"
    elif [ "$swizzin_detect" = true ]; then
        echo -e "${YELLOW}⚠${NC} Swizzin detection enabled - you'll be prompted if swizzin is found"
    fi
    
    echo ""
}

main "$@"

exit 0
