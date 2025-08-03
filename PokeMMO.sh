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

java_runtime="zulu17.48.15-ca-jdk17.0.10-linux.aarch64"
weston_runtime="weston_pkg_0.2"
mesa_runtime="mesa_pkg_0.1"

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

if [ ! -f "credentials.txt" ]; then
  mv credentials.template.txt credentials.txt
fi

# Fixed: Home screen freezing
rm pokemmo_crash_*.log
rm hs_err_pid*

echo RELEASE
cat $GAMEDIR/RELEASE

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
        fi

        exit 1
        ;;
    2)
        echo "[MENU] PokeMMO"
        cat data/mods/console_mod/dync/theme.xml > data/mods/console_mod/console/theme.xml

        client_ui_theme=$(grep -E '^client.ui.theme=' config/main.properties | cut -d'=' -f2)

        sed -i 's/^client\.gui\.scale\.guiscale=.*/client.gui.scale.guiscale=1.0/' config/main.properties
        sed -i 's/^client\.gui\.hud\.hotkeybar\.y=.*/client.gui.hud.hotkeybar.y=0/' config/main.properties
        ;;
    3)
        echo "[MENU] PokeMMO for clone handhelds"
        cat data/mods/console_mod/dync/theme.xml > data/mods/console_mod/console/theme.xml

        client_ui_theme=$(grep -E '^client.ui.theme=' config/main.properties | cut -d'=' -f2)

        sed -i 's/^client\.gui\.scale\.guiscale=.*/client.gui.scale.guiscale=1.0/' config/main.properties
        sed -i 's/^client\.gui\.scale\.hidpifont=.*/client.gui.scale.hidpifont=false/' config/main.properties
        sed -i 's/^client\.gui\.hud\.hotkeybar\.y=.*/client.gui.hud.hotkeybar.y=0/' config/main.properties
        sed -i 's/^client\.graphics\.max_fpx=.*/client.graphics.max_fpx=20/' config/main.properties
        ;;
    4)
        echo "[MENU] PokeMMO Android"
        cat data/mods/console_mod/dync/theme.android.xml > data/mods/console_mod/console/theme.xml

        client_ui_theme=$(grep -E '^client.ui.theme=' config/main.properties | cut -d'=' -f2)

        sed -i 's/^client\.gui\.scale\.guiscale=.*/client.gui.scale.guiscale=1.8/' config/main.properties
        sed -i 's/^client\.gui\.scale\.hidpifont=.*/client.gui.scale.hidpifont=true/' config/main.properties
        sed -i 's/^client\.ui\.theme\.mobile=.*/client.ui.theme\.mobile=true/' config/main.properties
        ;;
    5)
        echo "[MENU] PokeMMO Small"
        cat data/mods/console_mod/dync/theme.small.xml > data/mods/console_mod/console/theme.xml

        client_ui_theme=$(grep -E '^client.ui.theme=' config/main.properties | cut -d'=' -f2)

        sed -i 's/^client\.gui\.scale\.guiscale=.*/client.gui.scale.guiscale=1.4/' config/main.properties
        sed -i 's/^client\.gui\.hud\.hotkeybar\.y=.*/client.gui.hud.hotkeybar.y=0/' config/main.properties
        ;;
    6)
        echo "[MENU] PokeMMO Update"
        rm -rf /tmp/launch_menu.trace
        $GAMEDIR/menu/launch_menu.$DEVICE_ARCH $GAMEDIR/menu/menu.items $GAMEDIR/menu/FiraCode-Regular.ttf --trace &
        curl -L https://pokemmo.com/download_file/1/ -o _pokemmo.zip 2> /tmp/launch_menu.trace
        cp patch_applied.zip patch.zip
        unzip -o _pokemmo.zip >> /tmp/launch_menu.trace
        rm _pokemmo.zip
        rm PokeMMO.sh
        echo "Generating PATCHES" >> /tmp/launch_menu.trace
        sleep 1
        echo __END__ >> /tmp/launch_menu.trace
        ;;
    7)
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
        fi

        exit 0
        ;;
    *)
        echo "[MENU] Unknown option: $selection"
        cat data/mods/console_mod/dync/theme.xml > data/mods/console_mod/console/theme.xml

        client_ui_theme=$(grep -E '^client.ui.theme=' config/main.properties | cut -d'=' -f2)

        sed -i 's/^client\.gui\.scale\.guiscale=.*/client.gui.scale.guiscale=1.0/' config/main.properties
        sed -i 's/^client\.gui\.scale\.hidpifont=.*/client.gui.scale.hidpifont=true/' config/main.properties
        sed -i 's/^client\.gui\.hud\.hotkeybar\.y=.*/client.gui.hud.hotkeybar.y=0/' config/main.properties
        ;;
esac

__pids=$(ps aux | grep '[g]ptokeyb2' | grep 'launch_menu' | awk '{print $2}')

if [ -n "$__pids" ]; then
  echo "KILL: $__pids"
  $ESUDO kill $__pids
fi

echo ESUDO=$ESUDO
echo env_vars=$env_vars

