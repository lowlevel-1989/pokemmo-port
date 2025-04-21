#!/bin/bash
# PORTMASTER: pokemmo.zip, PokeMMO.sh
# PORTMASTER: PokeMMO

java_runtime="zulu17.54.21-ca-jre17.0.13-linux"
weston_runtime="weston_pkg_0.2"
mesa_runtime="mesa_pkg_0.1"

# PortMaster preamble
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

# Define $directory
source $controlfolder/control.txt
source $controlfolder/device_info.txt
source $controlfolder/funcs.txt

export LD_LIBRARY_PATH="$controlfolder:$GAMEDIR/libs:$LD_LIBRARY_PATH"

GAMEDIR=/$directory/ports/PokeMMO
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

cd $GAMEDIR

# Check if we need to use westonpack. If we have mainline OpenGL, we don't need to use it.
if glxinfo | grep -q "OpenGL version string"; then
    westonpack=0
else
    westonpack=1
fi

if [ "$westonpack" -eq 1 ]; then

# Mount Weston runtime
weston_dir=/tmp/weston
$ESUDO mkdir -p "${weston_dir}"
if [ ! -f "$controlfolder/libs/${weston_runtime}.squashfs" ]; then
  if [ ! -f "$controlfolder/harbourmaster" ]; then
    pm_message "This port requires the latest PortMaster to run, please go to https://portmaster.games/ for more info."
    sleep 5
    exit 1
  fi
  $ESUDO $controlfolder/harbourmaster --quiet --no-check runtime_check "${weston_runtime}.squashfs"
fi
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
    $ESUDO umount "${weston_dir}"
fi
$ESUDO mount -o loop "$controlfolder/libs/${weston_runtime}.squashfs" "${weston_dir}"

# Mount Mesa runtime
mesa_dir=/tmp/mesa
$ESUDO mkdir -p "${mesa_dir}"
if [ ! -f "$controlfolder/libs/${mesa_runtime}.squashfs" ]; then
  if [ ! -f "$controlfolder/harbourmaster" ]; then
    pm_message "This port requires the latest PortMaster to run, please go to https://portmaster.games/ for more info."
    sleep 5
    exit 1
  fi
  $ESUDO $controlfolder/harbourmaster --quiet --no-check runtime_check "${mesa_runtime}.squashfs"
fi
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
    $ESUDO umount "${mesa_dir}"
fi
$ESUDO mount -o loop "$controlfolder/libs/${mesa_runtime}.squashfs" "${mesa_dir}"

fi

# Mount Java runtime
export JAVA_HOME="/tmp/javaruntime/"
$ESUDO mkdir -p "${JAVA_HOME}"
if [ ! -f "$controlfolder/libs/${java_runtime}.squashfs" ]; then
  if [ ! -f "$controlfolder/harbourmaster" ]; then
    pm_message "This port requires the latest PortMaster to run, please go to https://portmaster.games/ for more info."
    sleep 5
    exit 1
  fi
  $ESUDO $controlfolder/harbourmaster --quiet --no-check runtime_check "${java_runtime}.squashfs"
fi
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
    $ESUDO umount "${JAVA_HOME}"
fi
$ESUDO mount -o loop "$controlfolder/libs/${java_runtime}.squashfs" "${JAVA_HOME}"
export PATH="$JAVA_HOME/bin:$PATH"

if [[ -n "$ESUDO" ]]; then
    ESUDO="$ESUDO LD_LIBRARY_PATH=$controlfolder"
fi

GPTOKEYB="$ESUDO $controlfolder/gptokeyb2"

$GPTOKEYB "java" -c "./controls.ini" &

if [ "$westonpack" -eq 1 ]; then 
$ESUDO env CRUSTY_SHOW_CURSOR=1 $weston_dir/westonwrap.sh drm gl kiosk virgl \
PATH="$PATH" JAVA_HOME="$JAVA_HOME" XDG_SESSION_TYPE="x11" XDG_DATA_HOME="$GAMEDIR" WAYLAND_DISPLAY= \
java -Xms128M -Xmx384M -Dorg.lwjgl.util.Debug=true -Dfile.encoding="UTF-8" -cp "libs/*:PokeMMO.exe" com.pokeemu.client.Client

#Clean up after ourselves
$ESUDO $weston_dir/westonwrap.sh cleanup
else
PATH="$PATH" CRUSTY_SHOW_CURSOR=1 JAVA_HOME="$JAVA_HOME" XDG_SESSION_TYPE="x11" java -Xms128M -Xmx384M -Dorg.lwjgl.util.Debug=true -Dfile.encoding="UTF-8" -cp "libs/*:PokeMMO.exe" com.pokeemu.client.Client

fi

if [[ "$PM_CAN_MOUNT" != "N" ]]; then
    if [ "$westonpack" -eq 1 ]; then
    $ESUDO umount "${weston_dir}"
    $ESUDO umount "${mesa_dir}"
    fi
    $ESUDO umount "${JAVA_HOME}"
fi

# Cleanup any running gptokeyb instances, and any platform specific stuff.
pm_finish
