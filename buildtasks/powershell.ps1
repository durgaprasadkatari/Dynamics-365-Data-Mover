[CmdletBinding()] 
param() 
 
Trace-VstsEnteringInvocation $MyInvocation
If (!(Get-Module "Microsoft.Xrm.Data.Powershell")) {
    Install-Module -Name Microsoft.Xrm.Data.Powershell -AcceptLicense -AllowClobber -Force -Scope AllUsers
    Write-Host "Installed Microsoft.Xrm.Data.Powershell"
} 
try { 
    # Get inputs. 
    $sourceUrl = Get-VstsInput -Name 'SourceCRMURL' -Require
    $sourceUserName = Get-VstsInput -Name 'SourceCRMUserName' -Require 
    $sourcePassword = Get-VstsInput -Name 'SourceCRMPassword' -Require
    $targetUrl = Get-VstsInput -Name 'TargetCRMURL' -Require
    $targetUserName = Get-VstsInput -Name 'TargetCRMUserName' -Require 
    $targetPassword = Get-VstsInput -Name 'TargetCRMPassword' -Require
    $fetchxmlQuery = Get-VstsInput -Name 'FetchXML' -Require
    
    $SourceCredentials = @{
        Username = "$sourceUserName"
        Password = "$sourcePassword"
        Url = "$sourceUrl"
    }

    $SourceUser = $SourceCredentials.Username
    $SourcePWord =  $SourceCredentials.Password | ConvertTo-SecureString -AsPlainText -Force
    $SourceUrl = $SourceCredentials.Url

    $sourceCred = New-Object System.Management.Automation.PSCredential($SourceUser,$SourcePWord)
    $sourceConn = Connect-CrmOnline -Credential $sourceCred -ServerUrl $SourceUrl
    Write-Host "Connected to source Dynamics 365" $sourceConn.CrmConnectOrgUriActual.AbsoluteUri

    $sourceRecords = Get-CrmRecordsByFetch -Fetch $fetchxmlQuery -conn $sourceConn
    Write-Host  "Total records count:" $sourceRecords.CrmRecords.Count

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
    foreach($entity in $sourceRecords.CrmRecords)
    {
        $createdRecordCount = 0
        $updatedRecordCount = 0
        $apiEntity = New-Object Microsoft.Xrm.Sdk.Entity("ft_api")
        $apiEntity.Id = $entity.ft_apiid
        $apiEntity.Attributes["ft_name"] = $entity.ft_name
        $apiEntity.Attributes["ft_url"] = $entity.ft_url
        $apiEntity.Attributes["ft_apikey"] = $entity.ft_apikey
        
        $statecode_code_os = New-Object Microsoft.Xrm.Sdk.OptionSetValue($entity.statecode_Property.Value.Value)
        $apiEntity.Attributes["statecode"] = [Microsoft.Xrm.Sdk.OptionSetValue] $statecode_code_os
        $statuscode_code_os = New-Object Microsoft.Xrm.Sdk.OptionSetValue($entity.statuscode_Property.Value.Value)
        $apiEntity.Attributes["statuscode"] = [Microsoft.Xrm.Sdk.OptionSetValue] $statuscode_code_os
        $request = new-object Microsoft.Xrm.Sdk.Messages.UpsertRequest
        $request.Target = $apiEntity
        $response = $targetConn.Execute($request)
        If($response.RecordCreated)
        {
            $createdRecordCount = $createdRecordCount + 1
        }
        else {
            $updatedRecordCount = $updatedRecordCount + 1
        }
    }

    Write-Host "Created:-" $createdRecordCount "Updated:-" $updatedRecordCount "out of " $sourceRecords.CrmRecords.Count
    
} finally { 
    Trace-VstsLeavingInvocation $MyInvocation 
}