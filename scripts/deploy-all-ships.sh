#!/bin/bash
# Deploy all three new ships to Shipyard
# Usage: ./deploy-all-ships.sh <API_KEY>

set -e

API_KEY="${1:?Usage: $0 <API_KEY>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "======================================"
echo "Deploying All Ships to Shipyard"
echo "======================================"
echo ""

# Deploy Color Palette Generator
echo "1/3: Deploying Color Palette Generator..."
"$SCRIPT_DIR/deploy-color-palette.sh" "$API_KEY"
echo ""
echo "======================================"
echo ""

# Deploy Regex Tester
echo "2/3: Deploying Regex Tester..."
"$SCRIPT_DIR/deploy-regex-tester.sh" "$API_KEY"
echo ""
echo "======================================"
echo ""

# Deploy Data Forge
echo "3/3: Deploying Data Forge..."
"$SCRIPT_DIR/deploy-data-forge.sh" "$API_KEY"
echo ""
echo "======================================"
echo ""

echo "✅ All three ships have been deployed!"
echo ""
echo "Ships deployed:"
echo "1. Color Palette Generator - Generate beautiful color harmonies"
echo "2. Regex Tester - Test and debug regular expressions"
echo "3. Data Forge - Generate realistic mock data"
echo ""
echo "Check your ships at https://shipyard.bot/apps"
