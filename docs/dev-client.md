# Native client

The desktop client is a component that may run on a separately managed device.
Its local runtime, credentials, display, camera, and startup configuration are
device-owned and are not controlled by this workspace.

Configure browser-accessible development API URLs through the device's local
environment. Do not use internal Compose service names, production endpoints,
or disabled TLS verification. Validate formatting, compilation, and tests in
the client repository; camera, touch, display, and device connectivity remain
separate observed checks.

Client synchronization or device deployment is not a Git, release, or
production workflow. Preserve device-owned configuration and credentials.
