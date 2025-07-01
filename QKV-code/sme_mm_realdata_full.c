#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <stdbool.h>
#include <limits.h> 
#include <arm_sve.h>
#include <arm_sme.h> 

#define TOLERANCE 1e-4f 
#define PATH_BUFFER_SIZE 2048 


/**
 * @brief Applies the naive softmax function row-wise to a matrix.
 */
void softmax_naive(float *matrix, int rows, int cols) {
    for (int i = 0; i < rows; i++) {
        
        float *row = matrix + i * cols;
        float max_val = row[0];
        for (int j = 1; j < cols; j++) {
            if (row[j] > max_val) max_val = row[j];
        }
        
        float sum_exp = 0.0f;
        for (int j = 0; j < cols; j++) {
            sum_exp += expf(row[j] - max_val);
        }

        float inv_sum_exp = (sum_exp > 1e-38f || sum_exp < -1e-38f) ? (1.0f / sum_exp) : 0.0f;
        for (int j = 0; j < cols; j++) {
            row[j] = expf(row[j] - max_val) * inv_sum_exp;
        }
    }
}

void softmax_sve(float *matrix, int rows, int cols) {
    uint64_t svl = svcntw(); 

    for (int i = 0; i < rows; i++) {
        float *row_ptr = matrix + i * cols;
        svbool_t pg;
        int64_t num_active_lanes;

        svfloat32_t row_max_vec = svdup_f32(-INFINITY);
        for (int j = 0; j < cols; j += svl) {
            pg = svwhilelt_b32((uint64_t)j, (uint64_t)cols);
            svfloat32_t vec = svld1_f32(pg, row_ptr + j);
            row_max_vec = svmax_f32_m(pg, row_max_vec, vec);
        }
        float max_val = svmaxv_f32(svptrue_b32(), row_max_vec); 

        svfloat32_t sum_exp_vec = svdup_f32(0.0f);
        float scalar_max_val = max_val; 
        svfloat32_t sv_max_val = svdup_f32(scalar_max_val);

        for (int j = 0; j < cols; j += svl) {
             pg = svwhilelt_b32((uint64_t)j, (uint64_t)cols);
             svfloat32_t vec = svld1_f32(pg, row_ptr + j);
             vec = svsub_f32_m(pg, vec, sv_max_val); 
             // Ideally we should use a true SVE exp function here
             float temp_in[svl], temp_out[svl];
             svst1_f32(pg, temp_in, vec);
             num_active_lanes = svcntp_b32(pg, pg);
             for(int lane=0; lane < num_active_lanes; ++lane) {
                temp_out[lane] = expf(temp_in[lane]);
             }
             vec = svld1_f32(pg, temp_out);

             sum_exp_vec = svadd_f32_m(pg, sum_exp_vec, vec); 
        }
        float sum_exp = svaddv_f32(svptrue_b32(), sum_exp_vec);

        float inv_sum_exp = (fabsf(sum_exp) > 1e-38f) ? (1.0f / sum_exp) : 0.0f;
        svfloat32_t sv_inv_sum_exp = svdup_f32(inv_sum_exp);

        for (int j = 0; j < cols; j += svl) {
             pg = svwhilelt_b32((uint64_t)j, (uint64_t)cols);
             svfloat32_t vec = svld1_f32(pg, row_ptr + j);
             vec = svsub_f32_m(pg, vec, sv_max_val);


             // Ideally we should use a true SVE exp function
             float temp_in[svl], temp_out[svl];
             svst1_f32(pg, temp_in, vec);
             num_active_lanes = svcntp_b32(pg, pg);
             for(int lane=0; lane < num_active_lanes; ++lane) {
                temp_out[lane] = expf(temp_in[lane]);
             }
             vec = svld1_f32(pg, temp_out);


             vec = svmul_f32_m(pg, vec, sv_inv_sum_exp); 
             svst1_f32(pg, row_ptr + j, vec);
        }
    }
}

/**
 * Naive matrix multiplication C = A * B.
 * A: n x m
 * B: m x k
 * C: n x k
 **/
void matrix_multiply_naive(const float *A, const float *B, float *C, int n, int m, int k) {
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < k; j++) {
            C[i * k + j] = 0.0f;
            for (int l = 0; l < m; l++) {
                C[i * k + j] += A[i * m + l] * B[l * k + j];
            }
        }
    }
}

