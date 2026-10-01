# Het Klimbos

Teken een plan op papier en bouw daarna in een megabos je eigen klimparcours tussen
de bomen: planken, platforms, bruggen, touwbruggen, klimtouwen, klimhaken,
klimnetten en tokkelbanen. Zes vriendjes klimmen mee op alles wat je bouwt.

## Spelen

- **In de browser (pc en tablet):** https://kgdivw.github.io/klimbos/
- **Windows-versie om te downloaden:** https://kgdivw.github.io/klimbos/HetKlimbos-Windows.zip
  (uitpakken en `HetKlimbos.exe` starten; Windows kan de eerste keer waarschuwen omdat
  het programma niet ondertekend is: kies dan *Meer info* → *Toch uitvoeren*)

Op een tablet speel je het liefst liggend (landschap). Je opgeslagen spellen blijven
in de browser bewaard.

## Besturing

| | Computer | Tablet |
|---|---|---|
| Lopen | WASD of pijltjes | joystick linksonder |
| Springen | spatie | knop *Spring* |
| Rondkijken | linkermuis slepen | met één vinger vegen |
| Zoomen | muiswiel | knijpen met twee vingers |
| Iets kiezen | linkermuis op de inventaris (of 1–9) | tik op de inventaris |
| Plaatsen | rechtermuis in de wereld | tik in de wereld |
| Tokkelen / naar beneden klimmen | E | knop *E* |
| Je plan bekijken | Tab | knop *Plan* |

Klimmen gaat vanzelf: loop tegen een klimtouw, klimnet of klimhaken aan. Op een
platform val je er niet af; op een brug loop je als op een rail. Tegen de rand van
een platform + springen = er bewust af springen.

**Express:** kies twee bomen; het spel bouwt dan zelf het parcours zoals je het
getekend hebt. Blauw getekend = tokkelbaan, rood/oranje/roze = touwbrug, andere
kleuren = brug.

## Zelf bouwen

Gemaakt met [Godot 4.5.1](https://godotengine.org). Alles (bos, bomen, figuren,
bouwsels) wordt in code opgebouwd; er zijn geen 3D-bestanden of plaatjes.

- Openen in Godot: `project.godot`
- De GitHub Action in `.github/workflows/bouw.yml` bouwt bij elke push naar `main`
  de web- en Windows-versie en zet ze op GitHub Pages.
