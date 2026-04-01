import re

def verify_code(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # We want to ensure that 'for (v in vars)' is gone
    if 'for (v in vars)' in content:
        print("Error: 'for (v in vars)' loop still present.")
        return False

    # We want to ensure 'across(' is used
    if 'across(' not in content:
        print("Error: 'across(' not found. Vectorized approach not implemented.")
        return False

    # Check that approx is still there
    if 'approx(yrs[observed]' not in content:
        print("Error: 'approx(yrs[observed]' not found. Interpolation logic lost.")
        return False

    # Check that replace is still there
    if 'replace(vals, TRUE, vals[observed][1])' not in content:
        print("Error: LOCF logic lost.")
        return False

    # Check that it groups by cow_col
    if 'group_by(!!sym(cow_col))' not in content:
        print("Error: grouping logic lost.")
        return False

    print("Static verification passed.")
    return True

if __name__ == "__main__":
    if not verify_code("R/06_impute_controls.R"):
        exit(1)
