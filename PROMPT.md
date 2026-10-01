# Build prompt (paste into a coding agent)

> You are building **BagSections**, a World of Warcraft addon for the **WoW: Forever**
> client (game type `camelot`, `## Interface: 16001`, Mainline/retail Lua API, Midnight
> addon restrictions). The full specification is in `SPEC.md` in this repo. Read it
> completely before writing code, and follow it. If the spec and this prompt disagree,
> the spec wins.
>
> **Goal:** a combined bag window, Bagnon-style, that replaces the default bags. The user
> creates named **sections**. A section contains only the items assigned to it, so it
> never has empty slots. Everything else, plus all empty slots, is shown in one **Rest**
> area. Dragging an item from Rest onto a section assigns it to that section. Sorting
> sorts each section separately.
>
> **Hard requirements**
> 1. Lua + XML only, no external libraries (Ace3 is optional, but don't add it unless it's
>    needed). SavedVariables: `BagSectionsDB` (account), `BagSectionsCharDB` (per char).
> 2. Item buttons must be built from Blizzard's `ContainerFrameItemButtonTemplate`.
>    Set the bag with `button:SetBagID(bag)` and the slot with `button:SetID(slot)`.
>    Never overwrite their `OnClick`/`OnDragStart`/`OnReceiveDrag`. Only use `HookScript`.
>    Create the button pool out of combat.
> 3. Catch drops on sections with separate drop overlay frames that only show while
>    `C_Cursor.GetCursorItem()` returns an item. Read the source bag/slot from the
>    returned `ItemLocation`, store the rule, then `ClearCursor()`.
> 4. Membership rules: itemID for stackables, item GUID (`C_Item.GetItemGUID`) for
>    equippable non-stackables. The GUID rule wins over the itemID rule.
> 5. Sorting v1 = "virtual sections" (spec §5 Option A): call `C_Container.SortBags()`
>    and render each section's items in physical bag order. Put the sort engine behind
>    `Sorter:Sort(layout, onDone)` so a physical move engine (Option B) can be added later.
> 6. No sorting in combat. Queue it until `PLAYER_REGEN_ENABLED`.
> 7. Throttle redraws: rescan on `BAG_UPDATE_DELAYED`, `ITEM_LOCK_CHANGED`,
>    `BAG_CONTAINER_UPDATE`, `INVENTORY_SEARCH_UPDATE`, `GET_ITEM_INFO_RECEIVED`, and
>    redraw at most once per frame.
> 8. Use the file layout in spec §4. Deliver milestones M1 to M3 from spec §11.
>
> **Verification:** there's no game client in your environment, so:
> * keep the code `luacheck`-clean, with WoW globals listed in `.luacheckrc`;
> * put the pure logic (rule classification, layout building, swap planning) in modules
>   that don't depend on the game, and unit-test them with `busted` using a mocked
>   `C_Container`;
> * write the manual in-game test checklist from spec §10 into `TESTING.md`.
>
> Ask before going against the spec. The open questions in spec §12 have defaults in the
> spec. Use those defaults unless the owner has answered.
