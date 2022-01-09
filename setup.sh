#!/bin/sh
# @file    setup.sh
# @date    January 3rd, 2022
# @author  Passific
# @brief   Environment configuration
# shellcheck disable=SC2059

readonly KERNELNAME=$(uname -s)
if grep -qi Microsoft /proc/version; then
    IS_WSL="yes"
else
    IS_WSL="no"
fi

setup_color() {
    # Only use colors if connected to a terminal
    if [ -t 1 ]; then
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

update_system() {
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
    command -v tree     >/dev/null 2>&1 || set -- tree "$@";
    command -v tr       >/dev/null 2>&1 || set -- coreutils "$@";
    command -v sed      >/dev/null 2>&1 || set -- sed "$@";
    command -v gpg      >/dev/null 2>&1 || set -- gpg "$@";
    if [ no = "$IS_WSL" ]; then
        command -v gcc        >/dev/null 2>&1 || set -- build-essential "$@";
        command -v shellcheck >/dev/null 2>&1 || set -- shellcheck "$@";
        command -v terminator >/dev/null 2>&1 || set -- terminator "$@";
    fi

    if [ $# -ne 0 ]; then
        printf "The following dependencies must be satisfied: %s\r" "$*"
        sudo apt-get -qq install "$@" > /dev/null && fixed_and_continue
    else
        ok_and_continue
    fi
}

install_ohmyzsh() {
    pprintf "Install oh-my-zsh..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(wget -qO- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattende && fixed_and_continue
    else
        ok_and_continue
    fi
}

config_ohmyzsh() {
    pprintf "Configure oh-my-zsh..."
    if [ ! -f "$HOME/.zshrc" ]; then
        cp zshrc "$HOME/.zshrc" ||·fail_and_exit
        chmod 644 "$HOME/.zshrc" && fixed_and_continue
    else
        ok_and_continue
    fi
}

config_wsl() {
    pprintf "Configure WSL..."
    if grep -q Microsoft /proc/version; then
        if [ ! -f "$HOME/.dircolors" ]; then
            wget -qO "$HOME/.dircolors" https://raw.githubusercontent.com/seebi/dircolors-solarized/master/dircolors.ansi-dark ||·fail_and_exit
            chmod 644 "$HOME/.dircolors" && fixed_and_continue
        else
            ok_and_continue
        fi
    else
        printf "WSL not detected"
        ok_and_continue
    fi
}

set_default_sh() {
    pprintf "Set zsh as default... %s" "$SHELL"
    if [ "$(which zsh)" != "$SHELL" ]; then
        chsh -s "$(which zsh)" && fixed_and_continue
    else
        ok_and_continue
    fi
}

config_git_name() {
    pprintf "Configure Git config user.name..."
    name="$(git config user.name)"
    printf "%s" "$name"
    if [ -z "$name" ]; then
        echo "Enter your first name:"
        read -r firstname
        echo "Enter your last name:"
        read -r lastname
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
        git config --global user.name "$firstname $lastname" && fixed_and_continue
    else
        ok_and_continue
    fi
}
config_git_email() {
    pprintf "Configure Git config user.email..."
    email="$(git config user.email)"
    printf "%s" "$email"
    if [ -z "$email" ]; then
        echo "Enter your email address:"
        read -r useremail
        git config --global user.email "$useremail" && fixed_and_continue
    else
        ok_and_continue
    fi
}
config_git_autocrlf() {
    pprintf "Configure Git config core.autocrlf..."
    autocrlf="$(git config core.autocrlf)"
    printf "%s" "$autocrlf"
    if [ -z "$autocrlf" ]; then
        if [ "Linux" = "$KERNELNAME" ]; then
            coreautocrlfval="input"
        else
            coreautocrlfval="false"
        fi
        if [ "$(git config core.autocrlf)" != "$coreautocrlfval" ]; then
            printf "set to %s" "$coreautocrlfval"
            git config --global core.autocrlf "$coreautocrlfval" && fixed_and_continue
        else
            ok_and_continue
        fi
    else
        ok_and_continue
    fi
}
config_git_hooksPath() {
    pprintf "Configure Git config core.hooksPath..."
    hooksPath="$(git config core.hooksPath)"
    printf "%s" "$hooksPath"
    if [ ".githooks" != "$hooksPath" ]; then
        printf " swithed to .githooks"
        git config --global core.hooksPath .githooks && fixed_and_continue
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
        exit 1
    else
        printf "%s" "$(gpg --list-secret-keys --keyid-format LONG "$email" | sed -n '2p' | xargs)"
        ok_and_continue
    fi
}
config_git_gpgsign() {
    pprintf "Configure Git config commit.gpgsign..."
    if [ "true" != "$(git config commit.gpgsign)" ]; then
        git config --global commit.gpgsign true && fixed_and_continue
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
        git config --global user.signingkey "$key" && fixed_and_continue
    else
        ok_and_continue
    fi
}

setup_color
printf "Environment configuration\n"

update_system           || fail_and_exit
check_dependencies      || fail_and_exit
install_ohmyzsh         || fail_and_exit
config_ohmyzsh          ||·fail_and_exit
config_wsl              ||·fail_and_exit
set_default_sh          || fail_and_exit
config_git_name         || fail_and_exit
config_git_email        || fail_and_exit
config_git_autocrlf     || fail_and_exit
config_git_hooksPath    || fail_and_exit
setup_gpg               || fail_and_exit
config_git_gpgsign      || fail_and_exit
config_git_signingkey   || fail_and_exit

ok_and_exit
