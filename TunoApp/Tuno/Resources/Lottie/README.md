# Lottie-animasjoner for "Ny annonse"-wizarden

`LottieView`-wrapperen viser SwiftUI-fallback hvis JSON-fil mangler — appen krasjer aldri.

## Status per 2026-04-25

| Filnavn                  | Status     | Kilde                                                                                                          |
|--------------------------|------------|-----------------------------------------------------------------------------------------------------------------|
| `welcome-tent.json`      | ✅ Egenkodet (4 KB) — telt med dør+pole, drop-in animasjon, blinkende stjerner | Hjemmebrygget Lottie 5.7.4              |
| `progress-pin.json`      | ✅ Egenkodet (2 KB) — pulserende mint-grønn ring + sentrert hvit/grønn pin     | Hjemmebrygget Lottie 5.7.4              |
| `success-confetti.json`  | ✅ Lastet ned (319 KB) — sjekkmerke + konfetti-eksplosjon                      | `assets1.lottiefiles.com/packages/lf20_ijpnbqs0.json` |
| `empty-spots.json`       | ✅ Egenkodet (3 KB) — pin som faller med skygge + bouncer 2 ganger             | Hjemmebrygget Lottie 5.7.4              |

## Bytte ut hvis du finner bedre

1. Last ned ny animasjon fra https://lottiefiles.com som "Lottie JSON"
2. Erstatt fil med samme filnavn i denne mappen
3. Bruk grønn `#46C185` der animasjonen tillater
4. Filer her bunkes automatisk via `project.yml` `sources`

## Hvis du vil verifisere fillhetshetshet

`python3 -c "import json; print(json.load(open('FIL.json'))['nm'])"` skal returnere navnet på animasjonen uten feil.
