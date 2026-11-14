# Fast (iOS 18+ SwiftUI + SwiftData + CloudKit)

Native iOS port of the Fast fasting timer and macro tracker.

## Setup in Xcode

1. **Generate the Xcode project** (using [XcodeGen](https://github.com/yonaskolb/XcodeGen)):
   ```bash
   cd ios/Fast
   xcodegen generate
   open Fast.xcodeproj
   ```
   *(Alternatively, create a new iOS App in Xcode 16+ targeting iOS 18.0 and add the `Fast/` source files, `Info.plist`, `Assets.xcassets`, and `Fast.entitlements`.)*

2. **Configure Signing & CloudKit**:
   - Select the **Fast** target → **Signing & Capabilities**.
   - Set your **Team** and update the Bundle Identifier if needed (e.g. `com.<yourname>.fast`).
   - Ensure **iCloud** is enabled with **CloudKit** checked and a container matching `Fast.entitlements` (default: `iCloud.com.tenebrsx.fast`).
   - Ensure **Background Modes** → **Remote notifications** is enabled for silent CloudKit sync pushes.

3. **Build & Run** on an iOS 18+ simulator or device.
