#!/bin/bash

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

source $controlfolder/control.txt

# We source custom mod files from the portmaster folder example mod_jelos.txt which containts pipewire fixes
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"

get_controls

java_runtime="zulu17.48.15-ca-jdk17.0.10-linux"
weston_runtime="weston_pkg_0.2"
mesa_runtime="mesa_pkg_0.1"
python_runtime="python_3.11"

# If /etc/machine-id doesn't exist and /tmp/dbus/machine-id exists, copy it over
if [ ! -f /etc/machine-id ]; then
  if [ -f /tmp/dbus/machine-id ]; then
    $ESUDO cp /tmp/dbus/machine-id /etc/machine-id
  fi
fi

if [[ -z "$GPTOKEYB2" ]]; then
  pm_message "This port requires the latest PortMaster to run, please go to https://portmaster.games/ for more info."
  sleep 5
  exit 1
fi

GAMEDIR=/$directory/ports/pokemmo
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

cd $GAMEDIR

echo RELEASE
cat $GAMEDIR/RELEASE

echo Dump CFW info
$controlfolder/device_info.txt 2> /dev/null

echo ls -l ${GAMEDIR}
ls -l ${GAMEDIR}

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
echo ls -l ${weston_dir}
ls -l ${weston_dir}

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
echo ls -l ${mesa_dir}
ls -l ${mesa_dir}

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

echo ls -l ${JAVA_HOME}
ls -l ${JAVA_HOME}


if ! command -v python >/dev/null 2>&1 || (( $(python -c 'import sys; print(sys.version_info[0])') <= 2 )); then
  echo MOUNT PYTHON
  # Mount Python runtime
  export PYTHONHOME="/tmp/python"
  $ESUDO mkdir -p "${PYTHONHOME}"
  if [ ! -f "$controlfolder/libs/${python_runtime}.squashfs" ]; then
    if [ ! -f "$controlfolder/harbourmaster" ]; then
      pm_message "This port requires the latest PortMaster to run, please go to https://portmaster.games/ for more info."
      sleep 5
      exit 1
    fi
    $ESUDO $controlfolder/harbourmaster --quiet --no-check runtime_check "${python_runtime}.squashfs"
  fi
  if [[ "$PM_CAN_MOUNT" != "N" ]]; then
      $ESUDO umount "${PYTHONHOME}"
  fi
  $ESUDO mount -o loop "$controlfolder/libs/${python_runtime}.squashfs" "${PYTHONHOME}"
  export PATH="${PYTHONHOME}/bin:$PATH"

  which python
  echo ls -l ${PYTHONHOME}
  ls -l ${PYTHONHOME}
fi

# Resolve the Python interpreter once, up front.
if command -v python &>/dev/null; then
  PYTHON_CMD=python
elif command -v python3 &>/dev/null; then
  PYTHON_CMD=python3
else
  echo "Error: Neither 'python' nor 'python3' command found." >&2
  exit 1
fi

# BusyBox's `unzip` (ROCKNIX and some other CFWs) fails with
# "unzip: short read" on entries inside patch.zip / PokeMMO.exe, which
# silently truncates extraction and breaks everything downstream.
# Use Python's zipfile module instead, which isn't affected by that
# BusyBox limitation.
pm_unzip() {
  "$PYTHON_CMD" "$GAMEDIR/pmzipextract.py" "$@"
}

if [ ! -f "credentials.txt" ]; then
  mv credentials.template.txt credentials.txt
fi

# Fixed: Home screen freezing
rm pokemmo_crash_*.log
rm hs_err_pid*

export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

$ESUDO chmod +x $GAMEDIR/controller_info.$DEVICE_ARCH
$ESUDO chmod +x $GAMEDIR/menu/launch_menu.$DEVICE_ARCH

echo INFO CONTROLLER
$GAMEDIR/controller_info.$DEVICE_ARCH
echo $SDL_GAMECONTROLLERCONFIG

if [[ -n "$ESUDO" ]]; then
    ESUDO="$ESUDO LD_LIBRARY_PATH=$controlfolder"
fi

# MENU
$GPTOKEYB2 "launch_menu" -c "./menu/controls.ini" &
$GAMEDIR/menu/launch_menu.$DEVICE_ARCH $GAMEDIR/menu/menu.items $GAMEDIR/menu/FiraCode-Regular.ttf

# Capture the exit code
selection=$?

if [ -f "$GAMEDIR/controller.map" ]; then
    echo load controller.map
    export SDL_GAMECONTROLLERCONFIG="$(cat $GAMEDIR/controller.map)"
    echo $SDL_GAMECONTROLLERCONFIG
fi

env_vars=""

