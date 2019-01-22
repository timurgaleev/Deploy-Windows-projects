Param(
  $Server,
  $RemoteUser,
  $RemoteUserPass,
  $RemoteLocation,
  $SiteName,
  $SiteNamePool
)
if ([bool]$RemoteLocation -eq 0) {Write-error "Ohh shit. Please send me full destination path on remote server. Quickly!"; Exit}
#prepare create PSSession
$pwd = convertto-securestring "$RemoteUserPass" -asplaintext -force
$cred=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$RemoteUser",$pwd
#Create powershell remote session
$SessionRemotly = New-PSSession -ComputerName $Server -Credential $cred
if (($SessionRemotly) -ne $null){Write "##teamcity[message text='PSSession create']"}
else {
  $status="FAILURE";
  $messagetext="Can't create PSSession";
  write "##teamcity[buildStatus status='$status' text='$messagetext']" ;
exit 
}
#Stop-Website on IIS
$StopSite = {Stop-WebSite $args[0]};  
Invoke-Command -ScriptBlock $StopSite -ArgumentList $SiteName -Session $SessionRemotly;
$StopSitePool = {Stop-WebAppPool $args[0]};  
Invoke-Command -ScriptBlock $StopSitePool -ArgumentList $SiteNamePool -Session $SessionRemotly;
sleep -s 15
#Delete all files on the server
#Command -Session $SessionRemotly -ScriptBlock {param($RemoteLocation) ri $RemoteLocation"*" -Recurse -Force } -ArgumentList $RemoteLocation;
#create Site Archive
& 'C:\Program Files\7-Zip\7z.exe' a -aoa -tzip ".\SiteArchive.zip" ".\output\*" -x!".git\" -x!".gitignore" -x!'*.zip';
Get-ChildItem -Recurse %teamcity.build.workingDir%\\SmartHead.VisaEDS\SmartHead.VisaEDS.Web\ClientApp\build | Format-Table Directory,Name,Length
if (test-path "%teamcity.build.workingDir%\archive.zip") {remove-item "%teamcity.build.workingDir%\archive.zip" -Recurse -force}
& 'C:\Program Files\7-Zip\7z.exe' a -aoa -tzip "%teamcity.build.workingDir%\archive.zip" "%teamcity.build.workingDir%\\SmartHead.VisaEDS\SmartHead.VisaEDS.Web\ClientApp\build*"
#copy files remote server
Copy-Item .\SiteArchive.zip -Destination $RemoteLocation -Force -Recurse -ToSession $SessionRemotly;
Copy-Item %teamcity.build.workingDir%\archive.zip -Destination %env.destserverpath% -Force -Recurse -ToSession $sessionremotly
#extract
Invoke-Command -ScriptBlock {param($RemoteLocation) sl $RemoteLocation; & 'C:\Program Files\7-Zip\7z.exe' x $RemoteLocation"SiteArchive.zip" "-o$RemoteLocation" -aoa} -ArgumentList $RemoteLocation -Session $SessionRemotly;
Invoke-Command -ScriptBlock {param($RemoteLocation) ri $RemoteLocation"SiteArchive.zip" -Force} -ArgumentList $RemoteLocation -Session $SessionRemotly;
Invoke-Command -ScriptBlock {& 'C:\Program Files\7-Zip\7z.exe' x %env.destserverpath%archive.zip -o%env.destserverpath% -aoa} -Session $sessionremotly
Invoke-Command -ScriptBlock {Remove-Item %env.destserverpath%archive.zip -Force} -Session $sessionremotly
sleep -s 5
#Start-Website on IIS
$StartSite = {Start-WebSite $args[0]};  
Invoke-Command -ScriptBlock $StartSite -ArgumentList $SiteName -Session $SessionRemotly;
$StartSitePool = {Start-WebAppPool $args[0]};  
Invoke-Command -ScriptBlock $StartSitePool -ArgumentList $SiteNamePool -Session $SessionRemotly;

#remove powershell session
Remove-PSSession $SessionRemotly