__arm_new("za") void matmul_sme(
    const float* A,
    const float* B,
    float* C,
    int M,
    int K,
    int N
) __arm_streaming {
    uint64_t svl = svcntw();

    if ((M % svl != 0) || (N % svl != 0) || (K % svl != 0)) {
        return;
    }

    uint64_t tile_m_elems = svl;
    uint64_t tile_n_elems = svl;

    for (uint64_t i = 0; i < M; i += tile_m_elems) {
        for (uint64_t j = 0; j < N; j += tile_n_elems) {

            svzero_za(); 

            for (uint64_t k_outer = 0; k_outer < K; k_outer += svl) {
                for (uint64_t k_inner = 0; k_inner < svl; ++k_inner) {
                    
                    float a_row_buf[svl];
                    for (uint64_t l = 0; l < svl; ++l) {
                        a_row_buf[l] = A[(i + l) * K + (k_outer + k_inner)];
                    }
                    svfloat32_t vec_a = svld1_f32(svptrue_b32(), a_row_buf);

                    const float* ptr_b = B + (k_outer + k_inner) * N + j;
                    svfloat32_t vec_b = svld1_f32(svptrue_b32(), ptr_b);

                    svmopa_za32_f32_m(0, svptrue_b32(), svptrue_b32(), vec_a, vec_b);
                }
            }

            
            for (uint64_t C_tile_row = 0; C_tile_row < tile_m_elems; ++C_tile_row) {
                uint32_t slice_idx = C_tile_row;

                svfloat32_t result_vec = svread_hor_za32_f32_m(
                    svundef_f32(), svptrue_b32(), 0, slice_idx
                );

                float* ptr_c = C + (i + C_tile_row) * N + j;
                svst1_f32(svptrue_b32(), ptr_c, result_vec);
            }
        }
    }
}

__arm_new("za") void matmul_sme_scaled(
    const float* A, // Q 
    const float* B, // K_T
    float* C,       // Output
    int M,
    int K_dim,
    int N_dim,
    float scale_a   // Scaling factor for A
) __arm_streaming {
    uint64_t svl = svcntw();

    uint64_t tile_m_elems = svl;
    uint64_t tile_n_elems = svl;
    svbool_t pg_all = svptrue_b32();

    for (uint64_t i = 0; i < M; i += tile_m_elems) {
        svbool_t pg_m = svwhilelt_b32_u64(i, M); 

        for (uint64_t j = 0; j < N_dim; j += tile_n_elems) {
            svbool_t pg_n = svwhilelt_b32_u64(j, N_dim);

            svzero_za();

            for (uint64_t k = 0; k < K_dim; ++k) { 

                float a_col_buf[svl];
                 for (uint64_t l = 0; l < tile_m_elems; ++l) {
                     if (i + l < M) { a_col_buf[l] = A[(i + l) * K_dim + k]; }
                     else { a_col_buf[l] = 0.0f; }
                 }
                 svfloat32_t vec_a_unscaled = svld1_f32(pg_all, a_col_buf); 

                 svfloat32_t vec_a = svmul_n_f32_z(pg_all, vec_a_unscaled, scale_a); // Apply scaling

                 const float* ptr_b = B + k * N_dim + j;
                 svfloat32_t vec_b = svld1_f32(pg_n, ptr_b); 

                 svmopa_za32_f32_m(0, pg_all, pg_n, vec_a, vec_b); 
            }

            for (uint64_t C_tile_row = 0; C_tile_row < tile_m_elems; ++C_tile_row) {
                 if (i + C_tile_row < M) {
                     uint32_t slice_row_idx = C_tile_row;
                     svfloat32_t result_vec = svread_hor_za32_f32_m(svundef_f32(), pg_n, 0, slice_row_idx);
                     float* ptr_c = C + (i + C_tile_row) * N_dim + j;
                     svst1_f32(pg_n, ptr_c, result_vec); 
                 }
            }
        }
    }
}

/**
 * Loads matrix data from a file.
 */
