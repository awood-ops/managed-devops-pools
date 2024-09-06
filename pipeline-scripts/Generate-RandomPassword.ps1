function Generate-RandomPassword {
    param (
        [Parameter(Mandatory=$true)]
        [int]$Length
    )

    $characters = '!@#$%^&*0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz'
    $password = ''

    for ($i = 0; $i -lt $Length; $i++) {
        $randomCharacter = Get-Random -Maximum $characters.Length
        $password += $characters[$randomCharacter]
    }

    return $password
}

# Usage
$randomPassword = Generate-RandomPassword -Length 24
Write-Output $randomPassword