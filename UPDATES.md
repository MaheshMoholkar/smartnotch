# SmartNotch source and release publishing

SmartNotch is one monorepo containing the Swift macOS app, .NET/WPF Windows app, Python/PySide6 Linux preview, and Next.js website. Source goes in one public GitHub repository. Installers and update packages go in **GitHub Release assets**. Vercel hosts `landing/`, its small update feeds, checksums, images, and product video.

## Finish the one-time repository setup

Inspection on 21 November 2026 found no root `.git` and an empty `landing/.git`: no commits, refs, tracked index entries, or remotes. The complete nested Git metadata is backed up at `dist/repository-backups/landing-git-before-monorepo.tar`. The workspace prevents modifying Git directories, so finish the relocation in your own Terminal:

```sh
cd /Users/mahesh/portfolio/smartnotch
zsh scripts/prepare-source-repository.sh
git status --short --branch
git add .
git diff --cached --stat
```

The script moves the existing metadata to the root and saves another backup. It refuses to overwrite a root repository or relocate a nested repository with refs, tracked files, or remotes. If those conditions change, inspect and import the history before proceeding. Do not delete `.git` directories or run a fresh initialization over existing history.

Source and documentation no longer reference the old absolute project path. Ignored Swift `.build/` and .NET `obj/` caches still contain the previous location; regenerate those caches before the next native build. Existing installers and signatures were preserved.

Create an empty public GitHub repository manually, without a generated README or other initial commit. After reviewing the staged files, run these with your actual repository URL:

```sh
git commit -m "Prepare SmartNotch monorepo and GitHub release packaging"
git remote add origin https://github.com/OWNER/smartnotch.git
git push -u origin main
```

Root and website ignore rules exclude build output, installers, archives, local credentials, and local hosting metadata. `Package.resolved`, `landing/package-lock.json`, and `windows/.config/dotnet-tools.json` stay in source. Keep private signing keys in Keychain or an external credential store.

## Publish the existing 0.2.0 assets manually

The existing artifacts were verified and copied without rebuilding or repackaging. All original website files, including feed signatures and checksum files, were compared against a pre-migration SHA-256 inventory. Binaries formerly under `landing/public` are preserved under `dist/website-downloads/` with their original relative paths. Existing `dist` build outputs also remain local.

Upload **all files** in `dist/github-release/0.2.0/` to the manually created public GitHub Release. Use a specific tag such as `v0.2.0`.

| Asset | Used by |
| --- | --- |
| `SmartNotch.dmg` | Website Mac download |
| `SmartNotch-0.2.0.dmg` | Signed Sparkle update download |
| `SmartNotch-Windows-x64-Setup.exe` | Website Windows installer and the old setup route |
| `SmartNotch-0.2.0-full.nupkg` | Velopack update download |
| `SmartNotch-Linux.tar.gz` | Linux source installer |
| `SmartNotch.zip`, `SmartNotch-Windows-x64.zip` | Compatibility for older website download URLs |
| Matching `.sha256` files | Transfer-integrity checks |

GitHub Releases use a flat asset namespace. Keep the asset filenames exactly as staged. The Mac website DMG and versioned update DMG currently contain identical signed bytes; upload both names so both URLs work. Small feeds stay in `landing/public/updates`, and do not need to be uploaded as release assets for the existing updater configuration.

After uploading and publishing the assets, supply the release URL or run:

```sh
python3 scripts/configure_github_release.py https://github.com/OWNER/smartnotch/releases/tag/v0.2.0
cd landing
npm run build
npm run check:release
```

This sets direct GitHub download links in `landing/app/downloads.json` and generates external temporary redirects in `landing/vercel.json`. It does not modify archives, signatures, or feed checksums. Do not configure a guessed repository URL or deploy pending links. Verify the asset links work without signing in before deploying. Commit the updated `landing/release-assets.json`, `landing/vercel.json`, and `landing/app/downloads.json` from the root repository after configuring a release.

## Keep existing app-update URLs stable

Leave `updateBaseURL` in `release.json` set to `https://smartnotch.vercel.app/updates`. Existing apps already contain this address. Keep `sparklePublicKey` unchanged; its private key remains in Keychain.

| Existing path on smartnotch.vercel.app | Hosting behavior |
| --- | --- |
| `/updates/mac/appcast.xml` | Small signed-archive metadata served by Vercel |
| `/updates/mac/SmartNotch-0.2.0.dmg` | Redirect to that version's GitHub asset |
| `/updates/windows/win-x64/releases.win.json` | Original small Velopack feed served by Vercel |
| `/updates/windows/win-x64/RELEASES` | Original small legacy feed served by Vercel |
| `/updates/windows/win-x64/SmartNotch-0.2.0-full.nupkg` | Redirect to that version's GitHub asset |
| `/assets/SmartNotch.dmg`, Windows setup, Linux archive | Redirects retained for older website links |

