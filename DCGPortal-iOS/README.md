# DCG Portal iOS

This is a native iOS wrapper for the existing `index.html` portal.

## Open

Open `DCGPortal.xcodeproj` in Xcode on a Mac.

## Build

1. Select the `DCGPortal` target.
2. In **Signing & Capabilities**, choose your Apple Developer team.
3. Build and run on an iPhone simulator or device.

The bundled portal file lives at `DCGPortal/Web/index.html`.

## GitHub Actions

The repository includes `.github/workflows/ios-build.yml`.

After pushing to GitHub, open **Actions > iOS Build > Run workflow**. The workflow builds the app on a macOS runner and uploads `DCGPortal-simulator-app.zip`.

That artifact is for the iOS Simulator. Installing on a real iPhone or publishing through TestFlight/App Store still requires Apple signing credentials and a provisioning profile.

## Notes

- The app uses `WKWebView` to load the local HTML.
- Excel exports from the portal are intercepted and sent to the iOS share sheet, because normal browser downloads do not behave consistently inside `WKWebView`.
- Camera and photo-library usage descriptions are included for receipt attachments.
