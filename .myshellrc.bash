#!/bin/bash
# Run commands for all shells

# Add local binaries to path
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# SSH agent initialisation
SSH_ENV="$HOME/.ssh/agent-environment"
function start_agent {
#    echo "Initialising new SSH agent..."
    /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
#    echo succeeded
    chmod 600 "${SSH_ENV}"
    . "${SSH_ENV}" > /dev/null
    /usr/bin/ssh-add;
}
# Source SSH settings, if applicable
if [ -f "${SSH_ENV}" ]; then
    . "${SSH_ENV}" > /dev/null
    #ps ${SSH_AGENT_PID} doesn't work under cywgin
    ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
        start_agent;
    }
else
    start_agent;
fi

# If bat is installed, replace cat with bat
if command -v batcat &> /dev/null
then
    alias cat='batcat -p'
fi

# If micro is installed, use it as the default editor
if command -v micro &> /dev/null
then
    export EDITOR=$(command -v micro)
fi
