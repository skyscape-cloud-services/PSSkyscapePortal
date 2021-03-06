﻿$Global:SkyscapeURL = ""
$Global:Headers = @{"Content-Type" = "application/json"}
$Global:SkyscapeSession = $null
  
Function New-SkyscapePortalLogin($Username,$Password,$IL)
{
	$Data = @"
{"email": "$username", "password": "$password"}
"@
	
	if($IL -eq 2)
	{
		$Global:SkyscapeURL = "https://portal.skyscapecloud.com/api"	
	}
	else
	{
		$Global:SkyscapeURL = "https://portal.skyscapecloud.gsi.gov.uk/api"	
	}
	
	$Res = Invoke-WebRequest -Method Post -Headers $Global:Headers -Uri "$($Global:SkyscapeURL)/authenticate" -Body $Data -SessionVariable LocalSession
	$Global:SkyscapeSession = $LocalSession
	Return $Res
}

Function Invoke-SkyscapeRequest($URL)
{
	if($Global:SkyscapeSession -ne $null)
	{
		$Res = Invoke-WebRequest -Method Get -Headers $Global:Headers -Uri $URL -WebSession $Global:SkyscapeSession
	}
	else
	{
		Write-Warning "Please connect to the Skyscape Portal first using the New-SkyscapePortalLogin cmdlet"
		$Res = $Null
	}
	Return $Res
}

Function Invoke-SkyscapePUTRequest($URL,$Data)
{
	if($Global:SkyscapeSession -ne $null)
	{
		$Res = Invoke-WebRequest -Method PUT -Headers $Global:Headers -Uri $URL -WebSession $Global:SkyscapeSession -Body $Data
	}
	else
	{
		Write-Warning "Please connect to the Skyscape Portal first using the New-SkyscapePortalLogin cmdlet"
		$Res = $Null
	}
	Return $Res
}

Function Invoke-SkyscapePOSTRequest($URL,$Data)
{
	if($Global:SkyscapeSession -ne $null)
	{
		$Res = Invoke-WebRequest -Method POST -Headers $Global:Headers -Uri $URL -WebSession $Global:SkyscapeSession -Body $Data
	}
	else
	{
		Write-Warning "Please connect to the Skyscape Portal first using the New-SkyscapePortalLogin cmdlet"
		$Res = $Null
	}
	Return $Res
}

Function Get-SkyscapeTickets([Switch]$ForAccount)
{
	if($ForAccount)
	{
		$UserTickets = Get-SkyscapeTickets
		$Res = Invoke-SkyscapeRequest -URL "$($Global:SkyscapeURL)/my_calls?for=account"
		$Tickets = ($Res.content | ConvertFrom-Json)
		ForEach($Ticket in $Tickets)
		{
			$Check = ($UserTickets | ?{$_.TicketID -eq $Ticket.Ticket_ID} | Measure-Object).count
			if($Check -gt 0)
			{
				$Ticket | Add-Member -MemberType NoteProperty -Name "IsUser" -Value $true -Force
			}
			else
			{
				$Ticket | Add-Member -MemberType NoteProperty -Name "IsUser" -Value $False -Force
			}
		}
	}
	else
	{
		$Res = Invoke-SkyscapeRequest -URL "$($Global:SkyscapeURL)/my_calls?for=user"
		$Tickets = ($Res.content | ConvertFrom-Json)
	}
	Return $Tickets
}

Function Get-SkyscapeTicketData($Ticket,[switch]$ForAccount)
{
	if($Ticket.IsUser)
	{
		$ForAccount = $False
	}
	else
	{
		$ForAccount = $True
	}
	$TicketID = $Ticket.ticket_id
	
	if($ForAccount)
	{
		$Res = Invoke-SkyscapeRequest -URL "$($Global:SkyscapeURL)/my_calls/$($TicketID)?for=account"
		
	}
	else
	{
		$Res = Invoke-SkyscapeRequest -URL "$($Global:SkyscapeURL)/my_calls/$($TicketID)?for=user"
		
	}
	Return ($Res.content | ConvertFrom-Json)
}

