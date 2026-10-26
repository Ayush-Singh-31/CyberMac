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
