# Security Policy

## Intended Use

C2inaBox is a **lab orchestration tool** for security professionals. It is designed for:

- Isolated lab environments
- Authorised penetration testing engagements
- Security research and tool development
- Purple team exercises with detection validation

**Do not** deploy this on production networks, use it against systems without written authorisation, or expose the services to the internet.

## Responsible Disclosure

If you discover a security issue in C2inaBox itself (not Adaptix C2 or Elastic — report those upstream), please open a GitHub issue or contact the maintainers directly.

## Default Security Posture

- Elasticsearch runs with security **disabled** — this is intentional for lab simplicity. Do not expose port 9200 to untrusted networks.
- Adaptix C2 uses self-signed certificates generated at first boot.
- The default `profile.example.yaml` ships with placeholder passwords. Always change them before use.
- `config/profile.yaml` and `.env` are git-ignored to prevent credential leaks.
