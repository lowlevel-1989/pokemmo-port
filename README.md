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

### 🎮 Login Without Keyboard Input

To avoid typing your username and password every time:

1. Log in on your PC with the **"Remember Me"** option checked.
2. This will generate a file at:  
   `config/savedcredentials.properties`
3. Copy that file to:  
   `/roms/ports/PokeMMO/config/`

The game will now log in automatically when launched from PortMaster-compatible devices.

---

### Controls

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
|select| mode text (on) |
|start| mode text (off) |

#### Controller Support Status
Controller mapping is currently being tested using `gptokeyb2`. However, not all builds of `libSDL2-2.0.so.0` support analog stick input properly, which may limit functionality on some devices.

As an alternative, work is in progress to support the original `gptokeyb`, which is not affected by SDL2 stick issues—but it does not support keyboard simulation, which limits input emulation in other ways.

---

## 💬 Credits & Links

- Official site: [https://pokemmo.com](https://pokemmo.com)  
- Port suggestion on PortMaster: [View Suggestion](https://suggestions.portmaster.games/suggestion-details?id=ab4f9b6b87314eba96536a86804d7235)

