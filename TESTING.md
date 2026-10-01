# In-game test checklist

Run these on the WoW: Forever client after installing the addon. Turn on taint logging
first with `/console taintLog 1`. After testing, check `Logs\taint.log` for lines that
mention BagSections.

| # | Steps | Expected |
|---|---|---|
| T1 | `/bs new Essentials`, then drag Hearthstone, Mining Pick and Campfire Kit from Rest onto it | Header reads `Essentials (3)`, with 3 buttons and no empty slots. Rest has every other slot. |
| T2 | Click the sort button | Essentials and Rest are each in Blizzard's sort order, and sections keep their order. |
| T3 | `/reload` | Sections and their items are still there. |
| T4 | Create "Weapon swap", drag a weapon in, equip it, then unequip it | The section shrinks when the weapon is equipped, and the weapon comes back to the section when unequipped. |
| T5 | Drag an item from a section onto Rest | It shows in Rest and is no longer in the section. |
| T6 | Right-click a section header, Delete | A confirmation appears if the section has items, and its items go to Rest. |
| T7 | In combat, right-click a potion or food in a section | It's used, and there's no "AddOn blocked" error or taint log entry. |
| T8 | With Hearthstone in a section, get another item of the same kind (e.g. a second stack of a consumable you added) | It joins the section automatically. |
| T9 | Type in the search box | Non-matching items dim in every section. |
| T10 | Equip a reagent bag and sort | A "Reagents" area appears, and reagents are sorted into it. |
| T11 | Open a merchant, then close it | The bags open with the merchant and close with it. |
| T12 | Press B, B, then Escape | The window opens, closes, and Escape closes it. |
| T13 | Drag a piece of equipped gear from the character sheet onto a section | It goes into a free bag slot and shows in that section. |
| T14 | Alt+Right-click an item in a section, then Match, then "Every item of this kind" | Every copy of that item now goes to the section. |
| T15 | Drag an item from the reagent bag onto a section | An error explains that reagent bag items can't be added. |
| T16 | Settings: Options, AddOns, BagSections; change columns and scale | The window resizes immediately. |
| T17 | Click sort during combat | A message says sorting is queued, and the sort runs when combat ends. |
