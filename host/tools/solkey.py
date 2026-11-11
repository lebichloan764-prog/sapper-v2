#!/usr/bin/env python3
"""solkey.py — offline Solana key material check (no network, no solders).

  solkey.py check <ADDRESS> <secret>
      <secret> = base58 string, JSON array of 64 ints, or 32-byte hex seed
      prints MATCH <address> / NO <derived> and exits 0 only on match
  solkey.py addr <secret>            # derive the address only
  solkey.py b58 <hex> | hex <b58>    # conversions

Needs only `cryptography` (Ed25519); pure-python base58.
"""
import json
import sys

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization

ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"


def b58encode(b: bytes) -> str:
    n = int.from_bytes(b, "big")
    out = ""
    while n:
        n, r = divmod(n, 58)
        out = ALPHABET[r] + out
    pad = len(b) - len(b.lstrip(b"\0"))
    return "1" * pad + out


def b58decode(s: str) -> bytes:
    n = 0
    for ch in s:
        n = n * 58 + ALPHABET.index(ch)
    pad = len(s) - len(s.lstrip("1"))
    body = n.to_bytes((n.bit_length() + 7) // 8, "big") if n else b""
    return b"\0" * pad + body


def seed_of(secret: str) -> bytes:
    secret = secret.strip()
    if secret.startswith("["):
        arr = json.loads(secret)
        if len(arr) not in (32, 64):
            raise SystemExit("bad json key length %d" % len(arr))
        return bytes(arr[:32])
    if secret.lower().startswith("0x"):
        secret = secret[2:]
    if len(secret) == 64 and all(c in "0123456789abcdefABCDEF" for c in secret):
        return bytes.fromhex(secret)
    raw = b58decode(secret)
    if len(raw) not in (32, 64):
        raise SystemExit("bad secret length %d (need 32 or 64 bytes)" % len(raw))
    return raw[:32]


def addr_of(secret: str) -> str:
    seed = seed_of(secret)
    pub = Ed25519PrivateKey.from_private_bytes(seed).public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    return b58encode(pub)


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "addr":
        print(addr_of(sys.argv[2]))
        return 0
    if cmd == "check":
        want = sys.argv[2].strip()
        got = addr_of(sys.argv[3])
        if got == want:
            print("MATCH", got)
            return 0
        print("NO", got)
        return 1
    if cmd == "b58":
        print(b58encode(bytes.fromhex(sys.argv[2])))
        return 0
    if cmd == "hex":
        print(b58decode(sys.argv[2]).hex())
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
