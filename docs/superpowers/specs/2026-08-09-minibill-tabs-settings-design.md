# MiniBill Tabs and Settings Update Design

## Goal

Update MiniBill for version 1.0.1 and adjust navigation/settings before the 1.0.0 build finishes review.

## Scope

- Set the app marketing version to 1.0.1.
- Add a dedicated Statistics tab between Bills and Me.
- Keep statistics available from the bills monthly summary as a shortcut.
- Remove misleading non-action affordances in Statistics.
- Merge the standalone privacy page content into About MiniBill.
- Add More Apps, Contact Email, Rate App, and visible version information to settings.

## Navigation Design

The root tab view will have three tabs:

- Bills: ledger list and quick entry.
- Statistics: month analytics with its own navigation stack.
- Me: settings.

Notification routes will continue to support quick entry and statistics. Quick entry selects Bills and opens the sheet. Statistics selects the Statistics tab instead of pushing a statistics screen inside Bills.

Bills can still open Statistics from the monthly summary card. Because Statistics is now a tab-level destination, the shortcut will switch to the Statistics tab and set the selected month to the current month.

## Statistics Design

Statistics remains the existing monthly analytics screen: month switcher, summary card, share action, daily chart, and project rankings.

The monthly summary card will support an explicit chevron option. It will show the chevron only when the card itself is acting as a navigation affordance. The summary card inside Statistics will not show a chevron, removing the current grey non-clickable cue.

## Settings Design

Settings keeps the existing Form structure. The App section will include:

- Language.
- About MiniBill.
- Version display using `CFBundleShortVersionString`.
- Contact Email, opening `mailto:yokinzhu@gmail.com` and copying the email if Mail is unavailable.
- Rate App, temporarily using LightKitList's App Store review URL with app id `6761642667`.
- More Apps, opening the developer page used by LightKitList.

The standalone Privacy row will be removed. About MiniBill will show the app icon, app name, short description, version, and the existing privacy statements.

## Localization

All new visible strings will be added to `MiniBill/Resources/Localizable.xcstrings` for the currently supported languages: English, Simplified Chinese, Traditional Chinese, Japanese, and Korean.

## Error Handling

External links use `UIApplication.shared.open`. Contact Email falls back to copying the address to the pasteboard and showing a short alert if `mailto` cannot be opened. Invalid optional URLs are treated as no-ops to avoid crashes.

## Testing

Run the package or Xcode-backed test command available for MiniBill. At minimum, build/test the Swift package target if available and verify localization catalog parsing after edits.
