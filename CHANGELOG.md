# Changelog

## 1.0.12

### New
- **Bank window in Popoki Bag style:** at a banker the bank opens next to your bags with the same theme, search and views (Categories, Bags, All Items). Right-click and dragging move items between bank and bags as usual.
- **Deposit button** in the bank header opens the "Put in bank" list (To Bank and your profession items).
- **Bank bag slots** in the Bags view - drag a bag onto a bought slot to put it in the bank.
- **Bank button in the bag header:** see what was in your bank on your last visit, from anywhere (view only).
- **"In bank: N"** on item tooltips.
- **Right-click menu in the bank:** Sort, Deposit, Settings.
- New setting "Popoki Bag bank window" - turn it off to get the default bank back.

### Changed
- Sort now orders bag and bank items together, so both windows use the same order.
- "Buy bag slot" and "Default bank" switch to the game's own bank window for that visit - the game only lets its own window buy bank slots.

### Fixed
- Unknown game events no longer stop a part of the addon from loading.

## 1.0.11

### Fixed
- Make room: the "Picking up" box no longer shows a question mark and an empty name for items the game hasn't loaded yet. The icon and name appear right away, and the price and verdict fill in as soon as the item data arrives.
- Make room: coins and other non-item loot are ignored when picking what you're looting.

### Changed
- The release zip is now named `PopokiBag-X.Y.Z-forever.zip` so the WowUp Hub can match it to WoW Forever.

## 1.0.10

### New
- **Make room shows what you're picking up:** a box at the top with the item's icon, name and amount, plus its vendor and AH value next to it - hover it for the full tooltip. The verdict above it ("Worth it" / "Not worth it") is now shorter.

## 1.0.9

### New
- **Right-click menu:** right-click the bag background for Sort, Clean and Pack, with Settings below a line. Right-click again to close it.
  - **Sort** - orders the items inside each category by type (the old Cleanup button).
  - **Clean** - opens the Make room window.
  - **Pack** - moves items into the first bags so the last one can be emptied.
- **Compact mode in the Blizzard theme** has no left panel at all - the Categories / Bags / All Items icons sit in the header row next to the slot counter.

### Changed
- **The bag window resizes freely** - no more snapping; the grid fits as many columns as it can (6-16) and the rest is margin.
- The Cleanup button is gone from the header (it's "Sort" in the right-click menu), so the header buttons no longer overlap in a small window.
- The header row in the Blizzard theme sits a bit lower, with some space under the title bar.

## 1.0.8

### New
- **Compact mode** (Settings -> Look): the left panel becomes a column of icons (Categories, Bags, All Items) and the header buttons turn into icons. "Use me!" becomes the first section of Categories, highlighted in gold, and only shows up when there's something to use.
- **Cleanup** button (broom, next to the slot counter): orders the items inside each category by type - e.g. Consumables: food, drinks, potions, elixirs, flasks, scrolls, bandages. Nothing moves in your bags.
- **Resizable bag window:** drag the bottom-right corner - width snaps to 6-16 columns, height is free. /popoki reset restores the default.
- New settings: hide the categories from the left panel, turn off colored category names.

### Changed
- **Bags are never put up for sale:** a bag bigger than your smallest equipped one goes to "Use me!" (equip it), other bags, quivers and ammo pouches go to Essentials.
- Forever bundle crates ("Crate: ...") now go up for sale (For Vendor or For Auction) instead of To Bank.
- Items only for other classes (e.g. mage scrolls when you're not a mage) go up for sale.
- Make room has a fire icon; "Sort bags" in the Bags view is now called **Pack**.
- Make room also lists your "Use me!" items at the top (marked "use it") - using them frees a slot without destroying anything.

## 1.0.7

### Fixed
- Items from RestedXP guides leave Quest Items once their quest is turned in. Items collected ahead of a quest you haven't picked up yet stay protected.
- Fewer false "probably not needed" red dots on quest items: an item now counts as needed when the quest objective mentions it in other words (e.g. "Sarah's Ring" -> "Take Sarah Ladimore's ring to...").

## 1.0.6

### New
- **Cash-in breakdown:** the Cash-in total in the footer is now clickable - it lights up on hover and shows how much comes from For Vendor, For Auction and profession materials.
- **Make room highlights the swap:** with loot open, items cheaper than what you're picking up are marked green, the rest is dimmed. The verdict is bigger and updates live as the loot changes.

### Changed
- Make room no longer suggests ammo or anything in a quiver, ammo pouch or reagent bag - dropping those doesn't free a normal slot.

## 1.0.5

### New
- **Themes:** Dark and Blizzard (game-style frame on dark stone) for all windows - switch in Settings → Look → Theme.
- **Sort bags** button in the Bags view: packs items into the first bags so the last one can be emptied. Categories don't change.

### Changed
- Cleaner bag header: **Make room** and **Bags** buttons next to the search box, settings **gear** next to the X.
- Categories in the left panel are smaller and indented under *Categories*.
- New collapse icons on section headers.
- The footer (Ammo / Cash-in / gold) is now a separate bar.
- Settings window is wider so all text fits.

### Fixed
- Windows no longer overlap or show through each other; Settings and Make room open side by side.
- Header row and buttons are aligned in both themes.

### Other
- README is now in English.

## 1.0.4

- **Make room** window: opens when your bags are full (or from the header button) and lists the cheapest things to destroy, with a "Worth it / Not worth it" verdict for the loot you couldn't pick up.
- Partial stacks merge automatically.
- The bags always open on the Categories view.

## 1.0.3

- Splitting a stack (Shift + click) puts the split part straight into a free slot.

## 1.0.2

- First attempt at stack splitting (didn't work - fixed in 1.0.3).

## 1.0.1

- Marked as a WoW Forever addon for the WowUp catalogue.

## 1.0.0

- First version.
