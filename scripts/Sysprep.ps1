
Remove-LocalUser -Name packer -ErrorAction SilentlyContinue

& $env:SystemRoot\System32\Sysprep\Sysprep.exe /oobe /generalize /quiet /quit /mode:vm

while ($true) { 
    $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State |
                Select-Object ImageState; Write-Output $imageState.ImageState; 
                
    if ($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { 
        Start-Sleep -s 10 
    } else { 
        break 
    }
}