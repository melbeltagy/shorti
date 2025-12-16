alias o="open \$(pwd)"
alias cls=clear

if command -v lsd >/dev/null 2>&1; then
    alias ll='lsd -AlhF --color=auto'
else
    alias ll='ls -AlhF --color=auto'
fi

function print() {
    echo -e "\033[0;32m$1\033[0m"
}

function aup() {
    print "**** Updating package lists..."
    sudo apt update
    print "**** Upgrading installed packages..."
    sudo apt upgrade -y 
    print "**** Removing unnecessary packages..."
    sudo apt autoremove -y && sudo apt autoclean -y
    print "**** System update complete."
}