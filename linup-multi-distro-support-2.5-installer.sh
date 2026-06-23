#!/bin/bash

################################################################################
# Linux Updater with Multi-Distro Support - Installer
# Version: 2.5
# Description: Cross-distribution installer for Linux Updater
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

# Installation paths (will be set based on distro)
INSTALL_DIR=""
CONFIG_DIR="$HOME/cyberacq/software/linup"
LOG_FILE="/var/log/linup.log"
MANPAGE_DIR=""

# Distribution info
DISTRO_NAME=""
DISTRO_FAMILY=""
ELEVATION_CMD=""

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
    local text="$1"
    local text_length=${#text}
    local border_length=$((text_length + 4))
    local border=$(printf '━%.0s' $(seq 1 $border_length))

    echo -e "${CYAN}${border}${NC}"
    echo -e "${CYAN}  $text${NC}"
    echo -e "${CYAN}${border}${NC}"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

################################################################################
# Distribution Detection
################################################################################

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_NAME="$NAME"

        case "$ID" in
            ubuntu|debian|linuxmint|pop|elementary|zorin)
                DISTRO_FAMILY="debian"
                INSTALL_DIR="/usr/local/bin"
                MANPAGE_DIR="/usr/share/man/man1"
                ;;
            fedora|rhel|centos|rocky|almalinux)
                DISTRO_FAMILY="redhat"
                INSTALL_DIR="/usr/local/bin"
                MANPAGE_DIR="/usr/share/man/man1"
                ;;
            arch|manjaro|endeavouros|garuda)
                DISTRO_FAMILY="arch"
                INSTALL_DIR="/usr/local/bin"
                MANPAGE_DIR="/usr/share/man/man1"
                ;;
            opensuse*|sles)
                DISTRO_FAMILY="suse"
                INSTALL_DIR="/usr/local/bin"
                MANPAGE_DIR="/usr/share/man/man1"
                ;;
            gentoo)
                DISTRO_FAMILY="gentoo"
                INSTALL_DIR="/usr/local/bin"
                MANPAGE_DIR="/usr/share/man/man1"
                ;;
            alpine)
                DISTRO_FAMILY="alpine"
                INSTALL_DIR="/usr/local/bin"
                MANPAGE_DIR="/usr/share/man/man1"
                ;;
            void)
                DISTRO_FAMILY="void"
                INSTALL_DIR="/usr/local/bin"
                MANPAGE_DIR="/usr/share/man/man1"
                ;;
            *)
                DISTRO_FAMILY="unknown"
                INSTALL_DIR="/usr/local/bin"
                MANPAGE_DIR="/usr/share/man/man1"
                ;;
        esac
    else
        DISTRO_NAME="Unknown"
        DISTRO_FAMILY="unknown"
        INSTALL_DIR="/usr/local/bin"
        MANPAGE_DIR="/usr/share/man/man1"
    fi
}

################################################################################
# Privilege Elevation Detection
################################################################################

detect_elevation() {
    # Check if already root
    if [ "$EUID" -eq 0 ]; then
        ELEVATION_CMD=""
        return 0
    fi

    # Check for sudo
    if command -v sudo &> /dev/null; then
        ELEVATION_CMD="sudo"
        return 0
    fi

    # Check for doas (Alpine, some BSDs)
    if command -v doas &> /dev/null; then
        ELEVATION_CMD="doas"
        return 0
    fi

    # Check for pkexec (PolicyKit)
    if command -v pkexec &> /dev/null; then
        ELEVATION_CMD="pkexec"
        return 0
    fi

    print_error "No privilege elevation command found (sudo/doas/pkexec)"
    return 1
}

elevate() {
    if [ -n "$ELEVATION_CMD" ]; then
        $ELEVATION_CMD "$@"
    else
        "$@"
    fi
}

################################################################################
# Show Help
################################################################################

