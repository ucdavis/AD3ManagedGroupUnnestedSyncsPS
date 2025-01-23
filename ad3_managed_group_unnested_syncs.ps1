<#
    Title: ad3_managed_group_unnested_syncs.ps1
    Authors: Ben Clark and Dean Bunn
    Last Edit: 2025-01-22
#>

#Array of Custom AD Unnested Group Settings
$arrADUnnestedGrpSyncs = @();

#Custom Object for AD3 Managed Unnested Group
$cstAD3UnnestMngdGrp1 = New-Object PSObject -Property (@{ AD3_Unnested_Grp_GUID="c462cf19-195a-4071-8273-02277b426a17";
                                                          AD3_Unnested_Grp_Name="COE-SW-Empire";
                                                          SRC_Nested_Groups_GUIDs=@("6b0fd000-5dbd-4fe1-9d25-4d01dfcd7b35",
                                                                                    "b4961625-87fc-4aec-bc72-7201880b2e79");
                                                        });

#Add Custom AD3 Managed Unnested Groups to Sync Array
$arrADUnnestedGrpSyncs += $cstAD3UnnestMngdGrp1;

#Initiate Principal Contexts for Both AD3 and OU Domains
$prctxAD3 = New-Object DirectoryServices.AccountManagement.PrincipalContext([DirectoryServices.AccountManagement.ContextType]::Domain,"AD3","DC=AD3,DC=UCDAVIS,DC=EDU");
$prctxOU = New-Object DirectoryServices.AccountManagement.PrincipalContext([DirectoryServices.AccountManagement.ContextType]::Domain,"OU","DC=OU,DC=AD3,DC=UCDAVIS,DC=EDU");

#Var for UCD Users DN Partial
[string]$ucdUsersDNPartial = ",ou=ucdusers,dc=ad3,dc=ucdavis,dc=edu";

foreach($cstAUGS in $arrADUnnestedGrpSyncs)
{
    #Hash Table for Source Groups Members GUIDs
    $htSrcGrpMbrGUIDs = @{};

    #Hash Table for Members to Remove from AD Group  
    $htMTRFG = @{};

    #HashTable for Members to Add to AD Group
    $htMTATG = @{};

    foreach($srcGrpGUID in $cstAUGS.SRC_Nested_Groups_GUIDs)
    {
        #Var for Sync Source Group's LDAP Path Based Upon AD GUID
        [string]$grpLDAPPathSSG = "LDAP://ad3.ucdavis.edu/<GUID=" + $srcGrpGUID + ">";

        #Check for LDAP Path Before Pulling Group
        if([DirectoryServices.DirectoryEntry]::Exists($grpLDAPPathSSG) -eq $true)
        {
            #Initiate Directory Entry for Source Group
            $deADGroupSSG = New-Object DirectoryServices.DirectoryEntry($grpLDAPPathSSG);

            #Var for Group's DN
            [string]$grpDNSSG = $deADGroupSSG.Properties["distinguishedname"][0].ToString();

            #Var for GroupPrincipal for Sync Source Group
            $grpPrincipalSSG = $null;

            #Configure Group Principal Based Upon Domain of Source Group
            if($grpDNSSG.ToLower().Contains("dc=ou,") -eq $true)
            {
                $grpPrincipalSSG = [DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($prctxOU, [DirectoryServices.AccountManagement.IdentityType]::DistinguishedName,$grpDNSSG);
            }
            else 
            {
                $grpPrincipalSSG = [DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($prctxAD3, [DirectoryServices.AccountManagement.IdentityType]::DistinguishedName,$grpDNSSG);
            }

            #Check Membership Count of Sync Source Group
            if($grpPrincipalSSG.Members.Count -gt 0)
            {
                #Pull All Nested Membership for the Group
                foreach($ssgMbr in $grpPrincipalSSG.GetMembers($true))
                {
                    #Only Sync AD3 UCD Users 
                    if($ssgMbr.DistinguishedName.ToString().ToLower().EndsWith($ucdUsersDNPartial) -eq $true)
                    {

                        #Check for Unique Source Member's GUID
                        if($htSrcGrpMbrGUIDs.ContainsKey($ssgMbr.Guid.ToString()) -eq $false)
                        {
                            $htSrcGrpMbrGUIDs.Add($ssgMbr.Guid.ToString(),"1");
                        }

                    }
                    else 
                    {
                       Write-Output "User account is not meant for this sync tool"; 
                    }
                    
                }#End of Source Group Membership Foreach

            }#End of Membership Count Check on Sync Source Group

            #Close out Directory Entry for Source Group
            $deADGroupSSG.Close();

        }#End of Directory Entry Check on LDAP Path

    }#End of Source Nested Groups GUIDs Foreach

    #Pull Membership of Unnested Group
    #Var for LDAP Path of Unnested Group
    [string]$grpLDAPPathUNN = "LDAP://ad3.ucdavis.edu/<GUID=" + $cstAUGS.AD3_Unnested_Grp_GUID + ">"; 

    #Check LDAP Path of Unnested Group
    if([DirectoryServices.DirectoryEntry]::Exists($grpLDAPPathUNN) -eq $true)
    {
        #Initiate Directory Entry for Unnested Group
        $deADGroupUNN = New-Object DirectoryServices.DirectoryEntry($grpLDAPPathUNN);

        #Var for Group's DN
        [string]$grpDNUNN = $deADGroupUNN.Properties["distinguishedname"][0].ToString();

        #Var for GroupPrincipal for Unnested Group
        $grpPrincipalUNN = $null;

        #Configure Group Principal Based Upon Domain of Unnested Group
        if($grpDNUNN.ToLower().Contains("dc=ou,") -eq $true)
        {
            $grpPrincipalUNN = [DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($prctxOU, [DirectoryServices.AccountManagement.IdentityType]::DistinguishedName,$grpDNUNN);
        }
        else 
        {
            $grpPrincipalUNN = [DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($prctxAD3, [DirectoryServices.AccountManagement.IdentityType]::DistinguishedName,$grpDNUNN);
        }

        #Check Membership Count of Unnested Group
        if($grpPrincipalUNN.Members.Count -gt 0)
        {
            #Pull All Unnested Membership for the Unnested Group
            foreach($unnMbr in $grpPrincipalUNN.GetMembers($false))
            {
                #Load Current Members Into Remove Hash Table 
                $htMTRFG.Add($unnMbr.Guid.ToString(),"1");
                
            }#End of Source Group Membership Foreach

        }#End of Membership Count Check on Unnested Group

        #Close Out Directory Entry for Unnested Group
        $deADGroupUNN.Close();
        
        #Do Stuff Here


    }#End of Unnested Group LDAP Path Exists Check

}#End of $arrADUnnestedGrpSyncs Foreach



