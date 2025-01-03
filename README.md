# pipeshell
Powershell-based named pipe shell that relies on .NET framework's abstraction (`System.IO.Pipes.NamedPipeServerStream`/`System.IO.Pipes.NamedPipeClientStream`) for named pipes. Local-only IPC for command execution.

server:
`.\pipeshell_server.ps1 -p [pipe_name] -k [one byte XOR key]`

client:
`.\pipeshell_client.ps1 -p [pipe_name] -k [one byte XOR key]`
