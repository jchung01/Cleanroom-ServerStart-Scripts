#!/usr/bin/env pwsh
# Above line should also allow for running cross-platform Powershell (on Linux) if installed.

<# 
Created by ChaosStrikez, adapting some code from https://github.com/AllTheMods/Server-Scripts.
If you are using Windows, either run this file with right-click -> "Run with Powershell",
or use starter.bat.
If you're not using Windows and don't have Powershell installed, use ServerStart.sh.

*** THIS FILE IS NOT INTENDED TO BE EDITED, USE "settings.cfg" INSTEAD ***

The below license is provided as some code is taken from the "All The Mods Team".
All other code is subject to MIT license.
================================================================================
*** LICENSE ***

	Copyright (c) 2017 All The Mods Team

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	You must give appropriate credit to the "All The Mods Team" as original 
	creators for any parts of this Software being used. A link back to original 
	content is optional but would be greatly appreciated. 

	It is forbidden to charge for access to the distribution of this Software or 
	gain money through it. This includes any type of inline advertisement, such 
	as url shorteners (adf.ly or otherwise) or ads. This also includes 
	restricting any amount of access behind a paywall. Special permission is 
	given to allow this Software to be bundled or distributed with projects on 
	Curse.com, CurseForge.com or their related sub-domains and subsidiaries.

	Derivative works must be open source (have its source visible and allow for 
	redistribution and modification).

	The above copyright notice and conditions must be included in all copies or 
	substantial portions of the Software, including derivative works and 
	re-licensing thereof. 

================================================================================
#>
$settings = $null
$useCleanroom = $null
$LOADER_NAME = $null
$LOADER_VER = $null
$MC_VER = $null
$JAVA_ARGS = $null
$JAVA_PATH = $null
$JAR_NAME = $null
$PACK_NAME = $null
$CRASH_TIMER = $null
$OFFLINE = $null
function ExitError {
    Read-Host -Prompt "The above error occurred. Press Enter to exit"
    exit
}

function WriteToLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [bool]$CreateFile
    )
    if ($CreateFile) {
        if (-not (Test-Path $PSScriptRoot/"logs")) {
            New-Item -Path $PSScriptRoot -Name "logs" -ItemType "directory" | Out-Null
        }
        Write-Output $Message | Out-File -FilePath $PSScriptRoot/"logs/serverstart.log"
    }
    else {
        Write-Output $Message | Out-File -FilePath $PSScriptRoot/"logs/serverstart.log" -Append
    }
}

function CheckJava {
    Write-Host "Checking java installation..." -ForegroundColor yellow
    $version = Get-Command $JAVA_PATH | Select-Object -ExpandProperty Version
    $errored = $false
    & $JAVA_PATH -version
    WriteToLog "DEBUG: JAVA version output: $(& $JAVA_PATH -version 2>&1)"
    if ($useCleanroom -and ($version.Major -ge 21)) {
        Write-Host "ERROR: Invalid java version found. Check your environment variables or set JAVA_PATH in settings.cfg." -ForegroundColor red
        Write-Host "Using Cleanroom, which requires Java 22, but found $($version).`nIf you want to use Cleanroom with your current Java, set 'USE_CLEANROOM = true' in settings.cfg." -ForegroundColor red
        $errored = $true
    }
    elseif (-not ($useCleanroom) -and ($version.Major -ne 8)) {
        Write-Host "ERROR: Invalid java version found. Check your environment variables or set JAVA_PATH in settings.cfg." -ForegroundColor red
        Write-Host "Using Forge, which requires Java 8, but found $($version).`nIf you want to use Forge with your current Java, set 'USE_CLEANROOM = false' in settings.cfg." -ForegroundColor red
        $errored = $true
    }
    if ($errored) {
        ExitError
    }

    $bitness = & $JAVA_PATH -XshowSettings:properties -version 2>&1 | Select-String -Pattern sun.arch.data.model | ConvertFrom-StringData
    $bitness.GetEnumerator() | ForEach-Object {
        if ($_.Value -eq 64) {
            WriteToLog "INFO: Found 64-bit Java $($version)"
        }
        else {
            WriteToLog "INFO: Found 32-bit Java $($version)"
            Write-Host "ERROR: 32-bit java version found. Please install 64-bit java." -ForegroundColor red
            ExitError
        }
    }
}

