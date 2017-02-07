<# 
Get-ByBlueFolderVmHardDiskScsiId

.Description
    Get vm's hard disk, SCSI position and RDM cannonical name
	russ 02/02/2016
	
.Acknowledgments 
	vNugglets.com -- http://www.vnugglets.com/2013/12/get-vm-disks-and-rdms-via-powercli.html
	LucD -- http://lucd.info
    
.Example
    ./Get-ByBlueFolderVmHardDiskScsiId
	./Get-ByBlueFolderVmHardDiskScsiId -vmName <vm> 
#>

# Set variables
[CmdletBinding()]
param (
[string]$vm = " "
)

# Write our folders to choose from
Get-folder | Where {$_.Type -eq "VM"} | Select Name



# Set file path, filename, date and time
# This is my standard path, you should adjust as needed
$filepath = "C:\vSpherePowerCLI\Output\"
$filename = "VmDiskReport"
$initalTime = Get-Date
$date = Get-Date ($initalTime) -uformat %Y%m%d
$time = Get-Date ($initalTime) -uformat %H%M


# Option to run script against a single vm or vm in a blue folder
if ($vm -eq " "){
    
	Write-host "`n" 
	Write-host "To run the script on a single vm cancel, and use the -VM <vm name> switch"  -ForegroundColor Yellow
	Write-host "To run all vms in a blue folder, enter folder or cluster name"  "`n"  -ForegroundColor White 
	
	$choice = Read-Host " "
	Try
	{
	$f = Get-Folder "$choice"  
	}
	
	Catch
	{
	Write-Warning "You must enter the folder name or run with the -VM <vm name> switch..!"
	Break
	}

	# Identify the containing folder and add to variable
	$folder = (Get-Folder $f | Get-View)

	$foldervms = Get-View -SearchRoot $folder.MoRef -ViewType "VirtualMachine" | Select Name
	
	#Filter only powered on vms
	$vms =  Get-vm $foldervms.Name | where {$_.powerstate -eq "PoweredOn"}
}

else{
$vms = Get-VM -name $vm
}


Write-Host "Output will be saved to:" $filepath$filename-$date-$time".csv"  "`n" -ForegroundColor DarkYellow 


## Pipe results through @() array operator so output returned is an array rather than a single item
$report = @() 
foreach ($vm in $vms){ 

## Use get-view to collect the VM object(s)
$VmView = Get-View -Viewtype VirtualMachine -Property Name, Config.Hardware.Device, Runtime.Host -Filter @{"Name" = "$vm"}
if (($VmView | Measure-Object).Count -eq 0) {Write-Warning "No VirtualMachine objects found matching name pattern '$vm'"; exit} 
 
## the array of items to select for output
$arrPropertiesToSelect = "VMName,HardDiskName,ScsiId,SizeGB,RawDeviceId,Path".Split(",")
 
   # Collect output of $VmView to results array
   $report += $VmView | %{
        $viewVmDisk = $_
        ## get the view of the host on which the VM currently resides
        $VmView = Get-View -Id  $viewVmDisk.Runtime.Host -Property Config.StorageDevice.ScsiLun
 
        $viewVmDisk.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualDisk]} | %{
            $HardDisk = $_
            $ScsiLun = $VmView.Config.StorageDevice.ScsiLun | ?{$_.UUID -eq $HardDisk.Backing.LunUuid}
			
            ## the properties to return in new object
            $VmProperties = @{
                VMName = $viewVmDisk.Name
                HardDiskName = $HardDisk.DeviceInfo.Label
                ## get device's SCSI controller and Unit numbers (1:0, 1:3, etc)
				ScsiId = &{$strScsiDevice = $_.ControllerKey.ToString(); "{0}`:{1}" -f $strScsiDevice[$strScsiDevice.Length - 1], $_.Unitnumber}
                #DeviceDisplayName = $oScsiLun.DisplayName
                SizeGB = [Math]::Round($_.CapacityInKB / 1MB, 0)
                RawDeviceId = $ScsiLun.CanonicalName
				Path = $HardDisk.Backing.Filename
				} 
				New-Object -Type PSObject -Property $VmProperties
			}    
		} 
}	

$report | Select -Property $arrPropertiesToSelect | Export-Csv $filepath$filename"-"$date"-"$time".csv" -NoTypeInformation
Write-output $report | Select $arrPropertiesToSelect | ft -a
Write-Host "When converting csv columns to excel, change the ScsiId field from general to text (step 3 of 3)" -ForegroundColor Yellow 