show_help() {
    cat << EOF
Linux Updater with Multi-Distro Support - Installer v2.5

USAGE:
    ./install-linup.sh [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -c, --compatibility     Check system compatibility before installing
    -v, --version           Show installer version

DESCRIPTION:
    Installs the Linux Updater with Multi-Distro Support to your system.

    Installation includes:
    • Main executable at /usr/local/bin/linup
    • Manual page at /usr/share/man/man1/linup.1.gz
    • Log file at /var/log/linup.log
    • Configuration directory at ~/cyberacq/software/linup

AFTER INSTALLATION:
    sudo linup                  Run the updater
    linup --help                Show help
    linup --compatibility       Check system compatibility
    linup --log                 View log file
    linup --remove              Uninstall linup
    man linup                   Read the manual

REQUIREMENTS:
    • Supported Linux distribution
    • Root privileges or sudo/doas/pkexec

SUPPORTED DISTRIBUTIONS:
    • Debian/Ubuntu (apt)
    • Fedora/RHEL/CentOS (dnf/yum)
    • Arch Linux (pacman)
    • openSUSE (zypper)
    • Alpine Linux (apk)
    • Void Linux (xbps)
    • Gentoo (emerge)

EOF
    exit 0
}

show_version() {
    echo "Linux Updater with Multi-Distro Support - Installer v2.5"
    exit 0
}

################################################################################
# Pre-Installation Compatibility Check
################################################################################

check_compatibility_preinstall() {
    echo ""
    print_header "Pre-Installation Compatibility Check"
    echo ""

    # Detect distribution
    detect_distro
    print_info "Distribution: $DISTRO_NAME"
    print_info "Distribution Family: $DISTRO_FAMILY"
    echo ""

    # Check for package manager
    local pkg_manager_found=false

    if command -v apt &> /dev/null && [ "$DISTRO_FAMILY" = "debian" ]; then
        print_success "Package Manager: apt (Debian/Ubuntu)"
        pkg_manager_found=true
    elif command -v dnf &> /dev/null && [ "$DISTRO_FAMILY" = "redhat" ]; then
        print_success "Package Manager: dnf (Fedora/RHEL)"
        pkg_manager_found=true
    elif command -v yum &> /dev/null && [ "$DISTRO_FAMILY" = "redhat" ]; then
        print_success "Package Manager: yum (CentOS/RHEL)"
        pkg_manager_found=true
    elif command -v pacman &> /dev/null && [ "$DISTRO_FAMILY" = "arch" ]; then
        print_success "Package Manager: pacman (Arch Linux)"
        pkg_manager_found=true
    elif command -v zypper &> /dev/null && [ "$DISTRO_FAMILY" = "suse" ]; then
        print_success "Package Manager: zypper (openSUSE)"
        pkg_manager_found=true
    elif command -v apk &> /dev/null && [ "$DISTRO_FAMILY" = "alpine" ]; then
        print_success "Package Manager: apk (Alpine Linux)"
        pkg_manager_found=true
    elif command -v xbps-install &> /dev/null && [ "$DISTRO_FAMILY" = "void" ]; then
        print_success "Package Manager: xbps (Void Linux)"
        pkg_manager_found=true
    elif command -v emerge &> /dev/null && [ "$DISTRO_FAMILY" = "gentoo" ]; then
        print_success "Package Manager: emerge (Gentoo)"
        pkg_manager_found=true
    fi

    if [ "$pkg_manager_found" = false ]; then
        echo ""
        print_error "No supported package manager found"
        echo ""
        echo "Supported package managers:"
        echo "  • apt (Debian/Ubuntu)"
        echo "  • dnf/yum (Fedora/RHEL/CentOS)"
        echo "  • pacman (Arch Linux)"
        echo "  • zypper (openSUSE)"
        echo "  • apk (Alpine Linux)"
        echo "  • xbps (Void Linux)"
        echo "  • emerge (Gentoo)"
        echo ""
        print_error "Your system is not currently supported"
        exit 1
    fi

    echo ""

    # Check elevation method
    if ! detect_elevation; then
        print_error "No privilege elevation method found"
        echo ""
        echo "Linup requires one of the following:"
        echo "  • sudo"
        echo "  • doas"
        echo "  • pkexec"
        echo "  • root access"
        echo ""
        exit 1
    fi

    if [ -n "$ELEVATION_CMD" ]; then
        print_success "Elevation method: $ELEVATION_CMD"
    else
        print_success "Elevation method: root"
    fi

    echo ""
    print_success "System is compatible with Linux Updater!"
    echo ""
    echo "Run './install-linup.sh' to install."
    echo ""

    exit 0
}

################################################################################
# Installation Functions
################################################################################

install_linup_script() {
    start_spinner "Creating linup executable..."
    sleep 1.0

    cat > "/tmp/linup" << 'LINUP_SCRIPT_EOF'
#!/bin/bash

################################################################################
# Linux Updater with Multi-Distro Support
# Version: 2.5
# Description: Cross-distribution system updater supporting multiple package managers
################################################################################

set -e

# Script metadata
SCRIPT_VERSION="2.5"
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

# Package manager detection
PKG_MANAGER=""
PKG_UPDATE_CMD=""
PKG_UPGRADE_CMD=""
PKG_UPGRADE_SINGLE_CMD=""
PKG_AUTOREMOVE_CMD=""
PKG_LIST_CMD=""
DISTRO_NAME=""
DISTRO_FAMILY=""

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

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
    log_action "INFO: $1"
}

print_header() {
    local text="$1"
    local text_length=${#text}
    local border_length=$((text_length + 4))
    local border=$(printf '━%.0s' $(seq 1 $border_length))

    echo -e "${CYAN}${border}${NC}"
    echo -e "${CYAN}  $text${NC}"
    echo -e "${CYAN}${border}${NC}"
}

################################################################################
# Distribution Detection
################################################################################

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_NAME="$NAME"

        # Detect distribution family
        case "$ID" in
            ubuntu|debian|linuxmint|pop|elementary|zorin)
                DISTRO_FAMILY="debian"
                ;;
            fedora|rhel|centos|rocky|almalinux)
                DISTRO_FAMILY="redhat"
                ;;
            arch|manjaro|endeavouros|garuda)
                DISTRO_FAMILY="arch"
                ;;
            opensuse*|sles)
                DISTRO_FAMILY="suse"
                ;;
            gentoo)
                DISTRO_FAMILY="gentoo"
                ;;
            alpine)
                DISTRO_FAMILY="alpine"
                ;;
            void)
                DISTRO_FAMILY="void"
                ;;
            *)
                DISTRO_FAMILY="unknown"
                ;;
        esac
    else
        DISTRO_NAME="Unknown"
        DISTRO_FAMILY="unknown"
    fi
}

