#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="${1:-build.yml}"

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         🔍 YAML Syntax Check 🔍           ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════╝${NC}"
echo ""

if [ ! -f "$FILE" ] && [ -f "$SCRIPT_DIR/$FILE" ]; then
  FILE="$SCRIPT_DIR/$FILE"
fi

if [ ! -f "$FILE" ]; then
  echo -e "${RED}❌ File not found: ${BLUE}$FILE${NC}"
  exit 1
fi

echo -ne "  📄 ${BLUE}$FILE${NC} ... "

if yamllint -d relaxed "$FILE" >/dev/null 2>&1; then
  echo -e "${GREEN}✅ PASS${NC}"
  echo ""
  echo -e "${GREEN}🎉 YAML syntax looks good!${NC}"
else
  echo -e "${RED}❌ FAIL${NC}"
  echo -e "    ${YELLOW}Errors:${NC}"
  yamllint -d relaxed "$FILE" 2>&1 | sed 's/^/      /'
  echo ""
  echo -e "${RED}⚠️  Please fix the YAML errors above.${NC}"
  exit 1
fi

echo ""
