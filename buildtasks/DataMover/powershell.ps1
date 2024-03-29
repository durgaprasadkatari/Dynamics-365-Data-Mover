[CmdletBinding()] 
param() 
 
Trace-VstsEnteringInvocation $MyInvocation
If (!(Get-Module "Microsoft.Xrm.Data.Powershell")) {
    Install-Module -Name Microsoft.Xrm.Data.Powershell -AcceptLicense -AllowClobber -Force -Scope AllUsers
    Write-Host "Installed Microsoft.Xrm.Data.Powershell"
}
try { 
    # Get inputs. 
    $sourceConnectionString = Get-VstsInput -Name 'SourceCRMConnectionString' -Require
    $targetConnectionString = Get-VstsInput -Name 'TargetCRMConnectionString' -Require
    
    $fetchxmlQuery = Get-VstsInput -Name 'FetchXML' -Require
    $relationshipName = Get-VstsInput -Name 'NNRelationshipName'
    $sourceEntity = Get-VstsInput -Name 'SourceEntityName'
    $targetEntity = Get-VstsInput -Name 'TargetEntityName'
    
    $sourceConn = Get-CrmConnection -ConnectionString $sourceConnectionString
    Write-Host "Connected to source Dynamics 365" $sourceConn.CrmConnectOrgUriActual.AbsoluteUri

    $sourceRecords = Get-CrmRecordsByFetch -Fetch $fetchxmlQuery -conn $sourceConn
    Write-Host  "Total records count:" $sourceRecords.CrmRecords.Count

    $targetConn = Get-CrmConnection -ConnectionString $targetConnectionString
        
    Write-Host "Connected to target Dynamics 365" $targetConn.CrmConnectOrgUriActual.AbsoluteUri
    $xml = [xml]$sourceRecords.FetchXml
    $atts = $xml.GetElementsByTagName('attribute');
    $entityName = $xml.GetElementsByTagName('entity').name;
    $createdRecordCount = 0
    $updatedRecordCount = 0
    foreach($entity in $sourceRecords.CrmRecords)
    {
        
        if(-not [string]::IsNullOrEmpty( $relationshipName ))
        {
            try {
                $entity1Id = $sourceEntity+"id";
                $entity2Id = $targetEntity+"id";
                $Entity1 = New-Object Microsoft.Xrm.Sdk.EntityReference($sourceEntity, $entity.$entity1Id)
                $Entity2 = New-Object Microsoft.Xrm.Sdk.EntityReference($targetEntity, $entity.$entity2Id)
                $request = new-object Microsoft.Xrm.Sdk.Messages.AssociateRequest
                $request.Target = $Entity1
                $request.RelatedEntities = New-Object Microsoft.Xrm.Sdk.EntityReferenceCollection
                $request.RelatedEntities.Add($Entity2) 
                $request.Relationship = New-Object Microsoft.Xrm.Sdk.Relationship($relationshipName)
                $response = $targetConn.Execute($request)
            }
            catch {
                Write-Host "Error occurred: for source entity id"+ $entity.$entity1Id + " target entity id "+$entity.$entity2Id
            }

        }
        else {
            $apiEntity = New-Object Microsoft.Xrm.Sdk.Entity($entityName)
            $InactiveRecord = 0
            foreach($att in $atts.name)
            {
                $att1 = $att+"_Property";
                if($att -eq $entityName+"id")
                {
                    $entityId = $entityName+"id";
                    $apiEntity.Id = $entity.$entityId
                }
                else {
                    if(($att -eq "statecode") -and ($entity.$att1.Value -eq 1))
                    {
                        $InactiveRecord = 1
                    }
                    else 
                    {
                        $apiEntity.Attributes[$att] = $entity.$att1.Value
                    }
                }           
            }
            
            if($InactiveRecord -eq 1)
            {
                $apiEntity.Attributes.Remove('statuscode')
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

            if($InactiveRecord -eq 1)
            {
                $apiEntity = New-Object Microsoft.Xrm.Sdk.Entity($entityName)
                $entityId = $entityName+"id";
                $apiEntity.Id = $entity.$entityId
                $apiEntity.Attributes["statecode"] = $entity.statecode_Property.Value;
                $apiEntity.Attributes["statuscode"] = $entity.statuscode_Property.Value;
                $request = new-object Microsoft.Xrm.Sdk.Messages.UpsertRequest
                $request.Target = $apiEntity
                $response = $targetConn.Execute($request)
            }
        }
    }

    Write-Host "Created:-" $createdRecordCount "Updated:-" $updatedRecordCount "out of " $sourceRecords.CrmRecords.Count
    
} finally { 
    Trace-VstsLeavingInvocation $MyInvocation 
}