detect_package_manager() {
    # APT (Debian/Ubuntu)
    if command -v apt &> /dev/null && [ "$DISTRO_FAMILY" = "debian" ]; then
        PKG_MANAGER="apt"
        PKG_UPDATE_CMD="apt update"
        PKG_UPGRADE_CMD="apt upgrade -y"
        PKG_UPGRADE_SINGLE_CMD="apt install --only-upgrade -y"
        PKG_AUTOREMOVE_CMD="apt autoremove -y"
        PKG_LIST_CMD="apt list --upgradable 2>/dev/null | grep -v 'Listing' | grep -v 'phased'"
        return 0
    fi

    # DNF (Fedora/RHEL 8+)
    if command -v dnf &> /dev/null && [ "$DISTRO_FAMILY" = "redhat" ]; then
        PKG_MANAGER="dnf"
        PKG_UPDATE_CMD="dnf check-update"
        PKG_UPGRADE_CMD="dnf upgrade -y"
        PKG_UPGRADE_SINGLE_CMD="dnf upgrade -y --best"
        PKG_AUTOREMOVE_CMD="dnf autoremove -y"
        PKG_LIST_CMD="dnf list updates"
        return 0
    fi

    # YUM (CentOS/RHEL 7)
    if command -v yum &> /dev/null && [ "$DISTRO_FAMILY" = "redhat" ]; then
        PKG_MANAGER="yum"
        PKG_UPDATE_CMD="yum check-update"
        PKG_UPGRADE_CMD="yum update -y"
        PKG_UPGRADE_SINGLE_CMD="yum update -y"
        PKG_AUTOREMOVE_CMD="yum autoremove -y"
        PKG_LIST_CMD="yum list updates"
        return 0
    fi

    # Pacman (Arch Linux)
    if command -v pacman &> /dev/null && [ "$DISTRO_FAMILY" = "arch" ]; then
        PKG_MANAGER="pacman"
        PKG_UPDATE_CMD="pacman -Sy"
        PKG_UPGRADE_CMD="pacman -Syu --noconfirm"
        PKG_UPGRADE_SINGLE_CMD="pacman -S --noconfirm"
        PKG_AUTOREMOVE_CMD="pacman -Rns \$(pacman -Qtdq) --noconfirm"
        PKG_LIST_CMD="pacman -Qu"
        return 0
    fi

    # Zypper (openSUSE)
    if command -v zypper &> /dev/null && [ "$DISTRO_FAMILY" = "suse" ]; then
        PKG_MANAGER="zypper"
        PKG_UPDATE_CMD="zypper refresh"
        PKG_UPGRADE_CMD="zypper update -y"
        PKG_UPGRADE_SINGLE_CMD="zypper update -y"
        PKG_AUTOREMOVE_CMD="zypper packages --unneeded | awk -F'|' 'NR>4 {print \$3}' | xargs zypper remove -y"
        PKG_LIST_CMD="zypper list-updates"
        return 0
    fi

    # APK (Alpine Linux)
    if command -v apk &> /dev/null && [ "$DISTRO_FAMILY" = "alpine" ]; then
        PKG_MANAGER="apk"
        PKG_UPDATE_CMD="apk update"
        PKG_UPGRADE_CMD="apk upgrade"
        PKG_UPGRADE_SINGLE_CMD="apk add -u"
        PKG_AUTOREMOVE_CMD="apk cache clean"
        PKG_LIST_CMD="apk version -v -l '<'"
        return 0
    fi

    # XBPS (Void Linux)
    if command -v xbps-install &> /dev/null && [ "$DISTRO_FAMILY" = "void" ]; then
        PKG_MANAGER="xbps"
        PKG_UPDATE_CMD="xbps-install -S"
        PKG_UPGRADE_CMD="xbps-install -yu"
        PKG_UPGRADE_SINGLE_CMD="xbps-install -yu"
        PKG_AUTOREMOVE_CMD="xbps-remove -yo"
        PKG_LIST_CMD="xbps-install -un"
        return 0
    fi

    # Emerge (Gentoo)
    if command -v emerge &> /dev/null && [ "$DISTRO_FAMILY" = "gentoo" ]; then
        PKG_MANAGER="emerge"
        PKG_UPDATE_CMD="emerge --sync"
        PKG_UPGRADE_CMD="emerge -uDU @world"
        PKG_UPGRADE_SINGLE_CMD="emerge -u"
        PKG_AUTOREMOVE_CMD="emerge --depclean"
        PKG_LIST_CMD="emerge -pvu @world | grep -E '^\['"
        return 0
    fi

    return 1
}

