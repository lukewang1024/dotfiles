moveMouse(x, horizontal := false)
{
  if (horizontal)
  {
    MouseMove, %x%, 0, 0, R
  }
  else
  {
    MouseMove, 0, %x%, 0, R
  }
}

turnOffMonitor()
{
  Sleep 1000
  SendMessage, 0x112, 0xF170, 2,, Program Manager
}

systemSleep()
{
  DllCall("PowrProf\SetSuspendState", "int", 0, "int", 0, "int", 0)
}

systemHibernate()
{
  DllCall("PowrProf\SetSuspendState", "int", 1, "int", 0, "int", 0)
}

showCustomShutdownMenu()
{
  SplashImage, , MC01, (1) Turn off monitor`n(2) Sleep`n(3) Hibernate`n(4) Log Off`n(5) Shutdown`n(6) Restart`n`nPress ESC to cancel., Press A Key:, Shutdown?, Courier New
  Input, choice, L1
  SplashImage, Off
  switch (choice)
  {
    case "1": turnOffMonitor()
    case "2": systemSleep()
    case "3": systemHibernate()
    case "4": ShutDown 0
    case "5": ShutDown 8
    case "6": ShutDown 2
  }
}