Function Get-SkyscapeTicketReport($ExportPath,[switch]$Open)
{
	$Tickets = Get-SkyscapeTickets -ForAccount
	if($Open)
	{
		$Tickets = $Tickets | ?{$_.status -ne "Closed"}
	}
	$TicketReport = @()
	$TTotal = ($Tickets | Measure-Object).count
	$I = 0
	ForEach($Ticket in $Tickets)
	{
		$I += 1
		$P = ($I/$TTotal)*100
		Write-Progress -Activity "Processing" -Status "$($Ticket.Ticket_ID)" -PercentComplete $P -Id 0
		$TicketData = Get-SkyscapeTicketData -Ticket $Ticket
		
		if(($TicketData.updates | Measure-Object).count -gt 0)
		{
			$UTotal = ($TicketData.Updates | Measure-Object).count
			$UI = 0
			$UpdateCounter = 1
			ForEach($Update in $TicketData.updates)
			{
				$UI += 1
				$UP = ($UI/$UTotal)*100
				Write-Progress -Activity "Processing Updates" -Status "$($UI)" -PercentComplete $UP -Id 1
				$Holder = "" | Select Ticket_ID,Summary,Submitted,Status,Description,HasUpdates,UpdateID,UpdateType,UpdateText,UpdateBy,UpdatedOn
				$Holder.Ticket_ID = $Ticket.ticket_id
				$Holder.Summary = $Ticket.summary
				$Holder.Submitted = $Ticket.submitted
				$Holder.Status = $Ticket.Status
				$Holder.Description = $TicketData.ticket.Description
				$Holder.HasUpdates = $True
				$Holder.UpdateID = $UpdateCounter
				$Holder.UpdateType = $Update.type
				$Holder.UpdateText = $Update.text
				$Holder.UpdateBy = $Update.owner
				$Holder.UpdatedOn = $Update.submitted_on
				$TicketReport += $Holder
				$UpdateCounter += 1
			}
				
		
		}
		else
		{
			$Holder = "" | Select Ticket_ID,Summary,Submitted,Status,Description,HasUpdates,UpdateID,UpdateType,UpdateText,UpdateBy,UpdatedOn
			$Holder.Ticket_ID = $Ticket.ticket_id
			$Holder.Summary = $Ticket.summary
			$Holder.Submitted = $Ticket.submitted
			$Holder.Status = $Ticket.Status
			$Holder.Description = $TicketData.ticket.Description
			$Holder.HasUpdates = $False
			$TicketReport += $Holder
		
		}
	}
	if($ExportPath)
	{
		Write-Host "Exporting report to $ExportPath"
		$TicketReport | Export-Csv -Path $ExportPath -NoTypeInformation
	}
	
	Return $TicketReport
}

