# Stable development signing

macOS Transparency, Consent, and Control (TCC) permissions such as
Accessibility and Input Monitoring are associated with an application's path,
bundle identifier, and code-signing requirement. An ad-hoc signature changes
when the executable changes, so macOS can treat every rebuild as a new client.

A persistent signing identity gives repeated local builds a stable designated
requirement. It does not bypass TCC: permission still has to be granted once for
each debug or release bundle.

## Recommended command-line setup

Run:

```sh
./scripts/setup-dev-signing.sh
```

The script:

1. Generates a 4096-bit RSA key and a ten-year self-signed Code Signing
   certificate named `RcmdLite Development`.
2. Packages them temporarily as PKCS#12 using a random, per-run password.
3. Imports the identity into the login keychain for `codesign`.
4. Deletes the temporary certificate, package, and unencrypted private key when
   the script exits.

The script never writes key material inside the repository.

One trust step remains intentionally manual:

1. Open Keychain Access.
2. Select the login keychain and find `RcmdLite Development`.
3. Double-click the certificate and expand Trust.
4. Set **Code Signing** to **Always Trust**, close the window, and authenticate.

Confirm that macOS sees a usable identity:

```sh
./scripts/signing-status.sh
```

Then build and inspect the signature:

```sh
./scripts/build-debug.sh
codesign -dv --verbose=4 "$HOME/Applications/RcmdLite Debug.app"
codesign --verify --deep --strict --verbose=2 "$HOME/Applications/RcmdLite Debug.app"
```

The output should contain an `Authority` and must not report
`flags=0x2(adhoc)`. The same identity is automatically used by the release
script.

## Alternative: Apple Development identity

Xcode can create an Apple Development identity from Settings > Accounts > your
team > Manage Certificates. A free Personal Team is sufficient for local
development. If `RcmdLite Development` is unavailable, the build script selects
the first installed Apple Development identity.

To choose an identity explicitly:

```sh
RCMD_SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)" \
  ./scripts/build-debug.sh
```

## Keeping permissions stable

- Always replace and launch the app at the same path.
- Keep the bundle identifier unchanged.
- Keep using the same certificate and private key. A certificate with no
  accompanying private key is not a signing identity.
- Do not delete and recreate the identity merely because the app was rebuilt.
- Grant permissions to the packaged `.app`, not `.build/debug/rcmd-lite`.
- Keep debug and release permission entries separate; their bundle identifiers
  intentionally differ.

The default bundles live outside synced Documents or File Provider storage to
avoid metadata changes that can invalidate strict signature verification. Set
`RCMD_APP_PATH` only when you can keep the replacement path stable.

## Backing up the local identity

Keychain Access can export `RcmdLite Development` together with its private key
as a password-protected `.p12` file. Store that backup in a password manager or
other encrypted secret store. Do not put it in this repository, attach it to a
GitHub issue, or publish it in a release.

Import the same identity if the development keychain is migrated to another
Mac. Generating a new certificate creates a different code-signing requirement
and existing TCC grants will not carry over.

## Troubleshooting

### `MAC verification failed during PKCS12 import`

The password supplied to `security import -P` does not match the password used
when exporting the PKCS#12 file, or the file is damaged. The checked-in setup
script generates one password and uses it for both operations, so rerun the
script rather than reusing an incomplete temporary file. For a manually
exported `.p12`, use its export password exactly.

### Certificate exists but no valid identity is listed

Verify that Keychain Access shows a private key beneath the certificate and
that Code Signing is trusted. A standalone certificate cannot sign code. Run:

```sh
security find-identity -p codesigning -v
```

Only identities listed by that command are eligible for automatic selection.

### Permissions still reset

Compare two builds with:

```sh
codesign -dr - "$HOME/Applications/RcmdLite Debug.app"
codesign -dv --verbose=4 "$HOME/Applications/RcmdLite Debug.app"
```

Confirm the app path, identifier, authority, and designated requirement remain
the same. Remove stale duplicate entries from Privacy & Security once, grant the
new stable bundle, and restart it after changing Input Monitoring access.

## Distributing releases

`RcmdLite Development` is only for local development. It does not provide
Gatekeeper trust or notarization for other users. Public downloadable builds
should be signed consistently with an Apple **Developer ID Application**
certificate, use the same bundle identifier across versions, include a secure
timestamp and hardened runtime, and be notarized and stapled.

Do not commit or upload the Developer ID private key, App Store Connect API
keys, notarization credentials, or keychain files. Supply them to release
automation through encrypted repository secrets.
