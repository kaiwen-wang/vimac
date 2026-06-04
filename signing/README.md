# Local signing files (not committed)

Put Apple signing material here. Everything except this README is gitignored.

## Expected files

| File | Required | Notes |
|------|----------|--------|
| `developerID_application.cer` | Optional | Public cert from Apple; double-click to install, or `make signing-install` |
| `developer-id.p12` | **CI + optional local** | Export from Keychain Access (cert + private key). Password → `signing/.env` |
| `AuthKey_*.p8` | For notarization | App Store Connect API key; path in `signing/.env` |

You can delete `CertificateSigningRequest.certSigningRequest` after the `.cer` is issued.

## Setup

```bash
cp signing/.env.example signing/.env
# Edit signing/.env (passwords stay local)

make signing-install   # install .cer into keychain
make release-dist      # signed + notarized zip → sparkle-releases/
```

## GitHub Actions secrets

From the repo root (after `developer-id.p12` exists):

```bash
make signing-github-secrets
```

Copy the printed values into **Settings → Secrets and variables → Actions**.
