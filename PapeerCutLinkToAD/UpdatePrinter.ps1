#on commence par update la data du serveur papercut.
#�tape non obligatoire car cela se fait tout les jour a minuit normalement.

#chemin vers l'exe CLI de papercut
$CLIpath = "C:\Program Files\PaperCut MF\server\bin\win\server-command.exe"
#on cr�er un credential d'un compte de service qui aura le droit d'executer la commande sur la machine. il ne sert que pour l'update
$srvice = "pedago.local\srvscript"
$PWord = ConvertTo-SecureString -String "password" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $srvice, $PWord
#on envoie la commande d'update
Invoke-Command -ComputerName srv-impression -Credential $Credential -ScriptBlock {&$CLIpath perform-user-and-group-sync}
#Fin de l'update non obligatoire

#on va ensuite tout faire par l'api, plus rapide que le CLI et sans besoin de logs user
$apiUrl = "http://1.1.1.1:9191/rpc/api/xmlrpc"  # URL de l'API
#base de la trame de requete contenant la clef api
$modele = '<?xml version="1.0" encoding="UTF-8"?>
<methodCall>
  <methodName>api.getUserProperty</methodName>
  <params>
    <param>
      <value>
        <string>CLEF_API</string>
      </value>
    </param>
    <param>
      <value>
        <string>username</string>
      </value>
    </param>
	<param>
      <value>
        <string>secondary-card-number</string>
      </value>
    </param>
  </params>
</methodCall> '

#emplacement des utilisateurs voulus
$OUPATH = 'OU=users,DC=domain,DC=local'
#chemin vers les dossiers scans
$scanPath = "\\chemin\vers\scans$\"
#liste des user de l'OU
$users = Get-ADUser -filter '*' -SearchBase $OUPATH
$count = 0

foreach ($user in $users)
{
    $requestBody = $modele -replace "username", $userName #construction de la requete
	
    #on envoie la requete
    $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $requestBody -ContentType 'text/xml'

    #on r�cup�re la r�ponse (code copieur)
    $copieur = $response.methodResponse.params.param.value

    #on modifie l'attribut AD "fax number" par le code r�cup�r�
    Set-AdUser -Identity $userName -Fax $copieur

	#cette partie concerne KOXO uniquement
	#koxo cr�er ses propres fichier pour chaque utilisateur et s'y r�f�re la plupart du temps (exemple jdoe.xml)
	#il faut donc modifier ces fichiers
    $path = "C:\Program Files\KoXo Dev\KoXoAdm\Data\Users\" #chemin vers les fiches users
	#on construit le chemin de celle qui nous int�resse ici (le chemin depend des OU)
    $list = $user.DistinguishedName -split ','
    for($i=5;$i -lt ($list.Count) ;$i++){
        $add = $list[-$i].Substring(3,$list[-$i].Length-3)
        $path += $add + "\"
    }
    $path += $userName + ".xml"

	#si le fichier existe bien on modifie la ligne FaxNumber en consequence. Si la ligne n'existe pas on la cr�er
    if(Test-Path $path){
        $xmlContent = Get-Content -Path $path -Raw -Encoding UTF8
        if($xmlContent -Match '(<FaxNumber>[\s\S]*</FaxNumber>)')
        {
            $xmlContent = $xmlContent -replace '(<FaxNumber>[\s\S]*</FaxNumber>)', "<FaxNumber>$copieur</FaxNumber>"
        }
        else
        {
            $xmlContent = $xmlContent -replace "</UserId>", "</UserId>`r`n<FaxNumber>$copieur</FaxNumber>"
        }
		#on r��crit dans le fichier
        Set-Content -Path $path -Value $xmlContent -Encoding UTF8
    }
	#fin de partie d�di� a KOXO
	
	#on va ensuite cr�er un dossier pour chaque utilisateur pour qu'ils r�cup�re leur scans sur le r�seau
	#on r�cup�re l'username pour cr�er le chemin complet du dossier scan
    $userName = $user.SamAccountName
	$totalPath = $scanPath + $userName
    if(!(Test-Path -Path $totalPath)){
		#on cr�er le dossier
        $folder = New-Item $totalPath -ItemType Directory
		
		#on commence par mettre tous les droits
        $perms =  "domain\$userName", 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
        $AclObj = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $perms

		#on r�cup�re les droits du dossier pour les modifier
        $Acl = Get-Acl $folder.FullName
        $Acl.SetAccessRuleProtection($true,$true)
        $Acl.SetAccessRule($AclObj)

		#on retire les droits non voulu
        $precise1 = New-Object System.Security.AccessControl.FileSystemAccessRule("domain\$userName", 'ChangePermissions', 'Allow')
        $precise2 = New-Object System.Security.AccessControl.FileSystemAccessRule("domain\$userName", 'Delete', 'Allow')
        $precise3 = New-Object System.Security.AccessControl.FileSystemAccessRule("domain\$userName", 'TakeOwnership', 'Allow')
        $Acl.RemoveAccessRule($precise1)
        $Acl.RemoveAccessRule($precise2)
        $Acl.RemoveAccessRule($precise3)

		#enfin on �dite les droits effectifs du dossier en cons�quence
        Set-Acl -Path $folder.FullName -AclObject $Acl
    }
}

#on va ensuite proc�der a un nettoyage des dossier scans dans le cas o� l'utilisateur n'existe plus
#on liste les dossiers
$listScan = dir -Path $scanPath -Directory

#pour chaque dossier on v�rifie si l'utilisateur existe encore.
#si non, on supprimer le dossier
foreach ($folder in $listScan)
{
    $testuser = $(try {Get-AdUser -Server "Domain" -Identity $folder.Name} catch {$null})
    if($testuser -eq $null)
    {
        Remove-Item -Path $folder.FullName
    }
}