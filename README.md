# BagSections

A bag addon for **World of Warcraft: Forever**. All your bags show as one window, and you
can create named **sections** such as "Essentials" or "Weapon swap". Each section holds only
the items you put in it, so it never has empty slots. Everything else, plus every empty slot,
goes into one big **Rest** area. When you sort, each section is sorted separately.

```
Bags  [search........]  [sort] [⚙] [x]
- Essentials (3) ─────────────────────
 [Hearth][Pick][Campfire]
- Weapon swap (2) ────────────────────
 [Sword][Shield]
Rest (15) ────────────────────────────
 [..][..][..][..][..][..][..][..][..][..]
 [..][..][..][ ][ ]
Reagents ─────────────────────────────
 [..][ ][ ][ ]
3 free / 20                     12g 34s
```

## Install

Copy the `BagSections` folder into
`World of Warcraft\_forever_\Interface\AddOns\`, then `/reload` or restart the game.

## Use

* **Open the bags** the normal way (B, the backpack button, a merchant or mailbox). The
  addon window replaces Blizzard's bags. You can turn that off in the settings.
* **New section:** click the gear icon, then "New section...", or type `/bs new Essentials`.
* **Add an item to a section:** drag it from Rest onto the section. Places you can drop
  it light up blue, the same way Blizzard highlights where an item can go.
* **Move an item between sections:** drag it onto the other section.
* **Remove an item from a section:** drag it onto any Rest slot. It lands in that slot.
* **Rest** shows its slots in bag order, empty slots included, like Blizzard's bag, so you
  can drop items into any empty slot.
* **Alt+Right-click** an item for a menu: add to a section, remove from a section, or choose
  whether the section matches *this exact item* or *every item of this kind*.
* **Collapse:** left-click any header to collapse it to just the header: your sections,
  Rest and Reagents. Click again to expand.
* **Section header right-click:** rename, move up/down, move below/above Rest, pick its
  colour, empty or delete it.
* **Sort:** the sort button, or `/bs sort`. Right-click the sort button to flip the sort
  direction. A sort clicked during combat runs once combat ends.
* Gear you add is matched by exact item, so only that sword goes to the section. Everything
  else is matched by item type: every Hearthstone, every stack of that potion. You can change
  this for gear in the settings, or per item with Alt+Right-click.
* Sections are saved per character.

### Quest Items section

Turn on **Quest Items section** in Settings (or the gear menu), and quest items go into
their own "Quest Items" section automatically. That includes quest starters and items
whose type is Quest. It's a normal section otherwise: rename it, colour it, or move it
below Rest. Drag a quest item to Rest to keep that item out, or into another section to
put it there instead. Turning the option off removes the section, unless you've added
other items to it by hand. The option is per character.

### Profiles

Settings → Profiles... (or the gear menu → Profiles) has *Save sections as profile...*,
*Load profile* and *Delete profile*. A profile saves your list of sections: names, order,
colours, above/below Rest, and whether the Quest Items section is on. It doesn't save which
items are in them. Profiles are shared by all your characters. Loading a profile keeps the
items in any section whose name matches. Sections that aren't in the profile are removed
after asking, and their items go back to Rest.

### Layouts

Switch layouts from the gear menu (Layout) or in Settings.

* **Default:** the layout above. Each section is stacked at full width.
* **Semi-compact:** like Default, but your sections sit side by side, a set number per row
  (Gear menu → Layout → Sections per row, or Settings; default 3). Each section gets an
  equal share of the width and grows downwards. Rest, Reagents and Keyring stay full
  width. The number per row is capped so every section is at least one slot wide (8 at
  10 columns). Names that don't fit are cut short; hover for the full name.
* **Compact:** works like Blizzard's combined bag. All sections run through one grid with
  no gaps: each section starts in the slot right after the previous one ends and wraps onto
  the next line. Each section is outlined in its own colour, even across line breaks, with
  its name on its top edge. Slots always line up in the same columns on every row. Compact
  spaces slots a little further apart than Default to fit thin outlines between sections,
  so its window is slightly wider. Reagents and Keyring sit below a thin divider, apart
  from your sections. Hover a name to see it in full. Change a section's colour
  from its right-click menu (Colour...). Rest is grey and Reagents green. Empty and
  collapsed sections keep a small space so their name stays visible.

  While the window is open, the compact layout **doesn't move things around**. Looting or
  using up an item leaves everything where it is, and a used-up slot stays as a gap until
  you next open the bags. The layout updates when you do something yourself (drag an item
  into a section, sort, change sections) and when you reopen the bags.

```
Bags  [search........]  [sort] [⚙] [x]
┌Rest (17)───────────────────────────┐
│ ▢ ▢ ▢ ▢ ▢ ▢ ▢ ▢ ▢ ▢                │
│ ▢ ▢ ▢ ▢ ▢ ▢ ▢ ┌Consumes (9)────────┤
├───────────────┘ ▢ ▢ ▢              │
│ ▢ ▢ ▢ ▢ ▢ ▢ ▢ ▢ ▢ ▢ ┌Gear (1)──────┤
├─────────────────────┘ ▢            │
```

### Rest position

Settings → **Rest position** sets where *new* sections go, including the Quest Items
section:
* **Rest at bottom** (default): new sections are added above Rest.
* **Rest at top**: new sections are added below Rest, so loot comes in at the top.

Existing sections stay where they are. Move any section with *Move above/below Rest* in its
right-click menu.

Slash commands: `/bs` (open/close), `/bs sort`, `/bs new <name>`,
`/bs add <section>` (adds the item under the mouse), `/bs config`.

## How it works

Sections are **virtual**. Items stay wherever the game puts them, and the addon groups them
by section when it draws the window. Inside each section, items are shown in bag order. So
sorting just runs Blizzard's normal sort, and every section ends up sorted on its own. That
is simple and can't break halfway through. The downside: sections only exist in this
window, not in Blizzard's default bags.

[SPEC.md](SPEC.md) has the research and full design. [TESTING.md](TESTING.md) is the in-game
test checklist.

## Development

```
lua tests/run.lua     # unit tests for section rules and layout
lua tests/smoke.lua   # loads the whole addon against a mocked WoW API
luacheck .
```

Both test files run on plain Lua 5.1 and need no other libraries. CI runs them on every push.
