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
┌──────────────────────────────────────────────────────────┐
│                      Host Machine                        │
│                                                          │
│  ┌───────────────────┐  ┌─────────────┐  ┌───────────┐  │
│  │    Adaptix C2     │  │Elasticsearch│  │  Kibana   │  │
│  │                   │  │  (single)   │  │           │  │
│  │ API    :4321      │  │             │  │           │  │
│  │ HTTPS  :8443 ◄──┐│  │ http://:9200│  │http://:5601  │
│  │ HTTP   :80/:443  ││  │             │  │           │  │
│  └───────────────────┘  └──────┬──────┘  └─────┬─────┘  │
│         ▲               │      │               │         │
│         │               │      └───────────────┘         │
│    Beacon Agent         │     Telemetry Pipeline         │
│    (runs on host)       │    (Sysmon → Elastic)          │
└──────────────────────────────────────────────────────────┘
```

### Services

| Service | Default Endpoint | Container | Notes |
|---------|-----------------|-----------|-------|
| Adaptix C2 | `https://localhost:4321/endpoint` | `c2inabox-adaptix` | Teamserver API + client |
| HTTPS Listener | `https://localhost:8443` | `c2inabox-adaptix` | Auto-created BeaconHTTP |
| Elasticsearch | `http://localhost:9200` | `c2inabox-elasticsearch` | Single-node, trial license |
| Kibana | `http://localhost:5601` | `c2inabox-kibana` | Security + Fleet |
| Fleet Server | `http://localhost:8220` | `c2inabox-fleet-server` | Agent management |
| Elastic Agent | — | Runs on host | Enrolled via `enroll-agent.ps1` |

## Configuration

### Environment (`.env`)

| Variable | Default | Description |
|----------|---------|-------------|
| `ADAPTIX_SRC` | `./../AdaptixC2` | Path to cloned Adaptix source |
| `ES_PORT` | `9200` | Elasticsearch port |
| `ES_HEAP` | `1g` | Elasticsearch JVM heap |
| `ES_MEM_LIMIT` | `3G` | Elasticsearch container memory limit |
| `ELASTIC_PASSWORD` | `c2inabox-lab` | Elasticsearch `elastic` user password |
| `KIBANA_PORT` | `5601` | Kibana port |
| `KIBANA_SYSTEM_PASSWORD` | `c2inabox-lab` | Kibana system user password |
| `FLEET_PORT` | `8220` | Fleet Server port |
| `FLEET_SERVICE_TOKEN` | — | Fleet service token (see setup) |

### Adaptix Profile (`config/profile.yaml`)

Teamserver configuration: password, operators, listeners, TLS settings. See [Adaptix docs](https://github.com/Adaptix-Framework/AdaptixC2) for all options.

> **Never commit real credentials.** The repo ships `profile.example.yaml` with placeholder values. Your local `config/profile.yaml` is git-ignored.

## Usage

### Deploy & Manage

```powershell
# Full stack — builds, starts, creates listener, and enrolls Elastic Agent
.\deploy.ps1

# Full stack + generate a beacon payload to C:\Tools\Payloads
.\deploy.ps1 -GeneratePayload

# Custom payload directory
.\deploy.ps1 -GeneratePayload -PayloadDir D:\Engagements\lab\payloads

# Skip build (use cached artifacts)
.\deploy.ps1 -SkipBuild

# Force rebuild Adaptix
.\deploy.ps1 -Force

# Deploy without auto-creating the listener
.\deploy.ps1 -NoListener

# Skip Elastic Agent enrollment
.\deploy.ps1 -SkipEnroll

# Elastic + Kibana only (no C2)
.\deploy.ps1 -ElasticOnly

# Create/recreate listener independently
.\setup-listener.ps1
.\setup-listener.ps1 -GeneratePayload -PayloadDir C:\Tools\Payloads

# Check service health
.\status.ps1

# Stop everything (keep data)
.\teardown.ps1

# Stop and purge all volumes
.\teardown.ps1 -Purge
```

### Test a Payload

1. **Deploy**: `.\deploy.ps1 -GeneratePayload`
2. **Run agent**: Execute the beacon from `C:\Tools\Payloads\`
3. **Connect**: Open the Adaptix client → `https://localhost:4321/endpoint`
4. **Execute**: Run your payload/BOF through the beacon
5. **Detect**: Check Kibana → Security → Alerts at `http://localhost:5601`

> The default HTTPS listener is created automatically on port 8443. Use `-NoListener` to skip this.

### What Gets Auto-Deployed

| Component | What | Auto-configured |
|-----------|------|-----------------|
| **Adaptix C2** | Teamserver + HTTPS listener on :8443 | Listener + TLS certs |
| **Elasticsearch** | Single-node, trial license (30d) | Behavioral protections unlocked |
| **Kibana** | Security app + Fleet | SIEM rules enabled |
| **Elastic Defend** | Endpoint protection in Detect mode | Malware, behavior, memory, ransomware |
| **Fleet Server** | Agent management | Service token + enrollment |
| **Elastic Agent** | Host endpoint telemetry | Auto-enrolled to default-policy |
| **Detection Rules** | 1266+ prebuilt rules | Windows + Endpoint subset enabled |

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
├── deploy.ps1                # One-command deploy (build + run + listener + agent)
├── docker-compose.yml        # Unified stack definition
├── enroll-agent.ps1          # Download and enroll Elastic Agent on host
├── setup-listener.ps1        # Auto-create HTTPS listener + optional payload gen
├── setup-siem.ps1            # Manual SIEM setup (detection rules, etc.)
├── status.ps1                # Health check
└── teardown.ps1              # Clean shutdown
```

## Roadmap

- [x] Elastic Agent auto-enrollment with Elastic Defend integration
- [x] Trial license + behavioral/memory/malware protections in Detect mode
- [x] 1266+ prebuilt detection rules auto-enabled
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
