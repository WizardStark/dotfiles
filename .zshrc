# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="jonathan"

CASE_SENSITIVE="true"

HIST_STAMPS="mm/dd/yyyy"

plugins=(git
      zsh-syntax-highlighting
      #zsh-autocomplete
      zsh-autosuggestions
      sudo
      dirhistory
      fzf
      autojump)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

export PATH=$PATH:/Users/barnardu/.toolbox/bin
export JAVA_HOME="/Library/Java/JavaVirtualMachines/amazon-corretto-17.jdk/Contents/Home"
export PATH="$HOME/.rbenv/bin:$PATH"
export PATH="$HOME/.rbenv/shims:$PATH"
export PATH="${PATH}:${HOME}/EC2CloudManagerOps"
export SSH_AUTH_SOCK=`find /tmp/com.apple.launchd.* -name 'Listeners'`
export PATH=$PATH:$HOME/.odin-tools/env/OdinRetrievalScript-1.0/runtime/bin
export EDITOR='nvim'
#export XDG_CONFIG_HOME="$HOME/.tmux/plugins"
eval "$(rbenv init - zsh)"

alias cl="printf '\33c\e[3J'"
alias nmw="cat ~/.midway/cookie | pbcopy"
alias dev="ssh dev-dsk-barnardu-1a-2f8f9f90.eu-west-1.amazon.com"
alias odin="ssh -f -N -L 2009:localhost:2009 dev-dsk-barnardu-1a-2f8f9f90.eu-west-1.amazon.com"

alias jouma="echo ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀\"⢀⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⣿⣿⣿⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣠⡄⠹⣿⣿⣿⣿⠏⣠⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⣠⣴⣾⣿⣿⣿⣦⣈⡙⢉⣁⣴⣿⣿⣿⣷⣦⣄⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⠀⠀⠀⠀
⠀⠀⠀⣰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣆⠀⠀⠀
⠀⠀⢠⣿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⣿⡄⠀⠀
⠀⠀⢼⣿⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⣿⡧⠀⠀
⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠁⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠈⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠋⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠛⠛⠿⠿⠿⠿⠿⠿⠟⠛⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣶⠀⠀⠀⠀⢰⣾⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠉⠀⠀⠀⠀⠈⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀\""
alias bb="brazil-build-rainbow"
alias bba='bb apollo-pkg'
alias bre='brazil-runtime-exec'
alias brc='brazil-recursive-cmd'
alias bws='brazil ws'
alias bwsuse='bws use -p'
alias bwscreate='bws create -n'
alias brc=brazil-recursive-cmd
alias bbr='brc brazil-build'
alias bball='brc --allPackages'
alias bbb='brc --allPackages brazil-build'
alias bbra='bbr apollo-pkg'
alias bwsvs="bwsuse -vs"
alias vim="nvim"
alias vi="nvim"

# Terminal Slack Notifier

function notify() {
    WEBHOOK="https://hooks.slack.com/workflows/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"

    echo "Executing function $@. I'll text you when it's done"
    eval $@
    exitcode=$?

    content="Command \`$@\`"
    if [[ $exitcode -eq 0 ]]
    then
        content="$content completed successfully! :tada:"
    else
        content="$content failed with exit code $exitcode! :this-is-fine-fire:"
    fi

    curl -X POST -H "Content-Type:application/json" --data "{\"Message\":\"$content\"}" $WEBHOOK
}

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# # klist -f | grep 'renew until' || kinit -f -l 2592000

# # Request weekly expiration with 30 day renewal, although the
# # server only gives out 10 hour expiration with 7 day renewal.
# echo "checking for Kinit status"
# klist -a | grep -i renew
# kinit_renew() { echo " renewing Kinit" ; kinit -f -l 7d -r 30d; }
# #
# # run kinit_renew when logging in if no kerberos ticket
# if ! klist -s; then kinit_renew;else echo "Kinit authenticated" ; fi

#
# Run ssh agent when it does not exist
function run_ssh_agent() {
 if ps -p $SSH_AGENT_PID > /dev/null
 then
   echo "ssh-agent is already running"
   # Do something knowing the pid exists, i.e. the process with $PID is running
 else
   eval `ssh-agent -s`
 fi
}


export PATH="/opt/homebrew/opt/mysql@5.7/bin:$PATH"
alias ahm='${ahm_dir}/cellheatbalancer.sh'
export ahm_dir='/Volumes/workplace/EC2CMCellHeatBalancer/src/EC2CMCellHeatBalancer'

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"
