# Contributing to C2inaBox

Thanks for your interest. Here's how to help.

## Getting Started

1. Fork the repo
2. Clone your fork and set up per the [README](README.md#setup)
3. Create a feature branch: `git checkout -b feature/my-change`
4. Make your changes
5. Test locally with `.\deploy.ps1`
6. Commit and push
7. Open a pull request

## Guidelines

- **One change per PR.** Keep pull requests focused.
- **Test your changes.** Run `.\deploy.ps1` and `.\status.ps1` to verify the stack works.
- **No credentials.** Never commit real passwords, tokens, or keys. Use the `.example` config files for defaults.
- **PowerShell 5.1 compatible.** The scripts target Windows PowerShell. Avoid `&&`, ternary operators, and other PS 7+ syntax.
- **Document new features.** Update the README and CHANGELOG.

## Reporting Issues

Open a GitHub issue with:

- What you expected
- What happened instead
- Steps to reproduce
- Docker and OS version (`docker version`, `winver`)

## Code of Conduct

Be respectful. This is a security tool — use it ethically and within the bounds of the law.
