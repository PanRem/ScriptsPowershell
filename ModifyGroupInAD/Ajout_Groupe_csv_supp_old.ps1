#D�finition des param�tres
[CmdletBinding()]
param (
    [Parameter(
      Mandatory = $false,
      HelpMessage = "Chemin du fichier CSV"
    )]
    [string] $Path =  $PSScriptRoot + "\group.csv"
    )
	
#D�claration du fichier de log
$logFile = "GroupLogs_{0:dd-MM-yyyy_HH\Hmm}.log" -f (Get-Date)

#r�cup�ration des donn�es du csv
Import-Csv $path -Delimiter ";" | Foreach-Object { 

    foreach ($property in $_.PSObject.Properties)
    {
		# traitement de l'id user (1�re colonne du csv)
        if($property.Name -eq "id")
        {
            $name = $property.Value
            $user = Get-ADUser -filter "SamAccountName -eq '$name'" | Select ObjectGUID
            $ADUser = Get-ADUser -filter "SamAccountName -eq '$name'" -Properties MemberOf
            If ($ADUser -eq $Null)
            {
                "Utilisateur $name introuvable" | Out-File -FilePath $LogFile -Append
            } else {
				#Nettoyage des groupes actuels du User
                "Suppression de tous les groupes de $name" | Out-File -FilePath $LogFile -Append
                [array]$Groups = $AdUser.MemberOf
                Foreach ($Group in $Groups)
                {
                    "Suppression de $name du groupe $Group" | Out-File -FilePath $LogFile -Append
                    Remove-ADGroupMember -Identity "$Group" -Members $user -Confirm:$false
                }
            }
        }
        else
        {
			#ajout des diff�rents groupe (autres colonnes du csv)
            if($property.Value -and $user)
            {
                Add-ADGroupMember -Identity $property.Value -Members $user
                "$name ajout� � $($property.Value)" | Out-File -FilePath $LogFile -Append
            }
        }
    } 
}

Read-Host -Prompt "Press enter to quit..."