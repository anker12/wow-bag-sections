# BagSections — Specification

A bag addon for **World of Warcraft: Forever** that shows all bags as one combined bag
and lets the player create named **sections** ("Essentials", "Weapon swap", …). A section
holds the items assigned to it. Everything else goes into one big **Rest** area. Each
section is sorted separately.

Status: v0.1 implements milestones M1–M3 with virtual sections (Option A). See §13 for where the code differs from this spec.

---

## 1. Feasibility verdict

**It can be built, and nothing in the restricted (Midnight-style) addon API stands in
the way.**

What was checked, using Blizzard's own Forever UI source (`Gethe/wow-ui-source`, branch
`forever`, build `1.60.1.70124`, 2026-09-30):

| Need | Forever API | Status |
|---|---|---|
| Read every bag slot | `C_Container.GetContainerNumSlots`, `GetContainerItemInfo`, `GetContainerItemID`, `GetContainerItemLink` | Present. Returns are **not** secret values. Only `SecretArguments = "AllowedWhenUntainted"` applies, so normal values passed from addon code are fine. |
| Move items | `C_Container.PickupContainerItem`, `C_Container.SplitContainerItem`, `ClearCursor` | Present and not protected. This is how Bagnon and Baganator move items. |
| Know which slot an item was dragged from | `C_Cursor.GetCursorItem()` → `ItemLocation:GetBagAndSlot()` | Present. Blizzard's own bag code uses it in Forever. |
| Identify one specific item, not just its type | `C_Item.GetItemGUID(ItemLocation)` | Present. |
| Blizzard "Clean Up Bags" sort | `C_Container.SortBags()`, `SetSortBagsRightToLeft`, `SetBagSlotFlag(bag, Enum.BagSlotFlags.DisableAutoSort, …)` | Present. It can only skip **whole bags**, not single slots. See §5. |
| Bag layout | `Enum.BagIndex`: `Backpack`=0, `Bag_1..4`=1–4, **`ReagentBag`=5**, `Keyring`=-1 | Forever has the modern reagent bag slot. The keyring index is in the enum, but check at runtime whether it has slots. |
| Item use from addon-made buttons | `ContainerFrameItemButtonTemplate` (Mainline file, loaded in Forever) | The same template Bagnon uses. Blizzard sets bag IDs through `SetBagID` → `SetAttribute("bagid")` specifically "to prevent bagID from tainting all interaction with items". |
| Events | `BAG_UPDATE`, `BAG_UPDATE_DELAYED`, `ITEM_LOCK_CHANGED`, `BAG_CONTAINER_UPDATE`, `CURSOR_CHANGED`, `PLAYER_REGEN_ENABLED/DISABLED` | Present. |

Other facts that matter here:

* Forever reports game type **`camelot`** and **interface `16001`** (client version 1.60.1).
  It uses the **Mainline** (retail) UI engine, so the Mainline `ContainerFrame.lua`
  combined bag is the frame being replaced. The client loads `<AddOn>_Camelot.toc` first,
  then falls back to `<AddOn>.toc`.
* Forever has the same addon restrictions as Midnight, but those restrictions (secret
  values) cover combat data: auras, unit health, cooldowns in encounters. **Bag and
  inventory addons are not affected.** Bagnon already ships a Forever build.
* The secret-value restrictions can change between patches. The acceptance tests (§10)
  include a check that bag data still reads correctly in combat and in instances.

**The one real limitation:** Blizzard's sort can't sort *within* a group of slots. It
sorts everything, or skips whole bags. "Sort each section separately" therefore needs one
of the two designs in §5. Both work. The spec recommends the simpler one for v1.

---

## 2. Concepts

| Term | Meaning |
|---|---|
| **Section** | A named, ordered group the user creates. It contains the items **assigned** to it that are currently in the bags. It never has empty slots, so its size is the number of assigned stacks present. |
| **Rest** | The built-in area that cannot be deleted. Holds every unassigned item and **all empty slots**. |
| **Assignment rule** | How the addon decides an item belongs to a section. There are two kinds: **by item type** (itemID, e.g. "all Hearthstones") and **by exact item** (item GUID, e.g. "this exact sword"). |
| **Reagent bag** | Shown as its own fixed area, labelled "Reagents", like Blizzard's UI. Items there can't be assigned in v1 (see open question Q5). |