################################################################################
# Compatibility Check
################################################################################

check_compatibility() {
    echo ""
    print_header "System Compatibility Check"
    echo ""

    # Detect distribution
    detect_distro
    print_status "Distribution: $DISTRO_NAME"
    print_status "Distribution Family: $DISTRO_FAMILY"
    echo ""

    # Detect package manager
    if detect_package_manager; then
        print_success "Package Manager: $PKG_MANAGER"
        echo ""
        echo "Commands that will be used:"
        echo "  Update:              $PKG_UPDATE_CMD"
        echo "  Upgrade (all):       $PKG_UPGRADE_CMD"
        echo "  Upgrade (specific):  $PKG_UPGRADE_SINGLE_CMD <package>"
        echo "  Autoremove:          $PKG_AUTOREMOVE_CMD"
        echo ""
        print_success "System is compatible!"
    else
        print_error "No supported package manager found"
        echo ""
        echo "Supported package managers:"
        echo "  • apt (Debian/Ubuntu)"
        echo "  • dnf/yum (Fedora/RHEL/CentOS)"
        echo "  • pacman (Arch Linux)"
        echo "  • zypper (openSUSE)"
        echo "  • apk (Alpine Linux)"
        echo "  • xbps (Void Linux)"
        echo "  • emerge (Gentoo)"
        echo ""
        print_error "Your system is not currently supported"
        exit 1
    fi

    # Check dependencies
    echo ""
    print_status "Checking dependencies..."

    local missing_deps=()

    # Check for systemd (for reboot detection)
    if ! command -v systemctl &> /dev/null; then
        missing_deps+=("systemd")
    fi

    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_success "All dependencies satisfied"
    else
        print_warning "Optional dependencies missing: ${missing_deps[*]}"
        echo "  Some features may be limited"
    fi

    echo ""
    exit 0
}

################################################################################
# Version and Help Functions
################################################################################

show_version() {
    echo "Linux Updater with Multi-Distro Support version $SCRIPT_VERSION"
    exit 0
}

show_help() {
    cat << EOF
Linux Updater with Multi-Distro Support v$SCRIPT_VERSION - Cross-Distribution Update Manager

USAGE:
    $SCRIPT_NAME [OPTIONS]

DESCRIPTION:
    Comprehensive system updater supporting multiple Linux distributions and
    package managers with intelligent update handling.

OPTIONS:
    -h, --help              Display this help message
    -v, --version           Display version information
    -l, --log               View the linup log file
    -c, --compatibility     Check system compatibility
    -r, --remove            Uninstall linup

SUPPORTED DISTRIBUTIONS:
    • Debian/Ubuntu (apt)
    • Fedora/RHEL/CentOS (dnf/yum)
    • Arch Linux (pacman)
    • openSUSE (zypper)
    • Alpine Linux (apk)
    • Void Linux (xbps)
    • Gentoo (emerge)

FEATURES:
    • Automatic package manager detection
    • Interactive update selection with numbered packages
    • Selective package upgrades using --only-upgrade equivalent
    • Tiered reboot management: required (kernel/libc/systemd/dbus) vs
      recommended (libssl/openssl/libgnutls)
    • Stale library detection via /proc maps for distros without reboot flags
    • Package cleanup and autoremove
    • Comprehensive logging
    • Cross-distribution compatibility

EXAMPLES:
    # Run the updater interactively
    sudo $SCRIPT_NAME

    # Check system compatibility
    $SCRIPT_NAME --compatibility

    # View the log file
    $SCRIPT_NAME --log

REQUIREMENTS:
    • Must be run as root or with sudo for update operations
    • Supported Linux distribution
    • Compatible package manager

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
# Reboot Detection Functions
################################################################################

check_kernel_reboot_needed() {
    # Debian/Ubuntu style - check for reboot-required file first
    if [ -f /var/run/reboot-required ]; then
        if grep -q "linux-image" /var/run/reboot-required.pkgs 2>/dev/null; then
            return 0
        fi
    fi

    # Check if running kernel differs from installed
    if [ -f /proc/version ]; then
        local running_kernel
        local installed_kernel=""
        running_kernel=$(uname -r)

        case "$PKG_MANAGER" in
            apt)
                # grep 'linux-image-[0-9]' excludes metapackages like linux-image-generic
                # which would otherwise produce "generic" != uname -r.
                # Extract the version suffix first, then version-sort the clean
                # strings: sorting the raw `dpkg -l` lines with `sort -V -k3` keys
                # on field 3 *through end of line* (the padded description column),
                # which corrupts the ordering and returns the OLDEST kernel — a
                # false "reboot required" on every run.
                installed_kernel=$(dpkg -l 2>/dev/null | grep ^ii | awk '{print $2}' | grep -E '^linux-image-[0-9]' | sed 's/linux-image-//' | sort -V | tail -1 || true)
                ;;
            dnf|yum)
                installed_kernel=$(rpm -q kernel 2>/dev/null | sort -V | tail -1 | sed 's/kernel-//' || true)
                ;;
            pacman)
                installed_kernel=$(pacman -Q linux 2>/dev/null | awk '{print $2}' || true)
                ;;
        esac

        # Only return true if we actually found a different kernel
        if [ -n "$installed_kernel" ] && [ "$running_kernel" != "$installed_kernel" ]; then
            return 0
        fi
    fi

    return 1
}