float* load_matrix_data(const char* filename, int* rows, int* cols) {
    FILE* file = fopen(filename, "r");
    if (!file) {
        perror("Error opening file");
        fprintf(stderr, "Failed to open: %s\n", filename);
        return NULL;
    }

    if (fscanf(file, "%d %d", rows, cols) != 2) {
        fprintf(stderr, "Error reading dimensions from %s\n", filename);
        fclose(file);
        return NULL;
    }

    int total = (*rows) * (*cols);
     if (total <= 0) {
         fprintf(stderr, "Invalid dimensions (%d x %d) read from %s\n", *rows, *cols, filename);
         fclose(file);
         return NULL;
     }

    float* matrix = malloc(total * sizeof(float));
    if (!matrix) {
        perror("Error allocating memory for matrix");
        fclose(file);
        return NULL;
    }

    for (int i = 0; i < total; i++) {
        if (fscanf(file, "%f", &matrix[i]) != 1) {
            fprintf(stderr, "Error reading matrix data element %d from %s\n", i, filename);
            free(matrix);
            fclose(file);
            return NULL;
        }
    }

    fclose(file);
    return matrix;
}

/**
 * Transposes a matrix A (rows x cols) into B (cols x rows).
 * Caller must free the returned matrix B.
 */
float* transpose(const float *A, int rows, int cols) {
     if (!A || rows <= 0 || cols <= 0) {
         fprintf(stderr, "Invalid input to transpose function\n");
         return NULL;
     }
    float *B = malloc(sizeof(float) * rows * cols);
     if (!B) {
         perror("Error allocating memory for transposed matrix");
         return NULL;
     }

    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            B[j * rows + i] = A[i * cols + j];
        }
    }
    return B;
}

float* transpose_sve2_scatter(const float *A, int rows, int cols) {

    if (!A || rows <= 0 || cols <= 0) {
        fprintf(stderr, "Invalid input to transpose_sve2_scatter (A=%p, rows=%d, cols=%d)\n", (void*)A, rows, cols);
        return NULL;
    }

    uint64_t svl = svcntw();


    uint64_t max_offset_step = (uint64_t)rows * sizeof(float);
    if (max_offset_step > UINT_MAX) {
         fprintf(stderr, "Error: Matrix dimensions (%d rows) too large for 32-bit scatter offsets.\n", rows);
         return NULL;
    }
    if (svl > 1 && ((svl - 1) * max_offset_step > UINT_MAX)) {
         fprintf(stderr, "Error: Matrix dimensions (%d rows) and vector length (%lu) too large for 32-bit scatter offsets.\n", rows, svl);
         return NULL;
    }


    float *B = malloc(sizeof(float) * cols * rows);
    if (!B) {
        perror("Error allocating memory for transposed matrix B");
        return NULL;
    }

    for (int j = 0; j < cols; j += svl) {
        svbool_t pg_cols = svwhilelt_b32((uint64_t)j, (uint64_t)cols);

        svuint32_t byte_offsets_scatter = svindex_u32(0, (uint32_t)rows * sizeof(float));

        for (int i = 0; i < rows; i++) {
            const float *ptr_A_row = A + (uint64_t)i * cols + j;
            svfloat32_t vec_A_row = svld1_f32(pg_cols, ptr_A_row);

            float *base_B_scatter_addr = B + (uint64_t)j * rows + i;

            svst1_scatter_u32offset_f32(pg_cols, base_B_scatter_addr, byte_offsets_scatter, vec_A_row);
        }
    }

    return B;
}

/**
 * Prints a matrix to stdout.
 */
void print_matrix(const char* name, const float* A, int rows, int cols) {
    printf("Matrix %s (%dx%d):\n", name, rows, cols);
     if (!A) {
         printf(" (NULL)\n");
         return;
     }
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            printf("%f ", A[i * cols + j]);
        }
        printf("\n");
    }
     printf("----\n");
}


/**
 * Compares two matrices element-wise within a tolerance.
 */
bool compare_matrices(const float* A, const float* B, int rows, int cols, float tolerance) {
    if (!A || !B) return false;
    for (int i = 0; i < rows * cols; ++i) {
        if (fabsf(A[i] - B[i]) > tolerance) {
            int row_idx = i / cols;
            int col_idx = i % cols;
            fprintf(stderr, "Mismatch at row %d, col %d (index %d): A=%f, B=%f, Diff=%f\n",
                    row_idx, col_idx, i, A[i], B[i], fabsf(A[i] - B[i]));
            return false;
        }
    }
    return true;
}


