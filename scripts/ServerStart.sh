#!/usr/bin/env bash

# Created by ChaosStrikez, adapting some code from https://github.com/AllTheMods/Server-Scripts.
# Make sure this is running as BASH.
# You might need to chmod +x before executing.
#
# *** THIS FILE IS NOT INTENDED TO BE EDITED, USE "settingsNew.cfg" INSTEAD ***
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
SCRIPT_ROOT="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/"
RED="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
RESET="$(tput sgr0)"

declare -A settings=
useCleanroom=
LOADER_NAME=
LOADER_VER=
MC_VER=
JAVA_ARGS=
JAVA_PATH=
JAR_NAME=
PACK_NAME=
CRASH_TIMER=
OFFLINE=

function exit_error {
    read -srp "The above error occurred. Press any key to exit" -n 1 
    exit 1
}

function write_to_log {
    # $1 = Message
    # $2 = (Optional) CreateFile
    # Create file
    if [[ $2 == true ]]; then
        if [[ ! -d "${SCRIPT_ROOT}logs/" ]]; then
            mkdir "${SCRIPT_ROOT}logs/"
        fi
        printf '%s\n' "$1" > "${SCRIPT_ROOT}logs/serverstart.log"
    else
        printf '%s\n' "$1" >> "${SCRIPT_ROOT}logs/serverstart.log"
    fi
}

