<h1 align="center">C2inaBox</h1>

<p align="center">
  <strong>One-command C2 + detection lab for security testing</strong>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> &bull;
  <a href="#architecture">Architecture</a> &bull;
  <a href="#configuration">Configuration</a> &bull;
  <a href="#usage">Usage</a> &bull;
  <a href="#contributing">Contributing</a>
</p>

---

C2inaBox deploys [Adaptix C2](https://github.com/Adaptix-Framework/AdaptixC2), Elasticsearch, and Kibana as a single Docker Compose stack. Build the C2 server from source, spin up the detection pipeline, test your payloads, and tear it all down when you're done.

> **Authorised use only.** This tool is for isolated lab environments and engagements with written authorisation. See [SECURITY.md](SECURITY.md).

## Quick Start

### Prerequisites

| Requirement | Version |
|-------------|---------|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | 24+ |
| [Adaptix C2 source](https://github.com/Adaptix-Framework/AdaptixC2) | Cloned locally |
| RAM | 8 GB free recommended |

### Setup

```powershell
# 1. Clone this repo
git clone https://github.com/p4zrs/C2inaBox.git
cd C2inaBox

# 2. Clone Adaptix C2 source alongside it
git clone https://github.com/Adaptix-Framework/AdaptixC2.git ../AdaptixC2

# 3. Copy config templates
cp .env.example .env
cp config/profile.example.yaml config/profile.yaml

# 4. Edit config/profile.yaml — change the default password and operators

# 5. Deploy
.\deploy.ps1
```

First run builds Adaptix from source (~5 min). Subsequent deploys reuse cached artifacts and start in seconds.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Host Machine                        │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Adaptix C2  │  │Elasticsearch │  │    Kibana    │  │
│  │  Teamserver  │  │  (single)    │  │              │  │
│  │              │  │              │  │              │  │
│  │ wss://:4321  │  │ http://:9200 │  │ http://:5601 │  │
│  │ network:host │  │              │  │              │  │
│  └──────────────┘  └──────┬───────┘  └──────┬───────┘  │
│         │                 │                  │          │
│         ▼                 └──────────────────┘          │
│    Beacon Agent                                         │
│    (runs on host)          Telemetry Pipeline            │
│                           (Sysmon → Elastic)            │
└─────────────────────────────────────────────────────────┘
```

### Services

| Service | Default Endpoint | Container | Notes |
|---------|-----------------|-----------|-------|
| Adaptix C2 | `wss://localhost:4321` | `c2inabox-adaptix` | `network_mode: host` — listeners bind any port |
| Elasticsearch | `http://localhost:9200` | `c2inabox-elasticsearch` | Single-node, security disabled |
| Kibana | `http://localhost:5601` | `c2inabox-kibana` | Detection dashboards |

## Configuration

### Environment (`.env`)

| Variable | Default | Description |
|----------|---------|-------------|
| `ADAPTIX_SRC` | `./../AdaptixC2` | Path to cloned Adaptix source |
| `ES_PORT` | `9200` | Elasticsearch port |
| `ES_HEAP` | `1g` | Elasticsearch JVM heap |
| `ES_MEM_LIMIT` | `3G` | Elasticsearch container memory limit |
| `KIBANA_PORT` | `5601` | Kibana port |

### Adaptix Profile (`config/profile.yaml`)

Teamserver configuration: password, operators, listeners, TLS settings. See [Adaptix docs](https://github.com/Adaptix-Framework/AdaptixC2) for all options.

> **Never commit real credentials.** The repo ships `profile.example.yaml` with placeholder values. Your local `config/profile.yaml` is git-ignored.

## Usage

### Deploy & Manage

```powershell
# Full stack (build + run)
.\deploy.ps1

# Skip build (use cached artifacts)
.\deploy.ps1 -SkipBuild

# Force rebuild Adaptix
.\deploy.ps1 -Force

# Elastic + Kibana only (no C2)
.\deploy.ps1 -ElasticOnly

# Check service health
.\status.ps1

# Stop everything (keep data)
.\teardown.ps1

# Stop and purge all volumes
.\teardown.ps1 -Purge
```

### Test a Payload

1. **Deploy**: `.\deploy.ps1`
2. **Connect**: Open the Adaptix client → `wss://localhost:4321`
3. **Listener**: Create an HTTP listener in the Adaptix UI
4. **Agent**: Generate a beacon agent and run it on the target host
5. **Execute**: Run your payload/BOF through the beacon
6. **Detect**: Check Kibana at `http://localhost:5601` for telemetry

### Docker Compose Profiles

| Profile | What it does |
|---------|-------------|
| `build` | Compiles Adaptix C2 server + extenders from source |
| `run` | Starts all runtime services |

```powershell
# Manual profile usage (if not using the scripts)
docker compose --profile build up --build
docker compose --profile run up -d
docker compose --profile run down
```

## Project Structure

```
C2inaBox/
├── .env.example              # Environment template
├── .gitignore
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── README.md
├── SECURITY.md
├── config/
│   └── profile.example.yaml  # Adaptix teamserver config template
├── deploy.ps1                # One-command deploy
├── docker-compose.yml        # Unified stack definition
├── docs/
│   └── banner.png            # Repo banner (placeholder)
├── status.ps1                # Health check
└── teardown.ps1              # Clean shutdown
```

## Roadmap

- [ ] Sysmon config + Winlogbeat/Elastic Agent ingest pipeline
- [ ] Pre-built Kibana dashboards for common detection signatures
- [ ] Bash equivalents of PowerShell scripts for Linux/macOS hosts
- [ ] Optional Caldera integration for adversary emulation plans
- [ ] Pre-built Adaptix images to skip the build step

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) — see the file for details.

## Acknowledgements

- [Adaptix C2 Framework](https://github.com/Adaptix-Framework/AdaptixC2) — the C2 platform this wraps
- [Elastic](https://www.elastic.co/) — Elasticsearch and Kibana
