"""Reject a slim Android installer that exceeds its declared byte ceiling."""

from argparse import ArgumentParser
from pathlib import Path


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("apk", type=Path)
    parser.add_argument("--max-bytes", type=int, default=800_000_000)
    args = parser.parse_args()

    if not args.apk.is_file():
        raise SystemExit(f"APK not found: {args.apk}")

    size = args.apk.stat().st_size
    print(f"Slim APK size: {size:,} bytes ({size / 1_000_000:.2f} MB)")
    if size > args.max_bytes:
        raise SystemExit(
            f"Slim APK exceeds the limit: {size:,} > {args.max_bytes:,} bytes"
        )
    print(f"PASS: installer is at or below {args.max_bytes / 1_000_000:.0f} MB")


if __name__ == "__main__":
    main()

