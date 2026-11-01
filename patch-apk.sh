#!/usr/bin/env bash

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;92m'
YELLOW='\033[0;93m'
BLUE='\033[0;34m'
MAGENTA='\033[0;95m'
CYAN='\033[0;96m'
WHITE='\033[0;97m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_TOOLS_DIR="$(printf '%s\n' "$SCRIPT_DIR"/build-tools/[0-9]*.[0-9]*.[0-9]* | sort -V | tail -n 1)"

if [ ! -d "$BUILD_TOOLS_DIR" ]; then
    echo -e "${RED}Error: Build tools directory not found.${RESET}"
    echo -e "${YELLOW}Run ./download-build-tools.sh to download.${RESET}"
    read -rsn1 && exit 1
fi

KEYSTORE="$SCRIPT_DIR/debuggable.keystore"
KEY_ALIAS="debuggable"
KEY_PASS="pwpwpw"

# Usage & directory check
if [ "$#" -ne 1 ]; then
    echo -e "${MAGENTA}Usage: $0 <input_directory>${RESET}"
    echo -e "${CYAN}e.g.: $0 com.android.chrome${RESET}"
    echo -e "${YELLOW}Press enter to exit...${RESET}"
    read -rsn1
    exit 1
fi

INPUT_DIR="${1%/}"
BASE_APK="$INPUT_DIR/base.apk"
OUT_DIR="$INPUT_DIR/debug-enabled"

if [ ! -d "$INPUT_DIR" ] || [ ! -f "$BASE_APK" ]; then
    echo -e "${RED}Error: '$BASE_APK' not found. Make sure '$INPUT_DIR' is a valid extracted APK directory.${RESET}"
    echo -e "${YELLOW}Press enter to exit...${RESET}"
    read -rsn1
    exit 1
fi

# Prepend build-tools to PATH
export PATH="$BUILD_TOOLS_DIR:$PATH"
export PATHEXT="${PATHEXT:-.COM;.EXE;.BAT;.CMD}"

# Generate debuggable.keystore if it doesn't exist yet
if [ ! -f "$KEYSTORE" ]; then
    echo -e "${YELLOW}Keystore not found. Generating $KEYSTORE via keygen.sh...${RESET}"
    (
        cd "$SCRIPT_DIR"
        bash "$SCRIPT_DIR/keygen.sh"
    )
else
    echo -e "${CYAN}Using existing keystore: $KEYSTORE${RESET}"
fi

# Prepare clean output directory
mkdir -p "$OUT_DIR"
rm -rf "$OUT_DIR"/*

# Patch, align, and sign base.apk via makeDebuggable.py
echo -e "${MAGENTA}--------------------------------------------------${RESET}"
echo -e "${MAGENTA}Patching base APK: $BASE_APK -> $OUT_DIR/base.apk${RESET}"
python "$SCRIPT_DIR/makeDebuggable.py" apk \
    "$BASE_APK" \
    "$OUT_DIR/base.apk" \
    "$KEYSTORE" \
    "$KEY_ALIAS" \
    "$KEY_PASS"

# Align and sign any split APKs in the directory
for apk in "$INPUT_DIR"/*.apk; do
    apk_name="$(basename "$apk")"
    if [ "$apk_name" = "base.apk" ]; then
        continue
    fi

    out_apk="$OUT_DIR/$apk_name"
    echo -e "${MAGENTA}--------------------------------------------------${RESET}"
    echo -e "${CYAN}Processing split APK: $apk_name${RESET}"

    echo -e "${BLUE}Aligning...${RESET}"
    zipalign -f -p 4 "$apk" "$out_apk"

    echo -e "${BLUE}Signing with debuggable.keystore...${RESET}"
    apksigner.bat sign \
        --ks "$KEYSTORE" \
        --ks-key-alias "$KEY_ALIAS" \
        --ks-pass "pass:$KEY_PASS" \
        "$out_apk"

    echo -e "${BLUE}Verifying signature...${RESET}"
    apksigner.bat verify "$out_apk"
done

# Cleanup idsig files
rm -f "$OUT_DIR"/*.idsig

echo -e "${MAGENTA}--------------------------------------------------${RESET}"
echo -e "${GREEN}Done! All debug-enabled APKs saved to: $OUT_DIR/${RESET}"
echo -e "${YELLOW}Press enter to exit...${RESET}"
read -rsn1
