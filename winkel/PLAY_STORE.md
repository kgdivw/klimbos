# Het Klimbos in de Google Play Store

Alles wat al klaar is staat in deze map. Wat je nog zelf moet doen staat in de
checklist hieronder (een account aanmaken, betalen en je wachtwoord kiezen kan
alleen jij).

## Wat er al klaarstaat

| Wat | Waar |
|---|---|
| Android-build (`.aab`) | GitHub bouwt hem bij elke push: repo → *Actions* → laatste run → *Artifacts* → `HetKlimbos-android-…`. Zonder uploadsleutel zit er alleen een test-APK in. |
| Test-APK om zelf op een tablet te zetten | zelfde download (`HetKlimbos-test.apk`) |
| Versienummer | gaat vanzelf omhoog (= nummer van de GitHub-run); Google eist dat elke upload hoger is |
| App-icoon 512×512 | `play_icoon_512.png` |
| Feature graphic 1024×500 | `feature_graphic_1024x500.png` |
| Schermafbeeldingen 1920×1080 (telefoon + tablet) | `schermafbeeldingen/` |
| Privacyverklaring | https://kgdivw.github.io/klimbos/privacy.html |
| Pakketnaam | `io.github.kgdivw.klimbos` — **kan na de eerste upload nooit meer veranderen** |
| Uploadsleutel maken + op GitHub zetten | `maak_uploadsleutel.bat` (dubbelklikken) |

Opnieuw winkelplaatjes maken (bijv. na een update):
`godot --path . --fixed-fps 30 res://scenes/_winkel.tscn` (schermafbeeldingen) en
hetzelfde met `-- banner` erachter (feature graphic).

## Checklist

1. **Ontwikkelaarsaccount** aanmaken op https://play.google.com/console
   (eenmalig 25 dollar, identiteit verifiëren). Je moet 18+ zijn; is de maker
   jonger, dan maakt een ouder het account.
2. **Uploadsleutel**: dubbelklik `winkel\maak_uploadsleutel.bat`. Kies een sterk
   wachtwoord en bewaar het goed. Daarna één keer pushen (of in GitHub bij
   *Actions* → *Bouw en publiceer* → *Run workflow*) → het `.aab` staat bij de run.
3. **App aanmaken** in de Play Console: naam *Het Klimbos*, standaardtaal
   Nederlands, *Game*, *Gratis*.
   (Gratis kan later niet meer betaald worden; betaald kan wel later gratis.)
4. **Play App Signing** aanzetten (staat standaard aan) — Google bewaart de echte
   ondertekensleutel, jij uploadt met je uploadsleutel.
5. **Winkelvermelding** invullen met de teksten hieronder en de plaatjes uit deze map.
6. **App-inhoud** (Policy → App content), zie de antwoorden hieronder.
7. **Testen**. Nieuwe *persoonlijke* accounts moeten eerst een **gesloten test met
   minstens 12 testers, 14 dagen lang** doen voordat je mag publiceren.
   Begin met *Interne test* (jezelf), dan *Gesloten test* (vrienden en familie
   met een Android-toestel; zij moeten zich via een link aanmelden).
8. Na die 14 dagen: **productietoegang aanvragen** → publiceren.

## Winkelteksten

**App-naam** (max. 30): `Het Klimbos`

**Korte beschrijving** (max. 80):
> Teken je plan en bouw een klimparcours tussen de bomen – met je vriendjes!