# Returns a newline-separated list of process names holding deleted *shared
# library* (.so) mappings. Matching bare '(deleted)' is too broad: long-running
# processes routinely hold deleted /memfd:, /SYSV (shm), dconf, semaphore and
# similar runtime mappings that have nothing to do with package updates, which
# made the critical-reboot fallback fire on essentially every run. Restrict to
# deleted .so mappings so only a genuine library replacement counts.
get_stale_processes() {
    find /proc -maxdepth 2 -name maps -readable 2>/dev/null \
        | xargs grep -lE '\.so[.0-9]*[[:space:]]+\(deleted\)' 2>/dev/null \
        | awk -F/ '{print $3}' \
        | sort -u \
        | while read -r pid; do cat "/proc/$pid/comm" 2>/dev/null; done \
        | sort -u
}

# Critical packages: cannot be activated without a reboot.
# Covers: core C library, init system, device manager, IPC bus, PAM stack.
check_critical_reboot_needed() {
    # Debian/Ubuntu: parse reboot-required.pkgs for critical non-kernel entries
    if [ -f /var/run/reboot-required.pkgs ]; then
        if grep -qE '^(libc6|systemd|udev|dbus|libpam)' /var/run/reboot-required.pkgs 2>/dev/null; then
            return 0
        fi
    fi

    # RHEL/Fedora: needs-restarting -r exits 1 when a reboot is needed
    if [ "$DISTRO_FAMILY" = "redhat" ] && command -v needs-restarting &>/dev/null; then
        if ! needs-restarting -r &>/dev/null; then
            return 0
        fi
    fi

    # Fallback for all distros: processes holding stale mappings for critical libs
    local stale
    stale=$(get_stale_processes | grep -E '^(systemd|dbus-daemon|udevd|sshd|init)$' || true)
    if [ -n "$stale" ]; then
        return 0
    fi

    return 1
}

# Recommended packages: running processes use the old version but a restart
# of individual services is an acceptable alternative to a full reboot.
check_recommended_reboot_needed() {
    # Debian/Ubuntu: check reboot-required.pkgs for TLS/crypto libraries
    if [ -f /var/run/reboot-required.pkgs ]; then
        if grep -qE '^(libssl|openssl|libgnutls|libcrypto)' /var/run/reboot-required.pkgs 2>/dev/null; then
            return 0
        fi
    fi

    # Fallback: any process holding a deleted libssl/libcrypto/libgnutls mapping
    local stale
    stale=$(find /proc -maxdepth 2 -name maps -readable 2>/dev/null \
        | xargs grep -lE 'lib(ssl|crypto|gnutls)[^/]*(deleted)' 2>/dev/null \
        | awk -F/ '{print $3}' | sort -u | head -1 || true)
    if [ -n "$stale" ]; then
        return 0
    fi

    return 1
}

