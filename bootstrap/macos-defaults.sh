# Ref: https://github.com/mathiasbynens/dotfiles/blob/master/.macos

better_macos_defaults()
{
  # Close any open System Preferences panes, to prevent them from overriding
  # settings we’re about to change
  osascript -e 'tell application "System Preferences" to quit'

  #################
  # General UI/UX #
  #################

  # Enable the startup chime
  sudo nvram StartupMute=%00

  # Disable transparency in the menu bar and elsewhere on Yosemite
  defaults write com.apple.universalaccess reduceTransparency -bool true

  # Disable motion during workspace switching
  defaults write com.apple.universalaccess reduceMotion -bool true

  # Set highlight color to green
  defaults write NSGlobalDomain AppleHighlightColor -string "0.764700 0.976500 0.568600"

  # Set sidebar icon size to medium
  defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 2

  # Set scrollbar mode depending on whether external mouse device is connected
  defaults write NSGlobalDomain AppleShowScrollBars -string "Automatic"
  # Possible values: `WhenScrolling`, `Automatic` and `Always`

  # Expand save panel by default
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

  # Expand print panel by default
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

  # Save to disk (not to iCloud) by default
  defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

  # Make notification disappear sooner
  defaults write com.apple.notificationcenterui bannerTime -int 3

  # Automatically quit printer app once the print jobs complete
  defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

  # Disable the “Are you sure you want to open this application?” dialog
  defaults write com.apple.LaunchServices LSQuarantine -bool false

  # Make Crash Reporter appear as a notification
  defaults write com.apple.CrashReporter UseUNC -bool true

  # Remove duplicates in the “Open With” menu (also see `lscleanup` alias)
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

  # Display ASCII control characters using caret notation in standard text views
  # Try e.g. `cd /tmp; unidecode "\x{0000}" > cc.txt; open -e cc.txt`
  defaults write NSGlobalDomain NSTextShowsControlCharacters -bool true

  # Disable Resume system-wide
  defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false

  # Disable automatic termination of inactive apps
  defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true

  # Set Help Viewer windows to non-floating mode
  defaults write com.apple.helpviewer DevMode -bool true

  # Disable automatic capitalization as it’s annoying when typing code
  defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

  # Disable smart dashes as they’re annoying when typing code
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

  # Disable automatic period substitution as it’s annoying when typing code
  defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

  # Disable smart quotes as they’re annoying when typing code
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

  # Disable auto-correct
  defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

  ####################
  # Reduce animation #
  ####################

  # Disable the over-the-top focus ring animation
  defaults write NSGlobalDomain NSUseAnimatedFocusRing -bool false

  # Disable the new window animation
  defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false

  # Increase window resize speed for Cocoa applications
  defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

  # Disable scrolling column views animation
  defaults write NSGlobalDomain NSBrowserColumnAnimationSpeedMultiplier -float 0

  # Resizing windows before and after showing the version browser
  # also disabled by NSWindowResizeTime -float 0.001
  defaults write NSGlobalDomain NSDocumentRevisionsWindowTransformAnimation -bool false

  # Disable smooth scrolling
  defaults write NSGlobalDomain NSScrollAnimationEnabled -bool false

  # Disable rubberband scrolling (doesn't affect web views)
  defaults write NSGlobalDomain NSScrollViewRubberbanding -bool false

  # Speed up showing a toolbar or menu bar in full screen
  defaults write NSGlobalDomain NSToolbarFullScreenAnimationDuration -float 0

  # Speed up opening and closing QuickLook windows
  defaults write NSGlobalDomain QLPanelAnimationDuration -float 0

  # Remove the auto-hiding Dock delay
  defaults write com.apple.dock autohide-delay -float 0

  # Remove the animation when hiding/showing the Dock
  defaults write com.apple.dock autohide-time-modifier -float 0

  # Speed up Mission Control animations
  defaults write com.apple.dock expose-animation-duration -float 0

  # Change minimize/maximize window effect
  defaults write com.apple.dock mineffect -string "scale"
  # Possible values: "genie", "scale" & "suck" (hidden effect)

  # Don’t animate opening applications from the Dock
  defaults write com.apple.dock launchanim -bool false

  # Speed up showing, hiding and page changing in Launchpad
  defaults write com.apple.dock springboard-show-duration -float 0
  defaults write com.apple.dock springboard-hide-duration -float 0
  defaults write com.apple.dock springboard-page-duration -float 0

  # Finder: disable window animations and Get Info animations
  defaults write com.apple.finder DisableAllAnimations -bool true

  # Disable send and reply animations in Mail.app
  defaults write com.apple.mail DisableReplyAnimations -bool true
  defaults write com.apple.mail DisableSendAnimations -bool true

  ###############################################################
  # Trackpad, mouse, keyboard, Bluetooth accessories, and input #
  ###############################################################

  # Trackpad: enable tap to click for this user and for the login screen
  defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
  defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

  # Enable 3-finger drag. (Moving with 3 fingers in any window "chrome" moves the window.)
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
  defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true

  # Trackpad: map bottom right corner to right-click
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
  defaults -currentHost write NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior -int 1
  defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true

  # Increase sound quality for Bluetooth headphones/headsets
  defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40

  # Enable full keyboard access for all controls
  # (e.g. enable Tab in modal dialogs)
  defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

  # Use scroll gesture with the Ctrl (^) modifier key to zoom
  defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true
  defaults write com.apple.universalaccess HIDScrollZoomModifierMask -int 262144
  # Follow the keyboard focus while zoomed in
  defaults write com.apple.universalaccess closeViewZoomFollowsFocus -bool true

  # Disable press-and-hold for keys in favor of key repeat
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

  # Set a blazingly fast keyboard repeat rate
  defaults write NSGlobalDomain KeyRepeat -int 2 # minimum 1
  defaults write NSGlobalDomain InitialKeyRepeat -int 15 # minimum 10

  ##########
  # Screen #
  ##########

  # Require password immediately after sleep or screen saver begins
  defaults write com.apple.screensaver askForPassword -int 1
  defaults write com.apple.screensaver askForPasswordDelay -int 0

  # Save screenshots to the desktop
  defaults write com.apple.screencapture location -string "${HOME}/Desktop"

  # Save screenshots in PNG format (other options: BMP, GIF, JPG, PDF, TIFF)
  defaults write com.apple.screencapture type -string "JPG"

  # Disable shadow in screenshots
  defaults write com.apple.screencapture disable-shadow -bool true

  # Enable subpixel font rendering on non-Apple LCDs
  # Reference: https://github.com/kevinSuttle/macOS-Defaults/issues/17#issuecomment-266633501
  defaults -currentHost write NSGlobalDomain AppleFontSmoothing -int 1

  # Fix terrible blurry font rendering issue in Mojave
  defaults write NSGlobalDomain CGFontRenderingFontSmoothingDisabled -bool false

  ##########
  # Finder #
  ##########

  # Use ForkList 3 as default file viewer
  # defaults write NSGlobalDomain NSFileViewer -string com.binarynights.ForkLift-3

  # Finder: allow quitting via ⌘ + Q; doing so will also hide desktop icons
  defaults write com.apple.finder QuitMenuItem -bool true

  # Set Desktop as the default location for new Finder windows
  # For other paths, use `PfLo` and `file:///full/path/here/`
  defaults write com.apple.finder NewWindowTarget -string "PfDe"
  defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Desktop/"

  # Show icons for hard drives, servers, and removable media on the desktop
  defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
  defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
  defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
  defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

  # Finder: show all filename extensions
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true

  # Finder: show status bar
  defaults write com.apple.finder ShowStatusBar -bool true

  # Finder: show path bar
  defaults write com.apple.finder ShowPathbar -bool true

  # Show hidden files in the Finder
  defaults write com.apple.finder AppleShowAllFiles -bool false

  # Display full POSIX path as Finder window title
  defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

  # Keep folders on top when sorting by name
  defaults write com.apple.finder _FXSortFoldersFirst -bool true
  
  # Keep folders on top on Desktop
  defaults write com.apple.finder _FXSortFoldersFirstOnDesktop -bool true

  # When performing a search, search the current folder by default
  defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

  # Disable the warning when changing a file extension
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

  # Enable spring loading for directories
  defaults write NSGlobalDomain com.apple.springing.enabled -bool true

  # Remove the spring loading delay for directories
  defaults write NSGlobalDomain com.apple.springing.delay -float 0

  # Avoid creating .DS_Store files on network or USB volumes
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

  # Disable disk image verification
  defaults write com.apple.frameworks.diskimages skip-verify -bool true
  defaults write com.apple.frameworks.diskimages skip-verify-locked -bool true
  defaults write com.apple.frameworks.diskimages skip-verify-remote -bool true

  # Automatically open a new Finder window when a volume is mounted
  defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true
  defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true
  defaults write com.apple.finder OpenWindowForNewRemovableDisk -bool true

  # Show item info near icons on the desktop and in other icon views
  /usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:showItemInfo true" ~/Library/Preferences/com.apple.finder.plist
  /usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:showItemInfo true" ~/Library/Preferences/com.apple.finder.plist
  /usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:showItemInfo true" ~/Library/Preferences/com.apple.finder.plist

  # Show item info to the right of the icons on the desktop
  /usr/libexec/PlistBuddy -c "Set DesktopViewSettings:IconViewSettings:labelOnBottom false" ~/Library/Preferences/com.apple.finder.plist

  # Enable snap-to-grid for icons on the desktop and in other icon views
  /usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
  /usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
  /usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist

  # Increase grid spacing for icons on the desktop and in other icon views
  /usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:gridSpacing 100" ~/Library/Preferences/com.apple.finder.plist
  /usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:gridSpacing 100" ~/Library/Preferences/com.apple.finder.plist
  /usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:gridSpacing 100" ~/Library/Preferences/com.apple.finder.plist

  # Increase the size of icons on the desktop and in other icon views
  /usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:iconSize 80" ~/Library/Preferences/com.apple.finder.plist
  /usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:iconSize 80" ~/Library/Preferences/com.apple.finder.plist
  /usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:iconSize 80" ~/Library/Preferences/com.apple.finder.plist

  # Use list view in all Finder windows by default
  # Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`
  defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

  # Disable the warning before emptying the Trash
  defaults write com.apple.finder WarnOnEmptyTrash -bool false

  # Enable AirDrop over Ethernet and on unsupported Macs running Lion
  defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true

  # Show the ~/Library folder
  chflags nohidden ~/Library

  # Expand the following File Info panes:
  # “General”, “Open with”, and “Sharing & Permissions”
  defaults write com.apple.finder FXInfoPanesExpanded -dict \
    General -bool true \
    OpenWith -bool true \
    Privileges -bool true

  ####################################
  # Dock, Dashboard, and hot corners #
  ####################################

  # Show more apps per page in Launchpad
  defaults write com.apple.dock springboard-columns -int 8
  defaults write com.apple.dock springboard-rows -int 7

  # Enable highlight hover effect for the grid view of a stack (Dock)
  defaults write com.apple.dock mouse-over-hilite-stack -bool true

  # Set the icon size of Dock items to 36 pixels
  defaults write com.apple.dock tilesize -int 36

  # Minimize windows into their application’s icon
  defaults write com.apple.dock minimize-to-application -bool true

  # Enable spring loading for all Dock items
  defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true

  # Show indicator lights for open applications in the Dock
  defaults write com.apple.dock show-process-indicators -bool true

  # Don’t group windows by application in Mission Control
  # (i.e. use the old Exposé behavior instead)
  defaults write com.apple.dock expose-group-by-app -bool false

  # Disable Dashboard
  defaults write com.apple.dashboard mcx-disabled -bool true

  # Don’t show Dashboard as a Space
  defaults write com.apple.dock dashboard-in-overlay -bool true

  # View open windows by two-finger scroll up gesture
  defaults write com.apple.dock scroll-to-open -bool true

  # Don’t automatically rearrange Spaces based on most recent use
  defaults write com.apple.dock mru-spaces -bool false

  # Automatically hide and show the Dock
  defaults write com.apple.dock autohide -bool true

  # Make Dock icons of hidden applications translucent
  defaults write com.apple.dock showhidden -bool true

  # Don’t show recent applications in Dock
  defaults write com.apple.dock show-recents -bool false

  # Reset Launchpad apps order
  local macosVersion=$(sw_vers -productVersion | cut -f1 -d'.')
  if [ macosVersion -le 15 ]; then
    find 2>/dev/null /private/var/folders/ -type d -name com.apple.dock.launchpad -exec rm -rf {} +
  else
    defaults write com.apple.dock ResetLaunchPad -bool true
  fi

  # Add a spacer to the left side of the Dock (where the applications are)
  defaults write com.apple.dock persistent-apps -array-add '{tile-data={}; tile-type="spacer-tile";}'
  # Add a spacer to the right side of the Dock (where the Trash is)
  defaults write com.apple.dock persistent-others -array-add '{tile-data={}; tile-type="spacer-tile";}'

  # Hot corners
  # Possible values:
  #  0: no-op
  #  2: Mission Control
  #  3: Show application windows
  #  4: Desktop
  #  5: Start screen saver
  #  6: Disable screen saver
  #  7: Dashboard
  # 10: Put display to sleep
  # 11: Launchpad
  # 12: Notification Center
  # Modifier values:
  # ⌘ -> 1048576
  # Top left screen corner → Show application windows
  defaults write com.apple.dock wvous-tl-corner -int 3
  defaults write com.apple.dock wvous-tl-modifier -int 1048576
  # Top right screen corner → Mission Control
  defaults write com.apple.dock wvous-tr-corner -int 2
  defaults write com.apple.dock wvous-tr-modifier -int 1048576
  # Bottom left screen corner → Start screen saver
  defaults write com.apple.dock wvous-bl-corner -int 5
  defaults write com.apple.dock wvous-bl-modifier -int 1048576
  # Bottom right screen corner → Desktop
  defaults write com.apple.dock wvous-br-corner -int 4
  defaults write com.apple.dock wvous-br-modifier -int 1048576

  ###################
  # Safari & WebKit #
  ###################

  # Shorten Safari's WebKit render engine's delay
  defaults write com.apple.Safari WebKitInitialTimedLayoutDelay 0.25
  defaults write com.apple.Safari WebKitResourceTimedLayoutDelay 0.0001

  # Privacy: don’t send search queries to Apple
  defaults write com.apple.Safari UniversalSearchEnabled -bool false
  defaults write com.apple.Safari SuppressSearchSuggestions -bool true

  # Press Tab to highlight each item on a web page
  defaults write com.apple.Safari WebKitTabToLinksPreferenceKey -bool true
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks -bool true

  # Show the full URL in the address bar (note: this still hides the scheme)
  defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

  # Set Safari’s home page to `about:blank` for faster loading
  defaults write com.apple.Safari HomePage -string "about:blank"

  # Prevent Safari from opening ‘safe’ files automatically after downloading
  defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

  # Allow hitting the Backspace key to go to the previous page in history
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled -bool true

  # Hide Safari’s bookmarks bar by default
  defaults write com.apple.Safari ShowFavoritesBar -bool false

  # Hide Safari’s sidebar in Top Sites
  defaults write com.apple.Safari ShowSidebarInTopSites -bool false

  # Disable Safari’s thumbnail cache for History and Top Sites
  defaults write com.apple.Safari DebugSnapshotsUpdatePolicy -int 2

  # Enable Safari’s debug menu
  defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

  # Make Safari’s search banners default to Contains instead of Starts With
  defaults write com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false

  # Remove useless icons from Safari’s bookmarks bar
  defaults write com.apple.Safari ProxiesInBookmarksBar "()"

  # Enable the Develop menu and the Web Inspector in Safari
  defaults write com.apple.Safari IncludeDevelopMenu -bool true
  defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

  # Add a context menu item for showing the Web Inspector in web views
  defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

  # Enable continuous spellchecking
  defaults write com.apple.Safari WebContinuousSpellCheckingEnabled -bool true
  # Disable auto-correct
  defaults write com.apple.Safari WebAutomaticSpellingCorrectionEnabled -bool false

  # Disable AutoFill
  defaults write com.apple.Safari AutoFillFromAddressBook -bool false
  defaults write com.apple.Safari AutoFillPasswords -bool false
  defaults write com.apple.Safari AutoFillCreditCardData -bool false
  defaults write com.apple.Safari AutoFillMiscellaneousForms -bool false

  # Warn about fraudulent websites
  defaults write com.apple.Safari WarnAboutFraudulentWebsites -bool true

  # Disable plug-ins
  defaults write com.apple.Safari WebKitPluginsEnabled -bool false
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2PluginsEnabled -bool false

  # Disable Java
  defaults write com.apple.Safari WebKitJavaEnabled -bool false
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled -bool false

  # Block pop-up windows
  defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically -bool false

  # Disable auto-playing video
  defaults write com.apple.Safari WebKitMediaPlaybackAllowsInline -bool false
  defaults write com.apple.SafariTechnologyPreview WebKitMediaPlaybackAllowsInline -bool false
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2AllowsInlineMediaPlayback -bool false
  defaults write com.apple.SafariTechnologyPreview com.apple.Safari.ContentPageGroupIdentifier.WebKit2AllowsInlineMediaPlayback -bool false

  # Enable “Do Not Track”
  defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true

  # Update extensions automatically
  defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true

  ########
  # Mail #
  ########

  # Copy email addresses as `foo@example.com` instead of `Foo Bar <foo@example.com>` in Mail.app
  defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false

  # Add the keyboard shortcut ⌘ + Enter to send an email in Mail.app
  defaults write com.apple.mail NSUserKeyEquivalents -dict-add "Send" "@\U21a9"

  # Display emails in threaded mode, sorted by date (oldest at the top)
  defaults write com.apple.mail DraftsViewerAttributes -dict-add "DisplayInThreadedMode" -string "yes"
  defaults write com.apple.mail DraftsViewerAttributes -dict-add "SortedDescending" -string "yes"
  defaults write com.apple.mail DraftsViewerAttributes -dict-add "SortOrder" -string "received-date"

  # Disable inline attachments (just show the icons)
  defaults write com.apple.mail DisableInlineAttachmentViewing -bool true

  # Disable automatic spell checking
  defaults write com.apple.mail SpellCheckingBehavior -string "NoSpellCheckingEnabled"

  ######################
  # Terminal & iTerm 2 #
  ######################

  # Only use UTF-8 in Terminal.app
  defaults write com.apple.terminal StringEncodings -array 4

  # Enable Secure Keyboard Entry in Terminal.app
  # See: https://security.stackexchange.com/a/47786/8918
  defaults write com.apple.terminal SecureKeyboardEntry -bool true

  # Disable the annoying line marks
  defaults write com.apple.Terminal ShowLineMarks -int 0

  # Don’t display the annoying prompt when quitting iTerm
  defaults write com.googlecode.iterm2 PromptOnQuit -bool false

  ###############################################################################
  # Activity Monitor                                                            #
  ###############################################################################

  # Show the main window when launching Activity Monitor
  defaults write com.apple.ActivityMonitor OpenMainWindow -bool true

  # Visualize CPU usage in the Activity Monitor Dock icon
  defaults write com.apple.ActivityMonitor IconType -int 5

  # Show all processes in Activity Monitor
  defaults write com.apple.ActivityMonitor ShowCategory -int 0

  # Sort Activity Monitor results by CPU usage
  defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
  defaults write com.apple.ActivityMonitor SortDirection -int 0

  ###############################################################################
  # Address Book, Dashboard, TextEdit, and Disk Utility                   #
  ###############################################################################

  # Enable the debug menu in Address Book
  defaults write com.apple.addressbook ABShowDebugMenu -bool true

  # Enable Dashboard dev mode (allows keeping widgets on the desktop)
  defaults write com.apple.dashboard devmode -bool true

  # Use plain text mode for new TextEdit documents
  defaults write com.apple.TextEdit RichText -int 0
  # Open and save files as UTF-8 in TextEdit
  defaults write com.apple.TextEdit PlainTextEncoding -int 4
  defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

  # Enable the debug menu in Disk Utility
  defaults write com.apple.DiskUtility DUDebugMenuEnabled -bool true
  defaults write com.apple.DiskUtility advanced-image-options -bool true

  # Auto-play videos when opened with QuickTime Player
  defaults write com.apple.QuickTimePlayerX MGPlayMovieOnOpen -bool true

  ###############################################################################
  # Mac App Store                                                               #
  ###############################################################################

  # Enable the WebKit Developer Tools in the Mac App Store
  defaults write com.apple.appstore WebKitDeveloperExtras -bool true

  # Enable Debug Menu in the Mac App Store
  defaults write com.apple.appstore ShowDebugMenu -bool true

  # Enable the automatic update check
  defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

  # Check for software updates daily, not just once per week
  defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

  # Download newly available updates in background
  defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

  # Install System data files & security updates
  defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

  # Automatically download apps purchased on other Macs
  defaults write com.apple.SoftwareUpdate ConfigDataInstall -int 1

  # Turn on app auto-update
  defaults write com.apple.commerce AutoUpdate -bool true

  # Allow the App Store to reboot machine on macOS updates
  defaults write com.apple.commerce AutoUpdateRestartRequired -bool true

  ###############################################################################
  # Photos                                                                      #
  ###############################################################################

  # Prevent Photos from opening automatically when devices are plugged in
  defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

  ###############################################################################
  # Messages                                                                    #
  ###############################################################################

  # Disable automatic emoji substitution (i.e. use plain text smileys)
  defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticEmojiSubstitutionEnablediMessage" -bool false

  # Disable smart quotes as it’s annoying for messages that contain code
  defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticQuoteSubstitutionEnabled" -bool false

  # Disable continuous spell checking
  defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "continuousSpellCheckingEnabled" -bool false

  ###############################################################################
  # Google Chrome & Google Chrome Canary                                        #
  ###############################################################################

  # Disable the all too sensitive backswipe on trackpads
  defaults write com.google.Chrome AppleEnableSwipeNavigateWithScrolls -bool false
  defaults write com.google.Chrome.canary AppleEnableSwipeNavigateWithScrolls -bool false

  # Disable the all too sensitive backswipe on Magic Mouse
  defaults write com.google.Chrome AppleEnableMouseSwipeNavigateWithScrolls -bool false
  defaults write com.google.Chrome.canary AppleEnableMouseSwipeNavigateWithScrolls -bool false

  # Use the system-native print preview dialog
  # defaults write com.google.Chrome DisablePrintPreview -bool true
  # defaults write com.google.Chrome.canary DisablePrintPreview -bool true

  # Expand the print dialog by default
  defaults write com.google.Chrome PMPrintingExpandedStateForPrint2 -bool true
  defaults write com.google.Chrome.canary PMPrintingExpandedStateForPrint2 -bool true

  # Disable mailto shortcuts
  defaults write com.google.Chrome NSUserKeyEquivalents -dict-add 'Email Link' '\0'
  defaults write com.google.Chrome.canary NSUserKeyEquivalents -dict-add 'Email Link' '\0'

  ################
  # SlowQuitApps #
  ################
  defaults write com.dteoh.SlowQuitApps delay -int 500

  # Apply the settings
  /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

  ##############################
  # Kill affected applications #
  ##############################

  for app in "Activity Monitor" \
    "Address Book" \
    "Calendar" \
    "cfprefsd" \
    "Contacts" \
    "Dock" \
    "Finder" \
    "Google Chrome Canary" \
    "Google Chrome" \
    "Mail" \
    "Messages" \
    "Opera" \
    "Photos" \
    "Safari" \
    "SystemUIServer"; do
    killall "${app}" &> /dev/null
  done
  echo "Done. Note that some of these changes require a logout/restart to take effect."
}
