#PanRem 03/02/2024

#On récupère la liste d'ip de switch (1 par ligne)
$iplist = Get-Content -Path ip.txt

foreach($ip in $iplist){
	
	#on se connecte sur le switch
	$socket = new-object System.Net.Sockets.TcpClient($ip, 23)
	Start-Sleep -Seconds 3
	write-host "Connected."
	$stream = $socket.GetStream()
	$writer = new-object System.IO.StreamWriter $stream
	Start-Sleep -Seconds 3
	
	#on envoie une touche quelconque pour passer le msg de bienvenue
	$writer.WriteLine("c")
	$writer.Flush()
	Start-Sleep -Seconds 3

	#on va dans le menu de configuration
	$writer.WriteLine("config")
	$writer.Flush()
	Start-Sleep -Seconds 3
	
	#on commande la définition du mot de passe op
	$writer.WriteLine("password operator")
	$writer.Flush()
	Start-Sleep -Seconds 3
	
	#mot de passe
	$writer.WriteLine("password")
	$writer.Flush()
	Start-Sleep -Seconds 3
	
	#confirmation
	$writer.WriteLine("password")
	$writer.Flush()
	Start-Sleep -Seconds 3
	
	#on créer la clef pour le ssh
	$writer.WriteLine("crypto key generate ssh")
	$writer.Flush()
	Start-Sleep -Seconds 3
	
	#on active le ssh
	$writer.WriteLine("ip ssh")
	$writer.Flush()
	Start-Sleep -Seconds 3
	
	#on défini le port personalisé du ssh
	$writer.WriteLine("ip ssh port 2180")
	$writer.Flush()
	Start-Sleep -Seconds 3
	
	#on coupe le telnet
	$writer.WriteLine("no telnet–server")
	$writer.Flush()
	Start-Sleep -Seconds 3

	#sauvegarde de la config
	$writer.WriteLine("write memory")
	$writer.Flush()
	Start-Sleep -Seconds 3
	
	#deconnextion
	$writer.Close()
	$stream.Close()
	Start-Sleep -Seconds 3
	
	Write-Output($ip + " check")
}
