#!/usr/bin/env bash

# Created by ChaosStrikez, adapting some code from https://github.com/AllTheMods/Server-Scripts.
# Make sure this is running as BASH.
# You might need to chmod +x before executing.
#
# *** THIS FILE IS NOT INTENDED TO BE EDITED, USE "settings.cfg" INSTEAD ***
#
# The below license is provided as some code is taken from the "All The Mods Team".
# All other code is subject to MIT license.
# ================================================================================
# *** LICENSE ***
#
# 	Copyright (c) 2017 All The Mods Team
#
# 	Permission is hereby granted, free of charge, to any person obtaining a copy
# 	of this software and associated documentation files (the "Software"), to deal
# 	in the Software without restriction, including without limitation the rights
# 	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# 	copies of the Software, and to permit persons to whom the Software is
# 	furnished to do so, subject to the following conditions:
#
# 	You must give appropriate credit to the "All The Mods Team" as original 
# 	creators for any parts of this Software being used. A link back to original 
# 	content is optional but would be greatly appreciated. 
#
# 	It is forbidden to charge for access to the distribution of this Software or 
# 	gain money through it. This includes any type of inline advertisement, such 
# 	as url shorteners (adf.ly or otherwise) or ads. This also includes 
# 	restricting any amount of access behind a paywall. Special permission is 
# 	given to allow this Software to be bundled or distributed with projects on 
# 	Curse.com, CurseForge.com or their related sub-domains and subsidiaries.
#
# 	Derivative works must be open source (have its source visible and allow for 
# 	redistribution and modification).
#
# 	The above copyright notice and conditions must be included in all copies or 
# 	substantial portions of the Software, including derivative works and 
# 	re-licensing thereof. 
#
# ================================================================================

# Specific to .sh
scriptRoot="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/"
RED="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
RESET="$(tput sgr0)"
CLEAR_LINE="$(tput el)"

declare -A settings
declare -a javaArgs
declare -a gameArgs
useCleanroom=
loaderName=
loaderVer=
mcVer=
javaPath=
jarName=
packName=
crashTimer=
offline=

function exit_error {
    read -srp "The above error occurred. Press any key to exit" -n 1 
    exit 1
}

function write_to_log {
    # $1 = Message
    # $2 = (Optional) CreateFile
    # Create file
    if [[ $2 == true ]]; then
        if [[ ! -d "${scriptRoot}logs/" ]]; then
            mkdir "${scriptRoot}logs/"
        fi
        printf '%s\n' "$1" > "${scriptRoot}logs/serverstart.log"
    else
        printf '%s\n' "$1" >> "${scriptRoot}logs/serverstart.log"
    fi
}

function check_java {
    echo -e "${YELLOW}Checking java installation...${RESET}"
    local fullVersion
    local majorVersion
    fullVersion=$("$javaPath" -version 2>&1 | awk -F '"' '/version/ {print $2}')
    majorVersion=$(echo "$fullVersion" | sed 's/^1\.//' | awk -F '[.\\-_]' '{print $1}')
    local errored=false
    "$javaPath" -version
    write_to_log "DEBUG: JAVA version output: $("$javaPath" -version 2>&1)"
    if [[ $useCleanroom == true && ! ($majorVersion -ge 21) ]]; then
        echo -e "${RED}ERROR: Invalid java version found. Check your environment variables or set JAVA_PATH in settings.cfg.${RESET}"
        echo -e "${RED}Using Cleanroom, which requires Java 21 or higher, but found $fullVersion.\nIf you want to use Cleanroom with your current Java, set 'USE_CLEANROOM = true' in settings.cfg.${RESET}"
        errored=true
    elif [[ $useCleanroom == false && ! ($majorVersion -eq 8) ]]; then
        echo -e "${RED}ERROR: Invalid java version found. Check your environment variables or set JAVA_PATH in settings.cfg.${RESET}"
        echo -e "${RED}Using Forge, which requires Java 8, but found $fullVersion.\nIf you want to use Forge with your current Java, set 'USE_CLEANROOM = false' in settings.cfg.${RESET}"
        errored=true
    fi
    if [[ $errored == true ]]; then
        exit_error
    fi

    local bitness
    bitness=$("$javaPath" -XshowSettings:properties -version 2>&1 | grep "sun.arch.data.model" | awk -F '=' '{printf $2+0}')
    if [[ $bitness -eq 64 ]]; then
        write_to_log "INFO: Found 64-bit Java $fullVersion"
    elif [[ $bitness -eq 32 ]]; then
        write_to_log "INFO: Found 32-bit Java $fullVersion"
        echo -e "${RED}ERROR: 32-bit java version found. Please install 64-bit java.${RESET}"
        exit_error
    # Looks like some JVMs don't report `sun.arch.data.model`
    else
        write_to_log "WARN: Couldn't determine if Java $fullVersion is 32 or 64-bit"
        echo -e "${YELLOW}WARN: Couldn't determine if Java $fullVersion is 64-bit, proceeding anyway!${RESET}"
    fi
}

