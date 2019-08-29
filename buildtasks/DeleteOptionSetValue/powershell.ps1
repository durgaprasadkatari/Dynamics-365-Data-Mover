[CmdletBinding()] 
param() 
 
Trace-VstsEnteringInvocation $MyInvocation
If (!(Get-Module "Microsoft.Xrm.Data.Powershell")) {
    Install-Module -Name Microsoft.Xrm.Data.Powershell -AcceptLicense -AllowClobber -Force -Scope AllUsers
    Write-Host "Installed Microsoft.Xrm.Data.Powershell"
} 
try { 
    # Get inputs. 
    $AttributeLogicalName = Get-VstsInput -Name 'AttributeLogicalName' -Require
    $GlobalOptionSetName = Get-VstsInput -Name 'GlobalOptionSetName'
    $OptionsToRemove = Get-VstsInput -Name 'OptionsToRemove'
	$AttrOptionsToRemove = Get-VstsInput -Name 'AttrOptionsToRemove'
	$targetUrl = Get-VstsInput -Name 'TargetCRMURL' -Require
    $targetUserName = Get-VstsInput -Name 'TargetCRMUserName' -Require 
    $targetPassword = Get-VstsInput -Name 'TargetCRMPassword' -Require

    $TargetCredentials = @{
        Username = "$targetUserName"
        Password = "$targetPassword"
        Url = "$targetUrl"
    }

    $TargetUser = $TargetCredentials.Username
    $TargetPWord =  $TargetCredentials.Password | ConvertTo-SecureString -AsPlainText -Force
    $TargetUrl = $TargetCredentials.Url

    $targetCred = New-Object System.Management.Automation.PSCredential($TargetUser,$TargetPWord)
    $targetConn = Connect-CrmOnline -Credential $targetCred -ServerUrl $TargetUrl
        
    Write-Host "Connected to target Dynamics 365" $targetConn.CrmConnectOrgUriActual.AbsoluteUri


	IF(![string]::IsNullOrWhiteSpace($GlobalOptionSetName)) {
	    Write-Host $GlobalOptionSetName
	    $GlobalOptionSets = $GlobalOptionSetName.Split("|")
		$globalOptionCounter = 0;
		foreach($globaloptionset in $GlobalOptionSets)
		{
			$request = new-object Microsoft.Xrm.Sdk.Messages.DeleteOptionValueRequest
		    $request.OptionSetName = $globaloptionset
			Write-Host "Deleting values from optionset " $globaloptionset
			$OptionSetValues = $OptionsToRemove.Split("|")[$globalOptionCounter].Split(";")
			foreach($option in $OptionSetValues)
			{
				$request.Value = [int]$option
				$response = $targetConn.Execute($request)
				Write-Host $response
			}
			$globalOptionCounter = $globalOptionCounter+1;
		}   
	}
	
	IF(![string]::IsNullOrWhiteSpace($AttributeLogicalName)) {
	    $entityAttrs = $AttributeLogicalName.Split("|")
		$attributeCounter = 0;
		foreach($entityAtt in $entityAttrs)
		{
			$entity = $entityAtt.Split("-")[0]
			$attribute = $entityAtt.Split("-")[1]
			$request = new-object Microsoft.Xrm.Sdk.Messages.DeleteOptionValueRequest
			$request.AttributeLogicalName = $attribute
			$request.EntityLogicalName = $entity
			Write-Host "Deleting values from optionset " $entity "-" $attribute
			$OptionSetValues = $AttrOptionsToRemove.Split("|")[$attributeCounter].Split(";")
			foreach($option in $OptionSetValues)
			{
				$request.Value = [int]$option
				$response = $targetConn.Execute($request)
				Write-Host $response
			}
			$attributeCounter = $attributeCounter+1;
		}  	   
	}  
        
} finally { 
    Trace-VstsLeavingInvocation $MyInvocation 
}