offer_reboot() {
    local kernel_reboot=false
    local critical_reboot=false
    local recommended_reboot=false

    check_kernel_reboot_needed  && kernel_reboot=true   || true
    check_critical_reboot_needed && critical_reboot=true || true
    check_recommended_reboot_needed && recommended_reboot=true || true

    # ── Required reboot ──────────────────────────────────────────────────────
    if [ "$kernel_reboot" = true ] || [ "$critical_reboot" = true ]; then
        echo ""
        print_warning "Reboot required to complete updates"
        echo ""

        if [ "$kernel_reboot" = true ]; then
            if [ -f /var/run/reboot-required.pkgs ]; then
                local kernel_pkgs
                kernel_pkgs=$(grep -E '^(linux-image|linux-modules)' /var/run/reboot-required.pkgs 2>/dev/null || true)
                if [ -n "$kernel_pkgs" ]; then
                    echo "  Kernel packages updated:"
                    echo "$kernel_pkgs" | sed 's/^/    - /'
                fi
            else
                echo "  Kernel: installed version differs from running kernel"
            fi
        fi

        if [ "$critical_reboot" = true ]; then
            echo "  Critical system libraries/services updated:"

            # Show named packages from reboot-required.pkgs when available
            if [ -f /var/run/reboot-required.pkgs ]; then
                local critical_pkgs
                critical_pkgs=$(grep -E '^(libc6|systemd|udev|dbus|libpam)' /var/run/reboot-required.pkgs 2>/dev/null || true)
                if [ -n "$critical_pkgs" ]; then
                    echo "$critical_pkgs" | sed 's/^/    - /'
                fi
            fi

            # Show stale process names detected via /proc maps
            local stale_critical
            stale_critical=$(get_stale_processes | grep -E '^(systemd|dbus-daemon|udevd|sshd|init)$' || true)
            if [ -n "$stale_critical" ]; then
                echo "  Processes running against replaced libraries:"
                echo "$stale_critical" | sed 's/^/    - /'
            fi

            # RHEL/Fedora: show needs-restarting output if available
            if [ "$DISTRO_FAMILY" = "redhat" ] && command -v needs-restarting &>/dev/null; then
                local nr_output
                nr_output=$(needs-restarting -r 2>&1 || true)
                if [ -n "$nr_output" ]; then
                    echo "  needs-restarting:"
                    echo "$nr_output" | sed 's/^/    /'
                fi
            fi
        fi

        echo ""
        log_action "Reboot required: kernel=$kernel_reboot critical=$critical_reboot"
        read -p "Reboot now? (Y/n): " response
        case "${response,,}" in
            n|no)
                print_status "Reboot postponed. Please reboot manually when convenient."
                log_action "User postponed required reboot"
                ;;
            *)
                print_status "Rebooting system in 5 seconds..."
                log_action "System reboot initiated by user"
                sleep 5
                reboot
                ;;
        esac
        return
    fi

    # ── Recommended reboot (only shown when no required reboot) ──────────────
    if [ "$recommended_reboot" = true ]; then
        echo ""
        print_info "Reboot recommended (non-critical)"
        echo ""

        if [ -f /var/run/reboot-required.pkgs ]; then
            local rec_pkgs
            rec_pkgs=$(grep -E '^(libssl|openssl|libgnutls|libcrypto)' /var/run/reboot-required.pkgs 2>/dev/null || true)
            if [ -n "$rec_pkgs" ]; then
                echo "  Packages that benefit from a reboot:"
                echo "$rec_pkgs" | sed 's/^/    - /'
            fi
        else
            echo "  TLS/crypto libraries were updated; running processes use the old versions."
        fi

        echo "  Affected services can alternatively be restarted individually."
        echo ""
        log_action "Reboot recommended: libssl/crypto libraries updated"
        read -p "Reboot now? (Y/n/skip): " response
        case "${response,,}" in
            n|no|s|skip)
                print_status "Reboot skipped. Consider restarting affected services."
                log_action "User skipped recommended reboot"
                ;;
            *)
                print_status "Rebooting system in 5 seconds..."
                log_action "System reboot initiated by user (recommended)"
                sleep 5
                reboot
                ;;
        esac
    fi
}

################################################################################
# Package Name Extraction Functions
################################################################################

extract_package_name() {
    local pkg_line="$1"
    local pkg_name=""

    case "$PKG_MANAGER" in
        apt)
            # Format: package/suite version arch [upgradable from: oldversion]
            pkg_name=$(echo "$pkg_line" | cut -d'/' -f1)
            ;;
        dnf|yum)
            # Format: package.arch version repo
            pkg_name=$(echo "$pkg_line" | awk '{print $1}')
            ;;
        pacman)
            # Format: package oldversion -> newversion
            pkg_name=$(echo "$pkg_line" | awk '{print $1}')
            ;;
        zypper)
            # Format varies, typically: package | version | arch | vendor
            pkg_name=$(echo "$pkg_line" | awk '{print $1}' | tr -d '|' | xargs)
            ;;
        apk)
            # Format: package-oldversion < newversion
            pkg_name=$(echo "$pkg_line" | awk '{print $1}' | sed 's/-[0-9].*//')
            ;;
        xbps)
            # Format: package-version
            pkg_name=$(echo "$pkg_line" | awk '{print $1}' | sed 's/-[0-9].*//')
            ;;
        emerge)
            # Format: [ebuild...] category/package-version
            pkg_name=$(echo "$pkg_line" | grep -oP '[\w-]+/[\w-]+' | cut -d'/' -f2 | sed 's/-[0-9].*//')
            ;;
        *)
            pkg_name=$(echo "$pkg_line" | awk '{print $1}')
            ;;
    esac

    echo "$pkg_name"
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
            eval $PKG_UPDATE_CMD > /dev/null 2>&1 || true

            # Capture upgradable packages
            mapfile -t UPDATES < <(eval $PKG_LIST_CMD 2>/dev/null || true)

            if [ ${#UPDATES[@]} -eq 0 ]; then
                print_success "No updates available"
                log_action "No updates available"
                return 1
            fi

            echo ""
            echo "Available updates:"
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
                local pkg_name=$(extract_package_name "$pkg_line")
                print_status "Installing $pkg_name (upgrade only)..."
                eval $PKG_UPGRADE_SINGLE_CMD "$pkg_name"
                print_success "Update applied successfully"
                log_action "Installed specific package: $pkg_name (upgrade-only mode)"
            else
                print_error "Invalid update number"
                log_action "Invalid update number entered: $update_num"
            fi
            ;;
        *)
            print_status "Applying all updates..."
            eval $PKG_UPGRADE_CMD
            print_success "All updates applied successfully"
            log_action "Applied all available updates"
            ;;
    esac
}

