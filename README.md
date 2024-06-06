# Cleanroom ServerStart Scripts
Server installation/start scripts for MC 1.12, using Forge or Cleanroom

These scripts will run a Forge or Cleanroom server, automatically installing the desired loader if necessary. Some code and this README is based off of the AllTheMods [ServerStart scripts](https://github.com/AllTheMods/Server-Scripts).

Originally created for use in the "MeatballCraft" modpack, but is free for anyone to use, modify or distribute under the MIT license. Borrowed code from AllTheMods falls under [their custom license](./LICENSE_AllTheMods.md).

## How to Use
**Do not modify ServerStart.bat or ServerStart.sh!** (unless you know what you are doing)  
All settings are modified in `settings.cfg` instead.  
If you would like to use Cleanroom Loader, set `USE_CLEANROOM` to `true`. You may need to specify the `JAVA_PATH` setting as well to point to your Java 22 installation.

### Arguments
| Setting   | Description                |
| ----------|----------------------------|
| -i, --install, install | (**ServerStart.sh only**) Runs only the install portion of the script. The server will not automatically start after.|

### Windows
You have two options:
1) `starter.bat` Run/double-click.
2) `ServerStart.ps1` Right-click -> **"Run with PowerShell"**.  

Either way, they do the same thing.

### Linux/Mac
You have two options:
1) `ServerStart.sh`[^1] Run from terminal[^2].
2) `ServerStart.ps1` This requires you to have [cross-platform Powershell](https://github.com/PowerShell/PowerShell?tab=readme-ov-file#get-powershell). I haven't tested this, but it should work.

[^1]: The .sh script relies on Bash. Please make sure you have Bash.  
[^2]: You may need to run `chmod +x ServerStart.sh` before executing.

## settings.cfg
Formatting is very important for it to load correctly:

- SETTING=VALUE
- No spaces around the equal sign
    - The only exception to this is `JAVA_PATH`. You can leave the right-hand side blank - equivalent to `DISABLE` - and it will use your default java.
- One setting per line

| Setting   | Description                | Default Value | 
| ----------|----------------------------| :------------:|
| **MAX_RAM**     | How much max RAM to allow the JVM to allocate to the server  | `4G` |
| **GAME_ARGS**   | Any other args to be passed to the game, not java args. Probably shouldn't add anything here, but can remove `nogui` if you really want the vanilla server panel. | `nogui` |
| **JAVA_ARGS**   | The defaults provided are meant to be as general as possible so they can work on both Java 8 and Java 22, but can be edited if desired | *See Below* |
| **USE_CLEANROOM** | Set to `true` if you want to use Cleanroom Loader. `false` is to use Forge, as usual. | `false` |
| **CRASH_COUNT** | The max number of consecutive crashes that each occur within so many seconds of each other. If max is reaches, the script will exit. This is to stop spamming restarts of a server with a critical issue. | `5` |
| **CRASH_TIMER** | The number of seconds to consider a crash within to be "consecutive" | `600` |
| **JAVA_PATH** | The path to your Java installation. This should end in `/bin/java`, **NOT `/bin/javaw`** as that will give you no console output! `DISABLE` or left blank means the script will use your default java installation, defined by your PATH or environment variables. | `DISABLE` |
| **IGNORE_OFFLINE** | The scripts may not run if a connection to the internet can not be found. If you want to force allow (i.e. to run a server for local/LAN only) then set to `true`. Note, however that it will need internet connection to at least perform initial download/install of the Forge binaries | `false` |
| **MODPACK_NAME** | Pack name to add flavor/description to script as it's running. Quotes are not needed. Can contain spaces. Technically can be very long, but will work better if short/concise (i.e. "Illumination" would be *much* better to use than "All The Mods Presents: Illumination") | `MeatballCraft, Dimensional Ascension` |
| **DEFAULT_WORLD_TYPE** | Allows for changing the type of world used.  | `BIOMESOP` |
| **MCVER** | Target Minecraft version. Usually set by pack dev before distributing and not intended to be changed by end-users. Must be complete/exact and matching the version on Forge's website (i.e. `1.12` is not the same as `1.12.2`) | `1.12.2` |
| **FORGEVER** | Target Forge version. Provided here for legacy purposes and **will not do anything**, as version 2860 will always be downloaded | `14.23.5.2860` | 
| **CLEANROOM_VER** | Target Cleanroom version. This should be set to whatever the shared prefix is in the assets for each Cleanroom release on their [Github](https://github.com/CleanroomMC/Cleanroom/releases/). | `0.2.2-alpha` |

## Optional Java Arguments
The default java arguments (using G1GC) are meant to be as general as possible to allow running on both Java 8 and Java 22. Most arguments provided are to set Java 8 defaults closer to Java 22 defaults, while some of the other ones seem to be generally good to have. Below are some alternative options that may (or may not!) help with performance. Replace the args in `JAVA_PATH` with the below ones if you want to use them.

**Please keep in mind** that java arguments are **not** what mainly determines your performance; optimization mods are! Check out the [Opticraft page](https://red-studio-ragnarok.github.io/Opticraft/) for generally good optimization mods for 1.12.2. Arguments are hard to test correctly, so don't expect much, if any, performance improvements from changing them!

Default option:
```
-server -XX:+UnlockExperimentalVMOptions -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+UseStringDeduplication -XX:+UseG1GC -XX:MaxGCPauseMillis=130 -XX:G1HeapRegionSize=8M -XX:G1NewSizePercent=28 -XX:ConcGCThreads=2 -Dfml.readTimeout=90 -Dfml.queryResult=confirm
```

### Java 8
Option 1:
``` 
-XX:+AggressiveOpts -XX:ParallelGCThreads=3 -XX:+UseConcMarkSweepGC -XX:+UnlockExperimentalVMOptions -XX:+UseParNewGC -XX:+ExplicitGCInvokesConcurrent -XX:MaxGCPauseMillis=10 -XX:GCPauseIntervalMillis=50 -XX:+UseFastAccessorMethods -XX:+OptimizeStringConcat -XX:NewSize=84m -XX:+UseAdaptiveGCBoundary -XX:NewRatio=3 -Dfml.readTimeout=90 -Dfml.queryResult=confirm 
```
This is what's provided by the AllTheMods server scripts. It uses the ParNew/CMS garbage collectors, which are the default ones used by MC in Java 8.  

Option 2:
```
-XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions -XX:+AlwaysActAsServerClassMachine -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:NmethodSweepActivity=1 -XX:ReservedCodeCacheSize=400M -XX:NonNMethodCodeHeapSize=12M -XX:ProfiledCodeHeapSize=194M -XX:NonProfiledCodeHeapSize=194M -XX:-DontCompileHugeMethods -XX:MaxNodeLimit=240000 -XX:NodeLimitFudgeFactor=8000 -XX:+UseVectorCmov -XX:+PerfDisableSharedMem -XX:+UseFastUnorderedTimeStamps -XX:+UseCriticalJavaThreadPriority -XX:ThreadPriorityPolicy=1 -XX:AllocatePrefetchStyle=3 -XX:+UseG1GC -XX:MaxGCPauseMillis=130 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=28 -XX:G1HeapRegionSize=16M -XX:G1ReservePercent=20 -XX:G1MixedGCCountTarget=3 -XX:InitiatingHeapOccupancyPercent=10 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=0 -XX:SurvivorRatio=32 -XX:MaxTenuringThreshold=1 -XX:G1SATBBufferEnqueueingThresholdPercent=30 -XX:G1ConcMarkStepDurationMillis=5 -XX:G1ConcRefinementServiceIntervalMillis=150 -XX:G1ConcRSHotCardLimit=16 -Dfml.readTimeout=90 -Dfml.queryResult=confirm
```
This is a list made from this [repo](https://github.com/Mukul1127/Minecraft-Performance-Flags-Benchmarks/tree/main). It uses G1GC, like the default set of args, with [Aikar's well-known server arguments](https://aikar.co/2018/07/02/tuning-the-jvm-g1gc-garbage-collector-flags-for-minecraft/) but it has more fine-tuning args that **are untested**, so take these with a grain of salt.

### Java 22
Option 1:
```
-XX:+UnlockExperimentalVMOptions -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+UseStringDeduplication -XX:+UseZGC -XX:+ZGenerational -Dfml.readTimeout=90 -Dfml.queryResult=confirm
```
Uses the new (generational) ZGC garbage collector. This may give you better performance, but you may need to allocate more RAM to see such an improvement. I would suggest trying this one out for yourself with varying RAM to see how it compares to the default args.

Option 2:
```
-XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions -XX:+AlwaysActAsServerClassMachine -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:NmethodSweepActivity=1 -XX:ReservedCodeCacheSize=400M -XX:NonNMethodCodeHeapSize=12M -XX:ProfiledCodeHeapSize=194M -XX:NonProfiledCodeHeapSize=194M -XX:-DontCompileHugeMethods -XX:MaxNodeLimit=240000 -XX:NodeLimitFudgeFactor=8000 -XX:+UseVectorCmov -XX:+PerfDisableSharedMem -XX:+UseFastUnorderedTimeStamps -XX:+UseCriticalJavaThreadPriority -XX:ThreadPriorityPolicy=1 -XX:AllocatePrefetchStyle=3 -XX:+UseG1GC -XX:MaxGCPauseMillis=130 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=28 -XX:G1HeapRegionSize=16M -XX:G1ReservePercent=20 -XX:G1MixedGCCountTarget=3 -XX:InitiatingHeapOccupancyPercent=10 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=0 -XX:SurvivorRatio=32 -XX:MaxTenuringThreshold=1 -XX:G1SATBBufferEnqueueingThresholdPercent=30 -XX:G1ConcMarkStepDurationMillis=5 -Dfml.readTimeout=90 -Dfml.queryResult=confirm
```
Same as Java 8's option 2 besides a few unsupported flags, so same warnings apply.