function check_internet {
    local online=false
    if (! (command -v ping >> /dev/null 2>&1)); then
        write_to_log "WARN: Ping is not installed, cannot assure internet connection"
        echo -e "${YELLOW}Ping is not installed, cannot assure internet connection!${RESET}"
        return 1
    fi
    write_to_log "DEBUG: Ping found on system"
    # Try with Google DNS
    if (ping -c 2 8.8.8.8 >> /dev/null 2>&1); then
        online=true
        write_to_log "INFO: Ping of '8.8.8.8' Successful"
    else
        write_to_log "INFO: Ping of '8.8.8.8' Failed"
    fi
    # If Google ping failed try one more time with L3 just in case
    if [[ $online == false ]]; then
        if (ping -c 2 4.2.2.1 >> /dev/null 2>&1); then
            online=true
            write_to_log "INFO: Ping of '4.2.2.1' Successful"
        else
            write_to_log "INFO: Ping of '4.2.2.1' Failed"
        fi
    fi
    if [[ $online == false ]]; then
        echo -e "${YELLOW}No internet connectivity found${RESET}"
        write_to_log "WARN: No internet connectivity found"
        return 1
    fi
}

function install_progress {
    local input
    while read -r input; do
        echo -ne "\r${CLEAR_LINE}${input}"
    done
}

function reinstall_loader {
    # $1 = Vanilla
    # $2 = Libs
    # $3 = Forge
    # $4 = Cleanroom
    # $5 = IsOnline

    # Clean files: vanilla jar, loader jar, libraries folder
    echo -e "${YELLOW}Clearing old files before installing $loaderName/minecraft...${RESET}"
    write_to_log "INFO: Clearing and installing ${loaderName}/minecraft..."
    local param
    for param in "${@:1:${#@}-1}"; do
        if [[ -n "$param" ]]; then
            if [[ $param == "${scriptRoot}libraries" ]]; then
                rm -r "$param"
            else
                rm "$param"
            fi
        fi
    done
    if [[ -f "${scriptRoot}installer-$loaderName-$loaderVer.jar" ]]; then
        echo "Existing $loaderName installer already found..."
	    echo 'Default is to use this installer and not re-download'
    # Download installer
    else
        if [[ $offline == true && ($5 == false) ]]; then
            echo -e "${RED}IGNORE_OFFLINE is set to true, please set it to false and ensure you have an internet connection to download the installer.${RESET}"
            write_to_log 'ERROR: IGNORE_OFFLINE is set to true, please set it to false and ensure you have an internet connection to download the installer.'
            exit_error
        fi
        local source
        if [[ $useCleanroom == true ]]; then
            # If the format changes this URL might need to be changed
            source="https://github.com/CleanroomMC/Cleanroom/releases/download/$loaderVer/cleanroom-$loaderVer-installer.jar"
        else
            # Hard coded, Forge shouldn't change
            source='https://maven.minecraftforge.net/net/minecraftforge/forge/1.12.2-14.23.5.2860/forge-1.12.2-14.23.5.2860-installer.jar'
        fi
        # Check for commands, then do the download
        if (command -v curl >> /dev/null 2>&1); then
            write_to_log "DEBUG: (curl) Downloading $source"
            curl -L "$source" -o "${scriptRoot}installer-$loaderName-$loaderVer.jar" >> "${scriptRoot}logs/serverstart.log" 2>&1
        elif (command -v wget >> /dev/null 2>&1); then
            write_to_log "DEBUG: (wget) Downloading ${source}"
            wget "$source" -O "${scriptRoot}installer-$loaderName-$loaderVer.jar" >> "${scriptRoot}logs/serverstart.log" 2>&1
        else
            echo -e "${RED}Neither wget or curl were found on your system. Please install one and try again${RESET}"
            write_to_log 'ERROR: Neither wget or curl were found'
            exit_error
        fi
    fi
    # Setup default files
    if [[ ! -f "${scriptRoot}server.properties" ]]; then
        echo 'Could not find server.properties, creating initial copy...'
        write_to_log 'INFO: server.properties not found... populating default'
        {
            echo "view-distance=8",
            echo "allow-flight=true",
            echo "enable-command-block=false",
            echo "level-type=${settings["DEFAULT_WORLD_TYPE"]}",
            echo "snooper-enabled=false",
            echo "max-tick-time=90000",
            echo "motd=$packName"
        } > "${scriptRoot}server.properties"
    fi
    if [[ ! -f "${scriptRoot}eula.txt" ]]; then
        echo 'Could not find eula.txt, creating initial copy...'
        write_to_log 'INFO: eula.txt not found... populating default'
        echo "eula=false" > "${scriptRoot}eula.txt"
    fi
    echo "Installing $loaderName now, please wait..."
    write_to_log "INFO: Starting $loaderName install now, details below:"
    local installerName="installer-$loaderName-$loaderVer.jar"
    write_to_log "--------------------------"
    "$javaPath" -jar "${scriptRoot}$installerName" --installServer "${scriptRoot}" 2>&1 | tee -a "${scriptRoot}logs/serverstart.log" | install_progress
    write_to_log "--------------------------"
    rm "${scriptRoot}$installerName"
    rm -- "${scriptRoot}"*installer*.log
}

