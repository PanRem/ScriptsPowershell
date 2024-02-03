#PanRem 03/02/2024

#on définie le path du dossier de config OpenVpn GUI
$path = "$($env:USERPROFILE)\OpenVPN\config"
$file = '.\config.ovpn'
$savefile = '.\config.ovpn.save'
#on déclare la ligne de configuration avec la nouvelle ip
$nouvelleip = "remote 1.1.1.1"

#on test l'existance du chemin et on s'y place
if(Test-Path($path)){
	Set-Location ($path)
} 
#on test l'exitance du fichier
if(Test-Path($file)){
	#on fait une save
	Copy-Item -path $file -Destination $savefile
	#on modifie la ligne voulu en la trouvant a l'aide d'un regex
	(Get-Content $file) -replace 'remote (\b25[0-5]|\b2[0-4][0-9]|\b[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}', $nouvelleip | Out-File $file
}
