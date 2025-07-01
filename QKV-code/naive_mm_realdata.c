#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <stdbool.h>
#include <limits.h> 

#define TOLERANCE 1e-4f 
#define PATH_BUFFER_SIZE 512 


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


/**
 * Loads matrix data from a file.
 * Assumes format: rows cols\ndata...
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

    //printf("Loading matrices for head %02d...\n", head_index);
    Q = load_matrix_data(q_path, &n, &d_k);
    K = load_matrix_data(k_path, &k_rows, &d_k);
    V = load_matrix_data(v_path, &v_rows, &d_v);
    Expected_Output = load_matrix_data(expected_path, &expected_rows, &expected_cols);


    K_T = transpose(K, n, d_k);
    if (!K_T) {
        perror("Head %02d: Failed to transpose K");
        goto head_cleanup;
    }

    QK_T_scaled = malloc(n * n * sizeof(float));
    if (!QK_T_scaled) {
        perror("Head %02d: Failed to allocate QK_T_scaled");
        goto head_cleanup;
    }

    Output = malloc(n * d_v * sizeof(float));
    if (!Output) {
        perror("Head %02d: Failed to allocate Output");
        goto head_cleanup;
    }

    matrix_multiply_naive(Q, K_T, QK_T_scaled, n, d_k, n);

    float scale_factor = 1.0f / sqrtf((float)d_k);
    for (int i = 0; i < n * n; ++i) {
        QK_T_scaled[i] *= scale_factor;
    }

    softmax_naive(QK_T_scaled, n, n);

    matrix_multiply_naive(QK_T_scaled, V, Output, n, n, d_v);


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
    } else if (argc != 1) {
        fprintf(stderr, "Usage: %s [base_directory_path num_heads]\n", argv[0]);
        fprintf(stderr, "Example: %s real_qkv_core_test_data_layer0 12\n", argv[0]);
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