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
| T20 | Gear menu, Layout, Compact | All sections run through one grid with no gaps, and each starts right after the previous one. Each is outlined in its colour, including across line breaks, with its name on its top edge. The window width doesn't change. |
| T21 | In compact, right-click a section header, then Colour... and pick a colour | The outline and name change colour as you pick. Cancel restores the old colour. |
| T22 | In compact, drag an item onto another section | It's added to that section, and the layout updates once. |
| T23 | Switch back to Layout, Default | The window looks and works exactly as before. |
| T24 | With a quest item in your bags, turn on Settings → Quest Items section | A "Quest Items" section appears with the quest item in it. |
| T25 | Loot or accept a quest that gives a quest item | The new item goes straight into Quest Items. |
| T26 | Drag a quest item from Quest Items to Rest | It stays in Rest, including after `/reload`. |
| T27 | Turn the Quest Items option off | The section disappears and quest items go back to Rest. |
| T28 | Settings → Profiles... → Save sections as profile..., name it "Main" | A chat message says it was saved. |
| T29 | On another character, Profiles... → Load profile → Main | You get the same sections with the same names, colours and order, and they're empty until you add items. |
| T30 | Add a section "Temp", then load "Main" again | A confirmation says 1 section will be removed. Accept: "Temp" is gone, and other sections keep their items. |
| T31 | Profiles... → Delete profile → Main | The profile is gone from the Load list. |
| T32 | In compact, with the bag open, drink a potion until the stack is gone, and loot something | Nothing moves; the used-up slot stays as a gap. Close and reopen: the gap is gone. |
| T33 | In compact, click sort | The layout follows the items as they're sorted. |
| T34 | In compact, collapse a section, and create an empty one | Both keep a small outlined space with their name visible. |
| T35 | In compact, hover over a short or cut-off name | The tooltip shows the full name. |
| T36 | Settings → Rest position → Rest at top, then create a section and turn on Quest Items | Both new sections appear below Rest. Existing sections don't move. |
| T37 | Look at the footer | The gold amount is the same text size as the section names. |
| T38 | In compact, look at the spacing | Every row has the same number of slots and they line up in columns. Outlines are thin, each the same distance from its items on all sides, with space between neighbouring sections. |
| T39 | In compact, make a section wrap so its two parts don't touch | The name shows once, on the larger part; both parts have the same outline colour. |
| T40 | In compact, look at sections that start partway along a row (e.g. after another section) | Their left-hand outline is fully drawn, the same as the other sides. |
| T41 | In compact, with a reagent bag (and keyring) | Reagents and Keyring sit below a thin divider, separate from your sections and Rest. |
| T42 | Drag an item while sections are on screen, in both layouts | Valid sections light up blue (a blue border in Default; the outline turns blue in Compact). There's no text in the sections; hovering one shows "Drop to add to …". |
| T43 | Start dragging an item, then cancel it several ways (right-click, Escape, drop on the action bar, drop in the world and cancel the destroy prompt) | The blue highlights go away every time, and sections stay usable without `/reload`. |
| T44 | Drag an item from a section onto an empty Rest slot | It lands in that exact slot and leaves the section. |
| T45 | In Rest, drag an item onto another empty Rest slot | It moves there and stays there. |
| T46 | Fresh install: create a section | It shows up straight away, empty, ready for drops. |
| T47 | Gear menu | The order is: New section, Show empty sections, Quest Items section, Show keyring, Rearrange sections (Semi-compact only), Layout, Profiles, then Settings. |
| T48 | Untick Show keyring | The keyring disappears from the bags. |
| T49 | Footer | It shows empty/total slots as `x / y`. |
| T50 | Gear menu → Layout → Semi-compact | Your sections sit 3 per row, side by side, each growing downwards. Rest, Reagents and Keyring are full width. The window width is unchanged. |
| T51 | Gear menu → Layout and Settings | There's no "Sections per row" option any more; Semi-compact starts at 3 per row. |
| T52 | Semi-compact with a long section name | The name is cut short with "…"; hovering the header shows it in full. |
| T53 | Semi-compact: drag an item onto a section, collapse a section, use right-click menus | Everything works as in Default. |
| T54 | Switch back to Default | It looks exactly as before. |
| T55 | Semi-compact: try to drag a section name without unlocking | Nothing moves; clicking the name still collapses it. |
| T56 | Gear menu → Rearrange sections | A blue bar under the title says sections can be dragged. |
| T57 | Drag a section name onto another row, between two sections | A blue vertical line shows the spot; on release the section joins that row there. |
| T58 | Drag a section name between two rows / below the last row | A blue horizontal line shows the spot; on release it starts a new row there. |
| T59 | Build: Rest alone on top, then a row of 2, a row of 3, a row of 1 | Works by dragging Rest to the top and sections into rows. |
| T60 | Try to drag a 9th section into a full row (10 columns) | No blue line appears there, and dropping does nothing. |
| T61 | Click the blue bar | Locked again; dragging names does nothing. `/reload` also locks. |
| T62 | Save a profile, load it on another character | Same rows. |
| T63 | Gear menu → Layout → Reset rows | Back to the automatic 3-per-row arrangement. |
| T64 | Switch to Default after rearranging | Sections are in the same order as the rows (reading order), with sections after Rest shown below it. |
| T65 | At the bank, right-click items bank → bags and bags → bank, repeatedly | They move every time; no "BagSections has been blocked" message. |
| T66 | Right-click a bind-on-equip item, then Cancel on the bind prompt | No blue drop highlights left behind; everything stays clickable. |
| T67 | Drag gear from the character pane and drop it back on the character pane | No blue drop highlights left behind. |
| T68 | B, merchant, bank, Escape, close button | The bags open and close as with Blizzard's bags; Escape closes them. |
| T69 | With Rest at the top, `/reload`, then click a Rest item and click it back into the same slot | The blue highlights disappear straight away. |
