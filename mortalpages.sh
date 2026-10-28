#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
KEYNOTE_BIN="$DIR/keynote_bg_swapper"
PDF_BIN="$DIR/pdf_hyperlink_engine"

# Ensure binaries are compiled
if [ ! -f "$PDF_BIN" ]; then
    echo "⚙️  Compiling pdf_hyperlink_engine..."
    swiftc -O "$DIR/pdf_hyperlink_engine.swift" -o "$PDF_BIN"
fi

if [ ! -f "$KEYNOTE_BIN" ]; then
    echo "⚙️  Compiling keynote_bg_swapper..."
    swiftc -O "$DIR/keynote_bg_swapper.swift" -o "$KEYNOTE_BIN"
fi

# If arguments passed, pass them directly
if [ "$1" = "--pdf-only" ] || [ "$1" = "-p" ]; then
    shift
    "$PDF_BIN" "$@"
    exit 0
elif [ "$1" = "--keynote-only" ] || [ "$1" = "-k" ]; then
    shift
    "$KEYNOTE_BIN" "$@"
    exit 0
elif [ "$1" = "--both" ] || [ "$1" = "-b" ]; then
    shift
    "$KEYNOTE_BIN" "$@"
    "$PDF_BIN" "$@"
    exit 0
elif [ "$#" -gt 0 ]; then
    "$KEYNOTE_BIN" "$@"
    exit 0
fi

# Interactive Menu
clear
echo "=========================================================="
echo "          ✨ mortalpages Notebook Automator ✨           "
echo "=========================================================="
echo ""
echo "Select an action to perform:"
echo "  [1] ⚡ Direct PDF Link Engine (Fastest ~0.5s - creates interactive PDF)"
echo "  [2] 🖥  Keynote Background Swapper (Updates Keynote slides in place)"
echo "  [3] 🚀 Run Both (Updates Keynote slides + creates interactive PDF)"
echo "  [4] ❌ Exit"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        echo ""
        "$PDF_BIN"
        ;;
    2)
        echo ""
        "$KEYNOTE_BIN"
        ;;
    3)
        echo ""
        echo "--> Step 1: Updating Keynote..."
        "$KEYNOTE_BIN"
        echo ""
        echo "--> Step 2: Creating Interactive PDF..."
        "$PDF_BIN"
        ;;
    4)
        echo "Exiting."
        exit 0
        ;;
    *)
        echo "Invalid choice."
        exit 1
        ;;
esac