Function Get-SkyscapeVMReport($ExportCSVPath)
{
	$Accounts = Get-SkyscapeAccounts
	$Report = @()
	$AccountTotal = ($Accounts | Measure-Object).count
	$AccountCounter = 1
	ForEach($Account in $Accounts)
	{
		$AccountPercentage = ($AccountCounter/$AccountTotal)*100
		$AccountCounter += 1
		Write-Progress -Activity "Processing Account" -Status "$($Account.name)" -PercentComplete $AccountPercentage -Id 0
		
		$VMS = Get-SkyscapeComputeServicesForAccount -AccountID ($Account.ID)
		
		$OrgTotal = ($vms.vorgs | Measure-Object).count
		$OrgCounter = 1
		ForEach($VORG in $VMS.vorgs)
		{
			$OrgPercentage = ($OrgCounter/$OrgTotal)*100
			$OrgCounter += 1
			Write-Progress -Activity "Processing ORG" -Status "$($VORG.name)" -PercentComplete $OrgPercentage -Id 1
			
			$VDCTotal = ($VORG.VDCs | Measure-Object).count
			$VDCCounter = 1
			ForEach($VDC in $VORG.VDCs)
			{
				$VDCPercentage = ($VDCCounter/$VDCTotal)*100
				$VDCCounter += 1
				Write-Progress -Activity "Processing VDC" -Status "$($VDC.name)" -PercentComplete $VDCPercentage -Id 2
				
				$VAPPTotal = ($VDC.vApps | Measure-Object).count
				$VAPPCounter = 1
				ForEach($VAPP in $VDC.vApps)
				{
					$VAPPPercentage = ($VAPPCounter/$VAPPTotal)*100
					$VAPPCounter += 1
					Write-Progress -Activity "Processing VAPP" -Status "$($VAPP.name)" -PercentComplete $VAPPPercentage -Id 3
					
					$VMTotal = ($VAPP.VMs | Measure-Object).count
					$VMCounter = 1
					ForEach($VM in $VAPP.VMs)
					{
						$VMPercentage = ($VMCounter/$VMTotal)*100
						$VMCounter += 1
						Write-Progress -Activity "Processing VM" -Status "$($VM.name)" -PercentComplete $VMPercentage -Id 4
						$Holder = "" | Select Account,ORG,ORGID,VDC,VAPP,Name,MonthToDate,EstimatedMonthlyTotal,BilledHoursOn,BilledHoursOff,PowerStatus,OS,CPUs,Memory,Storage
						$Holder.Account = $Account.name
						$Holder.ORG = $VORG.name
						$Holder.ORGID = $VORG.serviceId
						$Holder.VDC = $VDC.name
						$Holder.VAPP = $VAPP.name
						$Holder.Name = $VM.name
						$Holder.MonthToDate = $VM.monthToDate
						$Holder.EstimatedMonthlyTotal = $VM.estimatedMonthlyTotal
						$Holder.BilledHoursOn = $VM.billedHoursPoweredOn
						$Holder.BilledHoursOff = $VM.billedHoursPoweredOff
						$Holder.PowerStatus = $VM.powerStatus
						$Holder.OS = $VM.operatingSystem
						$Holder.CPUs = $VM.numberOfCPUs
						$Holder.Memory = $VM.memory
						$Holder.Storage = $VM.storage
						$Report += $Holder
					}
				}
			}
		}
	}
		
	if($ExportCSVPath)
	{
		$Report | Export-Csv -Path $ExportCSVPath -NoTypeInformation
	}
	Return $Report
}

Function Show-SkyscapeIncidentProblemAreas()
{
	$Message = @"
0 = Compute
1 = Storage
2 = Email and Collaboration
3 = Other
"@
Write-Host $Message
}

Function Show-SkyscapeServiceProblemAreas()
{
	$Message = @"
0 = Compute
1 = Storage
2 = Email and Collaboration
3 = Connectivity PSN or GSI
4 = Connectivity Leased Line
5 = Cloud Enablement Services
6 = IP Addresses
7 = Other
"@
Write-Host $Message
}

Function Show-SkyscapeServiceClassifications()
{
	$Message = @"
0 = Change a Configuration
1 = Add a New Service
2 = Claim Service Credits
3 = Expand an Existing Service
4 = Information Required
5 = Other
"@
Write-Host $Message
}

Function Show-SkyscapeIncidentClassifications()
{
	$Message = @"
0 = Production Service > unavailable or unresponsive
1 = Production Service > available, but performance degraded
2 = Production Service > available, but client access to service restricted
3 = Test/Dev Service > unavailable or unresponsive
4 = Test/Dev Service > available, but performance degraded
5 = Test/Dev Service > available, but client access to service restricted
6 = Service available, part of redundant infrastructure unavailable
7 = Confirmed data loss or breach
8 = Possible data loss or breach
9 = Other incident
"@
Write-Host $Message
}

