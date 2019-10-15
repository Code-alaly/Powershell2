$fso = Get-ChildItem -Recurse -path C:\pycharm-local

$fsoBU = Get-ChildItem -Recurse -path C:\Pshell

Compare-Object -ReferenceObject $fso -DifferenceObject $fsoBU