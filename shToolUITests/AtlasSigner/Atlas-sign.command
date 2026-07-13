#!/bin/bash
#!/usr/bin/expect
THIS_FILE=`basename "$0"`
rm ~/Library/Atlas2/encrypted.manifest 
rm ~/Library/Atlas2/encrypted.sig

CURRENT_DIR=$(cd `dirname $0`; pwd)

"${CURRENT_DIR}/AtlasSigner_V237" "${CURRENT_DIR}/check.plist" ~/Library/Atlas2

# #If everything passed, close the terminal window and exit
# osascript -e 'tell application "Terminal" to close (every window whose name contains "'"$THIS_FILE"'")' &
# exit