# PokeMMO Port for PortMaster

PokeMMO is a fan-made multiplayer online game that brings together multiple generations of Pokémon in a single MMO experience. This port allows you to run the Windows version of PokeMMO using PortMaster-compatible devices.

---

## 🛠 Installation Instructions

### 1. Install the Port


Create a `.zip` that includes only the following files from this repository:

- `PokeMMO.sh`  
- `PokeMMO` (the folder containing the port resources)

Place the `.zip` into:  
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

---

### 3. Add Required and Optional ROMs

Launch the game and use the in-game menu to locate your ROM files.

**Required ROM:**  
- Pokémon Black or White (Version 1)

**Optional ROMs (enable more regions):**  
- Fire Red  
- Emerald  
- Platinum  
- HeartGold / SoulSilver

---

### 🎮 Login Without Keyboard Input (Testing)

To avoid typing your username and password every time:

1. Log in on your PC with the **"Remember Me"** option checked.
2. This will generate a file at:  
   `config/savedcredentials.properties`
3. Copy that file to:  
   `/roms/ports/PokeMMO/config/`

The game will now log in automatically when launched from PortMaster-compatible devices.

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
|select+up| mouse up |
|select+down| mouse down |
|select+left| mouse left |
|select+right| mouse right |

#### Controller Support Status

Only the version with `gptokeyb2` supports the virtual keyboard.

---

## 💬 Credits & Links

- Official site: [https://pokemmo.com](https://pokemmo.com)  
- Port suggestion on PortMaster: [View Suggestion](https://suggestions.portmaster.games/suggestion-details?id=ab4f9b6b87314eba96536a86804d7235)

