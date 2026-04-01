import re
import sys

def verify_script(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    required_patterns = [
        (r'is_petro_state\s*=\s*if_else\(oil_income_pc\s*>\s*100,\s*1L,\s*0L\)', "is_petro_state calculation"),
        (r'log_gdp_pc\s*=\s*log\(coalesce\(\!\!\!syms\(gdp_candidates\)\)\)', "log_gdp_pc calculation with coalesce"),
        (r'select\(COWcode,\s*year,\s*gini_disp\)', "gini_disp selection"),
        (r'select\(COWcode,\s*year,\s*bmr\)', "bmr selection"),
        (r'select\(COWcode_a,\s*COWcode_b,\s*year,\s*exp_total\)', "exp_total selection"),
        (r'left_join\(export_merge,\s*by\s*=\s*c\("COWcode_a",\s*"COWcode_b",\s*"year"\)\)', "export_merge dyadic left join")
    ]

    missing = []
    for pattern, description in required_patterns:
        if not re.search(pattern, content):
            missing.append(description)

    if missing:
        print("Verification FAILED. Missing:")
        for m in missing:
            print(f"  - {m}")
        sys.exit(1)
    else:
        print("Verification PASSED. All required patterns found in R/04_build_controls.R")
        sys.exit(0)

if __name__ == "__main__":
    verify_script("R/04_build_controls.R")
