
# Script Name: RegisterMAC
# Description: Device-agnostic MAC registration for DSS-supported Laptops and Desktops 
# Author: Daniel Dubisz
# Collaborators: Benedict Yi Chua 
# Last Updated 09-19-2019

#powershell2 is folder this repository is on. 


#now to commit this to the master git. 
Write-Output "DSS Mobile Access Registration Powershell Script"

#Prompts user to enter device type for registration purposes.

Write-Output "`n<<<`tDevice Type Selection`t>>>`n"

while ($true) {

    $deviceType = Read-Host -Prompt "Is this a [l]aptop or a [d]esktop? [l/d] "

    if ($deviceType -ne "l" -and $deviceType -ne "d") {
        Write-Output "[!] Device type not recognized. Please enter a device type."
    }
        
    else {
        Write-Output "`nDevice Type Selected: $($deviceType)"
        break
    }
}

Write-Output "`n<<<`tUser Assignment Selection`t>>>`n"

# Takes input of UCINETID (optional). 
# If UCINETID is not valid, will cycle back and provide option to register without. 

while ($true) {

    $userRegistration = Read-Host -prompt "`nDo you have the UCINetID of the user? [y/n]"

    if ($userRegistration -eq "y") {
        do {
            $UCINetID = Read-Host -prompt "`nEnter the user\'s UCINetID: "
            $url = 'https://new-psearch.ics.uci.edu/people/' + $UCINetID
            $request = Invoke-WebRequest $url
            if ($request.AllElements.Count -le 70) {
                Write-Host "Sorry, looks like that didn't return a valid person"
            }
            
        } 
        while ($request.AllElements.Count -le 70)
        break
    }

    elseif ($userRegistration -eq "n") {
        break
    }

    elseif ($userRegistration -ne "y" -and $userRegistration -ne "n") {
        Write-Output "[!] That is not a valid input. Select [y]es or [n]o."
    }
}

#Testing

