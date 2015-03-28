@echo clean-out the existing sharepoint backups
pushd e:\spbackup
del _sharepoint_backup.*.log
del *.spbak
popd

@echo replace the daily command with a full command
del spbackup-daily.cmd
copy spbackup-full.txt spbackup-daily.cmd