function CheckInternet {
    $online = $false
    # Try with Google DNS
    if (Test-Connection -Count 2 -Quiet 8.8.8.8) {
        $online = $true
        WriteToLog "INFO: Ping of '8.8.8.8' Successful"
    }
    else {
        WriteToLog "INFO: Ping of '8.8.8.8' Failed"
    }
    # If Google ping failed try one more time with L3 just in case
    if (!$online) {
        if (Test-Connection -Count 2 -Quiet 4.2.2.1) {
            $online = $true
            WriteToLog "INFO: Ping of '4.2.2.1' Successful"
        }
        else {
            WriteToLog "INFO: Ping of '4.2.2.1' Failed"
        }
    }
    if (!$online) {
        Write-Host "No internet connectivity found" -ForegroundColor yellow
        WriteToLog "WARN: No internet connectivity found"
    }
    return $online
}

function ReinstallLoader {
    param (
        $Vanilla,
        $Libs,
        $Forge,
        $Cleanroom,
        $IsOnline
    )
    # Clean files: vanilla jar, loader jar, libraries folder
    Write-Host "Clearing old files before installing $($LOADER_NAME)/minecraft..." -ForegroundColor Yellow
    WriteToLog "INFO: Clearing and installing $($LOADER_NAME)/minecraft..."
    if ($null -ne $Vanilla) {
        Remove-Item $Vanilla
    }
    if ($null -ne $Libs) {
        Remove-Item -Recurse $Libs
    }
    if ($null -ne $Forge) {
        Remove-Item $Forge
    }
    if ($null -ne $Cleanroom) {
        Remove-Item $Cleanroom
    }
    if (Test-Path $PSScriptRoot/"installer-$($LOADER_NAME)-$($LOADER_VER).jar") {
        Write-Host "Existing $($LOADER_NAME) installer already found..."
	    Write-Host "Default is to use this installer and not re-download"
    }
    # Download installer
    else {
        if ($OFFLINE -and !$IsOnline) {
            Write-Host 'IGNORE_OFFLINE is set to true, please set it to false and ensure you have an internet connection to download the installer.' -ForegroundColor red
            WriteToLog 'ERROR: IGNORE_OFFLINE is set to true, please set it to false and ensure you have an internet connection to download the installer.'
            ExitError
        }
        Import-Module BitsTransfer
        $source = $null
        if ($useCleanroom) {
            # If the format changes this URL might need to be changed
            $source = "https://github.com/CleanroomMC/Cleanroom/releases/download/$($LOADER_VER)/cleanroom-$($LOADER_VER)-installer.jar"
        }
        else {
            # Hard coded, Forge shouldn't change
            $source = "https://maven.minecraftforge.net/net/minecraftforge/forge/1.12.2-14.23.5.2860/forge-1.12.2-14.23.5.2860-installer.jar"
        }
        Start-BitsTransfer -Source $source -Destination $PSScriptRoot/"installer-$($LOADER_NAME)-$($LOADER_VER).jar"
        Get-BitsTransfer | Complete-BitsTransfer
    }
    # Setup default files
    if (-not (Test-Path $PSScriptRoot/"server.properties")) {
        Write-Host "Could not find server.properties, creating initial copy..."
        WriteToLog "INFO: server.properties not found... populating default"
        Write-Output "view-distance=8",
            "allow-flight=true",
            "enable-command-block=false",
            "level-type=$($settings["DEFAULT_WORLD_TYPE"])",
            "snooper-enabled=false",
            "max-tick-time=90000",
            "motd=$($PACK_NAME)" | Out-File -FilePath $PSScriptRoot/"server.properties"
    }
    if (-not (Test-Path $PSScriptRoot/"eula.txt")) {
        Write-Host "Could not find eula.txt, creating initial copy..."
        WriteToLog "INFO: eula.txt not found... populating default"
        Write-Output "eula=false" | Out-File -FilePath $PSScriptRoot/"eula.txt"
    }
    Write-Host "Installing $($LOADER_NAME) now, please wait..."
    WriteToLog "INFO: Starting $($LOADER_NAME) install now, details below:"
    $installerName = "installer-$($LOADER_NAME)-$($LOADER_VER).jar"
    WriteToLog "--------------------------"
    & $JAVA_PATH -jar $installerName --installServer 2>&1 | Out-File -FilePath $PSScriptRoot/"logs/serverstart.log" -Append
    WriteToLog "--------------------------"
    Remove-Item $installerName
    Remove-Item "installer.log"
}