**Volledige beschrijving:**
> Welkom in Het Klimbos, een groot, gezellig bos vol bomen om in te klimmen!
>
> ✏️ TEKEN JE PLAN
> Je begint met een vel papier. Kies je kleur en je potlood (dun, gewoon of dik)
> en teken waar je parcours moet komen: lijnen van boom naar boom, kruisjes,
> nummers… Je tekening ligt daarna als een grote kaart op de bosgrond.
>
> 🪵 BOUW JE KLIMPARCOURS
> Planken, platforms, bruggen, wiebelende touwbruggen, klimtouwen, klimhaken,
> klimnetten en tokkelbanen met een touwzadeltje. Kies iets uit je rugzak en zet
> het in de bomen. Geen zin om alles zelf te bouwen? Met de Express-knop wijs je
> twee bomen aan en het spel bouwt je getekende parcours voor je.
>
> 🧗 KLIMMEN, LOPEN EN TOKKELEN
> Klim naar boven, wandel over je bruggen en zoef met de tokkelbaan naar het
> volgende platform. Zes vriendjes – Lotte, Sem, Noor, Daan, Fien en Milan –
> klimmen gezellig mee op alles wat jij bouwt.
>
> 💾 BEWAAR JE BOS
> Sla je spel op met een plaatje en de datum, en speel later verder.
>
> Geen advertenties, geen aankopen in de app, geen account en geen internet nodig.
> Het spel verzamelt geen gegevens.

**English short description:**
> Draw a plan and build a climbing course between the trees – with your friends!

**English full description:**
> Welcome to Het Klimbos ("The Climbing Forest"), a big, cosy forest full of trees
> to climb! Start with a sheet of paper: pick a colour and a pencil and draw where
> your course should go. Your drawing then lies on the forest floor as a giant map.
> Build planks, platforms, bridges, wobbly rope bridges, climbing ropes, climbing
> holds, cargo nets and zip lines – or press Express, point at two trees and the
> game builds your drawn course for you. Climb up, walk across your bridges and
> zip to the next platform, while six friends climb along on everything you build.
> Save your forest with a picture and the date, and continue later.
> No ads, no in-app purchases, no account and no internet needed. The game collects no data.

**Categorie:** Game → *Casual* (of *Educatief*). **Tags:** bouwen, klimmen, kinderen, creatief.
**Contact-e-mail:** verplicht en zichtbaar in de winkel — kies zelf welk adres.
**Website:** https://github.com/kgdivw/klimbos

## Antwoorden voor *App-inhoud*

- **Privacybeleid:** https://kgdivw.github.io/klimbos/privacy.html
- **Advertenties:** nee, de app bevat geen advertenties.
- **Toegang tot de app:** alle functies zijn zonder inloggen beschikbaar.
- **Gegevensveiligheid (Data safety):** de app verzamelt **geen** gegevens en deelt
  **geen** gegevens. (Opgeslagen spellen blijven op het toestel en worden niet
  verstuurd; dat telt niet als "verzamelen".) Geen account, dus geen
  account-verwijdering nodig.
- **Inhoudsclassificatie (IARC-vragenlijst):** categorie *Game*; geen geweld, geen
  angstaanjagende inhoud, geen grof taalgebruik, geen gokken, geen drugs/alcohol,
  geen seksuele inhoud, geen contact met andere gebruikers (de vriendjes zijn
  computerfiguren), geen aankopen, geen locatie delen. Verwachte uitkomst: PEGI 3.
- **Doelgroep en inhoud:** leeftijden **6–8** en **9–12** (eventueel 5 en jonger).
  Omdat je kinderen kiest, valt de app onder het **Families-beleid**: dat is in orde,
  want er zijn geen advertenties, geen gegevensverzameling en geen
  toestemmingen. Bij "Kan de app per ongeluk kinderen aanspreken" → ja, het is
  bewust voor kinderen.
- **Overheids-/financiële/gezondheidsapp, nieuws:** nee.

## Technisch

- Android 7.0 (API 24) en hoger, target API 36, arm64-v8a + armeabi-v7a, liggend scherm.
- Geen toestemmingen (permissions) nodig.
- Renderer: Compatibility (OpenGL ES 3), aanraakbediening met joystick en knoppen.
- Lokaal een `.aab` bouwen kan ook, maar dan heb je **Java 17** nodig (Godot 4.5
  werkt niet met de Java 25 die nu op de laptop staat). Via GitHub hoeft dat niet.
