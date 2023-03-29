#!/bin/sh
# @file    setup.sh
# @date    January 3rd, 2022
# @author  Passific
# @brief   Environment configuration
# shellcheck disable=SC2059

if [ -t 1 ]; then
    IS_INTERACTIVE="yes"
else
    IS_INTERACTIVE="no"
fi

readonly KERNELNAME=$(uname -s)
if grep -qi Microsoft /proc/version; then
    IS_WSL="yes"
else
    IS_WSL="no"
fi

if command -v apt-get >/dev/null 2>&1; then
    HAS_APT="yes"
else
    HAS_APT="no"
fi

if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    IS_SSH="yes"
else
    IS_SSH="no"
fi

USE_PROXY="no"

setup_color() {
    # Only use colors if connected to a terminal
    if [ yes = "${IS_INTERACTIVE}" ]; then
        RED=$(printf '\033[31m')
        GREEN=$(printf '\033[32m')
        YELLOW=$(printf '\033[33m')
        #~ BLUE=$(printf '\033[34m')
        #~ BOLD=$(printf '\033[1m')
        RESET=$(printf '\033[m')
    else
        RED=""
        GREEN=""
        YELLOW=""
        #~ BLUE=""
        #~ BOLD=""
        RESET=""
    fi
}

is_user_root() {
    [ "$(id -u)" -eq 0 ];
}

pprintf() {
    # shellcheck disable=SC2059
    printf " * [ .... ] %s " "$(printf "$@")"
}
ok_and_exit() {
    printf "\nEverything is done with ${GREEN}SUCCESS${RESET}\n"
    exit 0
}
ok_and_continue() {
    printf "\r * [  ${GREEN}OK${RESET}  ]\n"
}
fixed_and_continue() {
    printf "\r * [  ${YELLOW}FIX${RESET} ]\n"
}
fail_and_exit() {
    printf "\r * [${RED}FAILED${RESET}]\n"
    exit 1
}
do_install() {
    printf "The following packages must be installed: %s\r" "$*"
    if [ yes = "$HAS_APT" ]; then
        sudo apt-get -qq install "$@" > /dev/null || fail_and_exit
        fixed_and_continue
    else
        printf "\n"
        exit 1
    fi
}

check_parameters() {
    usage="Usage:
$0 <firstname> <lastname> <email> [<http_proxy> [<https_proxy> [<no_proxy>]]]
"
    if [ no = "${IS_INTERACTIVE}" ]; then
        missing="Error! Parameter missing... ${usage}"
        export firstname=${1:?${missing}}
        export lastname=${2:?${missing}}
        export useremail=${3:?${missing}}
        export http_proxy=${4:+${missing}}
        export https_proxy=${5:+${missing}}
        export no_proxy=${6:+${missing}}
    fi
    if [ "$#" -gt 6 ]; then
        echo "Too many arguments..."
        echo "${usage}"
        fail_and_exit
    fi
    exit 0
}

check_proxy() {
    pprintf "Checking proxy settings..."
    if [ -z ${http_proxy+x} ] && [ yes = "${IS_INTERACTIVE}" ]; then
        printf "\n${YELLOW}Please provide with proxy configuration${RESET}\n"
        printf "    HTTP proxy: ";  read -r http_proxy
        printf "    HTTPS proxy: "; read -r https_proxy
        printf "    no proxy: ";    read -r no_proxy

        if [ -n "${http_proxy}" ] || [ -n "${https_proxy}" ]; then
            export http_proxy
            export https_proxy
            export no_proxy
        fi
    fi
    if [ -n "${http_proxy}" ] || [ -n "${https_proxy}" ]; then
        USE_PROXY="yes"
        readonly aptConfig="/etc/apt/apt.conf.d/99mysettings"

        if [ yes = "$HAS_APT" ] && [ ! -f "${aptConfig}" ]; then
            pprintf "Applying proxy config to APT..."
            echo "Acquire::http::Proxy \"${http_proxy}\";" > tmpAptConfig          || fail_and_exit
            echo "Acquire::https::Proxy \"${https_proxy}\";" >> tmpAptConfig       || fail_and_exit
            sudo install -o "$USER" -g "$USER" -m 644 tmpAptConfig "${aptConfig}"  || fail_and_exit
            fixed_and_continue
        else
            ok_and_continue
        fi
    else
        pprintf "Not using proxy"
        ok_and_continue
    fi
}

