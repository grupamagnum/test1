# test1

## Plynna animacja GIF ze zdjec

Skrypt [`tools/make_gif.sh`](tools/make_gif.sh) sklada kilka zdjec w jeden
**plynny** GIF: klatki lacza sie miekkimi przejsciami (crossfade), a domyslnie
animacja gra "tam i z powrotem" (boomerang), wiec petla jest bezszwowa.
Idealne dla sekwencji typu "odklejanie profilu okiennego od pianki".

### Wymagania

- `ffmpeg` (z filtrami `xfade`, `palettegen`, `reverse` - sa w standardowej wersji).

  ```bash
  # Debian/Ubuntu
  sudo apt-get install -y ffmpeg
  # macOS
  brew install ffmpeg
  ```

### Uzycie

1. Wrzuc zdjecia do katalogu `frames/` (nazwane po kolei, np. `1.jpg`, `2.jpg`, `3.jpg`)
   i uruchom:

   ```bash
   tools/make_gif.sh
   ```

2. Albo podaj pliki bezposrednio jako argumenty:

   ```bash
   tools/make_gif.sh zdjecie1.jpg zdjecie2.jpg zdjecie3.jpg
   ```

Wynik domyslnie zapisywany jest do `out.gif`.

### Dostosowanie (zmienne srodowiskowe)

| Zmienna      | Domyslnie | Opis |
|--------------|-----------|------|
| `OUT`        | `out.gif` | nazwa pliku wyjsciowego |
| `WIDTH`      | `540`     | szerokosc GIF-a w pikselach |
| `HEIGHT`     | `0`       | wysokosc; `0` = wylicz z proporcji 1. zdjecia |
| `HOLD`       | `0.9`     | czas zatrzymania na klatce [s] |
| `TRANS`      | `0.6`     | czas przejscia crossfade [s] |
| `FPS`        | `30`      | klatki na sekunde |
| `BOOMERANG`  | `1`       | `1` = tam i z powrotem, `0` = tylko w przod |
| `TRANSITION` | `fade`    | rodzaj przejscia `xfade` (np. `fade`, `dissolve`, `smoothleft`) |

Przyklad - wolniejsza, wieksza animacja zapisana do `profil.gif`:

```bash
OUT=profil.gif WIDTH=720 HOLD=1.2 TRANS=0.8 tools/make_gif.sh
```