function check_java {
    echo -e "${YELLOW}Checking java installation...${RESET}"
    local version
    version=$("$JAVA_PATH" -version 2>&1 | awk -F '"' '/version/ {print $2}')
    local errored=false
    "$JAVA_PATH" -version
    write_to_log "DEBUG: JAVA version output: $("$JAVA_PATH" -version 2>&1)"
    if [[ $useCleanroom == true && ! ($version =~ ^"22".*) ]]; then
        echo -e "${RED}ERROR: Invalid java version found. Check your environment variables or set JAVA_PATH in settings.cfg.${RESET}"
        echo -e "${RED}Using Cleanroom, which requires Java 22, but found $version.\nIf you want to use Cleanroom with your current Java, set 'USE_CLEANROOM = true' in settings.cfg.${RESET}"
        errored=true
    elif [[ $useCleanroom == false && ! ($version =~ ^"1.8".*) ]]; then
        echo -e "${RED}ERROR: Invalid java version found. Check your environment variables or set JAVA_PATH in settings.cfg.${RESET}"
        echo -e "${RED}Using Forge, which requires Java 8, but found $version.\nIf you want to use Forge with your current Java, set 'USE_CLEANROOM = false' in settings.cfg.${RESET}"
        errored=true
    fi

    local bitness
    bitness=$("$JAVA_PATH" -XshowSettings:properties -version 2>&1 | grep "sun.arch.data.model" | awk -F '=' '{printf $2+0}')
    if [[ $bitness -eq 64 ]]; then
        write_to_log "INFO: Found 64-bit Java $version"
    else
        write_to_log "INFO: Found 32-bit Java $version"
        echo -e "${RED}ERROR: 32-bit java version found. Please install 64-bit java.${RESET}"
        errored=true
    fi
    if [[ $errored == true ]]; then
        exit_error
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

function reinstall_loader {
    # $1 = Vanilla
    # $2 = Libs
    # $3 = Forge
    # $4 = Cleanroom
    # $5 = IsOnline

    # Clean files: vanilla jar, loader jar, libraries folder
    echo -e "${YELLOW}Clearing old files before installing $LOADER_NAME/minecraft...${RESET}"
    write_to_log "INFO: Clearing and installing ${LOADER_NAME}/minecraft..."
    local param
    for param in "${@:1:${#@}-1}"; do
        if [[ -n "$param" ]]; then
            if [[ $param == "${SCRIPT_ROOT}libraries" ]]; then
                rm -r "$param"
            else
                rm "$param"
            fi
        fi
    done
    if [[ -f "${SCRIPT_ROOT}installer-$LOADER_NAME-$LOADER_VER.jar" ]]; then
        echo "Existing $LOADER_NAME installer already found..."
	    echo 'Default is to use this installer and not re-download'
    # Download installer
    else
        if [[ $OFFLINE == true && ($5 == false) ]]; then
            echo -e "${RED}IGNORE_OFFLINE is set to true, please set it to false and ensure you have an internet connection to download the installer.${RESET}"
            write_to_log 'ERROR: IGNORE_OFFLINE is set to true, please set it to false and ensure you have an internet connection to download the installer.'
            exit_error
        fi
        local source
        if [[ $useCleanroom == true ]]; then
            # If the format changes this URL might need to be changed
            source="https://github.com/CleanroomMC/Cleanroom/releases/download/$LOADER_VER/cleanroom-$LOADER_VER-installer.jar"
        else
            # Hard coded, Forge shouldn't change
            source='https://maven.minecraftforge.net/net/minecraftforge/forge/1.12.2-14.23.5.2860/forge-1.12.2-14.23.5.2860-installer.jar'
        fi
        # Check for commands, then do the download
        if (command -v curl >> /dev/null 2>&1); then
            write_to_log "DEBUG: (curl) Downloading $source"
            curl -JL "$source" -o "${SCRIPT_ROOT}installer-$LOADER_NAME-$LOADER_VER.jar" >> "${SCRIPT_ROOT}logs/serverstart.log" 2>&1
        elif (command -v wget >> /dev/null 2>&1); then
            write_to_log "DEBUG: (wget) Downloading ${source}"
            wget "$source" -o "${SCRIPT_ROOT}installer-$LOADER_NAME-$LOADER_VER.jar" >> "${SCRIPT_ROOT}logs/serverstart.log" 2>&1
        else
            echo -e "${RED}Neither wget or curl were found on your system. Please install one and try again${RESET}"
            write_to_log 'ERROR: Neither wget or curl were found'
            exit_error
        fi
    fi
    # Setup default files
    if [[ ! -f "${SCRIPT_ROOT}server.properties" ]]; then
        echo 'Could not find server.properties, creating initial copy...'
        write_to_log 'INFO: server.properties not found... populating default'
        {
            echo "view-distance=8",
            echo "allow-flight=true",
            echo "enable-command-block=false",
            echo "level-type=${settings["DEFAULT_WORLD_TYPE"]}",
            echo "snooper-enabled=false",
            echo "max-tick-time=90000",
            echo "motd=$PACK_NAME"
        } > "${SCRIPT_ROOT}server.properties"
    fi
    if [[ ! -f "${SCRIPT_ROOT}eula.txt" ]]; then
        echo 'Could not find eula.txt, creating initial copy...'
        write_to_log 'INFO: eula.txt not found... populating default'
        echo "eula=false" > "${SCRIPT_ROOT}eula.txt"
    fi
    echo "Installing $LOADER_NAME now, please wait..."
    write_to_log "INFO: Starting $LOADER_NAME install now, details below:"
    local installerName="installer-$LOADER_NAME-$LOADER_VER.jar"
    write_to_log "--------------------------"
    "$JAVA_PATH" -jar "$installerName" --installServer >> "${SCRIPT_ROOT}logs/serverstart.log" 2>&1
    write_to_log "--------------------------"
    rm "$installerName"
    # Name apparently has no prefix?
    rm "installer.log"
}

function check_setup {
    # $1 = IsOnline
    local vanilla
    local libs
    local forge
    local cleanroom
    local reinstall=false
    local jarName
    # Check a loader is installed
    if [[ ! -f "${SCRIPT_ROOT}minecraft_server.$MC_VER.jar" ]]; then
        echo -e "${YELLOW}Minecraft binary not found, installing $LOADER_NAME...${RESET}"
        write_to_log "INFO: Minecraft binary not found, installing $LOADER_NAME..."
        reinstall=true
    else
        vanilla="${SCRIPT_ROOT}minecraft_server.$MC_VER.jar"
    fi
    # Check libraries for proper loader install
    if [[ ! -d "${SCRIPT_ROOT}libraries" ]]; then
        echo -e "${YELLOW}Libraries folder not found, installing $LOADER_NAME...${RESET}"
        write_to_log "INFO: Libraries folder not found, installing $LOADER_NAME..."
        reinstall=true
    else
        libs="${SCRIPT_ROOT}libraries"
        if [[ -f "${SCRIPT_ROOT}forge-$MC_VER-$LOADER_VER.jar" ]]; then
            forge="${SCRIPT_ROOT}forge-$MC_VER-$LOADER_VER.jar"
        fi
        if [[ -f "${SCRIPT_ROOT}cleanroom-$LOADER_VER.jar" ]]; then
            cleanroom="${SCRIPT_ROOT}cleanroom-$LOADER_VER.jar"
        else
            # Remove any old Cleanroom
            rm cleanroom-*.jar 2> /dev/null
        fi
        # Check for existing Cleanroom
        if [[ $useCleanroom == true && (-z $cleanroom) ]]; then
            # Remove Forge if it exists as we want Cleanroom
            rm "${SCRIPT_ROOT}forge-$MC_VER-${settings["FORGE_VER"]}.jar" 2> /dev/null
            reinstall=true
        # Check for existing Forge
        elif [[ $useCleanroom == false && (-z $forge) ]]; then
            # Remove Cleanroom if it exists as we want Forge
            rm "${SCRIPT_ROOT}cleanroom-${settings["CLEANROOM_VER"]}.jar" 2> /dev/null
            reinstall=true
        fi
    fi
    # Set jarName even if jars not found
    if [[ $useCleanroom == true ]]; then
        jarName="${SCRIPT_ROOT}cleanroom-${settings["CLEANROOM_VER"]}.jar"
    else
        jarName="${SCRIPT_ROOT}forge-$MC_VER-${settings["FORGE_VER"]}.jar"
    fi
    if [[ $reinstall == true ]]; then
        reinstall_loader "$vanilla" "$libs" "$forge" "$cleanroom" "$1"
        echo "---------------------------------------------------"
        echo "$PACK_NAME Server Files are now ready!"
        echo "---------------------------------------------------"
    fi
    JAR_NAME=$jarName
}

function check_eula {
    # Check for EULA agreement
    if ! grep -q "eula=true" eula.txt 2> /dev/null; then
        echo
        echo -e "${RED}Could not find 'eula=true' in eula.txt file${RESET}"
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
declare -i days=
declare -i secs=
restartEntire=false
printf -v dateTime '%(%Y-%m-%d %H:%M:%S)T' -1 
printf -v rawTime '%(%s)T' -1
while true; do
    clear
    ### Initial setup ###
    write_to_log '--------------------------' true
    write_to_log 'Starting ServerStart.ps1'
    write_to_log $'--------------------------\n'
    
    # Read settings.cfg
    if [[ ! -f "${SCRIPT_ROOT}settingsnew.cfg" ]]; then
        cat "${SCRIPT_ROOT}settingsNew.cfg"
        exit_error
    fi
    write_to_log $'DEBUG: settings.cfg Found. Logging full contents below:\n--------------------------'
    cat "${SCRIPT_ROOT}settingsNew.cfg" >> "${SCRIPT_ROOT}logs/serverstart.log"
    write_to_log '--------------------------'
    #Read the config file line by line
    while IFS=$'\n\r' read -r line || [[ -n "$line" ]]; do
        #Fliters out comments and empty lines
        if [[ ${line:0:1} != '#' ]] && [[ $line = *[!\ ]* ]]; then
            key="${line%%=*}"
            value="${line#*=}"
            # Trim leading/trailing whitespace
            shopt -s extglob
            value=${value%%*([[:blank:]])}
            value=${value##*([[:blank:]])}
            shopt -u extglob
            settings["$key"]="$value"
        fi
    done < "${SCRIPT_ROOT}settingsNew.cfg"
    # Read MODPACK_NAME option
    PACK_NAME="${settings["MODPACK_NAME"]}"
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
        LOADER_NAME="Cleanroom"
        LOADER_VER=${settings["CLEANROOM_VER"]}
    else
        LOADER_NAME="Forge"
        LOADER_VER=${settings["FORGE_VER"]}
    fi
    # Verify MC_VER option
    if [[ ! (${settings["MC_VER"]} =~ [0-9\.]*) ]]; then
        echo -e "${RED}MC_VER is invalid: MC_VER=${settings["MC_VER"]}${RESET}"
        exit_error
    else
        MC_VER=${settings["MC_VER"]}
    fi
    # Read IGNORE_OFFLINE option
    case "${settings["IGNORE_OFFLINE"]}" in
        true) OFFLINE=${settings["IGNORE_OFFLINE"]} ;;
        false) OFFLINE=${settings["IGNORE_OFFLINE"]} ;;
        *)
            echo -e "${RED}IGNORE_OFFLINE must be 'true' or 'false': IGNORE_OFFLINE=${settings["IGNORE_OFFLINE"]}${RESET}"
            exit_error
        ;;
    esac
    echo
    echo -e "*** Loading $PACK_NAME Server ***"
    echo -e "Running $LOADER_NAME $LOADER_VER for Minecraft $MC_VER"
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
        echo -e "{$RED}MAX_RAM must follow end in M or G: MAX_RAM=${settings["MAX_RAM"]}${RESET}"
        exit_error
    fi
    # Read JAVA_PATH
    if [[ -n ${settings["JAVA_PATH"]} && ${settings["JAVA_PATH"]} != "DISABLE" ]]; then
        JAVA_PATH=${settings["JAVA_PATH"]}
        # Strip quotes just in case
        JAVA_PATH=${JAVA_PATH%\"}
        JAVA_PATH=${JAVA_PATH#\"}
    else
        JAVA_PATH=java
    fi
    # Read and set java args
    JAVA_ARGS="-Xmx${settings["MAX_RAM"]} -Xms${settings["MAX_RAM"]} ${settings["JAVA_ARGS"]}"
    # Read CRASH_TIMER option
    CRASH_TIMER=${settings["CRASH_TIMER"]}
    # ### Various checks ###
    check_java
    online=false
    if [[ $OFFLINE == true ]]; then
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
    ### Start ###
    echo -e "${YELLOW}Starting $PACK_NAME Server...${RESET}"
    write_to_log 'INFO: Starting Server...'
    echo "Attempting to execute [ $JAVA_PATH $JAVA_ARGS -jar $JAR_NAME ${settings["GAME_ARGS"]} ]"
    echo
    write_to_log "DEBUG: Attempting to execute [ $JAVA_PATH $JAVA_ARGS -jar $JAR_NAME ${settings["GAME_ARGS"]} ]"
    # shellcheck disable=SC2086
    "$JAVA_PATH" $JAVA_ARGS -jar "$JAR_NAME" ${settings["GAME_ARGS"]}
    # Check if we should restart the run
    echo
    echo -e "${YELLOW}$PACK_NAME Server was stopped (possibly crashed)...${RESET}"
    # check_eula
    printf -v dateTimeNow '%(%Y-%m-%d %H:%M:%S)T' -1 
    printf -v rawTimeNow '%(%s)T' -1
    days=("$rawTimeNow" - "$rawTime")/86400
    secs=("$rawTimeNow" - "$rawTime")/1
    stopCounter+=1
    echo "Server started at $dateTime has stopped at $dateTimeNow."
    write_to_log "ERROR: Server started at $dateTime has stopped at $dateTimeNow."
    echo "Server has $stopCounter consecutive stops, each within $CRASH_TIMER seconds of each other..."
    echo
    write_to_log "DEBUG: Server has $stopCounter consecutive stops, each within $CRASH_TIMER seconds of each other..."
    # Reset if it's been a day
    if [[ $days -gt 0 ]]; then
        echo 'More than one day since last crash/restart... resetting counter/timer'
        write_to_log 'INFO: More than one day since last crash/restart... resetting counter/timer'
        dateTime=$dateTimeNow
        rawTime=$rawTimeNow
        stopCounter=0
    # Reset if crash timer from config was exceeded
    elif [[ $secs -gt $CRASH_TIMER ]]; then
        echo "Last crash/startup was $secs+ seconds ago"
        write_to_log "INFO: Last crash/startup was $secs+ seconds ago"
        echo "More than $CRASH_TIMER seconds since last crash/restart... resetting counter/timer"
        write_to_log "INFO: More than $CRASH_TIMER seconds since last crash/restart... resetting counter/timer"
        dateTime=$dateTimeNow
        rawTime=$rawTimeNow
        stopCounter=0
    # Reset if reached max failures
    elif [[ $stopCounter -ge ${settings["CRASH_COUNT"]} ]]; then
        write_to_log "INFO: Last crash/startup was $secs+ seconds ago"
        echo
        echo
        echo -e "${RED}===================================================${RESET}"
        echo -e "${RED} Server has stopped/crashed too many times!${RESET}"
        echo -e "${RED}===================================================${RESET}"
        echo
        write_to_log 'ERROR: Server has stopped/crashed too many times!'
        echo "$stopCounter Crashes have been counted each within $CRASH_TIMER seconds."
        exit_error
    # Under threshold of crashes, go ahead and try restart
    else
        write_to_log "INFO: Last crash/startup was $secs+ seconds ago"
        dateTime=$dateTimeNow
        rawTime=$rawTimeNow
        write_to_log "Total consecutive crash/stops within time threshold: $stopCounter"
        echo
        echo
        echo
        echo 'Server will re-start *automatically* in less than 30 seconds...'
        if prompt_restart; then
            restartEntire=true
        else
            restartEntire=false
        fi
    fi
    [[ $restartEntire == true ]] || break 
done