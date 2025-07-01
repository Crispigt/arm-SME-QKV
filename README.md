# Performance Comparison of QKV Attention Mechanism with ARM SVE and SME Acceleration in gem5

---

## Abstract
This study investigates the performance implications of utilizing ARM's Scalable Matrix Extension (SME) for the Query-Key-Value (QKV) attention mechanism in transformer models, comparing it against traditional Scalable Vector Extension (SVE) and naive C implementations. The research aims to port the QKV mechanism to leverage SME and analyze its computational efficiency and resource utilization relative to SVE through automatic vectorization and a baseline, unoptimized version using the gem5 simulator. Core matrix multiplication components of the QKV mechanism were implemented using standard C, SVE-, and SME instructions, and subsequently benchmarked within a configured gem5 environment modelling an ARM processor with SVE/SME support. Performance metrics such as CPU cycles, simulated execution time, and instruction counts were collected. The results demonstrate that both SVE and SME significantly reduce CPU cycles and execution times compared to the naive implementation. Notably, SME shows an additional reduction in cycle counts and DRAM energy consumption over SVE in certain configurations, suggesting its potential for enhancing performance in matrix-intensive machine learning workloads on CPUs. 

---

The full text can be found here: (To be inserted when it's been uploaded to diva)

