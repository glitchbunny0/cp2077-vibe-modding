#!/bin/sh
# Run the WolvenKit CLI (Linux build, WolvenKit.ConsoleLinux) boxed, as docs/reviews.md finding 6 asks: podman,
# no network, the CLI mounted read-only, HOME on a throwaway tmpfs (its AppData writes vanish with the container),
# and only the work folder writable, mounted at /work. Paths you pass are /work/... or relative to the work folder.
#
#   WKIT_CLI    the unpacked WolvenKit.ConsoleLinux release (required; pinned version and hash: docs/reviews.md)
#   WKIT_WORK   the work folder (default: the current directory). It is SELinux-relabelled (:z), so give it a
#               dedicated folder, never a repository root or your home.
#   WKIT_IMAGE  the .NET runtime image (default mcr.microsoft.com/dotnet/runtime:10.0; the CLI targets net10.0)
#
# Never point it at third-party archives (uncook trusts names inside them), and keep nothing you want in its output
# folder: `pack` replaces a same-named .archive or directory there.
set -e
: "${WKIT_CLI:?set WKIT_CLI to the unpacked WolvenKit.ConsoleLinux folder}"
[ -f "$WKIT_CLI/WolvenKit.CLI.dll" ] || { echo "wkit: no WolvenKit.CLI.dll in $WKIT_CLI" >&2; exit 2; }
WORK="${WKIT_WORK:-$PWD}"
IMAGE="${WKIT_IMAGE:-mcr.microsoft.com/dotnet/runtime:10.0}"
exec podman run --rm --network=none --userns=keep-id \
    -v "$WKIT_CLI":/wkit:ro,z -v "$WORK":/work:z -w /work --tmpfs /tmp/home:rw,size=512m \
    -e HOME=/tmp/home -e DOTNET_CLI_TELEMETRY_OPTOUT=1 -e DOTNET_NOLOGO=1 \
    "$IMAGE" dotnet /wkit/WolvenKit.CLI.dll "$@"
