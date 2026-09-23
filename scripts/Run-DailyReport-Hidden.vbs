' Launches Run-DailyReport.ps1 with no visible window.
'
' The scheduled task fires hourly and on every unlock so that a due Mon/Thu
' cycle is never missed. Run-DailyReport.ps1's cycle gate exits in well under
' a second when nothing is due, but running powershell.exe directly still
' flashed a console window and stole focus every single time. Launching
' through wscript with window style 0 keeps those checks completely silent.
'
' The third Run() argument is True on purpose: wscript waits for PowerShell to
' finish, so the task's own ExecutionTimeLimit and MultipleInstances settings
' still apply to the real work. With False the task would report success
' immediately and those protections would be lost.

Dim fso, shell, scriptDir, ps1Path, command

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1Path = fso.BuildPath(scriptDir, "Run-DailyReport.ps1")

command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & ps1Path & """"

WScript.Quit shell.Run(command, 0, True)
