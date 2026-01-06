#!/bin/bash

# Optimize marketing images for web delivery
# Creates responsive sizes for each image

SOURCE_DIR="/Users/antoineschaller/GitHub/ballee/apps/web/public/images/marketing"
OUTPUT_DIR="/Users/antoineschaller/GitHub/ballee/apps/web/public/images/marketing/optimized"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to resize image
resize_image() {
    local input=$1
    local output=$2
    local width=$3
    local filename=$(basename "$input" .jpg)
    local output_file="${output}/${filename}-${width}w.jpg"

    echo "Creating ${width}px version of $filename..."
    sips -Z $width "$input" --out "$output_file" --setProperty formatOptions 85
}

# Optimize each image
for image in "$SOURCE_DIR"/*.jpg; do
    if [ -f "$image" ]; then
        filename=$(basename "$image")
        echo "Processing $filename..."

        # Create responsive sizes
        resize_image "$image" "$OUTPUT_DIR" 640   # Mobile
        resize_image "$image" "$OUTPUT_DIR" 1200  # Tablet/Desktop
        resize_image "$image" "$OUTPUT_DIR" 1920  # Large Desktop

        # Copy original with compression
        echo "Optimizing original $filename..."
        sips -s formatOptions 85 "$image" --out "$OUTPUT_DIR/${filename}"
    fi
done

# Handle PNG separately
for image in "$SOURCE_DIR"/*.png; do
    if [ -f "$image" ]; then
        filename=$(basename "$image" .png)
        echo "Processing PNG: $filename..."

        # Convert PNG to JPG with different sizes
        sips -s format jpeg -Z 640 "$image" --out "$OUTPUT_DIR/${filename}-640w.jpg" --setProperty formatOptions 85
        sips -s format jpeg -Z 1200 "$image" --out "$OUTPUT_DIR/${filename}-1200w.jpg" --setProperty formatOptions 85
        sips -s format jpeg -Z 1920 "$image" --out "$OUTPUT_DIR/${filename}-1920w.jpg" --setProperty formatOptions 85
    fi
done

echo "✅ Image optimization complete!"
echo "Images saved to: $OUTPUT_DIR"