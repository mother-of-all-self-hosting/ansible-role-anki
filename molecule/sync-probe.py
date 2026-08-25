#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

"""Drives a real Anki sync client handshake against a synchronization server.

The server answers `GET /health` with 200 and an empty body no matter how it is
configured, and answers everything else with 404, so neither tells us whether
the instance the role deployed is usable. What does tell us is the sync protocol
itself: `POST /sync/hostKey` with the credentials the role configured, followed
by `POST /sync/meta` with the key it hands back. Both requests carry an
`anki-sync` header and a zstd-compressed JSON body, exactly as Anki's own client
sends them (see rslib/src/sync/request/header_and_stream.rs upstream).

The output is a single JSON object on stdout, for the Molecule verifier to
assert on. Failures are reported in that object rather than raised, so that the
assertion which cares about a particular failure is the one that fails.
"""

import argparse
import json
import sys
import urllib.error
import urllib.request

import zstandard

# The version and platform an Anki client would report. Nothing on the server
# side depends on it, but the field is not optional.
CLIENT_VERSION = "anki,26.08 (molecule),linux:molecule"
SESSION_KEY = "molecule-sync-probe"
SYNC_VERSION = 11


def _post(base_url, method, payload, sync_key=""):
    """Performs one sync request, returning (status, decoded body or None)."""
    request = urllib.request.Request(
        "{}/sync/{}".format(base_url.rstrip("/"), method),
        data=zstandard.ZstdCompressor().compress(json.dumps(payload).encode()),
        headers={
            "anki-sync": json.dumps(
                {
                    "v": SYNC_VERSION,
                    "k": sync_key,
                    "c": CLIENT_VERSION,
                    "s": SESSION_KEY,
                }
            ),
            "Content-Type": "application/octet-stream",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read()
            status = response.status
    except urllib.error.HTTPError as error:
        # The server answers unauthorized requests with a plain-text status
        # code rather than a compressed body.
        return error.code, None
    except OSError as error:
        return "error: {}".format(error), None

    # Responses are streamed, so the frame carries no content size.
    return status, zstandard.ZstdDecompressor().decompressobj().decompress(body)


def _get(url):
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code
    except OSError as error:
        return "error: {}".format(error)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--username", required=True)
    parser.add_argument("--password", required=True)
    args = parser.parse_args()

    result = {
        "health_status": _get("{}/health".format(args.base_url.rstrip("/"))),
        "root_status": _get("{}/".format(args.base_url.rstrip("/"))),
    }

    status, body = _post(
        args.base_url, "hostKey", {"u": args.username, "p": args.password}
    )
    result["login_status"] = status
    key = ""
    if body:
        key = json.loads(body).get("key", "")
    result["login_key_length"] = len(key)

    result["wrong_password_status"] = _post(
        args.base_url, "hostKey", {"u": args.username, "p": args.password + "-wrong"}
    )[0]

    result["unknown_user_status"] = _post(
        args.base_url,
        "hostKey",
        {"u": args.username + "-nobody", "p": args.password},
    )[0]

    status, body = _post(
        args.base_url,
        "meta",
        {"v": SYNC_VERSION, "cv": CLIENT_VERSION},
        sync_key=key or "no-key",
    )
    result["meta_status"] = status
    result["meta"] = json.loads(body) if body else None

    result["forged_key_status"] = _post(
        args.base_url,
        "meta",
        {"v": SYNC_VERSION, "cv": CLIENT_VERSION},
        sync_key="0000000000000000000000000000000000000000",
    )[0]

    json.dump(result, sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
