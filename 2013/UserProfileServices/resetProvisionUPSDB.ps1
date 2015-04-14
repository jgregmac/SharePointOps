$syncdb=Get-SPDatabase 399dbdcb-9cf0-4ad0-bca9-792c997b48a9
$syncdb.Unprovision()
$syncdb.Status='Offline'
$upa=Get-SPServiceApplication 43cc572a-db2f-42c4-a291-03f12b91f56e
$upa.ResetSynchronizationMachine()
$upa.ResetSynchronizationDatabase()
$syncdb.Provision()