run_autoremove() {
    # Check if autoremove is applicable
    case "$PKG_MANAGER" in
        apt)
            local autoremove_check=$(apt autoremove --dry-run 2>/dev/null | grep -c "^Remv" || true)
            if [ "$autoremove_check" -eq 0 ]; then
                log_action "No packages to autoremove"
                return
            fi
            ;;
        pacman)
            if ! pacman -Qtdq &> /dev/null; then
                log_action "No orphaned packages"
                return
            fi
            ;;
    esac

    echo ""
    read -p "Do you want to run package cleanup/autoremove? (Y/n): " autoremove_choice

    case "${autoremove_choice,,}" in
        n|no)
            echo "Package cleanup not selected."
            log_action "User skipped autoremove"
            ;;
        *)
            print_status "Removing unnecessary packages..."
            eval $PKG_AUTOREMOVE_CMD 2>/dev/null || print_warning "Autoremove not applicable or failed"
            print_success "Cleanup completed"
            log_action "Autoremove completed"
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

    # Detect system
    detect_distro
    if ! detect_package_manager; then
        print_error "No supported package manager found on this system"
        echo "Run '$SCRIPT_NAME --compatibility' for more information"
        exit 1
    fi

    # Initialize log
    log_action "===== Linup session started on $DISTRO_NAME using $PKG_MANAGER ====="

    # Welcome banner
    echo ""
    print_header "Linux Updater with Multi-Distro Support v$SCRIPT_VERSION"
    print_status "Distribution: $DISTRO_NAME"
    print_status "Package Manager: $PKG_MANAGER"
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
    -c|--compatibility)
        check_compatibility
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

    elevate install -m 755 -o root -g root /tmp/linup "$INSTALL_DIR/linup"
    rm /tmp/linup

    stop_spinner "success" "Linup executable created"
}

