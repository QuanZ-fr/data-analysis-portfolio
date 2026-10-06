"""Download the raw IBM Telco Customer Churn data from Kaggle."""

import hashlib
from pathlib import Path

import kagglehub


DATASET_HANDLE = "blastchar/telco-customer-churn"
DATASET_FILE = "WA_Fn-UseC_-Telco-Customer-Churn.csv"
EXPECTED_SHA256 = "88be4b93fbe0cc83421af1c503794c97c342eca914c1576db7c276e61d61358a"
PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = PROJECT_ROOT / "data" / "raw"


def main() -> None:
    """Download the dataset file into the project's raw data directory."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    downloaded_path = kagglehub.dataset_download(
        DATASET_HANDLE,
        path=DATASET_FILE,
        output_dir=str(OUTPUT_DIR),
    )

    expected_file = OUTPUT_DIR / DATASET_FILE
    if not expected_file.exists():
        raise FileNotFoundError(
            f"Download finished, but the file was not found at: {expected_file}"
        )

    actual_sha256 = hashlib.sha256(expected_file.read_bytes()).hexdigest()
    if actual_sha256 != EXPECTED_SHA256:
        raise RuntimeError(
            "Checksum mismatch: the dataset on Kaggle may have changed.\n"
            f"Expected SHA-256: {EXPECTED_SHA256}\n"
            f"Actual SHA-256:   {actual_sha256}"
        )

    print(f"Path returned by Kaggle: {downloaded_path}")
    print(f"Saved to: {expected_file}")
    print(f"File size: {expected_file.stat().st_size:,} bytes")
    print(f"SHA-256 verified: {actual_sha256}")


if __name__ == "__main__":
    main()