function CheckSetup {
    param (
        [bool]$IsOnline
    )
    $vanilla = $null
    $libs = $null
    $forge = $null
    $cleanroom = $null
    $reinstall = $false
    $jarName = $null
    # Check a loader is installed
    if (-not (Test-Path $PSScriptRoot/"minecraft_server.$($MC_VER).jar")) {
        Write-Host "Minecraft binary not found, installing $($LOADER_NAME)..." -ForegroundColor yellow
        WriteToLog "INFO: Minecraft binary not found, installing $($LOADER_NAME)..."
        $reinstall = $true
    }
    else {
        $vanilla = "$($PSScriptRoot)/minecraft_server.$($MC_VER).jar"
    }
    # Check libraries for proper loader install
    if (-not (Test-Path $PSScriptRoot/"libraries")) {
        Write-Host "Libraries folder not found, installing $($LOADER_NAME)..." -ForegroundColor yellow
        WriteToLog "INFO: Libraries folder not found, installing $($LOADER_NAME)..."
        $reinstall = $true
    }
    else {
        $libs = "$($PSScriptRoot)/libraries"
        if (Test-Path $PSScriptRoot/"forge-$($MC_VER)-$($LOADER_VER).jar") {
            $forge = "$($PSScriptRoot)/forge-$($MC_VER)-$($LOADER_VER).jar"
        }
        if (Test-Path $PSScriptRoot/"cleanroom-$($LOADER_VER).jar") {
            $cleanroom = "$($PSScriptRoot)/cleanroom-$($LOADER_VER).jar"
        }
        else {
            # Check and remove old Cleanroom
            $oldCleanroom = Get-ChildItem $PSScriptRoot | Where-Object Name -like "cleanroom-*.jar"
            if ($oldCleanroom.Count -gt 0) {
                Remove-Item $oldCleanroom
            }
        }
        # Check for existing Cleanroom
        if ($useCleanroom -and ($null -eq $cleanroom)) {
            # Found Forge, remove it as we want Cleanroom
            if (Test-Path "$($PSScriptRoot)/forge-$($MC_VER)-$($settings["FORGE_VER"]).jar") {
                Remove-Item "$($PSScriptRoot)/forge-$($MC_VER)-$($settings["FORGE_VER"]).jar"
            }
            $reinstall = $true
        }
        # Check for existing Forge
        elseif (!$useCleanroom -and ($null -eq $forge)) {
            # Found Cleanroom, remove it as we want Forge
            if (Test-Path "$($PSScriptRoot)/cleanroom-$($settings["CLEANROOM_VER"]).jar") {
                Remove-Item "$($PSScriptRoot)/cleanroom-$($settings["CLEANROOM_VER"]).jar"
            }
            $reinstall = $true
        }
    }
    # Set jarName even if jars not found
    if ($useCleanroom) {
        $jarName = "$($PSScriptRoot)/cleanroom-$($settings["CLEANROOM_VER"]).jar"
    }
    else {
        $jarName = "$($PSScriptRoot)/forge-$($MC_VER)-$($settings["FORGE_VER"]).jar"
    }
    if ($reinstall) {
        ReinstallLoader -Vanilla $vanilla -Libs $libs -Forge $forge -Cleanroom $cleanroom -IsOnline $IsOnline
        Write-Host "---------------------------------------------------"
        Write-Host "$($PACK_NAME) Server Files are now ready!"
        Write-Host "---------------------------------------------------"
    }
    return $jarName
}

function CheckEula {
    # Check for EULA agreement
    if ((Test-Path $PSScriptRoot/"eula.txt") -and !(Select-String -Path $PSScriptRoot/"eula.txt" -Pattern "eula=true" -Quiet)) {
        $host.UI.RawUI.WindowTitle = "ERROR: EULA.TXT Must be updated before $($PACK_NAME) server can start"
        Clear-Host
        Write-Host 'Could not find "eula=true" in eula.txt file'
        Write-Host 'Please edit and save the EULA file before continuing.'
        # Pause
        Write-Host -NoNewLine 'Press any key to continue...'
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        Write-Host ''
        return $true
    }
    return $false
}

function PromptRestart {
    $timeout = 30  # Timeout in seconds
    $endTime = (Get-Date).AddSeconds($timeout)

    # Prompt the user for input with a timeout
    Write-Host 'Restart now (Y) or Exit (N):' -NoNewline
    while ($true) {
        # Check if the timeout has been reached
        if ((Get-Date) -ge $endTime) {
            Write-Host "`nTimed out after $timeout seconds."
            # Default is to restart
            return $true
        }

        # Check if input is available
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true).Key
            Write-Host $key
            switch ($key) {
                { $_ -eq "y" } { return $true }
                { $_ -eq "n" } { return $false }
                default { Write-Error "Only 'Y' or 'N' allowed!"; Write-Host 'Restart now (Y) or Exit (N):' -NoNewline }
            }
        }
        Start-Sleep -Milliseconds 200
    }
}

