# Deployment

## Website
https://notehaven.rsprojects.dev/ via GitHub Pages (source: GitHub Actions).
- Deploys automatically on every push to `main`; to run by hand: `gh workflow run pages.yaml`.
- Built with `--base-href /`. `app/web/CNAME` carries the custom domain into the artifact, and the build fails if it is missing.
- DNS (Porkbun): `CNAME notehaven -> roshandroids.github.io`, no A/AAAA records on that host. Check with `dig +short notehaven.rsprojects.dev`.
- After the DNS check passes, tick **Enforce HTTPS** in Settings > Pages. If `InvalidDNSError` lingers, use "Check again" or remove and re-add the domain.

## Platform builds
Actions > **Release builds** > Run workflow, pick macOS / Windows / Android. Never automatic.
