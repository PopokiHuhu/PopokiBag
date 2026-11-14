POPOKI BAG 1.0.12 - bags sorted into categories for WoW Forever
================================================================

Popoki Bag replaces the default bags with its own window where items are already
sorted by what to do with them: keep, sell to a vendor, post on the auction house
or put in the bank.


INSTALLATION
------------
1. Install with WowUp (Get Addons -> Install from URL -> https://github.com/PopokiHuhu/PopokiBag)
   to get automatic updates, or unzip so that this folder exists:
   World of Warcraft\_forever_\Interface\AddOns\PopokiBag
   (with the .lua files and PopokiBag.toc directly inside, no extra subfolder).
2. If you use EllesmereUI: on the character screen -> AddOns -> untick ONLY
   "EllesmereUIBags" (the rest of EllesmereUI can stay). Otherwise B opens the old
   bags and Popoki Bag is only available through /popoki.
3. Recommended (optional):
   - Auctionator: AH prices, the For Vendor / For Auction split, the posting window.
     Without it everything is valued at vendor price.
   - RestedXP: items needed by its guides go to Quest Items.


THE WINDOW
----------
Left panel - views:
  Categories   - the main view, items in categories (below)
  (categories) - each category on its own
  Bags         - your physical bags with empty slots; "Pack" moves items into the first
                 bags so the last one can be emptied (categories don't change)
  All Items    - everything, grouped by type (Weapons, Armor, Trade Goods...)
  "Use me!"    - bottom of the panel: things to use right away (quest starters,
                 recipes you can learn now, envelopes and pouches to open, and bags
                 bigger than your smallest equipped bag - equip them)

Categories (reorder them with the Edit button in the left panel):
  Essentials   - hearthstone, camp items (tent, campfire, Simple Wood...),
                 profession tools, keys, spare bags, quivers and ammo pouches
  Consumables  - food, potions, scrolls
  <your professions> - e.g. Skinning, Mining, Herbalism: materials for your primary
                 professions (gathering + crafting are merged, e.g. Skinning + LW)
  For Vendor   - greys, soulbound items, and anything not worth posting on the AH;
                 also Forever bundle crates and items only for other classes
                 (e.g. mage scrolls when you're not a mage) - or For Auction if they sell well
  For Auction  - items the AH pays >= 150% of vendor price and >= 2s more for
                 (change it in settings)
  To Bank      - recipes for a higher profession level, items that boost your professions
  Misfits      - items with no price or unclear ones, plus anything you chose to keep
  Quest Items  - quest items and items used by RestedXP guides

Ammo isn't in a category - the footer shows how much you have ("Ammo: ...").
The footer also shows "Cash-in": what you'd get for For Vendor, For Auction and materials
(click it for the breakdown).


DRAGGING AND ORDER
------------------
- Drop an item on a section's "+", on a section header, on a category name in the left
  panel or on an item in another section -> that kind of item stays there for good.
- Dragging within a section swaps items; the order is remembered.
- New items glow until you close the bags and show up first in their section.
- Clicking a section header collapses / expands it.
- Bags button in the header: the bar with your equipped bags (drag a new bag onto a slot
  there to equip it).
- Right-click the bag background for a small menu (right-click again to close it):
  Sort (orders the items inside each category by type), Clean (the Make room window),
  Pack (empties the last bag) and - below a line - Settings.
  Sort orders each category by type
  (e.g. Consumables: food, drinks, potions, elixirs, flasks, scrolls, bandages).
  Nothing moves in your bags; drag items afterwards if you want a different order.
- Shift + click a stack to split it; the split part goes straight to a free slot.
- Partial stacks of the same item merge automatically (not in combat or with NPC
  windows open; a stack you split yourself stays split for 5 minutes).
- The bags always open on the Categories view.
- Drag the corner grip (bottom right) to resize freely; the grid fits as many columns
  as it can (6-16).
  /popoki reset restores the default size and position.

THE BANK
--------
At a banker the bank opens in a Popoki Bag window next to your bags (same theme, search
and views: Categories, Bags, All Items). Right-click moves items between bank and bags,
dragging works both ways. Right-click the bank background for Sort, Deposit and Settings.
- Deposit (header button): the "Put in bank" list with To Bank and your profession items.
- Bags view: the 8 bank bag slots - drag a bag onto a bought slot to put it in the bank.
- Buy bag slot / Default bank (footer): switch to the game's own bank window for this
  visit. Buying bank slots only works there - the game blocks addons from doing it.
- Bank button in the bag header: see what was in your bank on your last visit, from
  anywhere (view only).
- Item tooltips show how many you have in the bank ("In bank: 12").
- Don't like it? Settings -> "Popoki Bag bank window" off brings back the default bank.


FULL BAGS - "MAKE ROOM"
-----------------------
When the game says your bags are full, the "Make room" window opens (or use the
Make room button in the bag header; click it again to close). It lists the cheapest
things you carry, valued by what is actually in the slot (1 hide out of 20 is pennies).
With loot open, the item you're picking up is shown at the top (icon, name, value -
hover it for the full tooltip) with a verdict: "Worth it" (drop something) or "Not worth it"
(what you're picking up is worth less than anything on the list).
Click to select, click again to destroy - and the loot you couldn't take is picked up.
At the top, marked blue "(use it)": your "Use me!" items - using them (learning a recipe,
equipping a bag, starting a quest) frees a slot without destroying anything.
Never suggested: Quest Items (including RestedXP ones), Essentials, Consumables,
Misfits, "Use me!", green "of the ..." items, items with no price, ammo and anything
in a quiver, ammo pouch or reagent bag (dropping those frees no normal slot).


NPC WINDOWS (open automatically, can be turned off in settings)
--------------------------------------------------------------
Vendor:   "Sell to vendor" - For Vendor items (plus tabs for your professions).
          Left click = sell this item, right click = keep it, Sell all = the rest.
          You can buy back the last 12 items sold at the vendor.
AH:       "Post to auction" - click loads the item into Auctionator's Selling tab,
          which picks the price; Post (or space) posts it, then the next one loads.
          Every auction needs a click - the game doesn't let addons post on their own.
Bank:     "Put in bank" - left click = deposit, right click = keep, Deposit all = the rest.


SETTINGS AND COMMANDS
---------------------
The gear next to the X in the bag corner, or /popoki settings:
  AH threshold (% and minimum profit), NPC windows, new item glow, armor colors,
  stack merging, the Make room window, theme for all windows (Dark or Blizzard),
  Compact mode (the left panel becomes a column of icons and the header buttons turn
  into icons), the Popoki Bag bank window,
  categories in the left panel and colored category names (both can be turned off).

/popoki            - open / close the bags (/plecak works too)
/popoki settings   - settings
/popoki room       - the Make room window
/popoki quests     - quest items: needed / not found in your quest log
/popoki armor      - which armor type the addon detected for your character
/popoki reset      - reset the window position


GOOD TO KNOW
------------
- Everything is per character: professions and their levels, armor type
  (red = too heavy for you, yellowish = lighter than you wear), manual assignments, order.
- Items with an "of the ..." suffix (e.g. Durable Hat of the Sorcerer): on Forever
  Auctionator keeps one price for all variants, so its tooltip price can be far too low.
  Such green items always go to For Auction; the real price shows in the posting window
  (Selling tab).
- A quest item with a red dot isn't in the objectives of any quest in your log.
  Probably not needed, but check before throwing it away (some items are handed in or used).
- The auction window uses Auctionator internals; if Auctionator changes, loading items
  may stop working (the rest of the bags keeps working).
- If something breaks: type /console scriptErrors 1 once to see Lua errors.