# Check what was selected
case $selection in
    0)
        pm_finish

        if [[ "$PM_CAN_MOUNT" != "N" ]]; then
          if [ "$westonpack" -eq 1 ]; then
            $ESUDO umount "${weston_dir}"
            $ESUDO umount "${mesa_dir}"
          fi
          $ESUDO umount "${JAVA_HOME}"
          $ESUDO umount "${PYTHONHOME}"
        fi

        exit 2
        ;;
    1)
        echo "[MENU] ERROR"
        pm_finish

        if [[ "$PM_CAN_MOUNT" != "N" ]]; then
          if [ "$westonpack" -eq 1 ]; then
            $ESUDO umount "${weston_dir}"
            $ESUDO umount "${mesa_dir}"
          fi
          $ESUDO umount "${JAVA_HOME}"
          $ESUDO umount "${PYTHONHOME}"
        fi

        exit 1
        ;;
    2)
        echo "[MENU] PokeMMO"
        cat data/mods/console_mod/dync/theme.xml > data/mods/console_mod/console/theme.xml

        sed -i 's/^client\.ui\.theme=.*/client.ui.theme=console/' main_config.properties

        client_ui_theme=$(grep -E '^client.ui.theme=' main_config.properties | cut -d'=' -f2)

        sed -i 's/^client\.gui\.scale\.guiscale=.*/client.gui.scale.guiscale=1.0/' main_config.properties
        sed -i 's/^client\.gui\.hud\.hotkeybar\.y=.*/client.gui.hud.hotkeybar.y=0/' main_config.properties
        sed -i 's/^client\.ui\.theme\.mobile=.*/client.ui.theme\.mobile=false/' main_config.properties

        sed -i 's/is_mobile="true"/is_mobile="false"/' data/mods/console_mod/info.xml
        ;;
    3)
        echo "[MENU] PokeMMO Android"
        cat data/mods/console_mod/dync/theme.android.xml > data/mods/console_mod/console/theme.xml

        sed -i 's/^client\.ui\.theme=.*/client.ui.theme=android/' main_config.properties

        client_ui_theme=$(grep -E '^client.ui.theme=' main_config.properties | cut -d'=' -f2)
        sed -i 's/^client\.gui\.scale\.guiscale=.*/client.gui.scale.guiscale=1.8/' main_config.properties
        sed -i 's/^client\.gui\.scale\.hidpifont=.*/client.gui.scale.hidpifont=true/' main_config.properties
        sed -i 's/^client\.ui\.theme\.mobile=.*/client.ui.theme\.mobile=true/' main_config.properties

        sed -i 's/is_mobile="false"/is_mobile="true"/' data/mods/console_mod/info.xml
        ;;
    4)
        echo "[MENU] PokeMMO Small"
        cat data/mods/console_mod/dync/theme.small.xml > data/mods/console_mod/console/theme.xml

        sed -i 's/^client\.ui\.theme=.*/client.ui.theme=console/' main_config.properties

        client_ui_theme=$(grep -E '^client.ui.theme=' main_config.properties | cut -d'=' -f2)

        sed -i 's/^client\.gui\.scale\.guiscale=.*/client.gui.scale.guiscale=1.4/' main_config.properties
        sed -i 's/^client\.gui\.hud\.hotkeybar\.y=.*/client.gui.hud.hotkeybar.y=0/' main_config.properties
        sed -i 's/^client\.ui\.theme\.mobile=.*/client.ui.theme\.mobile=false/' main_config.properties

        sed -i 's/is_mobile="true"/is_mobile="false"/' data/mods/console_mod/info.xml
        ;;
    5)
        echo "[MENU] PokeMMO Update"
        rm -rf /tmp/launch_menu.trace
        $GAMEDIR/menu/launch_menu.$DEVICE_ARCH $GAMEDIR/menu/menu.items $GAMEDIR/menu/FiraCode-Regular.ttf --trace &
        curl -L https://pokemmo.com/download_file/1/ -o _pokemmo.zip 2> /tmp/launch_menu.trace
        if [ ! -f "patch.zip" ]; then
          cp patch_applied.zip patch.zip
        fi
        pm_unzip _pokemmo.zip . >> /tmp/launch_menu.trace
        rm _pokemmo.zip
        rm PokeMMO.sh
        echo "Generating PATCHES" >> /tmp/launch_menu.trace
        sleep 1
        echo __END__ >> /tmp/launch_menu.trace
        ;;
    6)
        echo "[MENU] PokeMMO Restore"
        cp patch_applied.zip patch.zip
        $GAMEDIR/menu/launch_menu.$DEVICE_ARCH $GAMEDIR/menu/menu.items $GAMEDIR/menu/FiraCode-Regular.ttf --show "PokeMMO Restored"
        pm_finish

        if [[ "$PM_CAN_MOUNT" != "N" ]]; then
          if [ "$westonpack" -eq 1 ]; then
            $ESUDO umount "${weston_dir}"
            $ESUDO umount "${mesa_dir}"
          fi
          $ESUDO umount "${JAVA_HOME}"
          $ESUDO umount "${PYTHONHOME}"
        fi

        exit 0
        ;;
    7)
        echo "[MENU] PokeMMO Restore Mods"
        rm -rf data/mods/
        cp patch_applied.zip patch.zip
        $GAMEDIR/menu/launch_menu.$DEVICE_ARCH $GAMEDIR/menu/menu.items $GAMEDIR/menu/FiraCode-Regular.ttf --show "Restored Mods"
        pm_finish

        if [[ "$PM_CAN_MOUNT" != "N" ]]; then
          if [ "$westonpack" -eq 1 ]; then
            $ESUDO umount "${weston_dir}"
            $ESUDO umount "${mesa_dir}"
          fi
          $ESUDO umount "${JAVA_HOME}"
          $ESUDO umount "${PYTHONHOME}"
        fi

        exit 0
        ;;
    *)
        echo "[MENU] Unknown option: $selection"

        cat data/mods/console_mod/dync/theme.xml > data/mods/console_mod/console/theme.xml

        sed -i 's/^client\.ui\.theme=.*/client.ui.theme=console/' main_config.properties

        client_ui_theme=$(grep -E '^client.ui.theme=' main_config.properties | cut -d'=' -f2)

        sed -i 's/^client\.gui\.scale\.guiscale=.*/client.gui.scale.guiscale=1.0/' main_config.properties
        sed -i 's/^client\.gui\.hud\.hotkeybar\.y=.*/client.gui.hud.hotkeybar.y=0/' main_config.properties
        sed -i 's/^client\.ui\.theme\.mobile=.*/client.ui.theme\.mobile=false/' main_config.properties

        sed -i 's/is_mobile="true"/is_mobile="false"/' data/mods/console_mod/info.xml



        ;;
