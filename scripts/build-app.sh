#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build --product CyberMacApp
build_dir=$(swift build --show-bin-path)
app="$PWD/dist/CyberMac.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
/bin/cp "$build_dir/CyberMacApp" "$app/Contents/MacOS/CyberMacApp.new"
/bin/mv -f "$app/Contents/MacOS/CyberMacApp.new" "$app/Contents/MacOS/CyberMacApp"
for resource in "$build_dir"/*.bundle; do
  /usr/bin/ditto "$resource" "$app/Contents/Resources/${resource:t}"
done
preview_resources="$app/Contents/Resources/ClothingPreviewRenderer"
mkdir -p "$preview_resources/licenses"
for preview_source in render_clothing_package.py render_clothing_thumbnails.py prepare_lucy_assets.py clothing_materials.py clothing_texture_decode.py; do
  /bin/cp "tools/$preview_source" "$preview_resources/$preview_source"
done
/bin/cp tools/licenses/WolvenKit-GPL-3.0.txt "$preview_resources/licenses/WolvenKit-GPL-3.0.txt"
python3 tools/configure_clothing_previews.py --out .research/renderer-tools.json
/bin/cp .research/renderer-tools.json "$preview_resources/renderer-tools.json"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.cybermac.app</string>
<key>CFBundleName</key><string>CyberMac</string>
<key>CFBundleDisplayName</key><string>CyberMac</string>
<key>CFBundleExecutable</key><string>CyberMacApp</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/bin/codesign --force --sign - "$app"
print -r -- "Built: $app"