function check_setup {
    # $1 = IsOnline
    local vanilla
    local libs
    local forge
    local cleanroom
    local reinstall=false
    # Check a loader is installed
    if [[ ! -f "${scriptRoot}minecraft_server.$mcVer.jar" ]]; then
        echo -e "${YELLOW}Minecraft binary not found, installing $loaderName...${RESET}"
        write_to_log "INFO: Minecraft binary not found, installing $loaderName..."
        reinstall=true
    else
        vanilla="${scriptRoot}minecraft_server.$mcVer.jar"
    fi
    # Check libraries for proper loader install
    if [[ ! -d "${scriptRoot}libraries" ]]; then
        echo -e "${YELLOW}Libraries folder not found, installing $loaderName...${RESET}"
        write_to_log "INFO: Libraries folder not found, installing $loaderName..."
        reinstall=true
    else
        libs="${scriptRoot}libraries"
        if [[ -f "${scriptRoot}forge-$mcVer-$loaderVer.jar" ]]; then
            forge="${scriptRoot}forge-$mcVer-$loaderVer.jar"
        fi
        if [[ -f "${scriptRoot}cleanroom-$loaderVer.jar" ]]; then
            cleanroom="${scriptRoot}cleanroom-$loaderVer.jar"
        else
            # Remove any old Cleanroom
            rm cleanroom-*.jar 2> /dev/null
        fi
        # Check for existing Cleanroom
        if [[ $useCleanroom == true && (-z $cleanroom) ]]; then
            # Remove Forge if it exists as we want Cleanroom
            rm "${scriptRoot}forge-$mcVer-${settings["FORGE_VER"]}.jar" 2> /dev/null
            reinstall=true
        # Check for existing Forge
        elif [[ $useCleanroom == false && (-z $forge) ]]; then
            # Remove Cleanroom if it exists as we want Forge
            rm "${scriptRoot}cleanroom-${settings["CLEANROOM_VER"]}.jar" 2> /dev/null
            reinstall=true
        fi
    fi
    # Set jarName even if jars not found
    if [[ $useCleanroom == true ]]; then
        jarName="${scriptRoot}cleanroom-${settings["CLEANROOM_VER"]}.jar"
    else
        jarName="${scriptRoot}forge-$mcVer-${settings["FORGE_VER"]}.jar"
    fi
    if [[ $reinstall == true ]]; then
        reinstall_loader "$vanilla" "$libs" "$forge" "$cleanroom" "$1"
        echo "---------------------------------------------------"
        echo "$packName Server Files are now ready!"
        echo "---------------------------------------------------"
    fi
}

function check_eula {
    # Check for EULA agreement
    if ! grep -q "eula=true" eula.txt 2> /dev/null; then
        echo
        echo -e "${RED}Could not find 'eula=true' in eula.txt file, located at ${PWD}/eula.txt${RESET}"
        echo 'Please edit and save the EULA file before continuing.'
        exit_error
    fi
}

function prompt_restart {
    while true; do
        local choice
        if ! read -srp 'Restart now (Y) or Exit (N):' -t 30 -n 1 choice; then
            return 0
        fi
        echo
        case $choice in
            [Yy] ) return 0 ;;
            [Nn] ) return 1 ;;
        esac
    done
}

