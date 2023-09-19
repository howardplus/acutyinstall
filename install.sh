#!/usr/bin/env bash

# Run it with
#
# bash -c "$(curl -fsSL https://acuty.ai/install.sh)"
#
# Copyright 2023- Acuty.ai

set -u

DEFAULT_INSTALL_PATH=/usr/local/bin
ARTIFACT_NAME=agent
USER_INSTALL_PATH="$HOME/bin"
GITHUB_REPO="howardplus/acutyinstall"

ACUTY_BANNER="
=== ACUTY ===
"

ARTIFACT_BASE_PATH="https://github.com/${GITHUB_REPO}/raw/master/artifact"

# Fetch latest version.
LATEST_VERSION="$(curl -fsSL https://raw.githubusercontent.com/howardplus/acutyinstall/master/versions/latest.txt | cut -d ' ' -f 1)"
LATEST_MD5="$(curl -fsSL https://raw.githubusercontent.com/howardplus/acutyinstall/master/versions/latest.txt | cut -d ' ' -f 2)"

# Check if the OS is Linux.
if [[ "$(uname)" != "Linux" ]]; then
	abort "Only Linux platform is supported"
fi

# String formatting functions.
if [[ -t 1 ]]; then
	tty_escape() { printf "\033[%sm" "$1"; }
else
	tty_escape() { :; }
fi

tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_cyan="$(tty_mkbold 36)"
tty_yellow="$(tty_mkbold 33)"
tty_green="$(tty_mkbold 32)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

# Trap ctrl-c and call ctrl_c() to reset terminal.
trap ctrl_c INT

function ctrl_c() {
	stty sane
	exit
}

usage() {
	cat << EOS

${tty_bold}Usage:${tty_reset} $0

EOS
	exit 1
}

while getopts ":v:c:h" o; do
	case "${o}" in
       	h)
            usage
            ;;
       	*)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

artifact_url() {
	echo "${ARTIFACT_BASE_PATH}/${ARTIFACT_NAME}.${LATEST_VERSION}"
}

have_sudo_access() {
  if [[ -z "${HAVE_SUDO_ACCESS-}" ]]; then
    /usr/bin/sudo -l mkdir &>/dev/null
    HAVE_SUDO_ACCESS="$?"
  fi

  return "$HAVE_SUDO_ACCESS"
}

shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"; do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

emph_red() {
  printf "${tty_red}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

emph() {
  printf "${tty_cyan}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

abort() {
  printf "%s\n" "$1"
  exit 1
}

execute() {
  if ! "$@"; then
    abort "$(printf "Failed during: %s" "$(shell_join "$@")")"
  fi
}

wait_for_user() {
  local c
  echo
  read -r -p "Continue (Y/n): " c
  # We test for \r and \n because some stuff does \r instead.
  if ! [[ "$c" == '' || "$c" == $'\r' || "$c" == $'\n' || "$c" == 'Y' || "$c" == 'y' ]]; then
    exit 1
  fi
  echo
}

exists_but_not_writable() {
  [[ -e "$1" ]] && ! [[ -r "$1" && -w "$1" && -x "$1" ]]
}

if exists_but_not_writable "${DEFAULT_INSTALL_PATH}"; then
    DEFAULT_INSTALL_PATH=${USER_INSTALL_PATH}
fi

echo "${tty_green}${ACUTY_BANNER}${tty_reset}"

printf "\n\n"

emph "Installing Acuty Agent:"
# TODO:
# read -r -p "Install Path [${DEFAULT_INSTALL_PATH}]: " INSTALL_PATH
INSTALL_PATH=${INSTALL_PATH:-${DEFAULT_INSTALL_PATH}}

if [[ "$INSTALL_PATH" != /* ]]
then
  abort "Install Path must be absolute path: [/xxx]"
fi

if exists_but_not_writable "${INSTALL_PATH}"; then
    abort "${INSTALL_PATH} is not writable or does not exist."
fi

if [[ ! -e "${INSTALL_PATH}" ]]; then
    if ! mkdir -p "${INSTALL_PATH}"; then
        abort "Failed to create directory: ${INSTALL_PATH}"
    fi
fi

binary="acuagent"
service="acuty"
artifact_md5=${LATEST_MD5}
emph "Downloading artifact version ${LATEST_VERSION}"
execute curl -fsSL "$(artifact_url)" -o "${INSTALL_PATH}"/${binary}_new
actual_md5=$(md5sum "${INSTALL_PATH}"/${binary}_new | cut -d ' ' -f 1)
if [[ "$artifact_md5" != "$actual_md5" ]]; then
    abort "MD5 for downloaded agent does not match expected value"
fi
execute chmod +x "${INSTALL_PATH}"/${binary}_new
execute mv "${INSTALL_PATH}"/${binary}_new "${INSTALL_PATH}"/${binary}
execute mkdir -p /etc/${service}
execute mkdir -p /etc/${service}/message

# test only
execute cp /vagrant/agent "${INSTALL_PATH}"/${binary}

cat << EOS
- Acuty Agent has been installed to: ${INSTALL_PATH}.
EOS

emph "Bootstrap Acuty Agent to your system"
execute "${INSTALL_PATH}"/${binary} bootstrap

emph "Starting Acuty Agent service"
execute service acuty-agent start
