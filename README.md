> **Note:** To access all shared projects, get information about environment setup, and view other guides, please visit [Explore-In-HMOS-Wearable Index](https://github.com/Explore-In-HMOS-Wearable/hmos-index).

# Guess the Num Game

**Guess the Num Game** is a HarmonyOS wearable number guessing game designed for small circular screens. It includes classic, timed, and streak-based play modes, quick resume for active sessions, lifecycle logs, history and stats views, configurable background behavior, and durable state persistence across app restarts.

This project demonstrates lifecycle event handling, state management, wearable-friendly navigation, backup/restore support, and user interaction on HarmonyOS wearable devices.

# Preview

<div>
  <img src="screenshots/output.gif" width="24%">
  <img src="screenshots/output1.png" width="24%">
  <img src="screenshots/output2.png" width="24%">
</div>

# Use Cases

- **UI Lifecycle Logging**: Tracks key lifecycle events and surfaces them through a dedicated logs screen.
- **Number Guessing Game**: Play classic, timed, and streak-based rounds with quick resume for classic sessions.
- **State Persistence**: Profile, history, stats, settings, and session progress are stored durably across app restarts.
- **User Feedback**: Displays lives, score, streaks, results, achievements, and lifecycle status updates.
- **Simple and Responsive UI**: Designed for small circular wearable screens with compact controls and readable cards.
- **Backup and Restore**: Uses the backup extension to serialize and restore repository-backed app data.


# Technology
## Stack
- **Languages**: ArkTS, ArkUI
- **Frameworks**: HarmonyOS SDK 5.0.2(14)
- **Tools**: DevEco Studio Version 5.1.0.828
- **Libraries**:
  - `@kit.AbilityKit`
  - `@kit.ArkUI`
  - `@kit.CoreFileKit`
  - `@kit.PerformanceAnalysisKit`

## Required Permissions
- No need to permissions.

# Directory Structure
```
Guess the Num Game
|--- entry/src/main/ets/
| |--- common/
| | |--- util/
| | | |--- GlobalDataStorage.ets
| | | |--- LifecycleLog.ets
| |
| |--- data/
| |--- game/
| |--- pages/
| | |--- Index.ets
| |
| |--- resources/
| |--- screenshots/
```

# Constraints and Restrictions
## Supported Device

* Huawei Watch 5

# License

**Guess the Num Game** is distributed under the terms of the MIT License
See the [LICENSE](./LICENSE) for more information.
