source ~/.dotfiles/config/shared/ssh-agent-connect.sh

setKillSSHAgentHook()
{
  zshexit() { ssh-agent -k; \rm ~/.agent-profile; exit }
}

connectSSHAgent
