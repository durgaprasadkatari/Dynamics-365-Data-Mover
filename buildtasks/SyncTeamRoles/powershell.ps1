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
    
    $fetchxmlQuery = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>
                        <entity name='teamroles' >
                        <attribute name='roleid' />
                        <attribute name='teamid' />
                        <attribute name='teamroleid' />
                        <link-entity name='team' from='teamid' to='teamid' link-type='inner' >
                            <filter>
                            <condition attribute='name' operator='neq' valueof='businessunitidname' />
                            </filter>
                        </link-entity>
                        <link-entity name='role' from='roleid' to='roleid' link-type='inner' >
                            <attribute name='name' />
                            <attribute name='businessunitid' />
                        </link-entity>
                        </entity>
                    </fetch>"
    $relationshipName = "teamroles_association"
    $sourceEntity = "team"
    $targetEntity = "role"
    
    $sourceConn = Get-CrmConnection -ConnectionString $sourceConnectionString
    Write-Host "Connected to source Dynamics 365" $sourceConn.CrmConnectOrgUriActual.AbsoluteUri

    $sourceRecords = Get-CrmRecordsByFetch -Fetch $fetchxmlQuery -conn $sourceConn
    Write-Host  "Total records count:" $sourceRecords.CrmRecords.Count

    $targetConn = Get-CrmConnection -ConnectionString $targetConnectionString
        
    Write-Host "Connected to target Dynamics 365" $targetConn.CrmConnectOrgUriActual.AbsoluteUri
    foreach($entity in $sourceRecords.CrmRecords)
    {
        try {
            if($null -ne $relationshipName)
            {
                $entity1Id = $sourceEntity+"id";
                $roleNameAttr = "role2.name"
                $roleBUAttr = "role2.businessunitid_Property"
                $roleName = $entity.$roleNameAttr;
                $rolebusinessunitid = $entity.$roleBUAttr.Value.Value.Id
                $rolesFetch = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>
                <entity name='role' >
                <attribute name='roleid' />
                <filter>
                    <condition attribute='name' operator='eq' value='$roleName' />
                    <condition attribute='businessunitid' operator='eq' value='$rolebusinessunitid' />
                </filter>
                </entity>
            </fetch>"
                $roleRecords = Get-CrmRecordsByFetch -Fetch $rolesFetch -conn $targetConn
                $roleid = $roleRecords.CrmRecords[0].roleid
                $Entity1 = New-Object Microsoft.Xrm.Sdk.EntityReference($sourceEntity, $entity.$entity1Id)
                $Entity2 = New-Object Microsoft.Xrm.Sdk.EntityReference($targetEntity, $roleid)
                $request = new-object Microsoft.Xrm.Sdk.Messages.AssociateRequest
                $request.Target = $Entity1
                $request.RelatedEntities = New-Object Microsoft.Xrm.Sdk.EntityReferenceCollection
                $request.RelatedEntities.Add($Entity2) 
                $request.Relationship = New-Object Microsoft.Xrm.Sdk.Relationship($relationshipName)
                $targetConn.Execute($request)
                Write-Host "Associated security role $roleName to the team $entity.$entity1Id"
            }
        }
        catch {
            Write-Host "Security role already associated with the Team"
        }
    }

    
    
} finally { 
    Trace-VstsLeavingInvocation $MyInvocation 
}
