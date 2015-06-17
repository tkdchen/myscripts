# User specific aliases and functions

alias dnfi='sudo dnf install'
alias dnfs='sudo dnf search'
alias gcommit='git commit'
alias gdiff='git diff'
alias gst='git status'
alias vdestroy='vagrant destroy'
alias vhalt='vagrant halt'
alias vinit='vagrant init'
alias vs='vagrant up'
alias freemem='echo $(($(cat /proc/meminfo | grep "^MemFree" | sed -e "s/[a-zA-Z: ]//g") / 1024))'
alias vin='vagrant ssh'

alias emacs='emacs --no-window'

# Docker
alias none_images='docker images | grep "<none>"'

# Git
alias Gshortlog='git log --format=format:"%Cblue%h%Creset %s (%Cred%an%Creset) <%Cgreen%ar%Creset>" --graph'

function find-rpm {
	rpm -aq | grep $1
}

function github-clone {
	git clone https://github.com/$1
}

function ce-clone {
	git clone cqi@code.engineering.redhat.com:${1}.git
}

function Dremove_none_images {
	image_ids=`docker images | grep "<none>" | sed "s/ \+/ /g" | cut -d' ' -f3 | xargs`
        docker rmi $image_ids
}

function Dremove_all_containers {
        container_ids="$(docker ps -a -q | xargs)"
        docker stop $container_ids && docker rm $container_ids
}
