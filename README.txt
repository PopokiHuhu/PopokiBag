POPOKI BAG 1.0.4 - plecak z kategoriami dla WoW Forever
=========================================================

Popoki Bag zastępuje zwykły plecak własnym oknem, w którym przedmioty są od razu
posegregowane według tego, co z nimi zrobić: zostawić, sprzedać u vendora, wystawić
na aukcję albo odłożyć do banku. Napisy w grze są po angielsku.


INSTALACJA
----------
1. Wypakuj zip tak, żeby powstał folder:
   World of Warcraft\_forever_\Interface\AddOns\PopokiBag
   (w środku od razu pliki .lua i PopokiBag.toc, bez dodatkowego podfolderu).
2. Jeśli używasz EllesmereUI: na ekranie wyboru postaci -> AddOns -> odznacz TYLKO
   "EllesmereUIBags" (reszta EllesmereUI może zostać). Inaczej klawisz B otworzy stary
   plecak, a Popoki Bag będzie dostępny tylko przez /popoki.
3. Zalecane (nieobowiązkowe):
   - Auctionator: ceny z AH, podział na For Vendor / For Auction, okno wystawiania.
     Bez niego wszystko liczy się po cenie u vendora.
   - RestedXP: przedmioty potrzebne w guide'ach trafiają do Quest Items.


CO JEST W OKNIE
---------------
Lewy pasek - widoki:
  Categories   - główny widok, przedmioty w kategoriach (poniżej)
  (kategorie)  - każda kategoria osobno
  Bags         - fizyczne torby z pustymi slotami
  All Items    - wszystko, pogrupowane wg rodzaju (Weapons, Armor, Trade Goods...)
  "Use me!"    - na dole paska: rzeczy do użycia od razu (start questa, receptura,
                 którą możesz się nauczyć, koperty i sakiewki do otwarcia)

Kategorie (kolejność zmienisz przyciskiem Edit w lewym pasku):
  Essentials   - hearthstone, rzeczy do obozu (namiot, ognisko, Simple Wood...),
                 narzędzia profesji, klucze
  Consumables  - jedzenie, mikstury, scrolle
  <Twoje profesje> - np. Skinning, Mining, Herbalism: materiały do Twoich profesji
                 głównych (zbieracz + rzemieślnik łączą się, np. Skinning + LW)
  For Vendor   - szare, soulbound, i to, co na AH się nie opłaca
  For Auction  - to, co na AH daje >= 150% ceny vendora i >= 2s więcej (zmienisz w ustawieniach)
  To Bank      - receptury na wyższy poziom profesji, rzeczy wzmacniające Twoje profesje
  Misfits      - rzeczy bez ceny i niejasne, plus to, czego kazałeś nie sprzedawać
  Quest Items  - przedmioty questowe i z guide'ów RestedXP

Amunicja nie jest w kategoriach - jej ilość widać w stopce ("Ammo: ...").
W stopce jest też "Cash-in": ile dostaniesz, sprzedając For Vendor, For Auction i materiały.


PRZECIĄGANIE I UKŁADANIE
------------------------
- Przeciągnij przedmiot na "+" w sekcji, na nagłówek sekcji, na nazwę kategorii w lewym
  pasku albo na przedmiot z innej sekcji -> ten rodzaj przedmiotu zostaje tam na stałe.
- Przeciągnięcie w obrębie sekcji zamienia przedmioty miejscami; kolejność jest zapamiętana.
- Nowe przedmioty świecą do zamknięcia plecaka i pojawiają się na początku sekcji.
- Kliknięcie w nagłówek sekcji ją zwija/rozwija.
- Ikona torby w nagłówku: pasek założonych toreb (przeciągnij nową torbę, żeby ją założyć).
- Shift + klik na stosie dzieli go; oddzielona część sama trafia do wolnego slotu.
- Niepełne stosy tego samego przedmiotu łączą się same (poza walką i oknami NPC;
  stos podzielony ręcznie zostaje rozdzielony przez 5 minut).
- Plecak zawsze otwiera się na widoku Categories.


PEŁNY PLECAK - "MAKE ROOM"
--------------------------
Gdy gra powie, że plecak jest pełny, otwiera się okno "Make room" (albo przycisk
Make room w nagłówku plecaka; drugi klik zamyka). Pokazuje najtańsze rzeczy w plecaku,
liczone po tym, co faktycznie leży w slocie (1 skóra z 20 to grosze).
Przy otwartym lootcie u góry jest werdykt: "Worth it" (warto coś wyrzucić) albo
"Not worth it" (to, co podnosisz, jest warte mniej niż wszystko na liście).
Klik zaznacza, drugi klik niszczy - i od razu zabiera to, czego nie dało się podnieść.
Nigdy nie proponuje: Quest Items (też tych z RestedXP), Essentials, Consumables,
Misfits, "Use me!", zielonych "of the ..." i rzeczy bez ceny.


OKNA PRZY NPC (otwierają się same, wyłączysz w ustawieniach)
------------------------------------------------------------
Vendor:   "Sell to vendor" - lista z For Vendor (i zakładki Twoich profesji).
          Lewy klik = sprzedaj ten przedmiot, prawy = zostaw (keep), Sell all = resztę.
          Ostatnie 12 sprzedanych przedmiotów odkupisz u vendora (buyback).
AH:       "Post to auction" - klik ładuje przedmiot do zakładki Selling Auctionatora,
          który sam dobiera cenę; Post (albo spacja) wystawia, potem wskakuje następny.
          Każdą aukcję trzeba kliknąć - gra nie pozwala addonom wystawiać samym.
Bank:     "Put in bank" - lewy klik = odłóż, prawy = zostaw, Deposit all = resztę.


USTAWIENIA I KOMENDY
--------------------
Zębatka w nagłówku plecaka albo /popoki settings:
  próg AH (% i minimalny zysk), automatyczne okna przy NPC, świecenie nowych
  przedmiotów, kolorowanie pancerza, łączenie stosów, okno Make room.

/popoki            - otwórz / zamknij plecak (działa też stare /plecak)
/popoki settings   - ustawienia
/popoki room       - okno Make room
/popoki quests     - lista przedmiotów questowych: potrzebne / nie ma ich w dzienniku questów
/popoki armor      - jaki typ pancerza addon rozpoznał u postaci
/popoki reset      - przywróć domyślną pozycję okna


DOBRZE WIEDZIEĆ
---------------
- Wszystko jest liczone dla postaci, którą grasz: profesje i ich poziomy, typ pancerza
  (czerwony = za ciężki, żółtawy = lżejszy niż nosisz), ręczne przypisania i kolejność.
- Przedmioty z przyrostkiem "of the ..." (np. Durable Hat of the Sorcerer): Auctionator na
  Forever trzyma jedną cenę dla wszystkich wariantów, więc jego cena w tooltipie bywa
  mocno zaniżona. Takie zielone przedmioty idą zawsze do For Auction, a prawdziwą cenę
  pokazuje dopiero okno wystawiania (z zakładki Selling).
- Przedmiot questowy z czerwoną kropką = nie ma go w celach żadnego questa z dziennika.
  Pewnie zbędny, ale sprawdź przed wyrzuceniem (niektóre przedmioty się oddaje albo używa).
- Okno aukcji korzysta z wewnętrznych mechanizmów Auctionatora; jeśli Auctionator się
  zmieni, może przestać ładować przedmioty (reszta plecaka działa dalej).
- Gdy coś nie działa: wpisz raz /console scriptErrors 1, żeby widzieć błędy Lua.
