alias o="open \$(pwd)"
alias cls=clear

if command -v lsd >/dev/null 2>&1; then
    alias ll='lsd -AlhF --color=auto'
else
    alias ll='ls -AlhF --color=auto'
fi

alias aup='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y'