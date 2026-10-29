# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Initial release
- Docker Compose stack: Adaptix C2 + Elasticsearch 8.15.3 + Kibana 8.15.3
- `deploy.ps1` — one-command build and deploy with `-Force`, `-SkipBuild`, `-ElasticOnly` flags
- `teardown.ps1` — clean shutdown with optional `-Purge` for volume removal
- `status.ps1` — service health checks
- Configurable via `.env` and `config/profile.yaml`
- Adaptix build artifacts cached in Docker volumes for fast redeploy
