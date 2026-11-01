#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

# ANSI color codes
GREEN='\033[0;92m'
RESET='\033[0m'

# Scrape the active build version from Google's portal
LATEST_CMD_LINES_TOOLS_VERSION=$(curl -s https://developer.android.com/studio | grep -oE "commandlinetools-win-[0-9]+_latest\.zip" | head -n 1)

echo -e "${GREEN}Commandline tools latest build version : ${LATEST_CMD_LINES_TOOLS_VERSION//[^0-9]/}${RESET}"
echo -e "${GREEN}Downloading ${LATEST_CMD_LINES_TOOLS_VERSION}${RESET}"

# Download the latest commandlinetools zip
curl -LO "https://dl.google.com/android/repository/${LATEST_CMD_LINES_TOOLS_VERSION}"

# Unzip it and remove the archive
unzip -qo "${LATEST_CMD_LINES_TOOLS_VERSION}"
rm -f "${LATEST_CMD_LINES_TOOLS_VERSION}"

# Find the highest stable build-tools version
LATEST_BUILD_TOOLS_VERSION=$(./cmdline-tools/bin/sdkmanager.bat --list --sdk_root="./cmdline-tools" | grep "build-tools;" | grep -v "\-rc" | awk -F';' '{print $2}' | awk '{print $1}' | sort -V | tail -n 1)

echo -e "${GREEN}The latest stable build-tools version found is: ${LATEST_BUILD_TOOLS_VERSION}${RESET}"

# Download
echo -e "${GREEN}Downloading build-tools version: ${LATEST_BUILD_TOOLS_VERSION}${RESET}"
./cmdline-tools/bin/sdkmanager.bat "build-tools;${LATEST_BUILD_TOOLS_VERSION}" --sdk_root="./cmdline-tools"

# Relocate build-tools to script sibling directory
rm -rf ./build-tools
mv ./cmdline-tools/build-tools ./

# Prune non-essential files
echo -e "${GREEN}Deleting unnecessary files${RESET}"
find ./build-tools/ -type f \
    -not -path "./build-tools/${LATEST_BUILD_TOOLS_VERSION}/apksigner.bat" \
    -not -path "./build-tools/${LATEST_BUILD_TOOLS_VERSION}/lib/apksigner.jar" \
    -not -path "./build-tools/${LATEST_BUILD_TOOLS_VERSION}/zipalign.exe" \
    -exec rm -f {} +

# Remove empty directories left behind
find ./build-tools/ -mindepth 1 -type d -empty -delete

# Remove the commandlinetools directory
rm -rf ./cmdline-tools

echo -e "${GREEN}Done!${RESET}"
read -rsn1