Example: 20 slots, with Hearthstone, Mining Pick and Campfire assigned to "Essentials".
The window shows "Essentials (3)" with exactly 3 buttons, then "Rest (17)" with the other
items and every empty slot.

If an assigned item leaves the bags (equipped, sold, used up), its section shrinks. When
it comes back, the section grows again. Weapon-swap gear moves between the bags and the
character this way without any extra work.

---

## 3. User-facing behaviour

### 3.1 Window
* Replaces the default bag frame when bags are opened (B key, backpack button, "Open All
  Bags", opening a merchant, mailbox or bank). Uses the same hooks Bagnon uses:
  `ToggleAllBags`, `OpenAllBags`, `CloseAllBags`, `ToggleBackpack`, `OpenBackpack`, and
  the per-bag toggles.
* Layout from top to bottom:
  1. Title bar: search box, sort button, settings/menu button, close.
  2. Each user section in the user's order. Header shows `▸ Name (count)`, can collapse.
     Below it is a grid of item buttons.
  3. **Rest**: header, then a grid of items followed by empty slots.
  4. **Reagents**, shown only when a reagent bag is equipped.
  5. Footer: gold, free-slot count, e.g. `3 free / 20`.
* Columns are configurable (default 10). Sections start on a new row. Empty sections are
  hidden by default; there's an option to show them as a header with an empty drop zone.
* The window can be moved, its position is saved, and it closes with Escape (`UISpecialFrames`).

### 3.2 Creating and managing sections
* Menu → "New section…" asks for a name. A new section starts empty.
* Right-click a section header to get: Rename, Move up, Move down, Collapse/Expand, Delete,
  and "Clear items" (unassigns everything in it, so those items fall back to Rest).
* Deleting a section moves its items to Rest. Nothing physically moves, and there's no
  confirmation prompt unless the section has items.

### 3.3 Assigning items (drag and drop)
* **Drag an item from Rest and drop it on a section** (header or grid) to assign it to
  that section.
  * Under the hood: Blizzard's button `OnDragStart` puts the item on the cursor. The
    section's drop target calls `C_Cursor.GetCursorItem()`, reads the source bag/slot,
    stores the rule, then calls `ClearCursor()` so the item goes back to its own slot.
    In virtual mode (§5) nothing moves physically. The redraw puts it in the section.
* **Drag an item from one section to another** reassigns it.
* **Drag an item from a section onto Rest** unassigns it.
* **Drop on an item button inside a section.** Blizzard's default would swap the two items
  physically. While the cursor holds a bag item, the addon shows a **drop overlay** over
  each section's area, which catches the drop as "assign to this section". Rest keeps its
  normal behaviour, so dropping on a specific Rest slot still moves the item there.
* Alternatives that don't need dragging:
  * **Alt+Right-click** an item opens a menu: "Assign to ▸ <section>", "Remove from
    section", "Rule: this item type / this exact item".
  * `/bs add <section>` assigns the item under the mouse.
* Items picked up from outside the bags (character sheet, bank, merchant) and dropped on a
  section are **placed physically** into a free bag slot first with `PickupContainerItem`
  on an empty slot, and then assigned. If there are no free slots, show an error and do
  nothing.

### 3.4 Assignment rule granularity
* Default (decided here, can be changed, see Q2):
  * **Stackable or consumable items** use itemID. Every stack of that item goes to the
    section, including new ones you loot.
  * **Equippable, non-stackable items** use the exact GUID. "This sword", not every copy
    of that sword.
* The Alt+Right-click menu can change an item's rule between the two kinds.
* When a stack is split, both stacks have the same itemID and so stay in the same section.
  For GUID rules: if the GUID disappears after a merge, the item falls back to Rest. That
  is acceptable.

### 3.5 Sorting
* The **sort button** (and `/bs sort`) sorts every section **separately** and keeps
  sections in their order. See §5 for how.
* Right-click the sort button to choose: "Blizzard order" (default) or "Reverse".
  This maps to `SetSortBagsRightToLeft`.
* No sorting during combat. The button is disabled with a tooltip. A sort requested in
  combat runs after `PLAYER_REGEN_ENABLED`.

### 3.6 Everything else Bagnon-style users expect
* Search box. Use `C_Container.SetItemSearch` and the `isFiltered` flag, as Blizzard does.
  Sections with no matching items stay visible but dimmed.
* New-item glow, item-level / quality borders, junk icon, upgrade arrows, cooldown sweeps,
  quest-item markers. All of these come with `ContainerFrameItemButtonTemplate`.
* Bag-slot bar to equip and swap bags, like Blizzard's or Bagnon's.
* Tooltip line for assigned items: `Section: Essentials`.

### 3.7 Out of scope for v1
Bank, offline/alt viewing, automatic category rules ("all potions → Consumables"),
multiple windows, skins. The data model must leave room for automatic rules (see §6).

---

## 4. Architecture

```
BagSections/
  BagSections.toc            ## Interface: 16001     (game type check, see §8)
  BagSections_Camelot.toc    optional, if the addon also targets Midnight later
  Core.lua                   init, SavedVariables, slash commands, events
  Inventory.lua              scans bags → list of {bag, slot, itemID, guid, info}
  Rules.lua                  assignment lookup: item → sectionId | "rest"
  Layout.lua                 builds the section → buttons model, grid placement
  Frame.lua / Frame.xml      main window, headers, drop overlays, footer
  ItemButton.lua             pool of ContainerFrameItemButtonTemplate buttons
  Sorter.lua                 Blizzard sort wrapper (v1) and move engine (v2)
  Menu.lua                   context menus (Blizzard MenuUtil / dropdowns)
  Hooks.lua                  takes over the default bag open/close behaviour
  Locales/enUS.lua
```

Data flow: an event (`BAG_UPDATE_DELAYED` etc.) triggers `Inventory:Scan()`, which feeds
`Rules:Classify()`, then `Layout:Build()`, then `Frame:Render()`. Events are throttled:
the redraw runs at most once per frame (`C_Timer.After(0)`) after the last event.

---

## 5. Sorting design (the core question)

### Option A: virtual sections (recommended for v1)
Section membership is **only in the addon's data**. The addon window groups buttons by
section, whatever physical slot the items are in. Inside each section, buttons follow the
**physical order** (bag 0 slot 1, then onward, honouring the "sort right to left" setting).

Sorting is a plain `C_Container.SortBags()`. Blizzard's sort puts *all* items in its
standard order. Section membership doesn't change, so each section ends up showing its
items in Blizzard's standard order. **That is sorted within each section, with no extra
work.**

* Pros: very little code. Uses Blizzard's own sort (stack merging, reagent bag routing,
  bag-category flags). Can't break mid-sort. Works the same with any number of items.
