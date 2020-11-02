# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

powerline-daemon -q
POWERLINE_BASH_CONTINUATION=1
POWERLINE_BASH_SELECT=1
. /usr/share/powerline/bash/powerline.sh

# User specific environment
PATH="$HOME/.local/bin:$HOME/bin:$HOME/node_modules/.bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"
export PATH

export GOPATH=$HOME/go
export GO111MODULE=on

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions

export REQUESTS_CA_BUNDLE=/etc/pki/tls/certs/ca-bundle.crt
export GIT_EDITOR=nvim
export PYPI_INDEX=https://mirrors.aliyun.com/pypi/simple/

alias ff='firefox'

alias mygrep='grep --exclude=*.pyc --exclude=.git --exclude=.venv --color -rnH'

#alias docker=podman
alias gitst='git status'
alias gitdiff='git diff'
alias gitst='git status'
alias pinst='sudo dnf install'
alias repoquery='sudo repoquery'
alias git-stats-commit-count-by-author='git log --format="%an" | sort | uniq -c | sort -k1 -n --reverse'

alias tox='tox --workdir /tmp/tox-$(basename $PWD)'

alias my-bodhi-updates='bodhi updates query --user cqi'


if [ ! -e "$HOME/virtualenvs" ]; then
    mkdir "$HOME/virtualenvs"
fi
alias createvirtualenv='python3 -m venv $HOME/virtualenvs/$(basename $PWD)'
alias virtualenvon='. $HOME/virtualenvs/$(basename $PWD)/bin/activate'
alias virtualenvoff='deactivate'

alias login-aliyun-vm='ssh root@123.57.27.187'

VIRTUALENVS_ROOT=$HOME/virtualenvs/

function prepare_venv
{
    local -r venv_path="${VIRTUALENVS_ROOT}$(basename $PWD)/"
    local -r ycm_extra_conf=".ycm_extra_conf.py"

    python3 -m venv "$venv_path"

    if [ -e $ycm_extra_conf ]; then
        echo "$ycm_extra_conf exists already. You may have to add following interpreter by yourself."
        echo "${venv_path}bin/python3"
    else
        cat > $ycm_extra_conf <<EOF
def Settings( **kwargs ):
    return {
        'interpreter_path': '${venv_path}bin/python3'
    }
EOF
    fi

    if [ -e .git ]; then
        echo "$ycm_extra_conf" >> .git/info/exclude
    else
        echo "This is not a git repository. You have to ignore $ycm_extra_conf by yourself."
    fi
}

alias dmenu_go='dmenu -fn "DejaVu Sans Mono-14"'

function syncup-git-repo
{
    local -r branch=${1:-master}
    git fetch upstream
    git checkout "$branch"
    git merge "upstream/$branch"
}

function q-connect-network
{
    local -r networkname=$(nmcli --fields name c show | sed '1 d' | sed -e 's/ \+$//' | dmenu_go)
    [[ -n "$networkname" ]] && nmcli --ask c up "$networkname"
}

function q-notes-open
{
    local -r notefile=$(find $HOME/Documents/My/notes/ -name "*.org" -exec basename '{}' \; | dmenu_go)
    [[ -n "$notefile" ]] && emacs "$HOME/Documents/My/notes/$notefile" &
}

function q-pypi-mirrors
{
    echo "\
https://pypi.tuna.tsinghua.edu.cn/simple
https://mirrors.aliyun.com/pypi/simple/
https://pypi.doubanio.com/simple
https://mirrors.cloud.tencent.com/pypi/simple
" | dmenu_go
}
