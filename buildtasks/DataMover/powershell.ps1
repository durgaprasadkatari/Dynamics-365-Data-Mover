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
    $xml = [xml]$sourceRecords.FetchXml
    $atts = $xml.GetElementsByTagName('attribute');
    $entityName = $xml.GetElementsByTagName('entity').name;
    $createdRecordCount = 0
    $updatedRecordCount = 0
    foreach($entity in $sourceRecords.CrmRecords)
    {
        $apiEntity = New-Object Microsoft.Xrm.Sdk.Entity($entityName)
        foreach($att in $atts.name)
        {
            $att1 = $att+"_Property";
            if($att -eq $entityName+"id")
            {
                $entityId = $entityName+"id";
                $apiEntity.Id = $entity.$entityId
            }
            else {
                $apiEntity.Attributes[$att] = $entity.$att1.Value
            }           
        }

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