* Con: section layout only exists in this addon's window. If the addon is disabled, or
  in Blizzard's own bag view, it's one normal sorted bag.
* Con: Rest shows empty slots at the end even though they're physically spread between
  items. That's fine for display. When you drop an item on an empty Rest button, it goes
  to that real bag/slot.

### Option B: physical sections (optional v2 / setting)
The addon keeps a real physical layout: section 1's items in the first N slots of the
backpack, then section 2, and so on, with Rest filling the remaining slots. Sorting needs
the addon's own sort engine:

1. Get the target order. Build a list of the destination slots, then the order of items
   for each section using a comparator that approximates Blizzard's: item class order →
   subclass → quality (desc) → item level (desc) → name → itemID → stack count (desc).
   Merge partial stacks first.
2. Respect bag families. A slot in a profession bag or the reagent bag only takes
   compatible items (`C_Container.GetContainerNumFreeSlots` returns `bagFamily`;
   `C_Item.GetItemFamily(itemID)`). Items that can't go into special bags are never
   placed there.
3. Turn the target order into a minimal list of swaps (cycle decomposition), then run the
   swaps **one at a time**: `PickupContainerItem(src)` then `PickupContainerItem(dst)`.
   Wait for `ITEM_LOCK_CHANGED` / `BAG_UPDATE_DELAYED`, or until both slots read
   `isLocked == false`, before the next swap. Keep a timeout and a retry limit.
4. Abort cleanly when combat starts, the cursor already holds something, the bags change
   from outside (looting mid-sort), or there's a vendor/trade/mail interaction. Then
   re-plan from the current state.

When Option B is enabled, dropping an item on a section also **moves it physically** to
the end of that section's range. That's the "move it to that section" behaviour.

* Pros: layout holds in any bag UI, and when the addon is off.
* Cons: much more code, can take a few seconds with many moves, and can be interrupted.
  Baganator and BankStack ship sort engines like this, so it's proven.

**Recommendation:** ship Option A first. It meets every requirement in the brief. Add
Option B behind a setting ("Keep sections physically in place") if users want it. Keep
`Sorter.lua` behind a small interface (`Sorter:Sort(layout, onDone)`) so the two are
interchangeable.