Function New-SkyscapeIncident()
{
	Param(
		[Parameter(Mandatory=$true,HelpMessage="Please enter a value between 0 and 3, use Show-SkyscapeIncidentProblemAreas to see options")]
        [ValidateRange(0,3)] 
        [Int]
        $ProblemArea
    ,
		[Parameter(Mandatory=$true,HelpMessage="Please enter a value between 0 and 9, use Show-SkyscapeIncidentClassifications to see options")]
		[ValidateRange(0,9)] 
        [Int]
        $IncidentClassfication
    ,
		[Parameter(Mandatory=$true,HelpMessage="Please enter the name of the service you wish to log this incident against, use Get-SkyscapeComputeServices to see options")]
        [string] 
        $ServiceWithIssue
	,
		[Parameter(Mandatory=$true)]
		[string] 
        $Summary
	,
		[Parameter(Mandatory=$true)]
		[string] 
        $FurtherDetails
    ) 
	$ProblemArea_Actual = ""
	switch($ProblemArea)
	{
		0 {$ProblemArea_Actual = "compute"}
		1 {$ProblemArea_Actual = "storage"}
		2 {$ProblemArea_Actual = "email and collaboration"}
		3 {$ProblemArea_Actual = "other"}
	}
	
	$IncidentClassfication_Actual = ""
	switch($IncidentClassfication)
	{
		0 {$IncidentClassfication_Actual = 'Production Service > unavailable or unresponsive'}
		1 {$IncidentClassfication_Actual = 'Production Service > available, but performance degraded'}
		2 {$IncidentClassfication_Actual = 'Production Service > available, but client access to service restricted'}
		3 {$IncidentClassfication_Actual = 'Test/Dev Service > unavailable or unresponsive'}
		4 {$IncidentClassfication_Actual = 'Test/Dev Service > available, but performance degraded'}
		5 {$IncidentClassfication_Actual = 'Test/Dev Service > available, but client access to service restricted'}
		6 {$IncidentClassfication_Actual = 'Service available, part of redundant infrastructure unavailable'}
		7 {$IncidentClassfication_Actual = 'Confirmed data loss or breach'}
		8 {$IncidentClassfication_Actual = 'Possible data loss or breach'}
		9 {$IncidentClassfication_Actual = 'Other incident'}
	}
	
	$Body = @"
{"incident":{"problem_area": "$($ProblemArea_Actual)", "service": "$($ServiceWithIssue)", "classification": "$($IncidentClassfication_Actual)", "summary": "$($Summary)", "further_details": "$($FurtherDetails)"}}
"@
	Write-Host $Body
	$Res = Invoke-SkyscapePOSTRequest -url "$($Global:SkyscapeURL)/my_calls" -data $Body
	Return ($Res.content | ConvertFrom-Json)
}

Function New-SkyscapeServiceRequest()
{
Param(
		[Parameter(Mandatory=$true,HelpMessage="Please enter a value between 0 and 7, use Show-SkyscapeserviceProblemAreas to see options")]
        [ValidateRange(0,7)] 
        [Int]
        $ProblemArea
    ,
		[Parameter(Mandatory=$true,HelpMessage="Please enter a value between 0 and 5, use Show-SkyscapeServiceClassifications to see options")]
		[ValidateRange(0,5)] 
        [Int]
        $QueryNature
    ,
		[Parameter(Mandatory=$true,HelpMessage="Please enter the name of the service you wish to log this incident against, use Get-SkyscapeComputeServices to see options")]
        [string] 
        $ServiceWithIssue
	,
		[Parameter(Mandatory=$true)]
		[string] 
        $Summary
	,
		[Parameter(Mandatory=$true)]
		[string] 
        $FurtherDetails
    ) 
	$ProblemArea_Actual = ""
	switch($ProblemArea)
	{
		0 {$ProblemArea_Actual = "compute"}
		1 {$ProblemArea_Actual = "storage"}
		2 {$ProblemArea_Actual = "email and collaboration"}
		3 {$ProblemArea_Actual = 'Connectivity PSN or GSI'}
		4 {$ProblemArea_Actual = 'Connectivity Leased Line'}
		5 {$ProblemArea_Actual = 'Cloud Enablement Services'}
		6 {$ProblemArea_Actual = 'IP Addresses'}
		7 {$ProblemArea_Actual = "other"}
	}
	
	$QueryNature_Actual = ""
	switch($QueryNature)
	{
		0 {$QueryNature_Actual = 'Change a Configuration'}
		1 {$QueryNature_Actual = 'Add a New Service'}
		2 {$QueryNature_Actual = 'Claim Service Credits'}
		3 {$QueryNature_Actual = 'Expand an Existing Service'}
		4 {$QueryNature_Actual = 'Information Required'}
		5 {$QueryNature_Actual = 'Other'}
	}
	
	$Body = @"
{"service":{"problem_area": "$($ProblemArea_Actual)", "service": "$($ServiceWithIssue)", "query_nature": "$($QueryNature_Actual)", "summary": "$($Summary)", "further_details": "$($FurtherDetails)"}}
"@
	Write-Host $Body
	$Res = Invoke-SkyscapePOSTRequest -url "$($Global:SkyscapeURL)/my_calls" -data $Body
	Return ($Res.content | ConvertFrom-Json)

}

