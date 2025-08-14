# Performance Comparison of QKV Attention Mechanism with ARM SVE and SME Acceleration in gem5

---
This was the overall pipeline for how the code was run.

![Untitled 2025-05-26 16 54 59](https://github.com/user-attachments/assets/5c2cb1ab-0c87-43c0-81ae-bf45c1188522)

---

## Abstract
This study investigates the performance implications of utilizing ARM's Scalable Matrix Extension (SME) for the Query-Key-Value (QKV) attention mechanism in transformer models, comparing it against traditional Scalable Vector Extension (SVE) and naive C implementations. The research aims to port the QKV mechanism to leverage SME and analyze its computational efficiency and resource utilization relative to SVE through automatic vectorization and a baseline, unoptimized version using the gem5 simulator. Core matrix multiplication components of the QKV mechanism were implemented using standard C, SVE-, and SME instructions, and subsequently benchmarked within a configured gem5 environment modelling an ARM processor with SVE/SME support. Performance metrics such as CPU cycles, simulated execution time, and instruction counts were collected. The results demonstrate that both SVE and SME significantly reduce CPU cycles and execution times compared to the naive implementation. Notably, SME shows an additional reduction in cycle counts and DRAM energy consumption over SVE in certain configurations, suggesting its potential for enhancing performance in matrix-intensive machine learning workloads on CPUs. 

---

The full text can be found here: https://kth.diva-portal.org/smash/record.jsf?dswid=-9665&pid=diva2%3A1985696&c=1&searchType=UNDERGRADUATE&language=en&query=&af=%5B%5D&aq=%5B%5B%7B%22freeText%22%3A%22Performance+Comparison+of+Query-Key-Value+Attention+Mechanism+with+ARM+Scalable+Vector+Extension+and+Scalable+Matrix+Extension+Acceleration+in+gem5%22%7D%5D%5D&aq2=%5B%5B%5D%5D&aqe=%5B%5D&noOfRows=50&sortOrder=author_sort_asc&sortOrder2=title_sort_asc&onlyFullText=false&sf=all

