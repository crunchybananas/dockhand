#!/bin/bash
# Deploy Reputation Graph to Shipyard
set -e

API_KEY="shipyard_sk_44f8a52e45b0e82c1ced986e9f4852abab7a6a6f982dec140ed40d68c11645a3"
SHIP_ID="29"
BASE_URL="https://shipyard.bot"
TOOL_DIR="/Users/cloken/code/Dockhand/shipyard-microtools/docs/reputation-graph"

# Read and escape file contents for JSON
escape_json() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

INDEX_HTML=$(cat "$TOOL_DIR/index.html" | escape_json)
APP_JS=$(cat "$TOOL_DIR/app.js" | escape_json)
STYLES_CSS=$(cat "$TOOL_DIR/styles.css" | escape_json)

echo "Uploading files to ship $SHIP_ID..."
UPLOAD_RESPONSE=$(curl -s -X POST "$BASE_URL/api/ships/$SHIP_ID/files" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"files\": [
      {\"filename\": \"index.html\", \"content\": $INDEX_HTML},
      {\"filename\": \"app.js\", \"content\": $APP_JS},
      {\"filename\": \"styles.css\", \"content\": $STYLES_CSS}
    ]
  }")

echo "Upload response: $UPLOAD_RESPONSE"

echo "Deploying ship $SHIP_ID..."
DEPLOY_RESPONSE=$(curl -s -X POST "$BASE_URL/api/ships/$SHIP_ID/deploy" \
  -H "Authorization: Bearer $API_KEY")

echo "Deploy response: $DEPLOY_RESPONSE"