---

## 6. Data model (SavedVariables)

```lua
-- per character
BagSectionsCharDB = {
  version = 1,
  sections = {                     -- ordered list; "rest" is implicit and always last
    { id = "s1", name = "Essentials", collapsed = false },
    { id = "s2", name = "Weapon swap", collapsed = false },
  },
  rules = {
    byItemID = { [6948] = "s1", [2901] = "s1" },          -- Hearthstone, Mining Pick
    byGUID   = { ["Item-4184-0-40000ABC1234"] = "s2" },
    -- future: auto = { { match = "class:Consumable", section = "s3" } }
  },
  nextId = 3,
}

-- account wide
BagSectionsDB = {
  version = 1,
  frame = { point = "BOTTOMRIGHT", x = -60, y = 100, columns = 10, scale = 1 },
  showEmptySections = false,
  sortMode = "virtual",            -- "virtual" (A) | "physical" (B)
  reverseSort = false,
  stackableRule = "itemID", equippableRule = "guid",
}
```

Lookup order in `Rules:Classify(item)`: `byGUID[guid]`, then `byItemID[itemID]`, then
(future) auto rules, then `"rest"`. If a section ID no longer exists, that rule is ignored
and removed the next time data is saved.

Store sections **per character** because each character carries different things. A
"Copy sections from <character>" option can be added later.

---

## 7. Taint and combat rules (must follow)

1. Create every item button **out of combat**. Pre-create enough for the largest bag set
   (about 200), and grow the pool only after `PLAYER_REGEN_ENABLED`.
2. Build buttons from **`ContainerFrameItemButtonTemplate`**. Set the bag with
   **`button:SetBagID(bag)`** (attribute-based, as Blizzard intends) and the slot with
   `button:SetID(slot)`. **Never replace** the button's `OnClick`, `OnDragStart` or
   `OnReceiveDrag`. Use `HookScript` for any extra behaviour, and catch drops with the
   separate drop overlay frames from §3.3.
3. Don't change the template's Blizzard mixin methods or global functions.
   Use `hooksecurefunc` only for open/close hooks.
4. Moving and re-anchoring buttons in combat is fine because they aren't protected
   frames. Still keep layout cheap and throttled. Test using a Hearthstone, potion or food
   from the addon's window **in combat** (acceptance test T7).
5. Don't call `SortBags` or run the physical move engine in combat.
6. Never treat container values as secret. If a future patch makes any of them secret
   (`issecretvalue(v)`), fall back to showing the raw slot without classifying it rather
   than raising a Lua error.

---

## 8. Client targeting

* Primary target: WoW: Forever, game type `camelot`, `## Interface: 16001`.
  Increase the number when Blizzard changes it at launch (Forever launches 2026-11-04).
* Detection at runtime: check that `C_Container` exists and that
  `C_Container.GetContainerNumSlots(Enum.BagIndex.ReagentBag)` is non-nil. Don't use
  `WOW_PROJECT_ID` alone, because Forever reports `WOW_PROJECT_MAINLINE`.
* Because Forever shares the Mainline API, the same code should run on retail Midnight
  with only a second Interface number. That's optional and not a v1 goal.

---

## 9. Edge cases

| Case | Behaviour |
|---|---|
| A bag is removed or swapped | Rescan. Membership doesn't change because it's item-based, not slot-based. |
| Bags are full and an item is dragged into a section from the character sheet | Show an error and leave the item where it was. |
| Item data not cached yet (`GetItemInfo` returns nil) | Render with the icon and stack count from container info. Re-render on `GET_ITEM_INFO_RECEIVED`. |
| Item is on the cursor when the bags close | Don't touch it. The cursor stays as Blizzard leaves it. |
| A merchant is open | Right-click sells, as normal. The section shrinks by itself. |
| The same item type is in a GUID rule for section X and an itemID rule for section Y | The GUID rule wins. |
| A section's ID is deleted while items are assigned | Those items go back to Rest. |
| Keyring (`BagIndex.Keyring`) | Show it as its own area only if `GetContainerNumSlots(-1) > 0`. |

---

## 10. Acceptance tests (manual, in game)

* **T1** Create "Essentials". Drag Hearthstone, Mining Pick and Campfire in. The header
  shows `(3)`, there are no empty buttons in the section, and Rest shows 17 slots in total.
