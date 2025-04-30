# PokeMMO Port for PortMaster

PokeMMO is a fan-made multiplayer online game that brings together multiple generations of Pokémon in a single MMO experience.

---

## 🛠 Installation Instructions

### CFW Tests:

~~~
- [x] ArkOS
- [x] Rocknix
    -> [x] Panfrost ( recommended [30/60 fps] )
    -> [~] Libmali
- [~] MuOS  ( Work in progress )
- [] Knulli ( canceled )


Rocknix -> Panfrost -> 'headless noop kiosk crusty_glx_gl4es' -> OK
Rocknix -> libmali  -> 'drm gl kiosk virgl'                   -> OK
Rocknix -> libmali  -> 'headless noop kiosk crusty_glx_gl4es' -> FAIL, the screen freezes
ArkOS   ->          -> 'headless noop kiosk crusty_glx_gl4es' -> FAIL,  the screen freezes
ArkOS   ->          -> 'drm gl kiosk virgl'                   -> OK
MuOS    ->          -> 'drm gl kiosk virgl'                   -> FAIL, does not detect opengl
MuOS    ->          -> 'headless noop kiosk crusty_glx_gl4es'  -> FAIL,  the screen freezes
Knulli  ->          -> 'headless noop kiosk crusty_glx_gl4es'  -> FAIL,  the screen freezes
Knulli  ->          -> 'drm gl kiosk virgl'                    -> FAIL, does not detect opengl
~~~

### Assigning Panfrost in Rocknix

To configure Rocknix to use the **Panfrost** driver, first ensure your device supports it and that it’s not the only available option. For example, the **Powkiddy RGB30** supports both **libMali (GLES 3.2)** and **Panfrost (GL 3.1/GLES 3.1)**, as shown [here](https://rocknix.org/devices/powkiddy/rgb30/#software).

To switch to the Panfrost driver:
![step 1](docs/1.jpg)
![step 2](docs/2.jpg)


### 1. Install the Port

Download pokemmo.zip Place the `.zip` into:  
`/PortMaster/autoinstall`

Launch **PortMaster**. It will automatically install the port.

---

### 2. Add Official PokeMMO Client Files

Go to the official PokeMMO website:  
[https://pokemmo.com/en/downloads/portable](https://pokemmo.com/en/downloads/portable)

Download the **portable version**, extract it, and copy these into:  
`/roms/ports/PokeMMO/`

- `PokeMMO.exe`  
- `data/` folder

⚠️  Make sure not to replace the existing shaders folder, as it contains optimized shaders.
Replacing them may negatively impact performance on low-end devices.

---

### 3. Add Required and Optional ROMs

To add the ROMs, place them inside the PokeMMO/roms folder and set the following values in `main.properties`:
~~~
client.roms.nds=roms/pokemon_black.nds  
client.roms.em=roms/pokemon_emerald.gba  
client.roms.fr=roms/pokemon_firered.gba  
client.roms.nds2=roms/pokemon_platinum.nds  
client.roms.nds3=roms/pokemon_heartgold.nds
~~~

**Required ROM:**  
- Pokémon Black or White (Version 1)

**Optional ROMs (enable more regions):**  
- Fire Red  
- Emerald  
- Platinum  
- HeartGold / SoulSilver

---


### 🎮 Login Without Keyboard Input

If your device does not have a keyboard, you can try one of the following methods to log in:

#### 🔧 Option 1: PokeMMO/credentials.txt

Edit the file PokeMMO/credentials.txt with your login credentials.

#### 🔧 Option 2: Connect a Keyboard for First Login

Temporarily connect a physical keyboard (USB or Bluetooth), log in as usual, and make sure to check the **"Remember Me"** option.

#### 📝 Option 3: Type Password in Username Field (thanks ddrsoul)

Type your password in the **username** field, then **copy and paste** it into the password field. This allows you to use system copy/paste functions even without a keyboard.

The game will now automatically log in when launched on PortMaster-compatible devices.

---

### Controls gptokeyb2

| Button | Action |
|--|--| 
|A| A|
|B| B|
|X| show trainer card |
|Y| show bag |
|R2| show pokedex |
|L2| mode dpad mouse |
|R1| mouse left |
|L1| mouse right |
|start| menu |
|select| mode text (on) |
|start| mode text/mouse (off) |

To use the virtual keyboard mode with gptokeyb2, press the Select button once to enter letter mode.
Press Select again to switch to number mode.
To finish and exit keyboard mode, press the Start button.

### Controls gptokeyb

| Button | Action |
|--|--| 
|A| A|
|B| B|
|X| show trainer card |
|Y| show bag |
|R2| show friends list |
|L2| show pokedex |
|R1| mouse left |
|L1| mouse right |
|start| menu |

#### Controller Support Status

Only the version with `gptokeyb2` supports the virtual keyboard.

---

## Thanks

- Jeod
- BinaryCounter
- ddrsoul
- lil gabo
- Fran
- rttn
- zerchu
- Ganimoth

## Refs

- Official site: [https://pokemmo.com](https://pokemmo.com)  
- Port suggestion on PortMaster: [View Suggestion](https://suggestions.portmaster.games/suggestion-details?id=ab4f9b6b87314eba96536a86804d7235)
---
