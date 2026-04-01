import time

class MockDataFrame:
    def __init__(self, cols):
        self.cols = cols
        self.data = {c: [1]*1000000 for c in cols}

    def __contains__(self, item):
        return item in self.data

    def __getitem__(self, item):
        if isinstance(item, list):
            return [self.data[c] for c in item]
        return self.data[item]

    def __setitem__(self, key, value):
        if isinstance(key, list):
            for i, k in enumerate(key):
                self.data[k] = value[i]
        else:
            self.data[key] = value

n_cols = 50
core_spine_vars = [f"var{i}" for i in range(1, n_cols + 1)]
init_cols = [f"{v}.x" for v in core_spine_vars] + [f"{v}.y" for v in core_spine_vars]

df1 = MockDataFrame(init_cols)
df2 = MockDataFrame(init_cols)

def method_loop(df):
    for v in core_spine_vars:
        vx = f"{v}.x"
        vy = f"{v}.y"
        if vx in df:
            df[v] = df[vx]
        elif v not in df and vy in df:
            df[v] = df[vy]

def method_vectorized(df):
    vxs = [f"{v}.x" for v in core_spine_vars]
    has_vx = [vx in df for vx in vxs]

    if any(has_vx):
        dest_cols = [core_spine_vars[i] for i, v in enumerate(has_vx) if v]
        src_cols = [vxs[i] for i, v in enumerate(has_vx) if v]
        df[dest_cols] = df[src_cols]

    # in R, we can just do df[dest_cols] <- df[src_cols] natively.

# Measure
s = time.time()
for _ in range(100):
    method_loop(df1)
t1 = time.time() - s

s = time.time()
for _ in range(100):
    method_vectorized(df2)
t2 = time.time() - s

print(f"Loop: {t1:.4f}s")
print(f"Vec: {t2:.4f}s")
print(f"Speedup: {t1/t2:.2f}x")