if [ -f "patch.zip" ]; then
  rm -rf /tmp/launch_menu.trace
  rm -rf src f com /tmp/pokemmo f.jar loader.jar
  cp config/main.properties main.properties
  $GAMEDIR/menu/launch_menu.$DEVICE_ARCH $GAMEDIR/menu/menu.items $GAMEDIR/menu/FiraCode-Regular.ttf --trace &
  unzip -o patch.zip > /tmp/launch_menu.trace
  unzip -o PokeMMO.exe "f/*" "com/badlogic/gdx/controllers/desktop/*" -d /tmp/pokemmo >> /tmp/launch_menu.trace
  mv patch.zip patch_applied.zip
  for file in /tmp/pokemmo/f/*.class; do
    echo "[CHECKING] $file" >> /tmp/launch_menu.trace
    if grep -q --binary-files=text "client.ui.login.username" "$file"; then
      echo "[MATCH] $file" >> /tmp/launch_menu.trace
      class_name="${file%.class}"
      class_name="${class_name#/tmp/pokemmo/}"
      class_name="${class_name//\//.}"
      break
    fi
  done
  echo "Generating f.jar" >> /tmp/launch_menu.trace
  rm -rf credentials.javap.txt jamepad.javap.txt
  echo "class_name $class_name" >> /tmp/launch_menu.trace
  javap -v -classpath /tmp/pokemmo "$class_name" > credentials.javap.txt
  javap -v -classpath /tmp/pokemmo com.badlogic.gdx.controllers.desktop.JamepadControllerManager > jamepad.javap.txt
  echo jar cf f.jar -C /tmp/pokemmo f >> /tmp/launch_menu.trace
  jar cf f.jar -C /tmp/pokemmo f
  echo "Generating loader.jar" >> /tmp/launch_menu.trace
  python parse_javap.py >> /tmp/launch_menu.trace
  echo javac -d out/ -cp "f.jar:libs/*" src/*.java src/auto/*.java >> /tmp/launch_menu.trace
  javac -d out/ -cp "f.jar:libs/*" src/*.java src/auto/*.java
  echo jar cf loader.jar -C $GAMEDIR/out org -C $GAMEDIR/out com -C $GAMEDIR/out f >> /tmp/launch_menu.trace
  jar cf loader.jar -C $GAMEDIR/out org -C $GAMEDIR/out com -C $GAMEDIR/out f
  rm -rf out
  sleep 1
  echo __END__ >> /tmp/launch_menu.trace
fi

if [ ! -f "loader.jar" ]; then
  $GAMEDIR/menu/launch_menu.$DEVICE_ARCH $GAMEDIR/menu/menu.items $GAMEDIR/menu/FiraCode-Regular.ttf --show "ERROR: loader.jar"
  sleep 10
  pm_finish

  if [[ "$PM_CAN_MOUNT" != "N" ]]; then
    if [ "$westonpack" -eq 1 ]; then
      $ESUDO umount "${weston_dir}"
      $ESUDO umount "${mesa_dir}"
    fi
    $ESUDO umount "${JAVA_HOME}"
  fi

  exit 1
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

COMMAND="CRUSTY_SHOW_CURSOR=1 WESTON_HEADLESS_WIDTH="$DISPLAY_WIDTH" WESTON_HEADLESS_HEIGHT="$DISPLAY_HEIGHT" $weston_dir/westonwrap.sh headless noop kiosk crusty_glx_gl4es"
PATCH="loader.jar:libs/*:PokeMMO.exe"

JAVA_OPTS="-Xms128M -Xmx384M -Dorg.lwjgl.util.Debug=true -Dfile.encoding=UTF-8"
ENV_VARS="PATH="$PATH" JAVA_HOME="$JAVA_HOME" XDG_SESSION_TYPE=x11 GAMEDIR="$GAMEDIR""
CLASS_PATH="-cp "${PATCH}" com.pokeemu.client.Client"

echo "PokeMMO        $(cat RELEASE)"
echo "controlfolder  $controlfolder"
echo "theme          $client_ui_theme"

echo "WESTOMPACK  $westonpack"
echo "ESUDO       $ESUDO"
echo "COMMAND     $COMMAND"
echo "PATCH       $PATCH"
echo "GPTOKEYB2   $GPTOKEYB2"
echo "JAVA_OPTS   $JAVA_OPTS"
echo "ENV_VARS    $ENV_VARS"
echo "CLASS_PATH  $CLASS_PATH"

$GPTOKEYB2 "java" -c "./controls.ini" &
if [ "$westonpack" -eq 1 ]; then 
  # Weston-specific environment
  ENV_WESTON="$ENV_VARS XDG_DATA_HOME="$GAMEDIR" WAYLAND_DISPLAY="
  
  $ESUDO env $COMMAND $ENV_WESTON java $JAVA_OPTS $CLASS_PATH
  
  # Clean up Weston environment
  $ESUDO "$weston_dir/westonwrap.sh" cleanup
else
  # Non-Weston environment with cursor fix
  ENV_NON_WESTON="$ENV_VARS CRUSTY_SHOW_CURSOR=1"
  
  env $ENV_NON_WESTON java $JAVA_OPTS $CLASS_PATH
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
