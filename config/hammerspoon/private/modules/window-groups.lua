-- Membership is separate from group behavior and layout. Each application
-- declares whether all matching windows or one unambiguous main window joins.
return {
  remote={
    id='remote',
    apps={
      {bundleID='com.microsoft.rdc.macos',appName='Windows App',selection='all',
        nonEmptyTitle=true,excludeTitles={'Windows App','Microsoft Remote Desktop',
          'Settings','Preferences','设置'}},
      {bundleID='com.nomachine.nxdock',appName='NoMachine',selection='all',
        titlePattern=' %- NoMachine$',keepAspectRatio=true},
    },
  },
}
