addKeys()
{
  # Add all private keys start with 'id_'
  ssh-add $(find ~/.ssh -name 'id_*' ! -name '*.*' | tr '\n' ' ')
}

spawnPerUserSSHAgent()
{
  eval $(ssh-agent)
  echo "export SSH_AGENT_PID=$SSH_AGENT_PID" > ~/.agent-profile
  echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" >> ~/.agent-profile

  addKeys
  setKillSSHAgentHook
}

connectSSHAgent()
{
  if ! ps -u $(whoami) | grep '[ ]ssh-agent' &> /dev/null; then
    # Create per-user instance of ssh-agent if not exist
    spawnPerUserSSHAgent
  elif [ -f ~/.agent-profile ]; then
    # Having .agent-profile indicates that keys are added
    source ~/.agent-profile
  elif ! ssh-add -l &> /dev/null; then
    # Attempt to add keys if key list is empty
    addKeys
  fi
}
