#!/bin/bash

# Define base URL and output directory
OUTPUT_DIR="."

# Define issues, filenames, and PoC URLs
declare -A ISSUES_TO_FILES=(
  [488]="libtiff_#488.tiff"
  [498]="libtiff_#498.tiff"
  [519]="libtiff_#519.tiff"
  [520]="libtiff_#520.tiff"
  [527]="libtiff_#527.tiff"
  [530]="libtiff_#530.tiff"
  [548]="libtiff_#548.tiff"
  [559]="libtiff_#559.tiff"
)

declare -A ISSUE_URLS=(
  [488]="https://gitlab.com/-/project/4720790/uploads/dc58abe122495efd39b5f777e9d59ba8/poc"
  [498]="https://gitlab.com/-/project/4720790/uploads/b37c97c43f314daae2227b16dd00d369/poc.zip"
  [519]="https://gitlab.com/-/project/4720790/uploads/11e6bf121616d16b7f8918b06dd94e6c/poc"
  [520]="https://gitlab.com/-/project/4720790/uploads/434e1926d806f413edafb3b81cde4b54/poc"
  [527]="https://gitlab.com/-/project/4720790/uploads/5ebc8db7f141578653aca87979f5d84f/poc"
  [530]="https://gitlab.com/-/project/4720790/uploads/f08f3fad60d74ef290580cdb8f3e4918/poc"
  [548]="https://gitlab.com/-/project/4720790/uploads/92e334efa48e9ff4d4c55f25c3d189aa/poc_file"
  [559]="https://gitlab.com/-/project/4720790/uploads/7376851dd479d22fd36707b4e8c5a1bd/clusterfuzz-testcase-minimized-tiff_read_rgba_fuzzer-5100374058205184.zip"
)

# Download PoC files
for ISSUE_ID in "${!ISSUES_TO_FILES[@]}"; do
  FILE_NAME="${ISSUES_TO_FILES[$ISSUE_ID]}"
  POC_URL="${ISSUE_URLS[$ISSUE_ID]}"
  
  if [ -n "$POC_URL" ]; then
    echo "Downloading PoC for issue #${ISSUE_ID}..."
    curl -o "${OUTPUT_DIR}/${FILE_NAME}" "$POC_URL"
    
    # Check if the file is a zip
    if file "${OUTPUT_DIR}/${FILE_NAME}" | grep -q "Zip archive"; then
      echo "Extracting zip for issue #${ISSUE_ID}..."
      EXTRACTED_FILE=$(unzip -j "${OUTPUT_DIR}/${FILE_NAME}" -d "$OUTPUT_DIR" | awk '/inflating:/ {print $2}')
      mv "${OUTPUT_DIR}/${EXTRACTED_FILE}" "${OUTPUT_DIR}/${FILE_NAME}"
    fi
  else
    echo "No PoC URL defined for issue #${ISSUE_ID}."
  fi
done
