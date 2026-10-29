# Streakboard for macOS

Shows the last 10 weeks in the menu bar as one row of squares, one per week. The greener the square, the more days that week had a contribution (current week: days so far). Click it for the full year laid out like your GitHub profile, your streak and "Open at login". Right-click it to quit. There is no Dock icon or window.

It also includes a desktop / Notification Center widget with the same ring.

- The ring is your current streak as a percent of your best streak (100% = tied your record).
- Green means today has a contribution; amber means the streak is at risk.
- Small: ring + streak. Medium: ring + streak + last 20 weeks of the calendar.
- The menu bar refreshes every 10 minutes and on wake; the widget every 15 minutes and just after midnight.

## Build and install

Needs Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). No Apple developer account needed; it is signed to run locally.

```sh
cd macos-widget
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Streakboard.xcodeproj -scheme Streakboard -configuration Release -derivedDataPath build build
cp -R build/Build/Products/Release/Streakboard.app /Applications/
open /Applications/Streakboard.app
```

For the optional widget, right-click the desktop, choose **Edit Widgets**, search "Streakboard" and drag it out. Right-click the widget and choose **Edit "GitHub Streak"** to change the username.
