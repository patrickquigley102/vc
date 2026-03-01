#!/bin/bash

# Docker-based Voice Conversion Script
# Runs inference_v2.py inside the Docker container

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Required:"
    echo "  -s, --source FILE       Source audio file to convert"
    echo "  -t, --target FILE       Reference audio file (target voice)"
    echo ""
    echo "Optional:"
    echo "  -o, --output DIR        Output directory (default: ./output)"
    echo "  -d, --diffusion N       Diffusion steps (default: 8)"
    echo "  -l, --length-adjust N   Length adjustment factor (default: 1.0)"
    echo "  --intelligibility N     Intelligibility CFG rate (default: 0.75)"
    echo "  --similarity N          Similarity CFG rate (default: 0.75)"
    echo "  --convert-style BOOL    Convert style/emotion/accent (default: false)"
    echo "  --anonymization BOOL    Anonymization only (default: false)"
    echo "  --top-p N               Top-p sampling (default: 0.9)"
    echo "  --temperature N         Temperature (default: 0.9)"
    echo "  --repetition-penalty N  Repetition penalty (default: 1.1)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -s input/source.mp3 -t input/reference.mp3"
    echo "  $0 -s source.wav -t target.wav -o output -d 30"
    echo ""
    echo "Note: File paths should be relative to the current directory or absolute."
}

# Default values
OUTPUT_DIR="./output"
DIFFUSION_STEPS=40
LENGTH_ADJUST=1.0
INTELLIGIBILITY=0.75
SIMILARITY=0.75
CONVERT_STYLE="false"
ANONYMIZATION="false"
TOP_P=0.9
TEMPERATURE=0.9
REPETITION_PENALTY=1.1

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--source)
            SOURCE="$2"
            shift 2
            ;;
        -t|--target)
            TARGET="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -d|--diffusion)
            DIFFUSION_STEPS="$2"
            shift 2
            ;;
        -l|--length-adjust)
            LENGTH_ADJUST="$2"
            shift 2
            ;;
        --intelligibility)
            INTELLIGIBILITY="$2"
            shift 2
            ;;
        --similarity)
            SIMILARITY="$2"
            shift 2
            ;;
        --convert-style)
            CONVERT_STYLE="$2"
            shift 2
            ;;
        --anonymization)
            ANONYMIZATION="$2"
            shift 2
            ;;
        --top-p)
            TOP_P="$2"
            shift 2
            ;;
        --temperature)
            TEMPERATURE="$2"
            shift 2
            ;;
        --repetition-penalty)
            REPETITION_PENALTY="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            print_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$SOURCE" ] || [ -z "$TARGET" ]; then
    echo -e "${RED}Error: Source and target files are required${NC}"
    print_usage
    exit 1
fi

# Check if files exist
if [ ! -f "$SOURCE" ]; then
    echo -e "${RED}Error: Source file not found: $SOURCE${NC}"
    exit 1
fi

if [ ! -f "$TARGET" ]; then
    echo -e "${RED}Error: Target file not found: $TARGET${NC}"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Get absolute paths
SOURCE_ABS=$(realpath "$SOURCE")
TARGET_ABS=$(realpath "$TARGET")
OUTPUT_ABS=$(realpath "$OUTPUT_DIR")

# Get the directory containing the source and target files
SOURCE_DIR=$(dirname "$SOURCE_ABS")
TARGET_DIR=$(dirname "$TARGET_ABS")

# Get basenames
SOURCE_BASE=$(basename "$SOURCE_ABS")
TARGET_BASE=$(basename "$TARGET_ABS")

echo -e "${GREEN}Starting voice conversion...${NC}"
echo "Source: $SOURCE_ABS"
echo "Target: $TARGET_ABS"
echo "Output: $OUTPUT_ABS"
echo ""

# Run inference inside Docker container
docker run --rm \
  --gpus all \
  -v "$SOURCE_DIR:/input_source:ro" \
  -v "$TARGET_DIR:/input_target:ro" \
  -v "$OUTPUT_ABS:/output" \
  seed-vc:latest \
  python3 inference_v2.py \
    --source "/input_source/$SOURCE_BASE" \
    --target "/input_target/$TARGET_BASE" \
    --output /output \
    --diffusion-steps "$DIFFUSION_STEPS" \
    --length-adjust "$LENGTH_ADJUST" \
    --intelligibility-cfg-rate "$INTELLIGIBILITY" \
    --similarity-cfg-rate "$SIMILARITY" \
    --convert-style "$CONVERT_STYLE" \
    --anonymization-only "$ANONYMIZATION" \
    --top-p "$TOP_P" \
    --temperature "$TEMPERATURE" \
    --repetition-penalty "$REPETITION_PENALTY"

echo ""
echo -e "${GREEN}✓ Conversion complete! Output saved to: $OUTPUT_ABS${NC}"
