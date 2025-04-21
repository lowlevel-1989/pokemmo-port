# PokeMMO Port for PortMaster

PokeMMO is a fan-made multiplayer online game that brings together multiple generations of Pokémon in a single MMO experience. This port allows you to run the Windows version of PokeMMO using PortMaster-compatible devices.

---

## 🛠 Installation Instructions

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

If your device does not have a keyboard, you can try one of the following methods to log in:

#### 🔧 Option 1: Connect a Keyboard for First Login

Temporarily connect a physical keyboard (USB or Bluetooth), log in as usual, and make sure to check the **"Remember Me"** option.

#### 📝 Option 2: Type Password in Username Field (thanks ddrsoul)

Type your password in the **username** field, then **copy and paste** it into the password field. This allows you to use system copy/paste functions even without a keyboard.

#### ✅ Option 3: Autologin Using Saved Credentials (Testing)

1. Log in on your PC with the **"Remember Me"** option enabled.  
2. This will generate a file at:  
   `config/savedcredentials.properties`  
3. Copy that file to your PortMaster device at:  
   `/roms/ports/PokeMMO/config/`

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

## Thanks

- Jeod
- BinaryCounter
- ddrsoul
- lil gabo
- Fran

## Refs

- Official site: [https://pokemmo.com](https://pokemmo.com)  
- Port suggestion on PortMaster: [View Suggestion](https://suggestions.portmaster.games/suggestion-details?id=ab4f9b6b87314eba96536a86804d7235)
---