Function New-SkyscapeTicketUpdate($TicketID,$UpdateText)
{
	$Body = @"
{"description": "$UpdateText"}
"@
	$Res = Invoke-SkyscapePUTRequest -url "$($Global:SkyscapeURL)/my_calls/$($TicketID)" -data $Body
	Return ($Res.content | ConvertFrom-Json)
}

Function Set-SkyscapeTicketOwner($TicketID,$OwnerEmail)
{
	$Body = @"
{"email": "$YourEmail"}	
"@
	$Res = Invoke-SkyscapePUTRequest -url "$($Global:SkyscapeURL)/my_calls/$($TicketID)/change_owner" -data $Body
	Return ($Res.content | ConvertFrom-Json)
}

Function Get-SkyscapeTicketSubscription($TicketID,$YourEmail)
{
	$Body = @"
{"email": "$YourEmail"}	
"@
	$Res = Invoke-SkyscapePUTRequest -url "$($Global:SkyscapeURL)/my_calls/$($TicketID)/subscribe" -data $Body
	Return ($Res.content | ConvertFrom-Json)
}

Function Remove-SkyscapeTicketSubscription($TicketID,$YourEmail)
{
	$Body = @"
{"email": "$YourEmail"}	
"@
	$Res = Invoke-SkyscapePUTRequest -url "$($Global:SkyscapeURL)/my_calls/$($TicketID)/unsubscribe" -data $Body
	Return ($Res.content | ConvertFrom-Json)
}

Function ReOpen-SkyscapeTicket($TicketID)
{
	$Res = Invoke-SkyscapePUTRequest -url "$($Global:SkyscapeURL)/my_calls/$($TicketID)/reopen" -data $null
	Return ($Res.content | ConvertFrom-Json)

}

Function Cancel-SkyscapeTicket($TicketID)
{
	$Res = Invoke-SkyscapePUTRequest -url "$($Global:SkyscapeURL)/my_calls/$($TicketID)/cancel" -data $null
	Return ($Res.content | ConvertFrom-Json)

}

Function Close-SkyscapeTicket($TicketID)
{
	$Res = Invoke-SkyscapePUTRequest -url "$($Global:SkyscapeURL)/my_calls/$($TicketID)/close" -data $null
	Return ($Res.content | ConvertFrom-Json)

}

Function Test-SkyscapePortal()
{
	$Res = Invoke-SkyscapeRequest -url "$($Global:SkyscapeURL)/ping"
	Return ($Res.content | ConvertFrom-Json)

}

Function Get-SkyscapeAccounts()
{
	$Res = Invoke-SkyscapeRequest -url "$($Global:SkyscapeURL)/accounts"
	Return ($Res.content | ConvertFrom-Json)
}

Function Get-SkyscapeComputeServices()
{
	$Accounts = Get-SkyscapeAccounts
	$Final = @()
	$AccTotal = ($Accounts | Measure-Object).count
	$I = 0
	ForEach($Acc in $Accounts)
	{
		$I += 1
		$P = ($I/$AccTotal)*100
		Write-progress -PercentComplete $P -Activity "Account: $($Acc.name)" -Status "Processing" -Id 0
		$Services = Get-SkyscapeComputeServicesForAccount -AccountID ($Acc.Id)
		$STotal = ($Services.vOrgs | Measure-Object).count
		$SI = 0
		ForEach($Service in $Services.vOrgs)
		{
			$SI += 1
			$SP = ($SI/$STotal)*100
			Write-Progress -PercentComplete $SP -Activity "Service: $($Service.Name)" -Status "Processing" -Id 1
			$Holder = "" | Select AccountName,AccountID,ServiceID,ServiceName,ServiceURN
			$Holder.AccountName = $Acc.name
			$Holder.AccountID = $Acc.id
			$Holder.ServiceID = $Service.serviceId
			$Holder.ServiceName = $Service.name
			$Holder.ServiceURN = $Service.urn
			$Final += $Holder
		}
		
	
	}
	Return $Final
}

Function Get-SkyscapeComputeServicesForAccount($AccountID)
{
	$Res = Invoke-SkyscapeRequest -url "$($Global:SkyscapeURL)/accounts/$AccountID/compute_services"
	Return ($Res.content | ConvertFrom-Json)
}
