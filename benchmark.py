import pandas as pd
import numpy as np
import time

n_rows = 1000000
n_cols = 50

# Create dummy data
data = {f"var{i}.x": np.random.rand(n_rows) for i in range(1, n_cols + 1)}
data.update({f"var{i}.y": np.random.rand(n_rows) for i in range(1, n_cols + 1)})

df_base = pd.DataFrame(data)
core_spine_vars = [f"var{i}" for i in range(1, n_cols + 1)]

def method_loop(df):
    for v in core_spine_vars:
        vx = f"{v}.x"
        vy = f"{v}.y"
        if vx in df.columns:
            df[v] = df[vx]
        elif v not in df.columns and vy in df.columns:
            df[v] = df[vy]
    return df

def method_vectorized(df):
    vx_vars = [f"{v}.x" for v in core_spine_vars]
    vy_vars = [f"{v}.y" for v in core_spine_vars]

    # In python, finding intersections is easy
    has_vx = [vx in df.columns for vx in vx_vars]
    if any(has_vx):
        cols_to_assign = [core_spine_vars[i] for i, val in enumerate(has_vx) if val]
        src_cols = [vx_vars[i] for i, val in enumerate(has_vx) if val]
        df[cols_to_assign] = df[src_cols]

    has_no_base = [v not in df.columns for v in core_spine_vars]
    has_vy = [vy in df.columns for vy in vy_vars]

    to_fallback = [not has_vx[i] and has_no_base[i] and has_vy[i] for i in range(len(core_spine_vars))]
    if any(to_fallback):
        cols_to_assign = [core_spine_vars[i] for i, val in enumerate(to_fallback) if val]
        src_cols = [vy_vars[i] for i, val in enumerate(to_fallback) if val]
        df[cols_to_assign] = df[src_cols]
    return df

# Benchmark loop
df_test = df_base.copy()
start = time.time()
method_loop(df_test)
loop_time = time.time() - start

# Benchmark vectorized
df_test2 = df_base.copy()
start = time.time()
method_vectorized(df_test2)
vec_time = time.time() - start

print(f"Loop time: {loop_time:.4f} seconds")
print(f"Vectorized time: {vec_time:.4f} seconds")
print(f"Speedup: {loop_time / vec_time:.2f}x")
