#!/usr/bin/env python3
"""Cross-checks the frozen backup v1 known answer with an independent
implementation (Python's hashlib and the `cryptography` package), so the
fixture is not only checked against the code that wrote it (05_TEST_PLAN §3.4).

    python3 -I tool/crosscheck_backup.py test/vectors/backup_v1.json
"""
import hashlib
import json
import struct
import sys

from cryptography.hazmat.primitives.ciphers.aead import AESGCM


def main(path):
    with open(path, encoding="utf-8") as f:
        fx = json.load(f)
    salt = bytes.fromhex(fx["salt"])
    nonce = bytes.fromhex(fx["nonce"])
    iterations = fx["iterations"]
    header = b"FMFA" + bytes([1, 1]) + struct.pack(">I", iterations) + salt + nonce
    key = hashlib.pbkdf2_hmac(
        "sha256", fx["passphrase"].encode("utf-8"), salt, iterations, 32
    )
    sealed = AESGCM(key).encrypt(nonce, fx["plaintext"].encode("utf-8"), header)
    expected = header + sealed
    actual = bytes.fromhex(fx["backup"])
    if actual != expected:
        sys.exit("MISMATCH: the fixture does not match an independent implementation")
    # Decrypting with the independent implementation gives the stored plaintext.
    plain = AESGCM(key).decrypt(nonce, actual[38:], actual[:38])
    assert plain.decode("utf-8") == fx["plaintext"]
    print(f"ok: {len(actual)} bytes match (PBKDF2-HMAC-SHA256 x{iterations}, AES-256-GCM)")


if __name__ == "__main__":
    main(sys.argv[1])
