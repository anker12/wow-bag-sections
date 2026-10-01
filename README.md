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
* **Add an item to a section:** drag it from Rest onto the section. Empty sections appear as
  drop targets while you're dragging.
* **Move an item between sections:** drag it onto the other section.
* **Remove an item from a section:** drag it onto Rest.
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

### Layouts

Switch layouts from the gear menu (Layout) or in Settings.

* **Default:** the layout above. Each section is stacked at full width.
* **Compact:** the window keeps the same width, but each section is drawn as a box outlined
  in its own colour, with its name in a coloured strip at the top. Small sections sit next
  to each other. Change a section's colour from its right-click menu (Colour...). Rest is
  grey and Reagents green. Because of the outlines, a box holds one column fewer than the
  default layout's full width.

```
Bags  [search........]  [sort] [⚙] [x]
┌Essentials (3)─┐ ┌Weapon swap (2)┐
│[HS][Pick][CF] │ │[Sword][Shield]│
└───────────────┘ └───────────────┘
┌Rest (15)──────────────────────────┐
│[..][..][..][..][..][..][..][..][..]│
│[..][..][..][..][ ][ ]              │
└───────────────────────────────────┘
```

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