$restartEntire = $false
$restartRun = $false
$stopCounter = 0
$dateTime = Get-Date
do {
    Clear-Host
    ### Initial setup ###
    WriteToLog -Message "--------------------------" -CreateFile $true
    WriteToLog "Starting ServerStart.ps1"
    WriteToLog "--------------------------`n"
    
    # Read settings.cfg
    if (-not (Test-Path $PSScriptRoot/"settings.cfg")) {
        Get-Content $PSScriptRoot/"settings.cfg"
        ExitError
    }
    WriteToLog "DEBUG: settings.cfg Found. Logging full contents below:`n--------------------------"
    Get-Content $PSScriptRoot/"settings.cfg" | Out-File -FilePath $PSScriptRoot/"logs/serverstart.log" -Append
    WriteToLog "--------------------------"
    $settings = Get-Content $PSScriptRoot/"settings.cfg" | Where-Object {$_ -notmatch '^\s*#' -and $_ -match '='}
    $settings = $settings -replace '\\', '\\' -join "`n" | ConvertFrom-StringData
    
    # Read MODPACK_NAME option
    $PACK_NAME = $settings["MODPACK_NAME"]
    $host.UI.RawUI.WindowTitle = "$($PACK_NAME) ServerStart Script"
    # Read USE_CLEANROOM option
    if (-not ([bool]::TryParse($settings["USE_CLEANROOM"], [ref]$useCleanroom))) {
        Write-Error "USE_CLEANROOM must be 'true' or 'false': USE_CLEANROOM=$($settings["USE_CLEANROOM"])"
        ExitError
    }
    if ($useCleanroom) {
        $LOADER_NAME = "Cleanroom"
        $LOADER_VER = $settings["CLEANROOM_VER"]
    }
    else {
        $LOADER_NAME = "Forge"
        $LOADER_VER = $settings["FORGE_VER"]
    }
    # Verify MC_VER option
    if (-not ($settings["MC_VER"] -match '[0-9\.]*')) {
        Write-Error "MC_VER is invalid: MC_VER=$($settings["MC_VER"])"
        ExitError
    }
    else {
        $MC_VER = $settings["MC_VER"]
    }
    # Read IGNORE_OFFLINE option
    if (-not ([bool]::TryParse($settings["IGNORE_OFFLINE"], [ref]$OFFLINE))) {
        Write-Error "IGNORE_OFFLINE must be 'true' or 'false': IGNORE_OFFLINE=$($settings["IGNORE_OFFLINE"])"
        ExitError
    }
    
    Write-Host "`n*** Loading $($PACK_NAME) Server ***"
    Write-Host "Running $($LOADER_NAME) $($LOADER_VER) for Minecraft $($MC_VER)`n"
    
    Write-Host ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
    Write-Host "            Minecraft-Forge/Cleanroom Server install/launcher script"
    Write-Host "   (Created by ChaosStrikez, adapted from the 'All The Mods' ServerStart script)"
    Write-Host ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
    Write-Host "`nThis script will launch a Minecraft Modded server, runnning Forge or Cleanroom"
    Write-Host "`nSource: https://github.com/jchung01/Cleanroom-ServerStart-Scripts"
    Write-Host "`nThis was originally made for the MeatballCraft modpack, Links here;"
    Write-Host "  Curseforge: https://www.curseforge.com/minecraft/modpacks/meatballcraft"
    Write-Host "  MeatballCraft Discord: https://discord.com/invite/WVvVm7aWh3`n"
    # Verify MAX_RAM option
    if (-not ($settings["MAX_RAM"] -match '[0-9]*[mMgG]')) {
        Write-Error "MAX_RAM must follow end in M or G: MAX_RAM=$($settings["MAX_RAM"])"
        ExitError
    }
    # Read JAVA_PATH
    if ((![string]::IsNullOrWhitespace($settings["JAVA_PATH"])) -and ("DISABLE" -ne $settings["JAVA_PATH"])) {
        $JAVA_PATH = [string]$settings["JAVA_PATH"] -replace '"', ''
    }
    else {
        $JAVA_PATH = "java"
    }
    # Read and set java args
    $JAVA_ARGS = "-Xmx$($settings["MAX_RAM"]) -Xms$($settings["MAX_RAM"]) $($settings["JAVA_ARGS"])"
    # Read CRASH_TIMER option
    $CRASH_TIMER = $settings["CRASH_TIMER"]
    ### Various checks ###
    CheckJava
    $online = $false
    if ($OFFLINE) {
        Write-Host 'Skipping internet connectivity check...' -ForegroundColor yellow
        WriteToLog 'WARN: Skipping internet connectivity check...'
    }
    else {
        $online = CheckInternet
    }
    $JAR_NAME = CheckSetup -IsOnline $online
    ### Start ###
    do {
        $host.UI.RawUI.WindowTitle = "$($PACK_NAME) Server Running"
        Write-Host "Starting $($PACK_NAME) Server..." -ForegroundColor yellow
        WriteToLog "INFO: Starting Server at $($dateTime)..."
        Write-Host "Attempting to execute [ `"$($JAVA_PATH)`" $($JAVA_ARGS) -jar `"$($JAR_NAME)`" $($settings["GAME_ARGS"]) ]`n"
        WriteToLog "DEBUG: Attempting to execute [ `"$($JAVA_PATH)`" $($JAVA_ARGS) -jar `"$($JAR_NAME)`" $($settings["GAME_ARGS"]) ]"
        Start-Process -FilePath "$($JAVA_PATH)" -ArgumentList "$($JAVA_ARGS) -jar `"$($JAR_NAME)`" $($settings["GAME_ARGS"])" -NoNewWindow -Wait
        # Check if we should restart the run
        Write-Host "`n$($PACK_NAME) Server was stopped (possibly crashed)..." -ForegroundColor yellow
        $restartRun = CheckEula
    }
    while ($restartRun)
    $dateTimeNow = Get-Date
    $days = ($dateTime - $dateTimeNow).TotalDays
    $secs = ($dateTime - $dateTimeNow).TotalSeconds
    $stopCounter += 1
    Write-Host "Server started at $($dateTime) has stopped at $($dateTimeNow)."
    WriteToLog "ERROR: Server started at $($dateTime) has stopped at $($dateTimeNow)."
    Write-Host "Server has $($stopCounter) consecutive stops, each within $($CRASH_TIMER) seconds of each other...`n"
    WriteToLog "DEBUG: Server has $($stopCounter) consecutive stops, each within $($CRASH_TIMER) seconds of each other..."
    # Reset if it's been a day
    if ($days -gt 0) {
        Write-Host 'More than one day since last crash/restart... resetting counter/timer'
        WriteToLog 'INFO: More than one day since last crash/restart... resetting counter/timer'
        $dateTime = $dateTimeNow
        $stopCounter = 0
    }
    # Reset if crash timer from config was exceeded
    elseif ($secs -gt $CRASH_TIMER) {
        Write-Host "Last crash/startup was $(-$secs)+ seconds ago"
        WriteToLog "INFO: Last crash/startup was $(-$secs)+ seconds ago"
        Write-Host "More than $($CRASH_TIMER) seconds since last crash/restart... resetting counter/timer"
        WriteToLog "INFO: More than $($CRASH_TIMER) seconds since last crash/restart... resetting counter/timer"
        $dateTime = $dateTimeNow
        $stopCounter = 0
    }
    # Reset if reached max failures
    elseif ($stopCounter -ge $settings["CRASH_COUNT"]) {
        WriteToLog "INFO: Last crash/startup was $(-$secs)+ seconds ago"
        Write-Host "`n`n===================================================" -ForegroundColor red
        Write-Host " Server has stopped/crashed too many times!" -ForegroundColor red
        Write-Host "===================================================`n" -ForegroundColor red
        WriteToLog "ERROR: Server has stopped/crashed too many times!"
        Write-Host "$($stopCounter) Crashes have been counted each within $($CRASH_TIMER) seconds."
        ExitError
    }
    # Under threshold of crashes, go ahead and try restart
    else {
        WriteToLog "INFO: Last crash/startup was $(-$secs)+ seconds ago"
        $dateTime = $dateTimeNow
        WriteToLog "Total consecutive crash/stops within time threshold: $($stopCounter)"
        Write-Host "`n`n`nServer will re-start *automatically* in less than 30 seconds..."
        $restartEntire = PromptRestart
    }
}
while ($restartEntire)