* **T2** Press sort. Essentials is in Blizzard order, Rest is in Blizzard order, and
  sections keep their order.
* **T3** `/reload`. Sections and assignments are still there.
* **T4** Equip a sword from "Weapon swap". The section shrinks. Unequip it and it reappears
  in the section.
* **T5** Drag an item from a section onto Rest. It is unassigned.
* **T6** Delete a section. Its items appear in Rest.
* **T7** In combat, right-click a potion or food in a section. It is used, and there's no
  "AddOn blocked" or taint error (check with `/console taintLog 1`).
* **T8** Loot a second Hearthstone-type stack (an itemID rule). It joins Essentials by
  itself.
* **T9** Search filters items in all sections.
* **T10** Equip a reagent bag. The "Reagents" area appears, and sorting still routes
  reagents there.
* **T11** (Option B only) After sorting, open Blizzard's default bags (addon disabled).
  The Essentials items are in the first slots of the backpack.

---

## 11. Milestones

1. **M1**: Window that replaces the default bags, a combined grid using item-button
   pool, and search. (Bagnon-lite)
2. **M2**: Sections: create, rename, delete and reorder; the rules store; drag-and-drop
   assignment; Alt+Right-click menu; tooltip line.
3. **M3**: Sorting Option A, collapse, settings panel (`Settings.RegisterCanvasLayoutCategory`).
4. **M4** (optional): Option B physical move engine.
5. **M5** (optional): automatic category rules, bank support, sharing sections between
   characters.

---

## 12. Open questions for the owner

* **Q1. Virtual or physical sections?** Should sections only exist in this addon's window
  (Option A, recommended), or must items also *physically* sit in those slots, so the
  layout holds in Blizzard's bags (Option B)?
* **Q2. Item type or exact item?** When you drag a Hearthstone into Essentials, should
  *every* Hearthstone go there (item type)? When you drag a sword, should only *that*
  sword go there (exact item)? The current default is item type for stackables and exact
  item for gear.
* **Q3. Fixed size?** The brief says "allocate 3 slots". This spec treats a section's size
  as the number of items in it, with no empty slots. Is that right, or should a section
  also reserve a fixed number of slots?
* **Q4. Section position:** Should sections always be above Rest, or can Rest be moved
  between sections?
* **Q5. Reagent bag:** Keep it separate, as now, or allow reagent-bag items to be
  assigned to sections too?
* **Q6. Bank:** Is a sectioned bank wanted later?

---

## 13. Implementation notes (v0.1)

* **Opening the window:** the open/toggle functions (`ToggleBackpack`, `ToggleAllBags`,
  `OpenBackpack`, `OpenAllBags`, and `ToggleBag`/`OpenBag` for bags 0–5 and the keyring)
  are replaced, as Bagnon does. The close functions are only post-hooked with
  `hooksecurefunc`, so Blizzard's Escape and game-menu paths never run addon code. Bank
  bags still go to Blizzard's code. Settings has an option to turn the takeover off.
* **Empty sections while dragging:** empty sections are always shown while a bag item is on
  the cursor, so a brand-new section can receive its first item.
* **Bag-slot bar:** not included. Bags are still equipped and swapped from Blizzard's bag
  bar.
* **Money:** shown as text, not with Blizzard's money frame template.

### v0.2 additions

* **Sections below Rest:** each section has a `below` flag, toggled from its right-click
  menu. Order is: sections above Rest, Rest, sections below Rest, Reagents, Keyring.
  Move up/down only swaps with sections on the same side of Rest.
* **Collapse for built-in groups:** Rest, Reagents and Keyring can collapse like sections.
  This is stored per character in `collapsedBuiltin`.
* **Layouts:** `BagSectionsDB.layout` is `"default"` (unchanged) or `"compact"`.
  Compact draws each group as a block outlined in the group's colour, sized to its items
  and label, and packs blocks into the window width with bottom-left packing
  (`Layout.Pack`). Each section stores a `color`. New sections take the next colour from
  a palette. Colours can be changed with Blizzard's colour picker.

### v0.3 additions

* **Automatic Quest Items section** (per character, `charDB.autoQuest`): a section with
  `auto = "quest"` catches items where `GetContainerItemQuestInfo` reports a quest item or
  quest starter, or whose item class is `Enum.ItemClass.Questitem`. Classification order
  is: exact-item rule, item-type rule, automatic section, Rest. Dragging an
  auto-matched item to Rest stores an item-type rule pointing at `"rest"`, so the item
  stays out.
