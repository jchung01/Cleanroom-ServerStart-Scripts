# Cleanroom ServerStart Scripts
Server installation/start scripts for MC 1.12.2, using Forge or Cleanroom

These scripts will run a Forge or Cleanroom server, automatically installing the desired loader if necessary. Some code and this README is based off of the AllTheMods [ServerStart scripts](https://github.com/AllTheMods/Server-Scripts).

Originally created for use in the [MeatballCraft](https://www.curseforge.com/minecraft/modpacks/meatballcraft) modpack, but is free for anyone to use, modify or distribute under the MIT license. Borrowed code from AllTheMods falls under [their custom license](./LICENSE_AllTheMods.md).

Make sure you're using 64-bit Java and the right version for the right modloader! Java 8 for Forge, Java 21+ for Cleanroom.

## How to Use
Copy-paste/drop the contents of `/scripts` into your main server folder.

**Do not modify starter.bat, ServerStart.ps1, or ServerStart.sh!** (unless you know what you are doing)  
All settings are modified in `settings.cfg` instead.  
**If you would like to use Cleanroom Loader, set `USE_CLEANROOM` to `true`.** You may need to specify the `JAVA_PATH` setting as well to point to your Java 21+ installation.

As always, make sure you have the latest/matching Fugue and Scalar versions when using Cleanroom!  
<details>
<summary>Legacy note (Cleanroom 0.2.2-alpha or below)</summary>
You may need to disable/remove MixinBooter and ConfigAnytime as Cleanroom already bundles these mods and you will get a duplicate mod error. Newer versions of Cleanroom properly ignore these mods.
</details>

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
1) `ServerStart.sh`[^1] Run from terminal.[^2]
2) `ServerStart.ps1` This requires you to have [cross-platform Powershell](https://github.com/PowerShell/PowerShell?tab=readme-ov-file#get-powershell) installed. I haven't tested this, but it should work.

[^1]: The .sh script relies on Bash 4.2 or greater. Please make sure you have Bash 4.2+ installed.
[^2]: You may need to run `chmod +x ServerStart.sh` before executing.

## settings.cfg
Formatting is very important for it to load correctly:

- SETTING=VALUE
- No spaces around the equal sign
    - The only exception to this is `JAVA_PATH`. You can leave the right-hand side blank - equivalent to `DISABLE` - and it will use your default java.
- One setting per line

| Setting   | Description                | Default Value | 
| ----------|----------------------------| :------------:|
| **MAX_RAM**     | How much max RAM to allow the JVM to allocate to the server  | `6G` |
| **GAME_ARGS**   | Any other args to be passed to the game, not java args. Probably shouldn't add anything here, but can remove `nogui` if you really want the vanilla server panel. | `nogui` |
| **JAVA_ARGS**   | The defaults provided are meant to be as general as possible so they can work on both Java 8 and Java 21+, but can be edited if desired | *See Below* |
| **USE_CLEANROOM** | Set to `true` if you want to use Cleanroom Loader. `false` is to use Forge, as usual. | `false` |
| **CRASH_COUNT** | The max number of consecutive crashes that each occur within so many seconds of each other. If max is reaches, the script will exit. This is to stop spamming restarts of a server with a critical issue. | `5` |
| **CRASH_TIMER** | The number of seconds to consider a crash within to be "consecutive" | `600` |
| **JAVA_PATH** | The path to your Java installation. This should end in `/bin/java`, **NOT `/bin/javaw`** as that will give you no console output! `DISABLE` or left blank means the script will use your default java installation, defined by your PATH or environment variables. | `DISABLE` |
| **IGNORE_OFFLINE** | The scripts may not run if a connection to the internet can not be found. If you want to force allow (i.e. to run a server for local/LAN only) then set to `true`. Note, however that it will need internet connection to at least perform initial download/install of the Forge binaries | `false` |
| **MODPACK_NAME** | Pack name to add flavor/description to script as it's running. Quotes are not needed. Can contain spaces. Technically can be very long, but will work better if short/concise (i.e. "Illumination" would be *much* better to use than "All The Mods Presents: Illumination") | `MeatballCraft, Dimensional Ascension` |
| **DEFAULT_WORLD_TYPE** | Allows for changing the type of world used.  | `BIOMESOP` |
| **MCVER** | Target Minecraft version. Usually set by pack dev before distributing and not intended to be changed by end-users. Must be complete/exact and matching the version on Forge's website (i.e. `1.12` is not the same as `1.12.2`) | `1.12.2` |
| **FORGEVER** | Target Forge version. | `14.23.5.2860` | 
| **CLEANROOM_VER** | Target Cleanroom version. This should be a version specified from [Cleanroom's Maven](https://repo.cleanroommc.com/#/releases/com/cleanroommc/cleanroom). | `0.5.9-alpha` |

## Optional Java Arguments
The default java arguments (using G1GC) are meant to be as general as possible to allow running on both Java 8 and Java 21+. Most arguments provided are to set Java 8 defaults closer to Java 21+ defaults, while some of the other ones seem to be generally good to have. Below are some alternative options that may (or may not!) help with performance. Replace the args in `JAVA_ARGS` with the below ones if you want to use them.

**Please keep in mind** that java arguments are **not** what mainly determines your performance (especially for Java 8); optimization mods are! Check Cleanroom's ["Preparing Your Modpack"](https://cleanroommc.com/wiki/end-user-guide/preparing-your-modpack) page and considering using the mod [PackCompanion](https://www.curseforge.com/minecraft/mc-mods/packcompanion) for guidance on optimzation mods. Arguments are hard to test correctly, so don't expect much, if any, performance improvements from changing them!

Default option:
```
-server -XX:+UnlockExperimentalVMOptions -XX:+AlwaysPreTouch -XX:+UseStringDeduplication -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:G1HeapRegionSize=8M -XX:G1NewSizePercent=28 -Dfml.readTimeout=90 -Dfml.queryResult=confirm
```

### Java 8
```
-server -XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions -XX:+AlwaysActAsServerClassMachine -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:+AggressiveOpts -XX:+UseFastAccessorMethods -XX:MaxInlineLevel=15 -XX:MaxVectorSize=32 -XX:+UseCompressedOops -XX:ThreadPriorityPolicy=1 -XX:+UseDynamicNumberOfGCThreads -XX:NmethodSweepActivity=1 -XX:ReservedCodeCacheSize=350M -XX:-DontCompileHugeMethods -XX:MaxNodeLimit=240000 -XX:NodeLimitFudgeFactor=8000 -XX:+UseFPUForSpilling -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=28 -XX:G1HeapRegionSize=16M -XX:G1ReservePercent=20 -XX:G1MixedGCCountTarget=3 -XX:InitiatingHeapOccupancyPercent=10 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=0 -XX:SurvivorRatio=32 -XX:MaxTenuringThreshold=1 -XX:G1SATBBufferEnqueueingThresholdPercent=30 -XX:G1ConcRefinementServiceIntervalMillis=150 -XX:G1ConcRSHotCardLimit=16 -Dfml.readTimeout=90 -Dfml.queryResult=confirm
```
This is a list made from this [repo](https://github.com/brucethemoose/Minecraft-Performance-Flags-Benchmarks/tree/main#java-8). It uses G1GC, like the default set of args, with a modified set of [Aikar's flags](https://docs.papermc.io/paper/aikars-flags/) and has more fine-tuning args that **are untested**, so take these with a grain of salt.

**Instead of using Java 8/Forge, I would recommend using Cleanroom to benefit from modern Java versions (21/25+).**

### Java 21~23
```
-XX:+UnlockExperimentalVMOptions -XX:+AlwaysPreTouch -XX:+UseStringDeduplication -XX:+UseZGC -XX:+ZGenerational -Dfml.readTimeout=90 -Dfml.queryResult=confirm
```
Uses the (generational) ZGC garbage collector. This is generally better if you have more CPU cores and RAM to spare. If you are especially constrained by either, G1GC/the default args may be better.

### Java 25 or higher
This section has arguments similar to Java 21, but enables a new feature officially shipped in Java 25, [Compact Object Headers](https://openjdk.org/jeps/450), which should noticeably reduce memory usage.

Option 1:
```
-XX:+UseCompactObjectHeaders -XX:+AlwaysPreTouch -XX:+UseStringDeduplication -XX:+UseZGC -Dfml.readTimeout=90 -Dfml.queryResult=confirm
```
Uses ZGC garbage collector (generational is now default). Same note as Java 21 about ZGC applies.

Option 2:
```
-XX:+UnlockExperimentalVMOptions -XX:+UseCompactObjectHeaders -XX:+AlwaysPreTouch -XX:+UseStringDeduplication -XX:G1HeapRegionSize=8M -XX:G1NewSizePercent=28 -Dfml.readTimeout=90 -Dfml.queryResult=confirm
```
Uses the default G1GC garbage collector.

### More resources:
Cleanroom Java Arguments: https://cleanroommc.com/wiki/end-user-guide/args  
Article on JVM Arguments: https://exa.y2k.diy/garden/jvm-args/  
Another article on modern Java Arguments (ZGC focused): https://github.com/Obydux/Minecraft-startup-flags