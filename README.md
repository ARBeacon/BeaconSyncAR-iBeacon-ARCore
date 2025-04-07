# BeaconSyncAR-iBeacon-ARCore

iOS app for BLE-assisted AR synchronization using Google ARCore's Cloud Anchors.

## 🚀 Quick Start

### Prerequisites
- Xcode 16+
- iOS device with ARKit support
- Running [Google ARCore API Instance](https://console.cloud.google.com/apis/library/arcore)

### Local Setup

1. Clone the repository: 
```bash
git clone https://github.com/ARBeacon/BeaconSyncAR-iBeacon-ARCore.git
cd BeaconSyncAR-iBeacon-ARCore
```
2. Configure environment variables:
```bash
cp BeaconSyncAR-iBeacon-ARCore/Config.xcconfig.example BeaconSyncAR-iBeacon-ARCore/Config.xcconfig
```
Edit the Config.xcconfig file with your Google ARCore API's credentials and your [backend](https://github.com/ARBeacon/BeaconSyncAR-api) endpoint url.

3. Run the app:

open the project in Xcode and click "Run".