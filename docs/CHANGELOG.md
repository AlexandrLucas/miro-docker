# 📜 Changelog

This project adheres to [Semantic Versioning](https://semver.org/).

---
## [v4.0.0] - 2025-10-26

### Added
 - Expanded docs

### Changed
 - Enforce LF line endings for cross-platform work
 - Split Docker Compose files based on OS and dGPU brand (if present)

### Fixed
 - Various tweaks to `miro` command

## [v3.0.0] - 2025-10-11
### Added
 - Conditional builds
 - More docs

### Changed
 - Refactored Dockerfile for better readability
 - Moved most variables from Dockerfile to compose and .env

### Fixed
 - Cairo (Mics plotting in MiRo GUI)

## [v2.0.0] - 2025-10-05
### Added
- `miro`, one command to rule them all (to be used inside docker)

### Changed
- Removed Turtlebot3 scripts
- Improved layer organisation in Dockerfile

### Fixed
- A few (harmless) warnings

## [v1.0.0] - 2025-10-05
### Added
- Initial release of MiRo Docker environment
- Working GUI, networking and GPU passthrough setup
