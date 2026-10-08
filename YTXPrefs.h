// Shared by the tweak and the prefs bundle.

#define kYTXDomain        "com.anlai.youtubex"
#define kYTXPrefsChanged  "com.anlai.youtubex/prefschanged"

// Keys stored by the prefs bundle
#define kYTXEnabled         "enabled"
#define kYTXActivation      "activation"     // 0 = only on CarPlay, 1 = always
#define kYTXIPadLayout      "ipadLayout"
#define kYTXForceLandscape  "forceLandscape"

// Defaults when the user hasn't touched Settings
#define kYTXDefaultEnabled         YES
#define kYTXDefaultActivation      0
#define kYTXDefaultIPadLayout      YES
#define kYTXDefaultForceLandscape  YES

// YouTube is sandboxed and can't read the prefs plist, but it can read the state of a
// notify token. The prefs bundle packs the settings into these bits.
// Change the "valid" bit whenever a setting is added, so state from an old build is ignored.
#define kYTXStateValid           (1ULL << 9)
#define kYTXStateEnabled         (1ULL << 1)
#define kYTXStateAlways          (1ULL << 2)
#define kYTXStateIPadLayout      (1ULL << 3)
#define kYTXStateForceLandscape  (1ULL << 4)
