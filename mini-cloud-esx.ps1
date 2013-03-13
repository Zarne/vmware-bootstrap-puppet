function GetPercentages(){
       # get all the hosts
       $objHosts = get-vmhost -Location c9-sw;

       # loop through each of the hosts and calculate the percentage of memory used
       foreach($objHost in $objHosts){
               $objHost | add-member NoteProperty PercentMemory ([int]($objHost.MemoryUsageMB/$objHost.MemoryTotalMB *100))
               $objHost
       }
}


function GetRecommendedHost(){
	# Any host with Memory Utilization >70% is discarded, then we return most idle VMhost
	GetPercentages | Where {$_.PercentMemory -lt 70} | Sort-Object CPuUsageMhz | select -First 1
}

#UNTESTED: get-vmhost -location c9-sw | foreach { new-vm -name "$(get-random)-shadow" -template ubuntu-tmpl-12042 -VMhost $_
#get-vm '*shadow' | New-Snapshot -Name goldsnap

function GetShadowVM($VMHOST){
	#$rechost = GetRecommendedHost
	$shadowvm  = Get-VM '*shadow' | Where-Object {$_.Host.Name -eq $VMHOST}
	$shadowvm
}

function EnvFromCSV($CSV){
	$env = import-csv $CSV
    
    # Start thread pool for creating VMs, wait for all to finish
    $vmbgtasks = @()
	$env | foreach {
		$vmhost = GetRecommendedHost
		$shadowvm = GetShadowVM($vmhost)
		$vmbgtasks += new-vm -name "$($_.name)-$($_.ipoctet)" -LinkedClone -ReferenceSnapshot goldsnap -Location staging -VM $shadowvm -VMHost $vmhost -RunAsync
    }
    wait-task -Task $vmbgtasks
     
    # Start thread pool for starting VMs, wait for all to finish
    $vmbgtasks = @()
	$env | foreach {
		$vmbgtasks += start-vm -VM "$($_.name)-$($_.ipoctet)" -Confirm:$false -RunAsync
    }
    wait-task -Task $vmbgtasks
     
    # Wait for VMware tools to be ready
	$env | foreach {
        do {
			$toolsstatus = (Get-VM "$($_.name)-$($_.ipoctet)").extensiondata.Guest.ToolsStatus
			Write-Host "Checking host $($_.name)-$($_.ipoctet) $toolsstatus"
			sleep 10
		} until ($toolsstatus -eq 'toolsOk' )
    }
    
    # Ask for Guest credentials
    # Start thread pool for customizing VMs, wait for all to finish
    #$creds = Get-Credential
    $vmbgtasks = @()
    $env | foreach {
        $stext = "/home/c9er/vmware-bootstrap-puppet/customization.sh $($_.name)-$($_.ipoctet).$($_.domain) 192.168.55.$($_.ipoctet) 255.255.255.0 192.168.55.1 192.168.55.150;"
        Write-Host "Running $stext"
		$vmbgtasks += Invoke-VMScript -VM "$($_.name)-$($_.ipoctet)" -ScriptText $stext -ScriptType Bash -GuestCredential $creds -RunAsync
    }
    wait-task -Task $vmbgtasks
}