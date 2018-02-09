try {
  $null = gcm pshazz -ea stop;
  pshazz init 'default';
  Import-Module Jump.Location;
} catch { }