`landing/release-assets.json` records each asset's checksum, version, name, and compatibility path. Keep this file and all old versioned routes in source. Each release version has its own pinned GitHub URL; updating the website's current download never repoints an old update package. ARM64 Windows assets receive a `win-arm64-` prefix on GitHub to avoid filename collisions with x64; feed filenames remain unchanged and redirect to the corresponding assets.

The feeds keep short cache lifetimes. Redirects use `permanent: false` (HTTP 307). Upload and publish the assets **before** deploying the changed website and feeds. Never remove a GitHub asset referenced by an old feed.

## Package future releases

Increment `version` and the monotonic `build` in `release.json`; edit `RELEASE_NOTES.md`. Keep the existing update URL and Sparkle key.

### macOS

With Swift dependencies resolved and the existing signing key accessible in your login Keychain:

```sh
swift package resolve
./scripts/package-update.sh
```

This builds the DMG, optionally notarizes/staples it, signs the final archive with Sparkle, independently verifies the Ed25519 signature using CryptoKit, writes the small feed, and stages binary assets under `dist/github-release/<version>/`. It never copies a DMG into the website. `scripts/sync_site_downloads.py` can restage an existing verified build.

For first-time signing-key setup only, run `./scripts/prepare-release.sh` in Terminal. Do not generate a replacement key for each release. Apple Developer ID signing and notarization are separate: set `SMARTNOTCH_SIGNING_IDENTITY` and optionally `SMARTNOTCH_NOTARY_PROFILE` before packaging. Never modify a DMG after Sparkle signs it.

### Windows

Cross-package on macOS/Linux with Python and the .NET 10 SDK:

```sh
./scripts/package-windows.sh
# Optional separate ARM64 channel:
./scripts/package-windows.sh win-arm64
```

On Windows, install the .NET 10 SDK and Python 3.10+, then run:

```powershell
.\windows\publish.ps1 -Runtime win-x64
```

Both paths run the same checksum and executable-architecture verification and stage the release assets outside the website. Python is required for native release staging. `-Development` produces local development packages without staging a public release. Cross-packaging cannot validate installation hooks, WPF UI, or a real update; verify those on Windows. Builds remain unsigned unless code signing is configured separately.

Velopack source output stays under `dist/updates/windows/<runtime>`. Small JSON/RELEASES feeds and checksums go to `landing/public/updates/windows/<runtime>`; installer and package bytes go to `dist/github-release/<version>/`.

### Linux preview

```sh
python3 scripts/package_linux.py
```

This builds and verifies the source installer, stages it under `dist/github-release/<version>/`, and updates website metadata and a checksum file only. Installation requires Python 3.10–3.14, venv support, and internet access for Qt. Updates are manual. Core tests pass; Linux desktop GUI testing is still pending. The Linux CI workflow is configured for GUI tests under Xvfb and a separate native x64 portable build; no hosted CI results are claimed here.

For every new release, upload all staged assets first, run `scripts/configure_github_release.py` with that release's URL, build/check the website, then deploy it yourself. Staging rejects replacing a versioned asset with different bytes: increment the version when rebuilding for publication.

## Verify and deploy the lightweight website yourself

Set the Vercel project's **Root Directory** to `landing`, Build Command to `npm run build`, and use the Next.js framework preset. Retain the existing production domain. Deploy from `landing/`, rather than uploading the entire native-app workspace.

Both root and `landing/.vercelignore` protect CLI uploads. Git ignores protect repository-based deployments. The website's prebuild/postbuild checks reject installers or update packages in `public/` or exported `out/`; `public/` has a 20 MiB total budget. When Vercel runs the build, unresolved release URLs also fail the build. Local builds can run while waiting for the real release URL, but print a pending-URL warning. `npm run check:release` requires all mappings to be configured and the exported output to be clean.

```sh
python3 -m unittest discover -s scripts -p 'test_*.py' -v
python3 -m unittest discover -s linux/tests -p test_model.py -v
cd landing
npm run build
npm run check:release
```

A local Next.js static preview does not execute Vercel redirects; the redirects are checked as configuration locally. After your deployment, test the old Mac archive URL and Windows package URL with redirects followed, compare downloaded hashes, and confirm a real in-app update from an older installed version. Confirm saved notes, scripts, and reading positions survive the update. Linux GUI and Windows/macOS installation-update behavior require their respective desktop environments.

Nothing in these scripts creates a GitHub repository, uploads release files, pushes source, or deploys Vercel automatically.
