<#
.SYNOPSIS
    Enable ADMIN$, fully enable Remote Desktop (including NLA, firewall, group membership), suspend BitLocker for one reboot, then reboot via WMI remote‑process.

.DESCRIPTION
    1. Turn on auto‑shares and restart the Server service (ADMIN$)  
    2. Enable RDP in the registry and start TermService  
    3. Require Network Level Authentication (NLA)  
    4. Open all Remote Desktop firewall rules (group + explicit TCP/UDP 3389 on all profiles)  
    5. Add your account to the Remote Desktop Users group  
    6. Suspend BitLocker for one reboot  
    7. Reboot the machine  

.NOTES
    - Needs WMI (RPC) access and an account in local Administrators on the target.
    - Make sure TCP 135 and dynamic RPC ports are reachable.
#>

# ---------------------------
# Configuration — edit these
# ---------------------------

$RemoteHost = "host"   # Remote computer name or IP
$Username   = "domain\user"         # Account with admin rights on remote host
$Password   = "pass"    # Password for above account
$BitLockerVolume  = "C:"                           # Volume to suspend BitLocker on

# --------------------
# Don't modify below
# --------------------
# Build credential
$SecurePwd  = ConvertTo-SecureString $Password -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($Username, $SecurePwd)

$Namespace = "root\cimv2"

# Commands to run remotely
$Commands = @(
    # 1) Ensure ADMIN$ auto‑shares
    'cmd.exe /c reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v AutoShareServer /t REG_DWORD /d 1 /f',
    'cmd.exe /c sc.exe config LanmanServer start= auto',
    'cmd.exe /c sc.exe stop LanmanServer',
    'cmd.exe /c sc.exe start LanmanServer',

    # 2) Enable Remote Desktop at the OS level
    'cmd.exe /c reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f',
    'cmd.exe /c sc.exe config termservice start= auto',
    'cmd.exe /c sc.exe start termservice',

    # 3) Require Network Level Authentication (more secure RDP)
    'cmd.exe /c reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 1 /f',

    # 4) Open all Remote Desktop firewall rules (built‑in group + explicit TCP/UDP 3389 for any profile)
    'cmd.exe /c netsh advfirewall firewall set rule group="Remote Desktop" new enable=Yes profile=any',
    'cmd.exe /c netsh advfirewall firewall add rule name="Allow RDP TCP" protocol=TCP dir=in localport=3389 action=allow profile=any',
    'cmd.exe /c netsh advfirewall firewall add rule name="Allow RDP UDP" protocol=UDP dir=in localport=3389 action=allow profile=any',

    # 5) Add your user to the Remote Desktop Users group
    "cmd.exe /c net localgroup `"Remote Desktop Users`" `"$Username`" /add",

    # 6) Suspend BitLocker on $BitLockerVolume for one reboot
    "cmd.exe /c manage-bde -protectors -disable $BitLockerVolume -RebootCount 1",

    # 7) Reboot immediately
    'cmd.exe /c shutdown.exe /r /t 0'
)

foreach ($Cmd in $Commands) {
    Write-Host "[$RemoteHost] → $Cmd"
    try {
        $res = Invoke-WmiMethod `
            -Namespace $Namespace `
            -Class Win32_Process `
            -Name Create `
            -ArgumentList $Cmd `
            -ComputerName $RemoteHost `
            -Credential $Credential `
            -ErrorAction Stop

        if ($res.ReturnValue -eq 0) {
            Write-Host "    ✅ Success"
        }
        else {
            Write-Warning "    ⚠️ Exit code $($res.ReturnValue)"
        }
    }
    catch {
        Write-Warning "    ❌ Failed: $($_.Exception.Message)"
    }
}