declare -i stopCounter=0
declare -i days
declare -i secs
restartEntire=false
printf -v dateTime '%(%Y-%m-%d %H:%M:%S)T' -1 
printf -v rawTime '%(%s)T' -1
if [[ ${BASH_VERSINFO[0]} -lt 4 || (${BASH_VERSINFO[0]} -eq 4 && ${BASH_VERSINFO[1]} -lt 2) ]]; then
    echo 'Bash 4.2 or greater is required for this script. Please update to 4.2 or greater.'
    exit_error
fi
while true; do
    clear
    ### Initial setup ###
    write_to_log '--------------------------' true
    write_to_log 'Starting ServerStart.sh'
    write_to_log $'--------------------------\n'
    
    # Read settings.cfg
    if [[ ! -f "${scriptRoot}settings.cfg" ]]; then
        cat "${scriptRoot}settings.cfg"
        exit_error
    fi
    write_to_log $'DEBUG: settings.cfg Found. Logging full contents below:\n--------------------------'
    cat "${scriptRoot}settings.cfg" >> "${scriptRoot}logs/serverstart.log"
    write_to_log '--------------------------'
    # Read the config file line by line
    while IFS=$'\n\r' read -r line || [[ -n "$line" ]]; do
        # Filters out comments and empty lines
        if [[ ${line:0:1} != '#' ]] && [[ $line = *[!\ ]* ]]; then
            key="${line%%=*}"
            value="${line#*=}"
            # Trim leading/trailing whitespace
            value=${value%%*([[:blank:]])}
            value=${value##*([[:blank:]])}
            settings["$key"]="$value"
        fi
    done < "${scriptRoot}settings.cfg"
    # Read MODPACK_NAME option
    packName="${settings["MODPACK_NAME"]}"
    # Read USE_CLEANROOM option
    case "${settings["USE_CLEANROOM"]}" in
        true) useCleanroom=${settings["USE_CLEANROOM"]} ;;
        false) useCleanroom=${settings["USE_CLEANROOM"]} ;;
        *)
            echo -e "${RED}USE_CLEANROOM must be 'true' or 'false': USE_CLEANROOM=${settings["USE_CLEANROOM"]}${RESET}"
            exit_error
        ;;
    esac
    if [[ $useCleanroom == true ]]; then
        loaderName="Cleanroom"
        loaderVer=${settings["CLEANROOM_VER"]}
    else
        loaderName="Forge"
        loaderVer=${settings["FORGE_VER"]}
    fi
    # Verify MC_VER option
    if [[ ! (${settings["MC_VER"]} =~ [0-9\.]*) ]]; then
        echo -e "${RED}MC_VER is invalid: MC_VER=${settings["MC_VER"]}${RESET}"
        exit_error
    else
        mcVer=${settings["MC_VER"]}
    fi
    # Read IGNORE_OFFLINE option
    case "${settings["IGNORE_OFFLINE"]}" in
        true) offline=${settings["IGNORE_OFFLINE"]} ;;
        false) offline=${settings["IGNORE_OFFLINE"]} ;;
        *)
            echo -e "${RED}IGNORE_OFFLINE must be 'true' or 'false': IGNORE_OFFLINE=${settings["IGNORE_OFFLINE"]}${RESET}"
            exit_error
        ;;
    esac
    echo
    echo -e "*** Loading $packName Server ***"
    echo -e "Running $loaderName $loaderVer for Minecraft $mcVer"
    echo
    
    echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
    echo "            Minecraft-Forge/Cleanroom Server install/launcher script"
    echo "   (Created by ChaosStrikez, adapted from the 'All The Mods' ServerStart script)"
    echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
    echo
    echo "This script will launch a Minecraft Modded server, runnning Forge or Cleanroom"
    echo
    echo "Source: https://github.com/jchung01/Cleanroom-ServerStart-Scripts"
    echo
    echo "This was originally made for the MeatballCraft modpack, Links here;"
    echo "  Curseforge: https://www.curseforge.com/minecraft/modpacks/meatballcraft"
    echo "  MeatballCraft Discord: https://discord.com/invite/WVvVm7aWh3"
    echo
    # Verify MAX_RAM option
    if [[ ! (${settings["MAX_RAM"]} =~ [0-9]*[mMgG])]]; then
        echo -e "${RED}MAX_RAM must follow end in M or G: MAX_RAM=${settings["MAX_RAM"]}${RESET}"
        exit_error
    fi
    # Read JAVA_PATH
    if [[ -n ${settings["JAVA_PATH"]} && ${settings["JAVA_PATH"]} != "DISABLE" ]]; then
        javaPath=${settings["JAVA_PATH"]}
        # Strip quotes just in case
        javaPath=${javaPath%\"}
        javaPath=${javaPath#\"}
    else
        javaPath=java
    fi
    # Read and set java args
    read -r -a args <<< "${settings["JAVA_ARGS"]}"
    javaArgs=("-Xmx${settings["MAX_RAM"]}" "-Xms${settings["MAX_RAM"]}")
    for arg in "${args[@]}"; do
        javaArgs+=("$arg")
    done
    # Read and set game args
    read -r -a args <<< "${settings["GAME_ARGS"]}"
    gameArgs=()
    for arg in "${args[@]}"; do
        gameArgs+=("$arg")
    done
    # Read CRASH_TIMER option
    crashTimer=${settings["CRASH_TIMER"]}
    ### Various checks ###
    check_java
    online=false
    if [[ $offline == true ]]; then
        echo -e "${YELLOW}Skipping internet connectivity check...${RESET}"
        write_to_log 'WARN: Skipping internet connectivity check...'
    else
        if check_internet; then
            online=true
        else
            online=false
        fi
    fi
    check_setup "$online"
    while true; do
        case $1 in
            -i|--install|install) exit ;;
            *) break ;;
        esac
        shift
    done
    ### Start ###
    echo -e "${YELLOW}Starting $packName Server...${RESET}"
    write_to_log 'INFO: Starting Server...'
    echo "Attempting to execute [ $javaPath ${javaArgs[*]} -jar $jarName ${gameArgs[*]} ]"
    echo
    write_to_log "DEBUG: Attempting to execute [ $javaPath ${javaArgs[*]} -jar $jarName ${gameArgs[*]} ]"
    "$javaPath" "${javaArgs[@]}" -jar "$jarName" "${gameArgs[@]}"
    # Check if we should restart the run
    echo
    echo -e "${YELLOW}$packName Server was stopped (possibly crashed)...${RESET}"
    check_eula
    printf -v dateTimeNow '%(%Y-%m-%d %H:%M:%S)T' -1 
    printf -v rawTimeNow '%(%s)T' -1
    days=("$rawTimeNow" - "$rawTime")/86400
    secs=("$rawTimeNow" - "$rawTime")/1
    stopCounter+=1
    echo "Server started at $dateTime has stopped at $dateTimeNow."
    write_to_log "ERROR: Server started at $dateTime has stopped at $dateTimeNow."
    echo "Server has $stopCounter consecutive stops, each within $crashTimer seconds of each other..."
    echo
    write_to_log "DEBUG: Server has $stopCounter consecutive stops, each within $crashTimer seconds of each other..."
    # Reset if it's been a day
    if [[ $days -gt 0 ]]; then
        echo 'More than one day since last crash/restart... resetting counter/timer'
        write_to_log 'INFO: More than one day since last crash/restart... resetting counter/timer'
        dateTime=$dateTimeNow
        rawTime=$rawTimeNow
        stopCounter=0
    # Reset if crash timer from config was exceeded
    elif [[ $secs -gt $crashTimer ]]; then
        echo "Last crash/startup was $secs+ seconds ago"
        write_to_log "INFO: Last crash/startup was $secs+ seconds ago"
        echo "More than $crashTimer seconds since last crash/restart... resetting counter/timer"
        write_to_log "INFO: More than $crashTimer seconds since last crash/restart... resetting counter/timer"
        dateTime=$dateTimeNow
        rawTime=$rawTimeNow
        stopCounter=0
    # Exit if reached max failures
    elif [[ $stopCounter -ge ${settings["CRASH_COUNT"]} ]]; then
        write_to_log "INFO: Last crash/startup was $secs+ seconds ago"
        echo
        echo
        echo -e "${RED}===================================================${RESET}"
        echo -e "${RED} Server has stopped/crashed too many times!${RESET}"
        echo -e "${RED}===================================================${RESET}"
        echo
        write_to_log 'ERROR: Server has stopped/crashed too many times!'
        echo "$stopCounter Crashes have been counted each within $crashTimer seconds."
        exit_error
    # Under threshold of crashes, go ahead and try restart
    else
        write_to_log "INFO: Last crash/startup was $secs+ seconds ago"
        dateTime=$dateTimeNow
        rawTime=$rawTimeNow
        write_to_log "Total consecutive crash/stops within time threshold: $stopCounter"
    fi
    echo
    echo
    echo
    echo 'Server will re-start *automatically* in less than 30 seconds...'
    if prompt_restart; then
        restartEntire=true
    else
        restartEntire=false
    fi
    [[ $restartEntire == true ]] || break 
done