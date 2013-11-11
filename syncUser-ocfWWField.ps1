Param(	
	# Set to true to prevent changes being made
	[switch]$isTrialRun
)

Set-StrictMode -version 2
Import-Module ActiveDirectory

# attributeFilter lists the values of ExtensionAttribute6 which should be considered part of the "Field"
# list below matches who is entitled to the "Demo" org as per Alex P in September 2013
# http://helpzilla.eng.vmware.com/show_bug.cgi?id=1461755 
$attributeFilter  =     "ExtensionAttribute6 -like ""WW Field Sales"" "
# $attributeFilter += "-or ExtensionAttribute6 -like ""Vistro Sales"" "
# $attributeFilter += "-or ExtensionAttribute6 -like ""AMER Field Sales"" "
$attributeFilter += "-or ExtensionAttribute6 -like ""APAC Field Sales"" "
$attributeFilter += "-or ExtensionAttribute6 -like ""EMEA Field Sales"" "
# $attributeFilter += "-or ExtensionAttribute6 -like ""Customer"" "

# groupIdentity will have it's membership synced with users who match the attributeFilter
$groupIdentity = "OCF-WW Field"

#
#
#

$membersToDelete = New-Object "System.Collections.Generic.List[string]"
$membersToAdd = New-Object "System.Collections.Generic.List[string]"
$targetMembers = New-Object "System.Collections.Generic.List[string]"
$timeStamp = Get-Date
$salt = (get-date -uformat %H%M%S)
$logFilename = "logs\$groupIdentity-$salt.txt"
$log = @()

$log += $timeStamp

# sanity checks

if(-Not (Get-ADGroup -Filter {SamAccountName -eq $groupIdentity}) )
{
	Write-Host "Error: Group cannot be found in AD"
	Exit 1
}

$username = "c_oc_f_memldap"
$password = cat C:\code\pw\$username.txt | convertto-securestring

$creds = new-object -typename System.Management.Automation.PSCredential -argumentlist "VMWAREM\$username", $password

# Find members in Group
 
write-host "Group:  $groupIdentity"
$group = Get-ADGroup -Identity $groupIdentity

foreach($member in Get-ADGroupMember($group))
{
	$membersToDelete.Add($member.SamAccountName)
}

# Find members matching filter

write-host "Filter: $attributeFilter"
foreach($member in (Get-ADUser -Filter $attributeFilter))
{
    $targetMembers.Add($member.SamAccountName)
}

Write-Host ("Number of members in Group :  " + $membersToDelete.Count)
Write-Host ("Number of members in Filter:  " + $targetMembers.Count)

# loop and compare SamAccountName

foreach($member in $targetMembers)
{
    if ( $membersToDelete.Contains($member))
    {
        $temp = $membersToDelete.Remove($member)
    }
    else
    {
        $membersToAdd.Add($member)
    }
}

Write-Host ("Accounts to remove from group: " + $membersToDelete.Count)
Write-Host ("Accounts to add to group:      " + $membersToAdd.Count)

foreach($member in $membersToAdd)
{
	if($isTrialRun)
	{
		$log += "add-trial,$member"
	}
	else
	{
		$log += "add,$member"
		Add-ADGroupMember -Identity $groupIdentity -Members $member -Credential $creds
	}
}

Write-Host ("Members to be deleted from the group: " + $membersToDelete.Count)

foreach($member in $membersToDelete)
{
	if($isTrialRun)
	{
		$log += "delete-trial,$member"
	}
	else
	{
		$log += "delete,$member"
		Remove-ADGroupMember -Identity $groupIdentity -Members $member -Confirm:$false -Credential $creds
	}
}

$log | out-file $logfilename
