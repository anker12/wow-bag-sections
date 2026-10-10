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
| T23 | Switch back to Layout, Stacked | The window looks and works exactly as before. |
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
| T42 | Drag an item while sections are on screen, in both layouts | Valid sections light up blue (a blue border in Stacked; the outline turns blue in Compact). There's no text in the sections; hovering one shows "Drop to add to …". |
| T43 | Start dragging an item, then cancel it several ways (right-click, Escape, drop on the action bar, drop in the world and cancel the destroy prompt) | The blue highlights go away every time, and sections stay usable without `/reload`. |
| T44 | Drag an item from a section onto an empty Rest slot | It lands in that exact slot and leaves the section. |
| T45 | In Rest, drag an item onto another empty Rest slot | It moves there and stays there. |
| T46 | Fresh install: create a section | It shows up straight away, empty, ready for drops. |
| T47 | Gear menu | The order is: New section, Show empty sections, Show keyring, Rearrange sections (Semi-compact only), Layout, Profiles, then Settings. |
| T48 | Untick Show keyring | The keyring disappears from the bags. |
| T49 | Footer | It shows empty/total slots as `x / y`. |
| T50 | Gear menu → Layout → Semi-compact | Your sections sit 3 per row, side by side, each growing downwards. Rest, Reagents and Keyring are full width. The window width is unchanged. |
| T51 | Gear menu → Layout and Settings | There's no "Sections per row" option any more; Semi-compact starts at 3 per row. |
| T52 | Semi-compact with a long section name | The name is cut short with "…"; hovering the header shows it in full. |
| T53 | Semi-compact: drag an item onto a section, collapse a section, use right-click menus | Everything works as in Stacked. |
| T54 | Switch back to Stacked | It looks exactly as before. |
| T55 | Semi-compact: try to drag a section name without unlocking | Nothing moves; clicking the name still collapses it. |
| T56 | Gear menu → Rearrange sections | A blue bar under the title says sections can be dragged. |
| T57 | Drag a section name onto another row, between two sections | A blue vertical line shows the spot; on release the section joins that row there. |
| T58 | Drag a section name between two rows / below the last row | A blue horizontal line shows the spot; on release it starts a new row there. |
| T59 | Build: Rest alone on top, then a row of 2, a row of 3, a row of 1 | Works by dragging Rest to the top and sections into rows. |
| T60 | Try to drag a 9th section into a full row (10 columns) | No blue line appears there, and dropping does nothing. |
| T61 | Click the blue bar | Locked again; dragging names does nothing. `/reload` also locks. |
| T62 | Save a profile, load it on another character | Same rows. |
| T63 | Gear menu → Layout → Reset rows | Back to the automatic 3-per-row arrangement. |
| T64 | Switch to Stacked after rearranging | Sections are in the same order as the rows (reading order), with sections after Rest shown below it. |
| T65 | At the bank, right-click items bank → bags and bags → bank, repeatedly | They move every time; no "BagSections has been blocked" message. |
| T66 | Right-click a bind-on-equip item, then Cancel on the bind prompt | No blue drop highlights left behind; everything stays clickable. |
| T67 | Drag gear from the character pane and drop it back on the character pane | No blue drop highlights left behind. |
| T68 | B, merchant, bank, Escape, close button | The bags open and close as with Blizzard's bags; Escape closes them. |
| T69 | With Rest at the top, `/reload`, then click a Rest item and click it back into the same slot | The blue highlights disappear straight away. |
| T70 | Look at the bag window | It has Blizzard's bronze border by default. Settings → Blizzard border off gives the thin plain border. |
| T71 | Settings → Background → Blizzard, then move Background opacity | Blizzard's panel background, getting more see-through as the slider goes down. Dark works the same way. |
| T72 | Compact layout, Settings → Outline opacity | The section outlines get fainter or stronger. |
| T73 | Settings → Section name tooltips off, hover a section name | No tooltip. |
| T74 | Profiles → Share profile → pick one, Ctrl+C, then Profiles → Import profile..., Ctrl+V, Accept | Chat says it was imported as "name (2)"; loading it gives the same sections and rows. |
| T75 | Import some random text, or a code with a few characters deleted | Chat says it isn't a valid code or is damaged; nothing is saved. |
| T76 | Character → Currency tab, tick "Show on Backpack" for one currency, open the bags | The currency shows left of the gold, amount then icon. Hovering it shows the currency tooltip. |
| T77 | Track several currencies (or set Columns to 6) so they don't fit between the free slots and the gold | They move to their own line above the gold, right-aligned, wrapping onto more lines as needed. Nothing overlaps and nothing runs past the window edge; the window grows to fit. |
| T78 | Untick "Show on Backpack" with the bags open, and earn or spend some of a tracked currency | The footer updates straight away. |
| T79 | Settings → Section name size, Gold and currency size, Free slots size | Each changes only its own text, in every layout. Big section names get taller headers; in Compact, names stay clear of the items. None of the three is in the gear menu. |
| T80 | `/console taintLog 1`, `/reload`. Open the bags with B, close them with the window's X, fight something, then right-click food or a potion in Rest | It's used. No "blocked from an action" popup and no Lua error, and `Logs\taint.log` has no BagSections lines. |
| T81 | Close the bags with the X, then press B | The bags open with one press. B again closes them. |
| T82 | Open the bags with B and press Escape, then B again | Escape closes them; B opens them. |
| T83 | Open and close the bags with B many times, in and out of combat, and via the backpack button | No Lua errors. |
| T84 | Fresh install, right-click the "Bags" title before visiting a bank | A Bank window opens next to the bags saying to visit a bank first. Right-click the title again: it closes. Hovering the title shows "Right-click: view bank". |
| T85 | Drag the window by its "Bags" title | The window still moves, and left-click on the title does nothing else. |
| T86 | Visit a banker, then right-click the title | The Bank window shows every character bank tab (and account bank tabs, marked "Account: …") with the same items as Blizzard's bank. The footer says "Live". |
| T87 | At the bank, move items between bank and bags, buy a bank tab, rename a tab | The Bank window follows each change. |
| T88 | Leave the bank, fly somewhere, `/reload`, then `/bs bank` | Same contents as when you left. The footer says "Updated … ago". Tooltips work; Shift-click links an item in chat. |
| T89 | Log in to another character on the same account | Its own character bank (or the visit hint), and the same account bank tabs. |
| T90 | Change Columns, Section name size, background and border settings with the Bank window open | It follows them, like the bags. |
| T91 | Semi-compact, Settings → the two Semi-compact spacing sliders: drag each to the smallest, then the largest, then back to the default (4 and 12) | Each changes only its own gap. Smallest: every row's items stay clear of the section names below, and blue drop highlights of neighbouring sections don't touch. Largest side by side: rows that no longer fit wrap. The defaults look as before. Neither slider is in the gear menu. |
| T92 | Bags closed. Esc → Options → AddOns → BagSections | The bags open above the Settings panel, titled "Bags (preview)". Moving any slider or ticking any box changes them straight away. Click another settings page: they close. Close Settings: they stay closed, and B opens them normally. |
| T93 | Bags open, then `/bs config` | The bags stay open as the preview; after closing Settings they're still open. |
| T94 | Options → AddOns → BagSections | Settings are grouped under Layout, Sections and items, Appearance, Text size, General and Profiles. Every setting still works (and shows in the preview). |
| T95 | Fresh install (rename the SavedVariables), log in | A Quest Items section exists and catches quest items. |
| T96 | Turn Quest Items off on one character, log in another | It's off there too, and its empty Quest Items section is gone. |
| T97 | Change a text size on one character, log in another | Same size there. |
| T98 | Put a crafting reagent (cloth, herb) in a normal bag. Settings → Gather reagents from bags on | It moves from Rest into the Reagents section, after the reagent bag's items and before its empty slots, as one block with one count, in all three layouts. No separate "Reagents (bags)". Off again: back in Rest. |
| T99 | Drag that reagent onto a Rest slot; then drag it onto the Reagents header | Rest: it stays in Rest. Header: it goes back to Reagents. |
| T100 | Add a reagent to one of your sections | It stays in the section. |
| T101 | Talk to a banker | BagSections' bank window opens (stone background, the bank's bag slots along the bottom, "Live" in the footer); Blizzard's bank isn't visible; the bags open too. No Lua errors or "blocked" popups. |
| T102 | At the bank: right-click an item in the bags, then one in the bank; drag items both ways; Shift-click to split a stack | Right-click deposits / withdraws; drag and drop works both ways; nothing is blocked. |
| T103 | At the bank: click the bank window's sort button; type in its search box | The bank sorts; items that don't match are dimmed. |
| T104 | Bank gear menu → Layout → Semi-compact, then Compact | The bank changes layout; the bags keep theirs. Settings → Bank layout shows the same choice. |
| T105 | At the bank with a bag slot left to buy: click "Buy slot", Yes; then hover and click a padlocked slot, Yes | "Buy slot" shows with "Cost:" and the price next to it (red if you can't afford it). Both open Blizzard's own confirm dialog with the price; Yes buys the slot and its padlock goes away. No "blocked" popup. |
| T106 | Close the bank window with its X; also press Escape at the bank; also walk away | Each ends the conversation with the banker, and the bank window closes. |
| T107 | Settings → Replace the default bank off, /reload, talk to a banker | Blizzard's bank opens as normal. |
| T108 | Visit a banker for the first time after updating | "Sort your bank into sections too?" Yes → "Copy your N bag sections to the bank?" (lists them) Yes. No question about Reagents. The bank now has those sections (same names, colours, order) and a Reagents section with your reagents in it. Not asked again on the next visit. |
| T109 | Bank gear menu → New section...; Copy sections from bags → one section, then All | New sections appear in the bank only; the bags don't change. Copy lists only bag sections the bank doesn't have yet. |
| T110 | At the bank, drag a bank item onto a bank section; drag a bag item onto a bank section | The bank item joins the section. The bag item moves into the bank, into that section. |
| T111 | Rename, recolour, collapse, delete a bank section; Alt+Right-click a bank item | Only the bank changes; the item menu lists the bank's sections. |
| T112 | Away from the bank, `/bs bank`, then pick up a bag item | The bank shows its sections from the last visit; bank sections don't light up as drop targets. |
| T113 | Put an item in a bag section that's linked to a bank section, then deposit it | It shows in the matching bank section. Withdraw it: back in the bag section. |
| T114 | Remove that item from the bank section (drag to Rest) | It's in Rest in the bank, and in Rest in the bags too after withdrawing. |
| T115 | Existing user: bag and bank sections with the same name made before this update, each with items | After /reload both have each other's items. |
| T116 | Bags gear menu → New section | When the bank has sections the bags don't, it opens a submenu: Empty section..., then those bank sections (and All). Picking one adds a linked bag section. Same in the bank's menu, the other way round. |
| T117 | Open the bank; Settings → Bank columns and Bank scale | The bank is about half as wide again as the bags by default (15 columns). Each slider changes only the bank; Columns and Scale change only the bags. |
| T118 | Open the bank | Its border is Blizzard's bank border with the banker's face in the round corner, the title next to it, items below; it looks like Blizzard's bank. Away from the bank (`/bs bank`) the corner shows a bank icon. |
| T119 | Look at the bottom row | "Bag slots:" then every bank bag slot: bought ones (with or without a bag) and the rest padlocked, the same number as Blizzard's bank. |
| T120 | Click a bag in a bought slot, then click another bag from your bags onto that slot; drag a bag into an empty bought slot | The bags swap / go in, like in Blizzard's bank; the bank's slots update. Nothing is blocked. |
| T121 | Bank columns at 6 | Buy slot and its price move to their own line above the bag slots instead of overlapping them. |
| T122 | At the bank, pick up the bag in a bought bank bag slot, move it over the bank and bags, put it back (or swap it with a bag from your bags) | No Lua error; the bag moves like in Blizzard's bank; no sections light up for it. |
| T123 | Bags open: hover each bag button on the action bar (backpack, bags, reagent bag) | That bag's slots glow in the bag window, in every layout; the glow goes when the mouse leaves. |
| T124 | At the bank: hover a bag in a bank bag slot | That bag's slots glow in the bank window; the glow goes when the mouse leaves. |
| T125 | Quest Items on, quest item in the bank: open the bank | The bank has a Quest Items section with the quest item in it. Turn the option off in Settings: the section goes from both bags and bank; on again: back in both. |
| T127 | Fresh install, or first login after updating | Gather reagents from bags and Reagents section in the bank are on. Neither gear menu has Quest Items or Reagents switches; Settings has Quest Items section, Gather reagents from bags and Reagents section in the bank. Turn Reagents section in the bank off: the bank's Reagents section goes, on every character. |
| T128 | Fresh install: open the bags and the bank | Both are in Semi-compact, with 4 between rows and 12 between sections side by side. The Layout menus and Settings list Stacked, Semi-compact and Compact (no "Default"). |
| T126 | Semi-compact, bags and bank, at a scale below 1 (e.g. Bank scale 0.8): collapse and expand sections in a shared row and on their own rows | Every header keeps its line to the right of its name, in narrow boxes too; none disappear as sections move. |
| T129 | At the bank, right-click a bag section with items, then Move all to bank | Every item of the section moves into the bank, onto matching stacks first, with no errors. A linked bank section shows them. |
| T130 | At the bank, right-click a bank section, then Move all to bags | Every item moves into your bags. |
| T131 | Away from the bank (or in the bank window showing a past visit), right-click a section | No Move all entry. |
| T132 | Move all to bank with more items than free bank slots | What fits moves; a chat message says how many didn't fit. |
| T133 | Start Move all to bank on a big section, then walk away from the banker | Moving stops, and a chat message says how many items were moved. |
