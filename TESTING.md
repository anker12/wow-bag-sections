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
| T18 | Right-click a section header, then "Move below Rest" | The section is drawn after Rest. "Move above Rest" puts it back. |
| T19 | Left-click the Rest header, then the Reagents header | Each collapses to just its header. Click again to expand. |
| T20 | Gear menu, Layout, Compact | Sections become coloured outlined boxes with their names showing, small ones sit side by side, and the window width doesn't change. |
| T21 | In compact, right-click a section header, then Colour... and pick a colour | The outline and name change colour as you pick. Cancel restores the old colour. |
| T22 | In compact, drag an item onto another section's box | It's added to that section. |
| T23 | Switch back to Layout, Default | The window looks and works exactly as before. |
| T24 | With a quest item in your bags, turn on Settings → Quest Items section | A "Quest Items" section appears with the quest item in it. |
| T25 | Loot or accept a quest that gives a quest item | The new item goes straight into Quest Items. |
| T26 | Drag a quest item from Quest Items to Rest | It stays in Rest, including after `/reload`. |
| T27 | Turn the Quest Items option off | The section disappears and quest items go back to Rest. |
| T28 | Settings → Profiles... → Save sections as profile..., name it "Main" | A chat message says it was saved. |
| T29 | On another character, Profiles... → Load profile → Main | You get the same sections with the same names, colours and order, and they're empty until you add items. |
| T30 | Add a section "Temp", then load "Main" again | A confirmation says 1 section will be removed. Accept: "Temp" is gone, and other sections keep their items. |
| T31 | Profiles... → Delete profile → Main | The profile is gone from the Load list. |
