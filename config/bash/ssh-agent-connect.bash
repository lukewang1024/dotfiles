source "$config_dir/sh/ssh-agent-connect.sh"

setKillSSHAgentHook()
{
  trap 'ssh-agent -k; \rm ~/.agent-profile; exit' EXIT
}

connectSSHAgent
