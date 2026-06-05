#!/usr/bin/env bash
#
# make_gif.sh - tworzy plynna animacje GIF z kilku zdjec.
#
# Klatki sa laczone miekkimi przejsciami (crossfade), a domyslnie
# animacja odtwarzana jest "tam i z powrotem" (boomerang), dzieki czemu
# petla jest bezszwowa - idealne dla sekwencji typu "odklejanie profilu
# od pianki" z dostarczonych zdjec.
#
# Wymagania: ffmpeg.
#
# Uzycie:
#   tools/make_gif.sh [opcje] [plik1 plik2 ...]
#
# Jesli nie podasz plikow, skrypt wezmie wszystkie obrazy z katalogu
# ./frames (posortowane po nazwie).
#
# Opcje (zmienne srodowiskowe):
#   OUT=animacja.gif   nazwa pliku wyjsciowego        (domyslnie out.gif)
#   WIDTH=540          szerokosc GIF-a w pikselach     (domyslnie 540)
#   HEIGHT=0           wysokosc; 0 = wylicz z proporcji pierwszego zdjecia
#   HOLD=0.9           czas zatrzymania na klatce [s]  (domyslnie 0.9)
#   TRANS=0.6          czas przejscia crossfade [s]    (domyslnie 0.6)
#   FPS=30             klatki na sekunde               (domyslnie 30)
#   BOOMERANG=1        1 = odtwarzaj tam i z powrotem, 0 = tylko w przod
#   TRANSITION=fade    rodzaj przejscia xfade (fade, dissolve, smoothleft...)
#   COLORS=256         liczba kolorow palety (mniej = mniejszy plik GIF)
#
# Przyklady:
#   tools/make_gif.sh frames/1.jpg frames/2.jpg frames/3.jpg
#   OUT=profil.gif HOLD=1.2 TRANS=0.8 tools/make_gif.sh
#
set -euo pipefail

# --- parametry -------------------------------------------------------------
OUT="${OUT:-out.gif}"
WIDTH="${WIDTH:-540}"
HEIGHT="${HEIGHT:-0}"
HOLD="${HOLD:-0.9}"
TRANS="${TRANS:-0.6}"
FPS="${FPS:-30}"
BOOMERANG="${BOOMERANG:-1}"
TRANSITION="${TRANSITION:-fade}"
COLORS="${COLORS:-256}"   # liczba kolorow w palecie GIF (mniej = mniejszy plik)

# --- sprawdzenie zaleznosci ------------------------------------------------
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "BLAD: nie znaleziono ffmpeg. Zainstaluj go (np. apt-get install ffmpeg)." >&2
  exit 1
fi

# --- zebranie listy klatek -------------------------------------------------
declare -a FRAMES=()
if [ "$#" -gt 0 ]; then
  FRAMES=("$@")
else
  if [ -d frames ]; then
    while IFS= read -r f; do
      FRAMES+=("$f")
    done < <(find frames -maxdepth 1 -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
      | sort)
  fi
fi

N="${#FRAMES[@]}"
if [ "$N" -lt 2 ]; then
  echo "BLAD: potrzebne sa co najmniej 2 zdjecia." >&2
  echo "Podaj pliki jako argumenty albo wrzuc je do katalogu ./frames" >&2
  exit 1
fi

for f in "${FRAMES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "BLAD: brak pliku: $f" >&2
    exit 1
  fi
done

echo ">> Klatki ($N): ${FRAMES[*]}"
echo ">> Wyjscie: $OUT  (WIDTH=$WIDTH HEIGHT=$HEIGHT HOLD=$HOLD TRANS=$TRANS FPS=$FPS BOOMERANG=$BOOMERANG)"

# --- ustalenie docelowych wymiarow -----------------------------------------
if [ "$HEIGHT" = "0" ]; then
  # wyliczamy wysokosc z proporcji pierwszego zdjecia, parzysta liczba
  IFS=, read -r IW IH < <(ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height -of csv=p=0 "${FRAMES[0]}")
  HEIGHT=$(awk -v w="$WIDTH" -v iw="$IW" -v ih="$IH" \
    'BEGIN{ h=int((w*ih/iw)+0.5); if(h%2)h++; print h }')
fi
echo ">> Docelowy rozmiar: ${WIDTH}x${HEIGHT}"

# Czas trwania pojedynczego klipu zrodlowego = HOLD + TRANS
DUR=$(awk -v a="$HOLD" -v b="$TRANS" 'BEGIN{printf "%.4f", a+b}')

# --- budowa filter_complex -------------------------------------------------
INPUTS=()
PRE=""    # przygotowanie kazdej klatki: skala + pad + fps + format
for i in $(seq 0 $((N-1))); do
  INPUTS+=( -loop 1 -t "$DUR" -i "${FRAMES[$i]}" )
  PRE+="[${i}:v]scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,"
  PRE+="pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=white,"
  PRE+="setsar=1,fps=${FPS},format=rgba[s${i}];"
done

# lancuch crossfade: offset k-tego przejscia = (k+1)*HOLD
CHAIN=""
PREV="[s0]"
for k in $(seq 0 $((N-2))); do
  NEXT="[s$((k+1))]"
  OFF=$(awk -v h="$HOLD" -v k="$k" 'BEGIN{printf "%.4f", (k+1)*h}')
  if [ "$k" -eq $((N-2)) ]; then
    LABEL="[fwd]"
  else
    LABEL="[x${k}]"
  fi
  CHAIN+="${PREV}${NEXT}xfade=transition=${TRANSITION}:duration=${TRANS}:offset=${OFF}${LABEL};"
  PREV="[x${k}]"
done

# boomerang: doklej odwrocona kopie, by petla byla bezszwowa
if [ "$BOOMERANG" = "1" ]; then
  LOOP="[fwd]split[f1][f2];[f2]reverse[rev];[f1][rev]concat=n=2:v=1[loop];"
  FINAL="[loop]"
else
  LOOP=""
  FINAL="[fwd]"
fi

# generowanie palety dla wysokiej jakosci GIF-a
PALETTE="${FINAL}split[p1][p2];[p1]palettegen=max_colors=${COLORS}:stats_mode=full[pal];"
PALETTE+="[p2][pal]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle[gif]"

FILTER="${PRE}${CHAIN}${LOOP}${PALETTE}"

# --- uruchomienie ----------------------------------------------------------
ffmpeg -y -hide_banner -loglevel warning \
  "${INPUTS[@]}" \
  -filter_complex "$FILTER" \
  -map "[gif]" \
  "$OUT"

echo ">> Gotowe: $OUT"
ls -lh "$OUT"