update_system() {
    if [ yes = "$HAS_APT" ]; then
        pprintf "Updating system..."
        printf "update..."
        sudo apt-get -qq update > /dev/null         || fail_and_exit
        printf " upgrade..."
        sudo apt-get -qq upgrade > /dev/null        || fail_and_exit
        printf " dist-upgrade..."
        sudo apt-get -qq dist-upgrade > /dev/null   || fail_and_exit
        printf " autoremove..."
        sudo apt-get -qq autoremove > /dev/null     || fail_and_exit
        ok_and_continue
    else
        printf "${YELLOW}Please check your system is up to date.${RESET}\n"
    fi
    if [ -f /var/run/reboot-required ]; then
        printf "\n${RED}REBOOT REQUIRED FOR:${RESET}\n"
        cat /var/run/reboot-required.pkgs
        exit 1
    fi
}

check_dependencies() {
    pprintf "Check dependencies..."
    command -v git      >/dev/null 2>&1 || set -- git "$@";
    command -v wget     >/dev/null 2>&1 || set -- wget "$@";
    command -v zsh      >/dev/null 2>&1 || set -- zsh "$@";
    command -v neofetch >/dev/null 2>&1 || set -- neofetch "$@";
    command -v tr       >/dev/null 2>&1 || set -- coreutils "$@";
    command -v ps       >/dev/null 2>&1 || set -- procps "$@";
    command -v sed      >/dev/null 2>&1 || set -- sed "$@";
    command -v gpg      >/dev/null 2>&1 || set -- gpg "$@";

    if [ $# -ne 0 ]; then
        do_install "$@"
    else
        ok_and_continue
    fi
}

install_packages() {
    # Must be run after dependencies check
    pprintf "Install packages..."

    # If run with sudo, SSH_* variables may not be forwarded
    if ps -o comm= -p "$PPID" | tr '\n' ' ' | grep -q sshd; then
        IS_SSH="yes"
    fi

    command -v tree       >/dev/null 2>&1 || set -- tree "$@";
    command -v nano       >/dev/null 2>&1 || set -- nano "$@";
    command -v file       >/dev/null 2>&1 || set -- file "$@";
    command -v curl       >/dev/null 2>&1 || set -- curl "$@";
    command -v wget       >/dev/null 2>&1 || set -- wget "$@";
    command -v dos2unix   >/dev/null 2>&1 || set -- dos2unix "$@";
    command -v shellcheck >/dev/null 2>&1 || set -- shellcheck "$@";

    if [ no = "$IS_WSL" ]; then
        command -v gcc      >/dev/null 2>&1 || set -- build-essential "$@";
        command -v ninja    >/dev/null 2>&1 || set -- ninja-build "$@";
        command -v valgrind >/dev/null 2>&1 || set -- valgrind "$@";

        if [ no = "$IS_SSH" ]; then
            command -v terminator >/dev/null 2>&1 || set -- terminator "$@";
        fi
    fi

    if [ $# -ne 0 ]; then
        do_install "$@"
    else
        ok_and_continue
    fi
}

install_ohmyzsh() {
    pprintf "Install oh-my-zsh..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(wget -qO- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || fail_and_exit
        fixed_and_continue
    else
        ok_and_continue
    fi
}

config_ohmyzsh() {
    pprintf "Configure oh-my-zsh..."
    if [ ! -f "$HOME/.zshrc" ]; then
        install -m 644 zshrc "$HOME/.zshrc"  || fail_and_exit
        fixed_and_continue
    else
        ok_and_continue
    fi
}

set_default_sh() {
    pprintf "Set zsh as default... %s" "$SHELL"
    if [ "$(command -v zsh)" != "$SHELL" ]; then
        chsh -s "$(command -v zsh)" || fail_and_exit
        fixed_and_continue
    else
        ok_and_continue
    fi
}

config_wsl() {
    pprintf "Configure WSL..."
    if [ yes = "$IS_WSL" ]; then
        if [ ! -f "$HOME/.dircolors" ]; then
            wget -qO "$HOME/.dircolors" https://raw.githubusercontent.com/seebi/dircolors-solarized/master/dircolors.ansi-dark || fail_and_exit
            chmod 644 "$HOME/.dircolors" || fail_and_exit
            fixed_and_continue
        else
            ok_and_continue
        fi
    else
        printf "WSL not detected"
        ok_and_continue
    fi
}

config_git_name() {
    pprintf "Configure Git config user.name..."
    name="$(git config --global user.name)"
    printf "%s" "$name"
    if [ -z "$name" ]; then
        if [ yes = "${IS_INTERACTIVE}" ]; then
            echo "Enter your first name:"
            read -r firstname
            echo "Enter your last name:"
            read -r lastname
        fi
        if [ -z "$firstname" ]; then
            echo "Firstname cannot be empty..."
            fail_and_exit
        fi
        if [ -z "$lastname"  ]; then
            echo "Lastname cannot be empty..."
            fail_and_exit
        fi
        #convert to lower case the first name
        firstname=$(echo "$firstname" | tr "[:upper:]" "[:lower:]";)
        #convert the first letter in upper case
        #firstname=${firstname^}   is not POSIX and does not work with dash ( default ubuntu sh)
        #\(.\) matches a single character
        #\U\1 replaces that character with an uppercase version
        #no /g means only the first match is processed.
        firstname=$(echo "$firstname" | sed 's/\(.\)/\U\1/')
        #convert in upper case the last name
        lastname=$(echo "$lastname" | tr "[:lower:]" "[:upper:]";)
        git config --global user.name "$firstname $lastname" || fail_and_exit
        fixed_and_continue
    else
        ok_and_continue
    fi
}
config_git_email() {
    pprintf "Configure Git config user.email..."
    email="$(git config --global user.email)"
    printf "%s" "$email"
    if [ -z "$email" ]; then
        if [ yes = "${IS_INTERACTIVE}" ]; then
            echo "Enter your email address:"
            read -r useremail
        fi
        if [ -z "$useremail" ]; then
            echo "Email cannot be empty..."
            fail_and_exit
        fi
        git config --global user.email "$useremail" || fail_and_exit
        fixed_and_continue
    else
        ok_and_continue
    fi
}
config_git_autocrlf() {
    pprintf "Configure Git config core.autocrlf..."
    autocrlf="$(git config --global core.autocrlf)"
    printf "%s" "$autocrlf"
    if [ -z "$autocrlf" ]; then
        if [ "Linux" = "$KERNELNAME" ]; then
            coreautocrlfval="input"
        else
            coreautocrlfval="false"
        fi
        if [ "$(git config --global core.autocrlf)" != "$coreautocrlfval" ]; then
            printf " set to %s" "$coreautocrlfval"
            git config --global core.autocrlf "$coreautocrlfval" || fail_and_exit
            fixed_and_continue
        else
            ok_and_continue
        fi
    else
        ok_and_continue
    fi
}
config_git_pull() {
    pprintf "Configure Git config pull.ff..."
    pull="$(git config --global pull.ff)"
    printf "%s" "$pull"
    if [ -z "$pull" ]; then
        printf " set to only"
        git config --global pull.ff only || fail_and_exit
        fixed_and_continue
    else
        ok_and_continue
    fi
}
config_git_credential() {
    pprintf "Configure Git config credential.helper..."
    credential="$(git config --global credential.helper)"
    printf "%s" "$credential"
    if [ -z "$credential" ]; then
        printf " set to store --file ~/.git-credentials"
        git config --global credential.helper 'store --file ~/.git-credentials' || fail_and_exit
        fixed_and_continue
    else
        ok_and_continue
    fi
}
config_git_hooksPath() {
    pprintf "Configure Git config core.hooksPath..."
    hooksPath="$(git config --global core.hooksPath)"
    printf "%s" "$hooksPath"
    if [ ".githooks" != "$hooksPath" ]; then
        printf " swithed to .githooks"
        git config --global core.hooksPath .githooks || fail_and_exit
        fixed_and_continue
    else
        ok_and_continue
    fi
}
setup_gpg() {
    pprintf "Setup GPG keys..."
    email=$(git config --global user.email)
    if [ -z "$(gpg --list-secret-keys --keyid-format LONG "$email" 2>/dev/null)" ]; then
        name=$(git config --global user.name)
        {
            echo "%no-protection"
            echo "%echo Generating a basic OpenPGP key"
            echo "Key-Type: 1"
            echo "Key-Length: 4096"
            echo "Name-Real: $name"
            echo "Name-Email: $email"
            echo "Expire-Date: 0"
            echo "%commit"
            echo "%echo done"
        } > /tmp/gpg-file || fail_and_exit
        gpg --batch --full-generate-key /tmp/gpg-file || fail_and_exit
        rm /tmp/gpg-file
        key=$(gpg --list-secret-keys --keyid-format LONG "$email" | head -n1 | xargs | cut -d' ' -f2 | cut -d '/' -f2)
        fixed_and_continue
        printf "${YELLOW}Copy the following key into your DevOps platforms${RESET}\n\n"
        gpg --armor --export "$key"
        if [ yes = "${IS_INTERACTIVE}" ]; then
            # User should import the key into his system before continuing
            #TODO: wait for input instead of exit?
            exit 1
        fi
    else
        printf "%s" "$(gpg --list-secret-keys --keyid-format LONG "$email" | sed -n '2p' | xargs)"
        ok_and_continue
    fi
}
config_git_gpgsign() {
    pprintf "Configure Git config commit.gpgsign..."
    if [ "true" != "$(git config --global commit.gpgsign)" ]; then
        git config --global commit.gpgsign true || fail_and_exit
        fixed_and_continue
    else
        ok_and_continue
    fi
}
config_git_signingkey() {
    pprintf "Configure Git config user.signingkey..."
    signingkey=$(git config --global user.signingkey)
    email=$(git config --global user.email)
    key=$(gpg --list-secret-keys --keyid-format LONG "$email" | head -n1 | xargs | cut -d' ' -f2 | cut -d '/' -f2)
    if [ -z "$signingkey" ] || [ "$signingkey" != "$key" ]; then
        git config --global user.signingkey "$key" || fail_and_exit
        fixed_and_continue
    else
        ok_and_continue
    fi
}
config_git_proxy() {
    pprintf "Configure Git config http.proxy..."
    if [ yes = "$USE_PROXY" ]; then
        if [ "true" != "$(git config --global http.proxy)" ]; then
            git config --global http.proxy "${http_proxy}"   || fail_and_exit
            git config --global https.proxy "${https_proxy}" || fail_and_exit
            fixed_and_continue
        else
            ok_and_continue
        fi
    else
        ok_and_continue
    fi
}

setup_color
printf "Environment configuration\n"

if is_user_root; then
    printf "${YELLOW}Careful, this script is meant to be executed in user context, not root.${RESET}\n"
    printf "${YELLOW}Otherwise root account will be configured not yours.${RESET}\n"
    exit 1
fi

check_parameters "$@"   || fail_and_exit
check_proxy             || fail_and_exit
update_system           || fail_and_exit
check_dependencies      || fail_and_exit
install_packages        || fail_and_exit
install_ohmyzsh         || fail_and_exit
config_ohmyzsh          || fail_and_exit
set_default_sh          || fail_and_exit
config_wsl              || fail_and_exit
config_git_name         || fail_and_exit
config_git_email        || fail_and_exit
config_git_autocrlf     || fail_and_exit
config_git_pull         || fail_and_exit
config_git_credential   || fail_and_exit
config_git_hooksPath    || fail_and_exit
config_git_proxy        || fail_and_exit
setup_gpg               || fail_and_exit
config_git_gpgsign      || fail_and_exit
config_git_signingkey   || fail_and_exit

ok_and_exit
