# Wick's UI

## 0.10.2 (unreleased)

### Nameplates

- A mob a quest of yours wants carries a mark at the right end of its
  bar, with how many more the quest wants beside it: the same count the
  game shows when you point at it. The mark goes once the quest has all
  it needs. Mark quest mobs and How many are left switch them, under
  Nameplates. On TBC Anniversary, whose mob tooltips carry no quest
  lines, only quest bosses are marked, as before.

### Fixes

- A quest opened from the map's quest log reads again. Its text was the
  dark ink the game uses on parchment, left on our dark panel, and its
  gold border, rewards banner and button dividers were still the game's.
  The panel now takes the look like the quest giver's window does.

## 0.10.1 (2026-10-03)

### TBC Classic Anniversary

- The quest tracker takes the look: a Quests header over an accent rule,
  and its lines in the look's font at the tracker text size. A quest in
  progress reads in the text colour and one ready to hand in in the
  accent; a finished objective is muted. It widens to fit its lines, so
  they no longer run off the right edge. Blizzard frames, Objective
  tracker switches it, and Tracker text size sets its size.

## 0.10.0 (2026-10-03)

### TBC Classic Anniversary

- Wick's UI loads on TBC Classic Anniversary 2.5.6 as well as Forever,
  from one folder and one version, on WickCore 0.11.0. The client is the
  same engine generation as Forever with the Classic interface on top,
  so the bars, unit frames, nameplates, chat, minimap, tooltips and info
  panels are the same code; what the client lacks is detected at load
  rather than assumed from the flavour.
- Auras on a client without the aura container: a plain-frame aura
  element with the same options, icons, counts, time left and dispel
  colours, built from C_UnitAuras. Cancelling a buff by click is not
  part of it; the buff display below is a secure header for that.
- The game's own player, pet, target and focus frames, and its own
  nameplates, are hidden on a client without role sets (what hides
  them on Forever). They had stayed on screen under ours, as still
  copies.
- Where the game has no damage meter of its own, the bags clear a
  Details window instead.
- The minimap gathers every addon's button, not only LibDBIcon's: the
  suite's own and hand-made ones too. Their round borders go, the icons
  sit in a grid of square tiles in the look's border, and an addon that
  puts its button back on the map's edge is answered. Pins drawn on the
  map itself are left alone, and the collector stands down when another
  one (MBB) is running.
- Your buffs and debuffs on such a client sit on two secure aura
  headers: the client's own secure code sorts them and places a
  button per aura, in combat too, and a right-click cancels a buff.
  Weapon enchants show among the buffs. The buttons are ours, drawn
  like the rest, with the time left on them.
- No boss frames, and no boss page, on a client without boss units.
- The talent info panel shows points per tree where there are no trait
  loadouts, and opens the talent window.
- The reputation bar reads the watched faction on either client.
- The retired ElvUI theme plugin kept its settings under this UI's name
  in the TBC folder; they are cleared once, with a line saying so, and
  the setup opens.
- The windows of the old kind (character, spellbook, talents, quest log,
  trainer, professions, bank, stable, flight master, battlegrounds,
  auction house, guild bank, scoreboard, key bindings, bags) take the
  look: our panel cut to the painted art, with their tabs, scroll bars,
  text boxes, spell and item slots and list rows redrawn as ours. The
  windows built on the portrait template keep the pass every window
  gets, and the old widgets inside them are looked over too.
- The minimap's own buttons (tracking, the group finder's eye, a
  battleground queue, the day and night dial) and WickCore's launcher
  sit in a row of tiles under the square map, with new mail at its
  end, where they had been scattered round its edge. Other addons'
  buttons stay in the flyout.
- The quest tracker moves: /wui move, "Quest tracker". It grows down
  from where you put it. Edit Mode has no place for it on this client.

### Movers

- The other Wick addons' bars, buttons and counters are movers too, in
  the Wick addons group of /wui move, starting where you had them. An
  addon hands its frame to WickCore; once Wick's UI has it, the addon's
  own drag stands down and its move and reset commands point here.
  Quest Key does so now; the rest follow as they move onto WickCore.
- The setup's last page says so, and how to put them back where you
  had them: show Wick addons in /wui move and press Reset shown.
- The need, greed and pass popups move: /wui move, "Loot rolls". Loot
  toasts follow them. On Forever the Items loot window is an Edit Mode
  system; move it there.

