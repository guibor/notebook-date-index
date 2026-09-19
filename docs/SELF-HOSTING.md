# Optional self-hosted date-history sync

[Back to README](../README.md) · [Tablet installation](INSTALL.md)

Dates works locally without this service. Use a hub only if you want creation
history for the same notebook on multiple devices. This guide configures
**your own server**; it never uses the maintainer's infrastructure.

## What is shared

Creation-history metadata includes notebook/page UUIDs, original timestamps,
calendar dates, timezones/offsets, estimate provenance and device names.
Handwriting, titles, document text and PDF contents are not sent to this hub.
Modified view stays local; an explicitly saved creation estimate can be synced.

The hub does not transfer notebook content. Both tablets must already contain
the same native notebook/page IDs through their normal sync method. A copy with
a new ID is a separate notebook. Do not promise private cloud-free notebook sync
from this feature: normal reMarkable synchronization is unchanged.

A hub namespace is for **one trusted owner/device group**, not unrelated tenants.
Each device credential authorizes that group's shared metadata. Tokens are
bearer credentials; protect them and the metadata backups accordingly.

## Server prerequisites

- Linux server, local Go toolchain (Go 1.22+; release tested with 1.24.6).
- A HTTPS domain and TLS reverse proxy you control.
- A non-root service account, persistent private storage and a backup plan.
- Matching current hub/client source. Upgrade an old hub before clients start
  sending estimated-baseline fields; old hubs reject those fields.

## Build and install the hub binary

From the repository root, for a Linux x86-64 server:

```sh
mkdir -p build/hub
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GOTOOLCHAIN=local \
  go build -buildvcs=false -trimpath -o build/hub/notebook-date-index .
```

Use `GOARCH=arm64` for an ARM64 server. Transfer the result over your normal
trusted administration channel. On the server, install it at
`$HOME/.local/lib/notebook-date-sync/notebook-date-index` for the provided
service template.

The remaining commands run **on the server as that service user**:

```sh
umask 077
mkdir -p "$HOME/.local/lib/notebook-date-sync"
mkdir -p "$HOME/.local/share/notebook-date-sync/history"
chmod 700 "$HOME/.local/share/notebook-date-sync"
chmod 700 "$HOME/.local/share/notebook-date-sync/history"
```

## Create independent device credentials

After placing the executable at the path above:

```sh
"$HOME/.local/lib/notebook-date-sync/notebook-date-index" \
  --init-sync-credentials "$HOME/.local/share/notebook-date-sync/credentials" \
  --sync-endpoint https://dates.example.com/dates/v1/exchange \
  --devices my-pro,my-move,probe
```

Replace the example domain with yours. HTTPS and the exact
`/dates/v1/exchange` path are required. Device names are unique lowercase
letters/digits/hyphens, start with a letter, and are at most 40 characters.
`probe` is reserved for an isolated synthetic test namespace.

This writes a hashed `devices.json` for the hub and one private
`<device>-client.json` per device. Tokens are generated randomly and not printed.
Existing files are not overwritten. Preserve these credentials across updates;
do not run initialization every time you install a new binary.

## Run behind HTTPS

To check foreground startup:

```sh
"$HOME/.local/lib/notebook-date-sync/notebook-date-index" --sync-server \
  --data "$HOME/.local/share/notebook-date-sync/history" \
  --credentials "$HOME/.local/share/notebook-date-sync/credentials/devices.json"
```

The hub binds only to **127.0.0.1:18743**. For a managed user service, adapt
[the portable service example](../examples/notebook-date-sync.service);
its binary, credentials and writable history paths must already exist.
User-service persistence across logout/reboot depends on your server's systemd
configuration; check that explicitly rather than assuming it.

Include [the nginx location example](../ops/dates-sync-location.conf) inside
your **existing HTTPS virtual host**. Validate the full proxy configuration
before reloading it. That snippet does not create DNS, certificates, TLS, or a
virtual host for you.

Do not expose the loopback port publicly, disable certificate verification,
enable request-body logging, or configure redirects for the endpoint. Clients
refuse redirects. Keep credential files mode 0600 and private directories 0700.

## Configure each qualified tablet

Securely copy only that tablet's generated client configuration to:

```text
/home/root/.local/share/notebook-date-index/sync.json
```

See [the example JSON](../examples/sync.json) for the shape; its placeholder
token is not usable. Give each tablet its own device name/token and mode-0600
file. Do not share the hub's `devices.json` with clients.

Restart **only the Dates service through the tablet's qualified recipe** to
load changed sync configuration. A UI restart is not inherently required, but
the transient service may need recreating rather than simply starting an old
unit. Do not use historical maintainer scripts as generic service installers.

Reopen Dates settings to see status for the current notebook. The background
worker is prompted by viewing history/record changes and retries roughly every
minute. If a page has not arrived through native sync, its received date is
retained but its link stays hidden until the page exists locally.

## Verify and back up

Use a disposable notebook present on both devices. Enable creation tracking on
each separately, add a page on one device, let native notebook sync complete,
and inspect its date on the other. Repeat in reverse and offline/reconnect.
Confirm receiving history does not enable tracking on a device where it is off.

Observed creation wins over an estimate. Other conflicts resolve by earliest
UTC and deterministic tie-break, retaining observations in the journal.
An incorrect device clock cannot be corrected automatically.

Back up hub history and credentials privately, plus each tablet's full Dates
directory. Neither a hosted-service uptime check nor a single delivered record
proves all physical creation, offline, or recovery cases. Report those separately.
