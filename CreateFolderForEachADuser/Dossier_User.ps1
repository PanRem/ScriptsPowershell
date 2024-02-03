#r�cup�ration de tous les usernames de l'AD
$users = Get-ADUser -filter '*' | Select -Property 'SamAccountName'
$count = 0

#cr�ation de dossier pour chaque user
foreach ($user in $users.SamAccountName)
{
	$path = "\\Emplacement\reseau\partage$\$user"
	#check si existant
    if(!(Test-Path -Path $path)){
        $folder = New-Item $path -ItemType Directory

        #on commence par mettre tous les droits
        $perms =  "domain\$user", 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
        $AclObj = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $perms
		#on r�cup�re les droits du dossier pour les modifier
        $Acl = Get-Acl $folder.FullName
        $Acl.SetAccessRuleProtection($true,$true)
        $Acl.SetAccessRule($AclObj)

		#on retire les droits non voulu
        $precise1 = New-Object System.Security.AccessControl.FileSystemAccessRule("domain\$user", 'ChangePermissions', 'Allow')
        $precise2 = New-Object System.Security.AccessControl.FileSystemAccessRule("domain\$user", 'Delete', 'Allow')
        $precise3 = New-Object System.Security.AccessControl.FileSystemAccessRule("domain\$user", 'TakeOwnership', 'Allow')
        $ACL.RemoveAccessRule($precise1)
        $ACL.RemoveAccessRule($precise2)
        $ACL.RemoveAccessRule($precise3)
		#enfin on �dite les droits effectifs du dossier en cons�quence
        Set-Acl -Path $folder.FullName -AclObject $Acl
        Write-Host "Dossier $user cr��"
        $count++
    }
}
Write-Host "$count dossiers cr��s"
Read-Host -Prompt "Press enter to quit..."