install_manpage() {
    start_spinner "Installing manual page..."
    sleep 1.0

    elevate mkdir -p "$MANPAGE_DIR"

    cat << 'MANPAGE_EOF' | gzip > /tmp/linup.1.gz
.TH linup 1 "June 2026" "Version 2.5" "User Commands"
.SH NAME
linup \- Linux Updater with Multi-Distro Support
.SH SYNOPSIS
.B linup
[\fIOPTIONS\fR]
.SH DESCRIPTION
.B linup
is a cross-distribution system update manager supporting multiple Linux distributions and package managers with intelligent update handling.
.PP
The script automatically detects your distribution and package manager, providing a unified interface for system updates across different Linux flavors.
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
.BR \-c ", " \-\-compatibility
Check system compatibility and show detected configuration
.TP
.BR \-r ", " \-\-remove
Uninstall linup from the system
.SH SUPPORTED DISTRIBUTIONS
.TP
.B Debian Family
Ubuntu, Debian, Linux Mint, Pop!_OS, Elementary, Zorin (using apt with --only-upgrade)
.TP
.B Red Hat Family
Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux (using dnf/yum with upgrade-only mode)
.TP
.B Arch Family
Arch Linux, Manjaro, EndeavourOS, Garuda (using pacman with targeted upgrades)
.TP
.B openSUSE
openSUSE, SLES (using zypper with update mode)
.TP
.B Alpine Linux
Alpine (using apk with upgrade mode)
.TP
.B Void Linux
Void (using xbps with upgrade mode)
.TP
.B Gentoo
Gentoo (using emerge with update mode)
.SH FEATURES
.TP
.B Automatic Detection
Detects your distribution and configures the appropriate package manager automatically
.TP
.B Interactive Updates with Selective Upgrades
Prompts for each operation with numbered package selection using upgrade-only modes
.TP
.B Tiered Reboot Management
Distinguishes between packages that require a reboot (kernel, libc6, systemd, udev,
dbus, libpam) and those where a reboot is merely recommended (libssl, openssl,
libgnutls). Each tier shows the responsible packages and prompts separately.
.TP
.B Stale Library Detection
Uses /proc/*/maps to detect processes holding file descriptors to replaced shared
libraries, providing reboot guidance on distributions that lack a reboot-required
flag file (Arch, openSUSE, Alpine, Void, Gentoo).
.TP
.B RHEL/Fedora Integration
Invokes needs-restarting(1) from dnf-utils when available for authoritative
reboot-required determination on Red Hat family systems.
.TP
.B Package Cleanup
Intelligent autoremove that only prompts when cleanup is needed
.TP
.B Comprehensive Logging
All actions are logged to /var/log/linup.log for audit purposes
.SH WORKFLOW
.PP
The script follows this workflow:
.IP 1. 3
Detect distribution and package manager
.IP 2.
Optional: List available updates with numbers
.IP 3.
Apply system package updates (all or specific with upgrade-only mode)
.IP 4.
Run package cleanup/autoremove if needed
.IP 5.
Check for required reboot (kernel, libc6, systemd, dbus, udev, libpam, or
stale critical process mappings). If detected, prompt to reboot now.
.IP 6.
If no required reboot, check for recommended reboot (libssl, openssl,
libgnutls or stale crypto library mappings). If detected, prompt to reboot
or skip in favour of individual service restarts.
.SH REBOOT DETECTION
.PP
Reboot detection uses multiple sources depending on the distribution:
.TP
.B /var/run/reboot-required.pkgs
Debian/Ubuntu systems write package names here after updates. linup
parses this file to classify packages as requiring or merely recommending
a reboot.
.TP
.B needs-restarting -r
On RHEL/Fedora systems with dnf-utils installed, this command provides
authoritative reboot-required status.
.TP
.B /proc/*/maps
All distributions: processes holding file descriptors to deleted (replaced)
shared library files are detected by scanning /proc/PID/maps for entries
marked (deleted). Critical process names (systemd, dbus-daemon, udevd, sshd)
trigger a required reboot warning; TLS library matches trigger a recommended
reboot warning.
.SH EXAMPLES
.TP
Run the updater interactively:
.B sudo linup
.TP
Check system compatibility:
.B linup --compatibility
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
.I /var/run/reboot-required
System reboot requirement flag (Debian/Ubuntu)
.TP
.I /var/run/reboot-required.pkgs
Packages that triggered the reboot requirement (Debian/Ubuntu)
.SH EXIT STATUS
.TP
.B 0
Success
.TP
.B 1
Error (not run as root, unsupported system, etc.)
.SH REQUIREMENTS
.IP \(bu 2
Must be run as root or with sudo for update operations
.IP \(bu
Supported Linux distribution
.IP \(bu
Compatible package manager
.SH AUTHOR
cyberacq - https://github.com/cyberacq/linup
.SH SEE ALSO
.BR apt (8),
.BR dnf (8),
.BR yum (8),
.BR pacman (8),
.BR zypper (8),
.BR apk (8),
.BR emerge (1),
.BR needs-restarting (1)
MANPAGE_EOF

    elevate install -m 644 -o root -g root /tmp/linup.1.gz "$MANPAGE_DIR/linup.1.gz"
    rm /tmp/linup.1.gz

    if command -v mandb &> /dev/null; then
        elevate mandb -q 2>/dev/null || true
    fi

    stop_spinner "success" "Manual page installed"
}

################################################################################
# Main Installation
################################################################################

main() {
    echo ""
    print_header "Linux Updater with Multi-Distro Support - Installer v2.5"
    echo ""

    # Detect distribution
    start_spinner "Detecting system configuration..."
    sleep 1.0
    detect_distro
    stop_spinner "success" "System configuration detected"

    echo ""
    print_info "Distribution: $DISTRO_NAME"
    print_info "Distribution Family: $DISTRO_FAMILY"
    print_info "Installation Directory: $INSTALL_DIR"
    print_info "Manpage Directory: $MANPAGE_DIR"
    echo ""

    # Detect elevation method
    if ! detect_elevation; then
        print_error "Cannot proceed without privilege elevation"
        exit 1
    fi

    if [ -n "$ELEVATION_CMD" ]; then
        print_info "Using '$ELEVATION_CMD' for privilege elevation"
        echo ""
        echo "You may be prompted for your password..."
        echo ""
    else
        print_info "Running as root"
        echo ""
    fi

    # Create directories
    start_spinner "Creating directories..."
    sleep 1.0
    mkdir -p "$CONFIG_DIR"
    elevate touch "$LOG_FILE"
    elevate chmod 644 "$LOG_FILE"
    stop_spinner "success" "Directories created"

    # Install linup script
    install_linup_script

    # Install manpage
    install_manpage

    echo ""
    print_header "Installation Complete!"
    echo ""
    echo "Linup has been successfully installed to $INSTALL_DIR/linup"
    echo ""
    echo "Installation details:"
    echo "  Executable: $INSTALL_DIR/linup (root-owned, user-executable)"
    echo "  Manpage: $MANPAGE_DIR/linup.1.gz"
    echo "  Log file: $LOG_FILE"
    echo ""
    echo "Usage:"
    echo "  sudo linup              - Run the updater"
    echo "  linup --help            - Show help"
    echo "  linup --compatibility   - Check system compatibility"
    echo "  linup --log             - View log file"
    echo "  linup --remove          - Uninstall linup"
    echo "  man linup               - Read the manual"
    echo ""

    # Show detected configuration
    print_info "Detected configuration:"
    echo "  Distribution: $DISTRO_NAME"
    echo "  Elevation method: ${ELEVATION_CMD:-root}"
    echo ""
}

################################################################################
# Argument Parsing
################################################################################

case "$1" in
    -h|--help)
        show_help
        ;;
    -v|--version)
        show_version
        ;;
    -c|--compatibility)
        check_compatibility_preinstall
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Run './install-linup.sh --help' for usage information"
        exit 1
        ;;
esac

exit 0