$trim = whoami.exe
$trim.ToString()
$tmpstring = $trim.Replace("-wa","")  
$your_name=$tmpstring.Replace("ad\","")
#function that goes through the page to find the right element for the data required

Write-Output "`n<<<`tIP Address Assignment`t>>>`n"

# Accepts Reserved DHCP IP address if available
# If multiple IP addresses to assign, option exists to assign IPs to individual NICs

while ($true) {
    $ip = Read-Host -Prompt "Do you have the ip to register? (if no, just leave blank and press enter)"
    if (($null -eq $ip) -or ($ip -eq '')) {
        $ipd = ''
        break
    }
    else {
        #Checks if the IP address is valid or not
        $IpCheck = "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
        if ($ip -notmatch $IpCheck) {
            Write-Host "Looks like that wasn't a valid IP Address, go ahead and try again"
        }
        else {
            $ipd = $ip + '; '
            break
        }
    }
}


function userinfo {
    param (
        $trait,
        $person
    )
    $url = 'https://new-psearch.ics.uci.edu/people/' + $person
    $re_request = Invoke-WebRequest $url

    $myarray = $re_request.AllElements 

    $stuff = $myarray | Where-Object { $_.outerhtml -ceq "<SPAN class=label>$trait</SPAN>" -or $_.outerHTML -ceq "<SPAN class=table_label>$trait</SPAN>" }
 

    $name = ([array]::IndexOf($myarray, $stuff)) + 1

    $myarray[$name].innerText
}

#grabs the info from the netid
$me = userinfo -trait Name -person $your_name
$UCINetID = userinfo -trait UCInetID -person $UCINetID
$dep = userinfo -trait Department -person $UCINetID
$loc = userinfo -trait Address -person $UCINetID

$info = "For $UCINetID in $dep; at $loc. Inputted by $me."

#opens up a page for adding bulk ips, so the user can log in and input the information
#has redundency in case internet explorer doesn't work. 

#removes un-needed output by sending it to tmp file and deleting it

Invoke-WebRequest 'http://apps.oit.uci.edu/mobileaccess/admin/mac/add_bulk.php' | Out-File "Recycle Bin"

if (!(Get-Process -Name iexplore -ErrorAction SilentlyContinue)) {
    Start-Process 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe' -ArgumentList 'http://apps.oit.uci.edu/mobileaccess/admin/mac/add_bulk.php'
}

#get's mac address of ethernet adapter that's active and isn't a virtual connection.

$macwired = (get-wmiobject win32_networkadapter -filter "netconnectionstatus = 2" | Where-Object -Property Name -NotMatch "VM" | Where-Object -Property netconnectionid -Match "Ethernet")
$macDoc = $macwired.MACAddress
#checks if the mac is for a docking station or not.
#perhaps here we would want to tell the user to plug it into the dock. and then if they want to put in 2 diff ips for dock and eth, the one where net conn statues = 2
#will auto go to eth, and the one where net conn status doesn't = 2 but still says eth will go to the laptop wired nic.
if ($macwired.name -match "real") {
    $macEth = (get-wmiobject win32_networkadapter | Where-Object -property name -Match 'Ethernet').macAddress
    
    $dock = " Dock connection;"

    #starts dell command update silently
    
    if (!(Test-Path 'C:\Program Files (x86)\Dell\CommandUpdate')) {

        Write-Host 'Please wait, retrieving dock information'
    
        Start-Process '\\ldcore\Files\Packages\Dell\Dell-Command-Update_DDVDP_WIN_2.4.0_A00.EXE' -ArgumentList "/s" -wait -NoNewWindow
    }
    #runs the update function untill it grabs the scan data, then it stops

    Start-Process  'C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe' -WindowStyle Hidden

    while (!(Test-Path 'C:\ProgramData\Dell\CommandUpdate\inventory.xml')) { Start-Sleep 5 }

    Get-Process | Where-Object { $_.path -like "*dcu*" } | Stop-Process

    #goes through the scan data to determine the dock type, and setvicetag if avaliable

    [xml]$xml = Get-Content -path "C:\ProgramData\Dell\CommandUpdate\inventory.xml"

    #$xml.getType().FullName

    $dock = $xml.SVMInventory.device | Where-Object { $_.application.componentType -match 'FRMW' } | Where-Object { $_.application.display -match 'WD' }
    $dockType = $dock.display
    $dockST = $dock.serviceTag
    
    #Need to test this peice on a WD15 Dock still.

    if ($dockType) {
        if ($dockType -inotlike 'Dock') {
            $dockType = 'Dock Model: ' + $dockType
        }

        $dockType = $dockType + '; '
  
        if ($dockST) {
            $dockST = 'Dock ST: ' + $dockST + '; '
            $later = $true
        }

    }
}

#if it's a laptop, gets the wifi mac address as well.
if ($deviceType -eq "l") {
    $WirelessMac = (get-wmiobject win32_networkadapter | Where-Object -Property Name -NotMatch "VM" | Where-Object -Property Name -Match "Wireless").MacAddress
}

#Grab's computer info about name, model and serial number
$name = (Get-WmiObject win32_computersystem).Name
$model = (Get-WmiObject win32_computersystem).model
$ST = (Get-WmiObject win32_bios).SerialNumber

if ($later)
{ $ST = 'Comp ST: ' + $ST }
 
#outputs info for the user to input for registration
#auto attatches to clipboard for pasting

#if there was a dock
if ($macwired.name -match "real") {
    Write-Host `n"********************Dock Mac Address*******************"`n
}
#if it's a desktop/ no dock 
else {
    Write-Host `n"********************Wired Mac Address*************************"`n
}
$Clip = "$macDoc,$ip,ADCOMDSS,$name; Wired; $dockType$dockST$model; $ST; $ipd$info"

Write-Host "$Clip"`n
 
Set-Clipboard -Value $Clip
 
#if laptop, clips mac for ethernet and wireless connection
if ($deviceType -eq "l") {
    Write-Host `n"*******************Wireless Mac Address********************"`n
    
    $Wireless = "$WirelessMac,,ADCOMDSS,$name; Wireless; $model; $ST; $ipd$info"

    Write-Host $Wireless`n

    #if there's a dock, and an ethernet port
    if ($macwired.name -match "real" -and $macEth) {
        Write-Host `n"********************Wired Mac Address*************************"`n

        $wired = "$macEth,,ADCOMDSS,$name; Wired; $model; $ST; $ipd$info"
    
        Write-Host $wired`n

        Set-Clipboard -Value "$Clip`n `n$Wireless`n `n$wired"
        
        break
    }
    #this is if it's just a laptop with ethernet connection and wireless MAC
    else {

        Set-Clipboard -Value  "$Clip`n `n$Wireless"
        
    }
}