### Fixes

- Forever: no flood of errors from the trade window. The window pass
  asked a frame the game keeps locked what kind of frame it was; it now
  checks that a frame can be read before it looks.
- The damage meter and the threat meter show class colours again,
  whatever the look, so you can tell who is who. Each is a switch: Damage
  meter in class colours under Windows, and Class colours on the Threat
  page. Off puts the bars in the look's colours, yours brightest.
- The need, greed and pass buttons on a loot roll keep their pictures.
  They had been taken for arrows and given chevrons.
- TBC: check boxes in the game's Settings show a fel square when
  ticked, as they do on Forever. They had been taken for icons, and
  the tick was drawn as a faint ring round the box.
- TBC: a right-click cancels a buff. The buttons listened only for the
  release, and this client acts on the press.
- TBC: no more error when someone near you starts casting. The game
  gives no "can be interrupted" flag on this client, and the cast bar
  had passed that straight on.

- The group finder no longer comes apart. Dragging it by its title could
  pull the page you were on out of the window, leaving the window empty
  beside it and the page cut short, back in the same split every time it
  opened. Its title now drags the whole window, and a page already
  pulled out goes back in the next time it opens.
- No more "attempt to call a nil value" errors from the game's own
  windows on Forever: the Settings window's Apply button, the quest
  log's Abandon button, the raid markers, the stack split box and the
  floating combat text. The game's code failed when it called a button
  or frame method that Wick's UI had hooked to restyle it. Wick's UI no
  longer hooks any of them: a widget the game switches (a button turned
  off, a layout chosen, a bar laid out or dimmed, a meter bar painted,
  the game menu's buttons, a click binding row filled) is followed by a
  light check while it is on screen, and your combat text reads each
  new line off the game's own. Nothing changes in how any of it looks.

## 0.9.3 (2026-10-01)

### Looks

- Crisp, the ninth look, comes with WickCore 0.10.1: see-through dark
  grey, one black pixel round everything, square corners and your class
  colour as the accent. The windows Wick's UI reskins go see-through
  with it, while tiles and buttons stay solid.
- Each look keeps the shape of every bar as well as its size: how many
  buttons, how many to a row and which way it grows. It keeps the power
  bar height and the cast bar size of each unit frame too. Setting up
  one look no longer changes another.

### Unit frames

- Resting shows as a crescent moon in the look's accent, on a small tile
  at the corner of your frame, in place of the game's yellow Zzz.

### Windows

- Gear in the character window glows softly in its quality colour, from
  green up, fading out round each slot. Switch it off with Quality glow
  on gear, under Windows.

### Fixes

- An incoming heal on the unit frames stops at the end of the health
  bar. At full health, the heal you were casting ran out past the edge
  of the frame.
- In Crisp, the text of a quest taken from an object, such as a console
  or a wanted poster, was dark on the dark panel. It reads again.

## 0.9.2 (2026-10-01)

### Combat text

- Your own combat text, the lines round your character, is drawn by
  Wick's UI where you put it. It has a box of its own among the frames
  you move, with a sample running in it while they are unlocked.
- Its font, outline, text size, crit size and scale are yours, and so are
  which way it runs (up, down or in an arc), how far, how long it stays
  and how it fades. Crits pop and hold where they land, as the game's do.
- Each kind of line keeps the game's colour until you pick one: damage,
  spell damage, heals, power, reputation, spell alerts and the rest.
  Right-click a colour to go back to the game's. Show a sample plays a
  line of each.
- The numbers over what you hit can take a font of their own, and their
  gravity, scatter, start spread, rise, fade and place on the screen can
  be set. A button puts the game's own back.
- Power gains that come in ticks can be shown.

### Windows

- The stack split, when you shift-click a stack to split it, is dressed
  in the look: the number in a well between the arrow marks, and Okay and
  Cancel as pills.

### Fixes

- The quest reward you choose is marked again, with the accent ring
  round its icon and a wash behind its name. The game's own marker had
  gone with the window's old art.
- A button the game has switched off is dimmed, so you can tell whether
  you can click it. The quest giver's Continue stays dim until the items
  the quest needs are in your bags.
- Arrow buttons the game switches off are faded too: the page arrows on
  the last page, the stack split's arrows at either end.

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
