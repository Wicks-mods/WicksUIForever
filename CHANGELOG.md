# Wick's UI

## 0.9.1 (2026-09-30)

### Nameplates

- In Wick Modern and the looks drawn like it, nameplates match the unit
  frames: the bar sits in a rounded card on a rounded track, and the cast
  bar is a thin line with the spell name and its time above it. Wick OG
  and Rebel keep the bordered bar with its spell icon, and the cast bar
  height and spell icon settings say they apply there.

### Windows

- The click cast bindings window is dressed in the look: the list on a
  card, each binding a pill with its icon on a tile, the accent ring on a
  new binding waiting for its click and on each icon a held spell can go
  on, and the talents and macros buttons as tiles with the ring on the
  open one. Its tutorial is a window of ours too, with a small unit frame
  card in place of the painting.
- The Legacy window takes the look's frame again (this client renamed
  it), with its tabs as tiles down the side like the other windows'.

### Fixes

- Text across the interface follows a theme change. Labels in the
  settings, the setup, the threat meter, the minimap and the info panels
  no longer keep the old colours until a reload.
- The unit frames' health gradient runs up to the new accent after a
  theme change, and frames and nameplates take the look's health colours
  again at once.
- A player's name on a tooltip takes the class colour set you chose, the
  Classic era one included.
- Highlights in the settings, the dropdown lists and the frame movers
  follow the look's rounded shapes.
- Cast bars on the unit frames and nameplates are in the look's accent,
  your class colour while the theme follows your class, unless you pick
  a colour. Keybind text on every bar, the stance and pet bars included,
  is in the look's text colour unless you pick one. Right-click either
  colour to follow the look again. A cast bar or keybind colour you never
  changed moves over to the look's by itself.
- "The look's own" outline works on the action bars.
- Talent nodes that can take a point stand apart from maxed ones in every
  look: a heavy ring in the accent for one you can spend on, a quiet ring
  over a light wash for one that is maxed.
- The setup's chosen answer keeps its ring after the pointer has been
  over it.
- Escape closes the setup, the way its close button does, and the mover
  panels. On the mover panel it locks the frames as well.
- Rings in Wick OG and Rebel are square, like their borders, and
  Foundry's small tiles take its own ring.
- A tile meant to sit flat no longer keeps a shadow from an earlier pass.
- A new bar texture reaches the rested XP bar, the tooltip's health bar,
  the swing timers, the bars in the game's windows and the overlays on
  unit frame and nameplate bars.
- A greyed-out slider no longer takes a typed number, and a greyed-out
  text area takes no typing and its buttons do nothing.
- Fewer of our own markers are written onto frames the game made (aura
  buttons, icons, the swing timer bar).

### Typing and keys

- Enter confirms a confirm dialog.
- A number or text you type is kept however you leave the box, not only
  with Enter, and a page refreshing while you type leaves it alone.
  Escape puts back what was there. Tab and Shift-Tab move between the
  boxes of a window.
- The mouse wheel over a slider scrolls the page. Hold Shift to turn the
  slider instead; where nothing scrolls, the wheel turns it as before.
- A dropdown list longer than it shows has a slim bar down its right edge.

### Settings

- The unit frame pages grey out what cannot apply: the whole page while
  a frame is switched off, each text, aura and cast bar section while its
  Show is off, and the dispel and heal-over-time sizes while those are off.
  The nameplate page does the same for its sizes, colours and cast bar.
- The setting for the look is called Look everywhere, and the font
  settings sit under "Fonts and bars".
- Settings call the accent the accent, not fel: "Accent border on your
  target", "Accent corners".
- Page names are in sentence case (Unit frames, Action bars), and the
  settings window's Keybinds button is Keybind mode, as on the General page.
- "Alpha" reads "opacity" everywhere in the settings.
- The action bars' Outline list names its choices the way the unit
  frames' list does.

## 0.9.0 (2026-09-30)

First release, on the suite's shared version for the Forever beta. The
suite goes to 1.0.0 together at launch.

### The interface

- Action bars on the game's own action pages and keybindings, with stance
  and pet bars, fading, hover keybinding (/wui kb), and spells moved up to
  the new rank when you train it.
- Unit frames for the player, target, target of target, focus, pet and
  bosses, with cast bars, auras and text you choose.
- Party and raid frames with a dispellable debuff in the middle, your own
  heals over time in the corners, missing health and a target border.
- Nameplates with target and focus markers, class marks, an execute
  highlight, threat colours for tanks, a lock on casts you cannot
  interrupt, and name-only friendly plates.
- Buffs and debuffs, chat, minimap with a button flyout, tooltips, info
  panels and XP and reputation bars.
- Threat: a ranked meter, a personal bar with a pull warning, and threat
  glows on frames and plates.
- Window skins for the character, spellbook, talents, professions, map,
  mail, bank, vendors, trainers, flight master, quest givers, friends,
  guild, the group finder, stable, calendar, collections, settings and
  menus. The damage meter and swing timers follow the look.
- Extras: raid marker bar, a quieter error line in combat, AFK screen,
  hidden picture settings and fuller combat text controls.
- The comforts from Wick's Comforts, built in and off until switched on.

### Looks

- Wick Modern, Wick OG, Hologram, Rebel, Gilded, Arena, Foundry and Frost,
  shared with every Wick addon. Colours come with each look and can be
  changed in /wickcore options.

### Setup

- A first-login setup, one question to a page: the look, class colours,
  scale, which bags B opens when Wick's Bags is on, and which addon keeps
  a job when another one does it too. Kits for other classes can be
  switched off for that character. One reload at the end.
