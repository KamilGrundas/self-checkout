# Optional client target

`ssh dev-client` is an optional, replaceable target computer for native
`self-checkout-client` validation. It supplements local client checks and the
Docker/integration workflow on `ssh dev`; it does not replace either one. No
specific hardware architecture, operating system, graphical stack, username,
filesystem layout, package manager, or startup mechanism is part of the
`dev-client` contract.

| Target | Responsibility |
| --- | --- |
| `dev` | Backend and ML APIs, Docker Compose, integration tests, health checks, and browser-facing development validation |
| `prod` | Approved immutable production releases through controlled infra procedures; never receives local source |
| `dev-client` | Optional native build and direct client validation on the currently configured target computer |

Local uncommitted client sources may be synchronized to `dev-client`. That does
not authorize commits, pushes, pull requests, merges, releases, or production
operations. Never install Codex on any remote target.

## Cached target profile

The target owns a non-secret profile at:

```text
$HOME/.config/self-checkout-client/dev-client-profile
```

After connecting, Codex reads this file with:

```bash
./ops/dev-client-inspect.sh
```

The profile caches the last inspected identity, OS, architecture, toolchain,
relevant build/runtime packages, client path, process and startup strategy,
runtime/session facts, output/log locations, development endpoints, and cursor
policy. Credentials, tokens, SSH material, environment-file contents, and
device identifiers must never be stored in it.

For a new target, an absent profile, or a machine/runtime change, perform
read-only discovery and then replace the cache with:

```bash
./ops/dev-client-inspect.sh --refresh
```

Ordinary client work must read the existing profile instead of repeatedly
enumerating packages and the full machine. The cache is an optimization, not
permission to trust stale state: compare live hostname, user, home, client-root
presence, process ownership, and endpoint connectivity before mutation.

## Controlled workflow

Run from the control workspace:

```bash
./ops/dev-client-check.sh --optional
./ops/dev-client-inspect.sh
./ops/dev-client-sync.sh --dry-run
./ops/dev-client-sync.sh --apply
./ops/dev-client-authorize.sh # only when authorization is absent or invalid
./ops/dev-client-deploy.sh
./ops/dev-client-status.sh
```

`dev-client-check.sh` exits `0` when reachable, `3` for genuine host/network
unavailability, and `2` for SSH configuration or authentication errors.
`--optional` converts only genuine unavailability into a successful `SKIPPED`
result. It never hides errors after reaching the host.

Synchronization uses checksums and copies only `Cargo.toml`, `Cargo.lock`,
`rust-toolchain.toml`, `src/`, and `assets/`. It does not use an rsync deletion
flag. Device `.env`, identity, persisted settings, build targets, Git metadata,
startup files, caches, target profile, and unrelated paths remain untouched.

The deploy script builds `cargo build --locked --release` natively with the
profiled toolchain. It retains the previous executable as
`target/release/self-checkout-client.previous`, records source and binary hashes
in `.dev-client-deployment`, validates the live process against the cached
startup strategy, restarts it, waits for stability, and verifies the running
executable hash. File synchronization alone is never deployment success.

Rollback is explicit: verify the retained binary, replace the release binary,
and restart through the profiled startup strategy. Do not roll back
automatically or discard the retained binary during ordinary deployment.

Non-secret overrides are:

- `SELF_CHECKOUT_DEV_CLIENT_HOST` (default `dev-client`);
- `SELF_CHECKOUT_DEV_CLIENT_CONNECT_TIMEOUT` (default `5`, allowed `1`–`30`);
- `SELF_CHECKOUT_DEV_CLIENT_ROOT` (default discovered remote
  `$HOME/self-checkout-client`, must end in `/self-checkout-client`).

## Development API invariant

The client process on `dev-client` always uses the backend and ML API running
on `dev`. Device-owned `API_BASE_URL` and `ML_API_BASE_URL` may use a direct
address, private DNS name, VPN address, or a controlled development-only relay,
but their traffic must terminate at the corresponding services on `dev`.

Do not use application services hosted on `dev-client`, the control computer as
an application backend, or any production endpoint. Validate both health
endpoints from `dev-client` before declaring device validation successful. A
missing route is a real target configuration failure after reachability has
been established.

Prefer a reachable private LAN address over a public address or
overlay-network address. If routing requires a controlled relay, bind its
target-facing side to the private LAN and record the route type—never
credentials—in the device profile.

The backend on `dev` must also contain a dedicated checkout-counter
authorization for this target. Use `dev-client` as its stable name unless the
profile explicitly records a different target name. Before restart or
handoff, verify the configured ID and password through
`POST /api/v1/checkout-sessions/connect`. If the record is absent or returns an
authentication error, create or rotate the development record and atomically
update the protected device `.env` with `ops/dev-client-authorize.sh`. The
script obtains admin authority only on `dev`, streams the generated target
credentials directly into the device-owned configuration without displaying
them, and never writes them into the workspace. The profile may record
`checkout_counter_name=dev-client` and whether credentials are present, but it
must never contain their values.

For every client-affecting change, validate the normal services on `dev` and
then the synchronized client against those services on a reachable
`dev-client`. When the target is unavailable, report only synchronization,
restart, authentication, and target validation as skipped; local and `dev`
validation still continue.

## Cursor and human confirmation

The client supports `HIDE_CURSOR=true`; production-mode client windows hide the
cursor by default when the variable is absent. Target configuration must keep
the cursor hidden without assuming a particular graphical implementation.

Remote automation can verify synchronization, compilation, binary hashes,
process replacement, immediate stability, profiled runtime prerequisites,
output/log signals, and development API responses. It cannot fully observe the
physical display, touch input, cameras, or scale.

After deployment, confirm on the target:

1. the cursor is not visible;
2. the app occupies the intended display area and renders correctly;
3. Polish and English text and images are correct;
4. touch or pointer interactions work despite the hidden cursor;
5. configured cameras and other peripherals are available;
6. the checkout flow communicates only with `dev`;
7. startup remains correct after reboot.
