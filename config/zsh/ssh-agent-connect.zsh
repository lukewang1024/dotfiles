source "$config_dir/sh/ssh-agent-connect.sh"

setKillSSHAgentHook()
{
  zshexit() { ssh-agent -k; \rm ~/.agent-profile; exit }
}

connectSSHAgent
