# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!--
Available bump types:
BUMP:patch - Increases the patch version (0.0.x)
BUMP:minor - Increases the minor version (0.x.0)
BUMP:major - Increases the major version (x.0.0)
-->

<!-- BUMP:minor -->
## v2.10.0 - 2025-09-29
### Changed
- **BREAKING CHANGE**: Updated to support upstream API changes from rail service provider
- Mandatory upgrade required for continued functionality

<!-- BUMP:patch -->
## v2.9.1 - 2025-08-07
### Added
- **Fallback System**: Added automatic fallback from original Israel Railways API to proxy endpoint if fails

<!-- BUMP:minor -->
## v2.9.0 - 2025-08-06
### Changed
- **API Update**: Switched to proxy endpoint to bypass geo-limiting restrictions from the official Israel Railways API
- Improved global accessibility for users on controlled/corporate networks with non-local routes.

<!-- BUMP:minor -->
## v2.8.0 - 2025-07-13
### Added
- Version checking: App now checks GitHub for new releases and displays update indicator

<!-- BUMP:minor -->
## v2.7.0 - 2025-07-11
### Changed
- **BREAKING CHANGE**: Updated to support upstream API changes from rail service provider
- Mandatory upgrade required for continued functionality

<!-- BUMP:patch -->
## v2.6.2 - 2025-05-09
### Added
- Display date in section headers for trains scheduled on future days
- Show notification when filter settings are active and some routes are hidden

<!-- BUMP:patch -->
## v2.6.1 - 2025-05-06
### Fixed
- Fixed platform display to always use `originPlatform`

<!-- BUMP:minor -->
## v2.6.0 - 2025-05-04
### Added
- Favorite Routes: Save and quickly access your frequently used train routes

<!-- BUMP:minor -->
## v2.5.0 - 2025-05-02
### Changed
- Improved direction reversal UX: Now only the arrow changes direction (→/←) while preserving station order in UI
- Added direction indicator to menu bar for better visibility
- Internal refactoring for direction handling with preferences synchronization

<!-- BUMP:patch -->
## v2.4.1 - 2024-04-29
### Added
- MacOS PKG installer - Helps overcoming app quarantine as I currently have no intention to Apple notarized this app

### Changed
- Redesign AboutView (added BuyMeCoffee link \o/)

<!-- BUMP:minor -->
## v2.4.0 - 2024-04-27
### Changed
- feat: Add max train changes filter
- Replaced useless train number with platform number

### Fixed
- Cache mechanism now actually works

<!-- BUMP:minor -->
## v2.3.0 - 2024-04-24
### Changed
- feat: `Walking time duration` - Adjusts schedule accordingly to the time it takes to walk from your location to the station. 

### Deprecated
- Removed color highlighting

<!-- BUMP:minor -->
## v2.2.0 - 2024-04-22
### Changed
- feat: Set activity for specific days / hours
- Few cosmetic changes, nothing too fancy

### Fixed
- A bug where Popover view was not getting refreshed according to schedule
  
<!-- BUMP:minor -->
## v2.1.0 - 2024-04-21
### Changed
- Preferences view is now also a Popover
- feat: Ability to search stations as the drop-down menu is clumsy
- Use `monospacedDigit` font for better UI experience

### Deprecated
- Replaced deprecetaed functions 

<!-- BUMP:major -->
## v2.0.0 - 2024-04-21
### Changed
- new: Change to Popover menu-bar
- fix: Better cache handeling

<!-- BUMP:patch -->
## v1.0.3 - 2024-04-19
### Changed
- fix: Adjust How-to-Install `README.txt` 

<!-- BUMP:patch -->
## v1.0.2 - 2024-04-19
### Added
- feat: Add reverse direction option

<!-- BUMP:patch -->
## v1.0.1 - 2024-04-16
### Added
- feat: Add refresh interval to Preferences

<!-- BUMP:major -->
## v1.0.0 - 2024-04-16
### Added
- Initial release
