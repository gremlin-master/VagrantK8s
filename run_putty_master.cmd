@echo off

REM Get the path to the directory from this batch and then remove 
REM the already attended slash at the end of THIS_BATCH_PATH because 
REM it makes reading paths more complicated when separation by slashes
REM can't be seen
set THIS_BATCH_PATH=%~dp0
set THIS_BATCH_PATH=%THIS_BATCH_PATH:~0,-1%

REM Use a local variable scope to avoid trouble with global variables
REM and to be able to set variables inside if clauses
setlocal EnableDelayedExpansion

set SSH_KEY=%THIS_BATCH_PATH%\.vagrant\machines\K8s-Master\virtualbox\private_key
set SSH_KEY_PUTTY=!SSH_KEY!.ppk

if not exist !SSH_KEY_PUTTY! (
    if exist !SSH_KEY! (
        echo A private key has been found. It will be converted into a putty/kitty suitable format
        call :ConvertSSHKey !SSH_KEY!
    )
)

if exist !SSH_KEY_PUTTY! (
    REM TODO: Search for putty/kitty instead of hardcoding the path
    set KITTY=C:\ProgramData\chocolatey\bin\kitty.exe
    set SSH_USERNAME=vagrant
    set AUTO_PASSWORD=vagrant

    REM If multiple vagrant vms are active vagrant assigns different ports to them on startup
    REM so for the correct connection we need to get the forwarding info from the vm
    call :RetrieveForwardingInformations FORWARDING_NAME FORWARDING_PROTOCOL HOST_IP HOST_PORT GUEST_IP GUEST_PORT

    REM -ssh selects the SSH protocol
    REM -l: specify a login name
    REM -pw: specify a password
    REM -i: specify an SSH private key
    REM -P: specify a port number
    REM -X turn on X11 forwarding in SSH
    !KITTY! -ssh -l !SSH_USERNAME! -pw !AUTO_PASSWORD! -i !SSH_KEY_PUTTY! -P !HOST_PORT! !HOST_IP! -X 
) else (
    echo No private key has been found for this vm. Connecting via ssh isn't possible.
)

endlocal
goto end

REM ------------------------------------------------------------------
REM @name         :ConvertSSHKey
REM @brief        Converts a ssh key into a putty suitable format
REM @param[in]    The path to the key file
REM ------------------------------------------------------------------
:ConvertSSHKey

REM use a local variable scope to avoid trouble with global variables
setlocal EnableDelayedExpansion

REM Use local variables for the parameters because the variable
REM name better describes what the parameters mean
set SSH_KEY=%~1

REM TODO: Search for WinSCP.com instead of hardcoding a path
if exist "C:\Program Files (x86)\WinSCP\WinSCP.com" (
    set WINSCP="C:\Program Files (x86)\WinSCP\WinSCP.com"
)

if exist "C:\ProgramData\chocolatey\bin\winscp.exe" (
    set WINSCP="C:\ProgramData\chocolatey\bin\winscp.exe"
)

if exist !WINSCP! (
    REM https://superuser.com/questions/912304/how-do-you-convert-an-ssh-private-key-to-a-ppk-on-the-windows-command-line
    %WINSCP% /keygen !SSH_KEY! /output=!SSH_KEY!.ppk
) else (
    echo WinSCP is needed for converting the ssh key but it can't be found
)

REM End the local variable scope
endlocal

REM return to calling function
goto :eof

REM ------------------------------------------------------------------
REM @name         :RetrieveForwardingInformations
REM @brief        Retrieves the forwarding informations from the vm if available
REM ------------------------------------------------------------------
:RetrieveForwardingInformations

REM use a local variable scope to avoid trouble with global variables
setlocal EnableDelayedExpansion

REM Use local variables for the parameters because the variable
REM name better describes what the parameters mean

REM Retrieve this vms id
set /p vm_id=<.vagrant\machines\K8s-Master\virtualbox\id

REM Get the forwarding information
for /f %%a in ('VBoxManage showvminfo --machinereadable !vm_id!') do (
    REM Split at the equal character
    set CURRENT_LINE=%%a

    if "!CURRENT_LINE:~0,10!"=="Forwarding" (
        REM Example: Forwarding(0)="ssh,tcp,127.0.0.1,2200,,22"
        for /f "tokens=1,2,3,4,5,6,7 delims==," %%b in ("!CURRENT_LINE!") do (
            set FORWARDING_NAME=%%~c
            set FORWARDING_NAME=!FORWARDING_NAME:"=!

            set FORWARDING_PROTOCOL=%%~d
            set FORWARDING_PROTOCOL=!FORWARDING_PROTOCOL:"=!

            set HOST_IP=%%e
            set HOST_IP=!HOST_IP:"=!

            set HOST_PORT=%%f
            set HOST_PORT=!HOST_PORT:"=!

            set GUEST_IP=%%g
            set GUEST_IP=!GUEST_IP:"=!

            set GUEST_PORT=%%~h
            set GUEST_PORT=!GUEST_PORT:"=!
        )
    )
)

REM End the local variable scope
endlocal & (
    set FORWARDING_NAME=%FORWARDING_NAME%
    set FORWARDING_PROTOCOL=%FORWARDING_PROTOCOL%
    set HOST_IP=%HOST_IP%
    set HOST_PORT=%HOST_PORT%
    set GUEST_IP=%GUEST_IP%
    set GUEST_PORT=%GUEST_PORT%
)

REM return to calling function
goto :eof

REM ------------------------------------------------------------------
REM @name         :end
REM @brief        ends the Batch File
REM ------------------------------------------------------------------
pause
:end