// --- Function to run test for a single head ---
bool run_attention_test_for_head(const char* base_dir, int head_index) {
    //printf("\n--- Testing Head %02d ---\n", head_index);

    float *Q = NULL, *K = NULL, *V = NULL, *Expected_Output = NULL;
    float *K_T = NULL;
    float *QK_T_scaled = NULL;
    float *Output = NULL;
    int n = 0, d_k = 0, d_v = 0;
    int k_rows = 0, v_rows = 0;
    int expected_rows = 0, expected_cols = 0;
    bool head_passed = false;

    char q_path[PATH_BUFFER_SIZE];
    char k_path[PATH_BUFFER_SIZE];
    char v_path[PATH_BUFFER_SIZE];
    char expected_path[PATH_BUFFER_SIZE];

    snprintf(q_path, sizeof(q_path), "%s/head_%02d/q_matrix.txt", base_dir, head_index);
    snprintf(k_path, sizeof(k_path), "%s/head_%02d/k_matrix.txt", base_dir, head_index);
    snprintf(v_path, sizeof(v_path), "%s/head_%02d/v_matrix.txt", base_dir, head_index);
    snprintf(expected_path, sizeof(expected_path), "%s/head_%02d/expected_context.txt", base_dir, head_index);

    Q = load_matrix_data(q_path, &n, &d_k);
    K = load_matrix_data(k_path, &k_rows, &d_k);
    V = load_matrix_data(v_path, &v_rows, &d_v);
    Expected_Output = load_matrix_data(expected_path, &expected_rows, &expected_cols);

    // printf("Head %02d: Matrices loaded.\n", head_index);

    K_T = transpose_sve2_scatter(K, n, d_k); // K is (n, d_k), K_T is (d_k, n)

    QK_T_scaled = malloc(n * n * sizeof(float)); // Stores Q*K_T
    memset(QK_T_scaled, 0, n * n * sizeof(float));

    Output = malloc(n * d_v * sizeof(float)); // Stores final result
    memset(Output, 0, n * d_v * sizeof(float));

    float scale_a = 1.0f / sqrtf((float)d_k);
    matmul_sme_scaled(Q, K_T, QK_T_scaled, n, d_k, n, scale_a);

    softmax_sve(QK_T_scaled, n, n);

    matmul_sme(QK_T_scaled, V, Output, n, n, d_v);

    if (compare_matrices(Output, Expected_Output, n, d_v, TOLERANCE)) {
        head_passed = true; 
    } else {
        printf("Head %02d: >>> TEST FAILED <<< :(\n", head_index);
        fprintf(stderr, "Head %02d: Calculated output does not match expected output within tolerance %f.\n", head_index, TOLERANCE);

    }

head_cleanup:
    free(Q);
    free(K);
    free(V);
    free(Expected_Output);
    free(K_T);
    free(QK_T_scaled);
    free(Output);

    return head_passed;
}


int main(int argc, char *argv[]) {
    const char* base_dir = "tests/workload_different_sizes/real_qkv_core_test_data_layer0_32";
    int num_heads = 12; 

    if (argc == 3) {
        base_dir = argv[1];
        num_heads = atoi(argv[2]);
        if (num_heads <= 0) {
            fprintf(stderr, "Error: Number of heads must be positive.\n");
            return EXIT_FAILURE;
        }
    } else if (argc != 1 && argc != 3) {
        fprintf(stderr, "Usage: %s [base_directory_path num_heads]\n", argv[0]);
        fprintf(stderr, "Example: %s tests/real_qkv_core_test_data_layer0 12\n", argv[0]);
        return EXIT_FAILURE;
    }

    printf("Starting Attention Core Test\n");
    printf("Base Directory: %s\n", base_dir);

    bool all_tests_passed = true; 

    for (int i = 0; i < num_heads; ++i) {
        bool result = run_attention_test_for_head(base_dir, i);
        if (!result) {
            all_tests_passed = false;
        }
    }

    printf("\n--- Test Summary ---\n");
    if (all_tests_passed) {
        printf("------------------------\n");
        printf(">>> OVERALL TEST PASSED <<< :D\n");
        printf("------------------------\n");
        return EXIT_SUCCESS;
    } else {
        printf("One or more head tests FAILED.\n");
         printf("------------------------\n");
        printf(">>> OVERALL TEST FAILED <<< D:\n");
        printf("------------------------\n");
        return EXIT_FAILURE;
    }
}