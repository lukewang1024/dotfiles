try {
  [System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor 192 -bor 48;
  $null = gcm pshazz -ea stop;
  pshazz init 'default';
  Import-Module Jump.Location;
} catch { }
