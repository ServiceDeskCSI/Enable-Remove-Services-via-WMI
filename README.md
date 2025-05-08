# Enable-Remove-Services-via-WMI


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