esac

echo KILL launch_menu
echo "ps -eo user,pid,args | grep '[g]ptokeyb2' | grep 'launch_menu'"
echo $(ps -eo user,pid,args | grep '[g]ptokeyb2' | grep 'launch_menu')
__pids=$(ps -eo user,pid,args | grep '[g]ptokeyb2' | grep 'launch_menu' | awk '{print $2}')
echo [$__pids]

if [ -n "$__pids" ]; then
  echo "KILL: $__pids"
  $ESUDO kill $__pids
fi

echo ESUDO=$ESUDO
echo env_vars=$env_vars

if [ -f "patch.zip" ]; then
  rm -rf /tmp/launch_menu.trace
  rm -rf src f com /tmp/pokemmo _mods f.jar loader.jar
  if [ ! -f "theme.xml" ]; then
    cp data/mods/console_mod/console/theme.xml theme.xml
  fi
  cp -rf data/mods _mods
  $GAMEDIR/menu/launch_menu.$DEVICE_ARCH $GAMEDIR/menu/menu.items $GAMEDIR/menu/FiraCode-Regular.ttf --trace &
  echo "pm_unzip patch.zip"
  pm_unzip patch.zip . > /tmp/launch_menu.trace
  pm_unzip PokeMMO.exe /tmp/pokemmo "f/" "com/badlogic/gdx/controllers/desktop/" >> /tmp/launch_menu.trace
  mv patch.zip patch_applied.zip
  mv theme.xml data/mods/console_mod/console/theme.xml
  cp -rf _mods/* data/mods
  rm -rf _mods
  echo __END__ >> /tmp/launch_menu.trace
fi

if [ "$DEVICE_NAME" = "TRIMUI-SMART-PRO" ]; then
  DISPLAY_WIDTH=1280
  DISPLAY_HEIGHT=720
fi

# FIX GPTOKEYB2, --preserve-env=SDL_GAMECONTROLLERCONFIG
if [ -n "$ESUDO" ]; then
  ESUDO="${ESUDO},SDL_GAMECONTROLLERCONFIG"
fi
GPTOKEYB2=$(echo "$GPTOKEYB2" | sed 's/--preserve-env=SDL_GAMECONTROLLERCONFIG_FILE,/&SDL_GAMECONTROLLERCONFIG,/')

ENV_VARS="PATH="$PATH" JAVA_HOME="$JAVA_HOME" XDG_SESSION_TYPE=x11 GAMEDIR="$GAMEDIR""
echo "PokeMMO        $(cat RELEASE)"
echo "controlfolder  $controlfolder"
echo "theme          $client_ui_theme"

echo "WESTOMPACK  $westonpack"
echo "ESUDO       $ESUDO"
echo "GPTOKEYB2   $GPTOKEYB2"
echo "ENV_VARS    $ENV_VARS"

$GPTOKEYB2 "PokeMMO" -c "./controls.ini" &
cp -f main_config.properties config/main.properties
$GAMEDIR/bin/linux/arm64/PokeMMO

if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  if [ "$westonpack" -eq 1 ]; then
    $ESUDO umount "${weston_dir}"
    $ESUDO umount "${mesa_dir}"
  fi
  $ESUDO umount "${JAVA_HOME}"
  $ESUDO umount "${PYTHONHOME}"
fi

# Cleanup any running gptokeyb instances, and any platform specific stuff.
pm_finish
