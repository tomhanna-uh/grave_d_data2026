import os
import json
import sys

def verify_renv_structure():
    """Verifies that the renv structure is correctly set up."""
    errors = []

    # 1. Check renv directory structure
    if not os.path.exists("renv"):
        errors.append("❌ 'renv' directory missing")
    if not os.path.exists("renv/activate.R"):
        errors.append("❌ 'renv/activate.R' file missing")

    # 2. Check .Rprofile
    if not os.path.exists(".Rprofile"):
        errors.append("❌ '.Rprofile' missing")
    else:
        with open(".Rprofile", "r") as f:
            content = f.read()
            if 'source("renv/activate.R")' not in content:
                errors.append("❌ '.Rprofile' does not source 'renv/activate.R'")

    # 3. Check renv.lock
    if not os.path.exists("renv.lock"):
        errors.append("❌ 'renv.lock' missing")
    else:
        try:
            with open("renv.lock", "r") as f:
                lock_data = json.load(f)

            packages = lock_data.get("Packages", {})
            required_pkgs = [
                "renv", "here", "tidyverse", "data.table",
                "haven", "readxl", "countrycode",
                "lubridate", "stringr", "cli",
                "rlang", "dplyr", "ggplot2"
            ]

            for pkg in required_pkgs:
                if pkg not in packages:
                    errors.append(f"❌ Package '{pkg}' missing from renv.lock")
                else:
                    ver = packages[pkg].get("Version")
                    print(f"✅ Found {pkg} (v{ver})")

        except json.JSONDecodeError:
            errors.append("❌ 'renv.lock' is not valid JSON")

    if errors:
        print("\nVerification FAILED:")
        for err in errors:
            print(err)
        sys.exit(1)
    else:
        print("\n✅ Verification PASSED: renv structure is correct.")
        sys.exit(0)

if __name__ == "__main__":
    verify_renv_structure()
