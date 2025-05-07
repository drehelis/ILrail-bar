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
## v1.0.2v - 2024-04-19
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