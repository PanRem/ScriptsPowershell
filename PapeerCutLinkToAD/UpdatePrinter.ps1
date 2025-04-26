#PanRem 03/02/2024

#on commence par update la data du serveur papercut.
#étape non obligatoire car cela se fait tout les jour a minuit normalement.

#chemin vers l'exe CLI de papercut
$CLIpath = "C:\Program Files\PaperCut MF\server\bin\win\server-command.exe"
#on créer un credential d'un compte de service qui aura le droit d'executer la commande sur la machine. il ne sert que pour l'update
$srvice = "domain.local\srvscript"
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

    #on récupère la réponse (code copieur)
    $copieur = $response.methodResponse.params.param.value

    #on modifie l'attribut AD "fax number" par le code récupéré
    Set-AdUser -Identity $userName -Fax $copieur

	#cette partie concerne KOXO uniquement
	#koxo créer ses propres fichier pour chaque utilisateur et s'y réfère la plupart du temps (exemple jdoe.xml)
	#il faut donc modifier ces fichiers
    $path = "C:\Program Files\KoXo Dev\KoXoAdm\Data\Users\" #chemin vers les fiches users
	#on construit le chemin de celle qui nous intéresse ici (le chemin depend des OU)
    $list = $user.DistinguishedName -split ','
    for($i=5;$i -lt ($list.Count) ;$i++){
        $add = $list[-$i].Substring(3,$list[-$i].Length-3)
        $path += $add + "\"
    }
    $path += $userName + ".xml"

	#si le fichier existe bien on modifie la ligne FaxNumber en consequence. Si la ligne n'existe pas on la créer
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
		#on réécrit dans le fichier
        Set-Content -Path $path -Value $xmlContent -Encoding UTF8
    }
	#fin de partie dédié a KOXO
	
	#on va ensuite créer un dossier pour chaque utilisateur pour qu'ils récupère leur scans sur le réseau
	#on récupère l'username pour créer le chemin complet du dossier scan
    $userName = $user.SamAccountName
	$totalPath = $scanPath + $userName
    if(!(Test-Path -Path $totalPath)){
		#on créer le dossier
        $folder = New-Item $totalPath -ItemType Directory
		
		#on commence par mettre tous les droits
        $perms =  "domain\$userName", 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
        $AclObj = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $perms

		#on récupère les droits du dossier pour les modifier
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

		#enfin on édite les droits effectifs du dossier en conséquence
        Set-Acl -Path $folder.FullName -AclObject $Acl
    }
}

#on va ensuite procéder a un nettoyage des dossier scans dans le cas où l'utilisateur n'existe plus
#on liste les dossiers
$listScan = dir -Path $scanPath -Directory

#pour chaque dossier on vérifie si l'utilisateur existe encore.
#si non, on supprimer le dossier
foreach ($folder in $listScan)
{
    $testuser = $(try {Get-AdUser -Server "Domain" -Identity $folder.Name} catch {$null})
    if($testuser -eq $null)
    {
        Remove-Item -Path $folder.FullName
    }
}
