tell application "Finder"
    try
        tell disk "Mac优化大师"
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set bounds of container window to {200, 150, 860, 550}
            set theViewOptions to the icon view options of container window
            set arrangement of theViewOptions to not arranged
            set icon size of theViewOptions to 100
            set background picture of theViewOptions to file ".background:background.png"
            set position of item "Mac优化大师.app" of container window to {140, 180}
            set position of item "Applications" of container window to {500, 180}
            close
            open
            update without registering applications
            delay 1
            close
        end tell
    end try
end tell
