# Performance Optimization TODO

## Current Status

- **Functional Alignment**: 100% (928/928 cases pass with 0 mismatches)
- **Performance Gap**: 9-94x slower than official graphviz
- **Coverage**: All cases that complete within 60s timeout

## Performance Analysis

### Benchmark Results

| Case    | Official | Ours    | Slowdown |
|---------|----------|---------|----------|
| b29     | 0.6s     | 35s     | 58x      |
| b102    | 0.16s    | <60s    | >375x    |
| badvoro | 0.34s    | <60s    | >176x    |
| xx      | 0.16s    | <60s    | >375x    |
| b100    | 6.5s     | >60s    | >9x      |
| b103    | 1.1s     | >60s    | >55x     |
| b104    | 6.5s     | >60s    | >9x      |
| root    | 0.25s    | >60s    | >240x    |

### Root Cause Analysis

#### 1. Iteration Count (Minor Factor)
- Current: `max_iter = 24` in mincross
- Reducing to 4: only 2.3x improvement (35s -> 15s)
- **Conclusion**: Not the main bottleneck

#### 2. Per-Iteration Cost (Major Factor)
- 51 `Map.get()` calls inside loops in mincross.mbt
- 115 total `Map.get()` calls
- 136 Map assignments
- 32 `Array.push()` calls
- 11 `Array.copy()` calls

**Hot spots identified:**
- Line 54: `desired.get(name)` in nested loop (depth 2)
- Line 149: `desired.get(sorted[lp])` in triple-nested loop (depth 3)
- Line 224-286: Multiple Map lookups in single-depth loops

#### 3. Algorithm Complexity
- `count_crossings()` uses merge-sort based inversion counting (O(n log n))
- Called 10 times per optimization pass
- With 24 iterations × multiple ranks = hundreds of calls
- Each call processes all edges

## Optimization Strategies

### Short-term (Quick Wins)
1. **Cache Map lookups** in hot loops
   - Pre-compute frequently accessed values
   - Use local variables instead of repeated Map.get()

2. **Reduce allocations**
   - Reuse arrays where possible
   - Avoid unnecessary `.copy()` calls

3. **Early termination**
   - More aggressive convergence checks
   - Skip optimization for graphs with 0 crossings earlier

### Medium-term (Algorithm Improvements)
1. **Optimize count_crossings()**
   - Profile to find bottlenecks
   - Consider incremental crossing count updates

2. **Better data structures**
   - Replace Map with Array where indices are dense
   - Use specialized structures for node ordering

3. **Parallel processing**
   - Independent rank optimizations could run in parallel
   - Crossing counts for different rank pairs are independent

### Long-term (Major Refactoring)
1. **Study official graphviz implementation**
   - Compare algorithm choices in C code
   - Identify MoonBit-specific inefficiencies

2. **Rewrite core algorithms**
   - May need fundamentally different approach
   - Consider trade-offs between correctness and performance

3. **Add profiling infrastructure**
   - Instrument key functions
   - Collect performance metrics
   - A/B test optimizations

## Attempted Optimizations

### 1. Adaptive Iteration Count (Failed)
```moonbit
let mut node_count = 0
for _rank, list in groups {
  node_count = node_count + list.length()
}
let max_iter = if node_count > 100 { 2 } else if node_count > 50 { 4 } else { 24 }
```
**Result**: No significant improvement (still ~15s for b29)

### 2. Reduced max_iter (Partial Success)
- max_iter=8: 35s -> 20s (1.75x)
- max_iter=4: 35s -> 15s (2.3x)
**Issue**: Still 25x slower than official even with 6x fewer iterations

## Next Steps

1. **Profile with real profiler**
   - Need actual CPU time breakdown
   - Identify true hotspots beyond static analysis

2. **Compare with graphviz C code**
   - Line-by-line algorithm comparison
   - Understand their optimization techniques

3. **Incremental improvements**
   - Start with caching Map lookups
   - Measure each optimization's impact
   - Build up to larger refactorings

4. **Consider alternative approaches**
   - Maybe MoonBit's Map is inherently slower
   - Could use different data structures
   - Trade memory for speed where appropriate

## References

- Official graphviz: `refs/graphviz/lib/dotgen/mincross.c`
- Our implementation: `src/layout/dot/mincross.mbt`
- Crossing count: `src/layout/dot/ordering_helpers.mbt:1145`