* **Profiles** (account wide, `BagSectionsDB.profiles`): each profile stores the section
  list only (name, order, colour, below/above Rest, collapsed, auto flag), not item rules.
  Loading matches existing sections by name, case-insensitive, and keeps their items.
  Sections not in the profile are removed after a confirmation. The UI is a button in
  Settings and a submenu in the gear menu.

### v0.4 changes

* **Compact layout, second version** (replaces the packed boxes). All groups flow through
  one grid of `columns` columns in order, each a contiguous run of cells (`Layout.Flow`).
  `Layout.RunPolygons` gives each run's outline as clockwise orthogonal polygons (two when
  a wrapping run doesn't overlap itself). They're drawn as 2px lines inset 1px, so
  neighbouring outlines sit side by side. Each name goes on the longest stretch of its
  run's top edge (`Layout.LabelSegment`), in a taller gap above that row, and may extend
  until the next name on that row starts. Empty and collapsed groups take enough cells
  for their name.
* **No jumping:** the compact arrangement is frozen while the window is open. Bag-content
  events (`"items"` refresh) reuse it and only update counts. It's rebuilt on open, on
  player actions (`"layout"` refresh), on bag container changes, and for 3 seconds after
  a sort.
* **Rest position setting** (`restPosition`: `"bottom"` default, or `"top"`): decides
  whether new sections, including the Quest Items section, are created above or below
  Rest.
* Gold text in the footer uses the same font size as section names.

### v0.5 changes

* **Compact spacing:** outlines sit 5px from the items on every side, with 8px between
  neighbouring outlines. A section that starts partway along a row is shifted right to
  make room, and wraps earlier if needed (`Layout.FlowRows`). Rows inside a single
  section keep normal spacing; rows where sections meet get room for both outlines.
  Outlines are built from padded per-row strips (`Layout.Strips`,
  `Layout.StripPolygons`). Steps sit on the edge of the wider row, so padding is even.
* A wrapped section whose parts don't touch gets a name on each part
  (`Layout.TopEdges`).

### v0.6 changes

* **Strict grid in compact:** every row has the same slots in the same columns, so slots
  line up. Sections no longer shift right to make room. Instead, all slots in compact
  are 10px apart (default layout: 4px), which leaves room for outlines between any two
  neighbouring sections. The compact window is a little wider than the default layout
  as a result.
* **Thinner outlines:** 1px at 70% opacity, 3px from the items on every side.
* **Outlines above slots:** item buttons' slot art is larger than the slot (a 64px frame
  texture on a 37px button) and was covering parts of the outlines. Outlines now draw
  above the buttons. They only sit in the gaps between slots, so they never cover icons.
* **Reagents and Keyring separated:** in compact they sit in their own grid below a thin
  divider, as in the default layout, with a smaller gap.
* **One name per section:** a wrapped section whose parts don't touch shows its name
  once, on its longest stretch of top edge. The outline colour ties the parts together.

## Sources

* Blizzard UI source, Forever branch (build 1.60.1.70124):
  <https://github.com/Gethe/wow-ui-source/tree/forever>. Specifically
  `Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua`,
  `BagIndexConstantsDocumentation.lua`, `BagConstantsDocumentation.lua`,
  `CursorDocumentation.lua`, `ItemDocumentation.lua`, and
  `Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua` / `.xml`.
* Forever TOC suffix / interface 16001 / `camelot` game type:
  <https://github.com/Ludovicus-Maior/WoW-Pro-Guides/pull/3460>
* Forever launch date and beta: <https://news.blizzard.com/en-us/article/24304160/the-world-of-warcraft-forever-beta-now-live>,
  <https://blizzardwatch.com/2026/09/17/world-warcraft-forever-beta/>
* Forever uses Midnight's addon restrictions:
  <https://kami-labs.fr/en/wow-classic/wow-forever-addons-restreints-comme-sur-midnight/>
* Bagnon has a Forever release: <https://www.curseforge.com/wow/addons/bagnon/files/9013777>
* Reagent bag slot in Forever: <https://www.warcrafttavern.com/forever/news/changes-to-bags-banks-in-world-of-warcraft-forever/>
* Similar addons to study: Bagnon, Baganator (its own sort engine and custom categories),
  BetterBags, ArkInventory, AdiBags.
