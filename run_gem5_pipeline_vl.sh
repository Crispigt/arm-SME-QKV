#!/bin/bash

set -e

SKIP_COMPILE=false    
SKIP_SIMULATIONS=false 

print_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --skip-compile     : Skip remote compilation and binary retrieval."
    echo "                       Assumes required binaries already exist locally."
    echo "  --skip-simulations : Skip running gem5 simulations. Assumes stats data"
    echo "                       already exists in ${LOCAL_STATS_DIR}. Useful for"
    echo "                       re-plotting or plotting existing data."
    echo "  -h, --help         : Display this help message and exit."
    exit 0
}


REMOTE_HOST="guoehi-dev"
REMOTE_USER_HOME="/home/fstenberg" 
REMOTE_CODE_DIR="${REMOTE_USER_HOME}/cCode"

# Local Directories (assuming script is run from ~/da150x-qkv)
LOCAL_QKV_DIR=$(pwd)
if [[ ! $(basename "${LOCAL_QKV_DIR}") == "da150x-qkv" ]]; then
    echo "Warning: Script assumes it's run from 'da150x-qkv' directory, but current directory is $(basename "${LOCAL_QKV_DIR}"). Paths might be incorrect."
fi

LOCAL_SOURCE_DIR="${LOCAL_QKV_DIR}/finalResults"
LOCAL_BIN_DIR="${LOCAL_SOURCE_DIR}/bin"             
LOCAL_GEM5_DIR="${LOCAL_QKV_DIR}/../gemfive2/gem5" 
LOCAL_GEM5_DATA_BASE_DIR="tests/workload_different_sizes"
LOCAL_GEM5_TESTS_DIR="${LOCAL_GEM5_DIR}/tests"
LOCAL_STATS_DIR="${LOCAL_QKV_DIR}/stats_vl"
LOCAL_PLOT_SCRIPT_DIR="${LOCAL_QKV_DIR}/show_stats"
LOCAL_PICTURES_DIR="${LOCAL_PLOT_SCRIPT_DIR}/pictures_gem5_vl"
LOCAL_TABLES_DIR="${LOCAL_PLOT_SCRIPT_DIR}/tables_gem5_vl"
LOCAL_PLOT_VENV_ACTIVATE="${LOCAL_QKV_DIR}/venv/bin/activate"
LOCAL_GEM5_VENV_ACTIVATE="${LOCAL_GEM5_DIR}/.venv/bin/activate"

PYTHON313_LIB_PATH="/opt/python3.13/lib"
PYTHON313_BIN_PATH="/opt/python3.13/bin"

MATRIX_SIZES=( "32" "64" "128" "256" "512" )
SVE_SME_VECTOR_LENGTHS=( "128" "256" "512" ) 

GEM5_OPTION_PARAM="1"

TARGET_NAMES=( "naive" "sve"  "sme_full")
SOURCE_FILES=( "naive_mm_realdata.c" "naive_mm_realdata.c" "sme_mm_realdata_full.c")
EXEC_NAMES=( "mm_naive" "mm_sve" "mm_sme_full")
M5OUT_NAMES_BASE=( "m5out_naive" "m5out_sve" "m5out_sme_full")
BASE_GCC_FLAGS="-march=armv9.2-a+sve2+sme2"
OPT_GCC_FLAGS="-O3"
LINKER_FLAGS="-static -lm"

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-compile)
      SKIP_COMPILE=true
      shift 
      ;;
    --skip-simulations) 
      SKIP_SIMULATIONS=true
      shift 
      ;;
    -h|--help)
      print_help
      ;;
    *)
      echo "Unknown option: $1"
      print_help
      exit 1
      ;;
  esac
done

mkdir -p "${LOCAL_BIN_DIR}"
mkdir -p "${LOCAL_GEM5_TESTS_DIR}"
mkdir -p "${LOCAL_STATS_DIR}"
mkdir -p "${LOCAL_PICTURES_DIR}"
mkdir -p "${LOCAL_TABLES_DIR}"

if [ "$SKIP_COMPILE" = false ]; then
    echo "######################################"
    echo "###     Remote Compilation         ###"
    echo "######################################"

    ssh "${REMOTE_HOST}" "mkdir -p ${REMOTE_CODE_DIR}"

    echo "--> Batch copying unique source files to ${REMOTE_HOST}:${REMOTE_CODE_DIR}..."
    declare -A unique_sources_map
    for src in "${SOURCE_FILES[@]}"; do
        unique_sources_map["$src"]=1
    done
    declare -a sources_to_copy_paths=()
    for src in "${!unique_sources_map[@]}"; do
        sources_to_copy_paths+=("${LOCAL_SOURCE_DIR}/${src}")
    done
    scp "${sources_to_copy_paths[@]}" "${REMOTE_HOST}:${REMOTE_CODE_DIR}/"
    echo "      Unique source files copied."


    echo "--> Preparing batch compilation command..."
    compile_commands_string=""
    num_targets=${#TARGET_NAMES[@]}
    for (( i=0; i<${num_targets}; i++ )); do
        target_name="${TARGET_NAMES[$i]}"
        src_file="${SOURCE_FILES[$i]}"
        exec_name="${EXEC_NAMES[$i]}"

        compile_flags="$BASE_GCC_FLAGS"
        if [[ "$target_name" == "naive" ]]; then
            : 
        elif [[ "$target_name" == "sve" || "$target_name" == sme* ]]; then
            compile_flags+=" $OPT_GCC_FLAGS"
        fi

        GCC_CMD="gcc ${compile_flags} ${src_file} -o ${exec_name} ${LINKER_FLAGS}"
        target_command="${GCC_CMD} && echo '--- Successfully compiled: ${exec_name}'"

        if [ -z "$compile_commands_string" ]; then
            compile_commands_string="${target_command}"
        else
            compile_commands_string+=" && ${target_command}"
        fi
    done
    echo "----- COMPILE COMMAND PREVIEW -----"
    echo "${compile_commands_string}"
    echo "---------------------------------"

    echo "--> Executing batch compilation on ${REMOTE_HOST}..."
    ssh "${REMOTE_HOST}" <<ENDSSH
set -e
source /opt/ohpc/admin/lmod/lmod/init/bash
module load GCC/14.1.0
cd "${REMOTE_CODE_DIR}"

eval "${compile_commands_string}"
ENDSSH
    echo "      Compilation finished."

    echo "--> Retrieving compiled binaries..."
    declare -a remote_exec_paths=()
    for exec_name in "${EXEC_NAMES[@]}"; do
        remote_exec_paths+=("${REMOTE_HOST}:${REMOTE_CODE_DIR}/${exec_name}")
    done

    if [ ${#remote_exec_paths[@]} -gt 0 ]; then
        echo "      Copying files back to ${LOCAL_BIN_DIR}..."
        scp "${remote_exec_paths[@]}" "${LOCAL_BIN_DIR}/"
        echo "      Binaries retrieved."
    else
        echo "      Warning: No binaries specified or found for retrieval."
    fi
    echo "" 

else
    echo "#####################################################"
    echo "### --skip-compile flag detected.                 ###"
    echo "### Skipping remote compilation and retrieval.    ###"
    echo "#####################################################"

    if [ "$SKIP_SIMULATIONS" = false ]; then
        all_binaries_exist=true
        missing_binaries=()
        for exec_name in "${EXEC_NAMES[@]}"; do
            if [ ! -f "${LOCAL_BIN_DIR}/${exec_name}" ]; then
                all_binaries_exist=false
                missing_binaries+=("${LOCAL_BIN_DIR}/${exec_name}")
            fi
        done

        if [ "$all_binaries_exist" = false ]; then
            echo "ERROR: --skip-compile used (and not skipping simulations), but the following required binaries are missing:" >&2
            for missing in "${missing_binaries[@]}"; do
                echo "  - ${missing}" >&2
            done
            echo "Please run the script without --skip-compile first, or ensure all binaries are present." >&2
            exit 1
        else
            echo "--> Found expected existing binaries in ${LOCAL_BIN_DIR} (needed for simulation)."
        fi
    else
        echo "--> --skip-simulations is active, binary check for simulation is bypassed."
    fi
    echo ""
fi 


if [ "$SKIP_SIMULATIONS" = false ]; then
    echo "######################################"
    echo "###   Prepare Local gem5 Env       ###"
    echo "######################################"
    echo "--> Copying all compiled executables from ${LOCAL_BIN_DIR} to ${LOCAL_GEM5_TESTS_DIR}..."
    cp "${LOCAL_BIN_DIR}"/* "${LOCAL_GEM5_TESTS_DIR}/"
    echo "      Executables copied to ${LOCAL_GEM5_TESTS_DIR}."
    echo "INFO: Ensure workload data files (real_qkv_*) are in ${LOCAL_GEM5_DIR}/${LOCAL_GEM5_DATA_BASE_DIR}/"
    echo ""
else
    echo "#####################################################"
    echo "### --skip-simulations flag detected.             ###"
    echo "### Skipping gem5 environment setup & simulations.###"
    echo "### Proceeding directly to plotting.              ###"
    echo "#####################################################"
    echo ""
fi


echo "######################################"
echo "### Run Simulations & Plotting     ###"
echo "######################################"

for size in "${MATRIX_SIZES[@]}"; do
    echo ""
    echo "--- Processing Matrix Size: ${size} ---"

    declare -a current_size_plot_dirs=()
    declare -a current_size_plot_labels=()

    if [ "$SKIP_SIMULATIONS" = false ]; then
        echo "--- Running Simulations for Size: ${size} ---"
        data_file_basename="real_qkv_core_test_data_layer0_${size}"
        gem5_data_file_path="${LOCAL_GEM5_DATA_BASE_DIR}/${data_file_basename}"
        gem5_options_arg="${gem5_data_file_path} ${GEM5_OPTION_PARAM}"

        num_targets=${#TARGET_NAMES[@]}
        for (( i=0; i<${num_targets}; i++ )); do
            target_name="${TARGET_NAMES[$i]}"
            exec_name="${EXEC_NAMES[$i]}"
            m5out_base="${M5OUT_NAMES_BASE[$i]}"
            gem5_binary_path="tests/${exec_name}" 

            if [[ "$target_name" == "naive" ]]; then
                vl_list=( "N/A" )
                is_vl_applicable=false
            elif [[ "$target_name" == "sve" || "$target_name" == sme* ]]; then
                vl_list=( "${SVE_SME_VECTOR_LENGTHS[@]}" )
                is_vl_applicable=true
            else
                echo "  WARNING: Unknown target type '${target_name}'. Skipping simulation."
                continue
            fi

            for vl in "${vl_list[@]}"; do
                m5out_name=""
                current_label=""
                gem5_vl_arg=""
                full_m5out_path=""


                if $is_vl_applicable; then
                    m5out_name="${m5out_base}_${size}_vl${vl}"
                    current_label="${target_name}_${size}_vl${vl}"
                    gem5_vl_arg="--vector-length ${vl}"
                else
                    m5out_name="${m5out_base}_${size}"
                    current_label="${target_name}_${size}"
                    gem5_vl_arg=""
                fi
                full_m5out_path="${LOCAL_STATS_DIR}/${m5out_name}"

                echo "--> Running Sim: Target=${target_name}, Size=${size}, VL=${vl} (Binary: ${gem5_binary_path})"
                echo "      Data file option: ${gem5_options_arg}"
                echo "      Vector Length arg: ${gem5_vl_arg:-'(none)'}"
                echo "      Output directory: ${full_m5out_path}"

                (
                    echo "        Setting up gem5 environment in subshell..."
                    cd "${LOCAL_GEM5_DIR}"

                    echo "        Activating gem5 venv: ${LOCAL_GEM5_VENV_ACTIVATE}"
                    if [ -f "${LOCAL_GEM5_VENV_ACTIVATE}" ]; then
                        source "${LOCAL_GEM5_VENV_ACTIVATE}"
                    else
                        echo "        ERROR: Gem5 venv activation script not found at ${LOCAL_GEM5_VENV_ACTIVATE}" >&2
                        exit 1
                    fi

                    echo "        Setting Python 3.13 paths..."
                    export LD_LIBRARY_PATH=${PYTHON313_LIB_PATH}:${LD_LIBRARY_PATH:-}
                    export PATH=${PYTHON313_BIN_PATH}:$PATH

                    echo "        Starting gem5.opt..."
                    ./build/ARM/gem5.opt configs/testing/simple.py --binary "${gem5_binary_path}" --options "${gem5_options_arg}" ${gem5_vl_arg}

                    echo "        gem5 finished in subshell."
                ) 

                if [ -d "${LOCAL_GEM5_DIR}/m5out" ]; then
                    echo "      Moving m5out to ${full_m5out_path}..."
                    if [ -d "${full_m5out_path}" ]; then
                       echo "      Warning: Output directory ${full_m5out_path} already exists. Overwriting."
                       rm -rf "${full_m5out_path}"
                    fi
                    mv "${LOCAL_GEM5_DIR}/m5out" "${full_m5out_path}"
                    echo "      Results saved for ${current_label}."
                    current_size_plot_dirs+=("${full_m5out_path}")
                    current_size_plot_labels+=("${current_label}")
                else
                    echo "      ERROR: m5out directory not found in ${LOCAL_GEM5_DIR} after gem5 run for ${current_label}. Check gem5 logs. Skipping results move." >&2
                fi
                echo ""
            done
        done 
    else
        echo "--- Discovering existing data for Size: ${size} (Simulations Skipped) ---"
        num_targets=${#TARGET_NAMES[@]}
        for (( i=0; i<${num_targets}; i++ )); do
            target_name="${TARGET_NAMES[$i]}"
            m5out_base="${M5OUT_NAMES_BASE[$i]}"

            vl_list_discover=()
            is_vl_applicable_discover=false

            if [[ "$target_name" == "naive" ]]; then
                vl_list_discover=( "N/A" )
                is_vl_applicable_discover=false
            elif [[ "$target_name" == "sve" || "$target_name" == sme* ]]; then
                vl_list_discover=( "${SVE_SME_VECTOR_LENGTHS[@]}" )
                is_vl_applicable_discover=true
            else
                continue
            fi

            for vl_discover in "${vl_list_discover[@]}"; do
                m5out_name_discover=""
                current_label_discover=""
                full_m5out_path_discover=""


                if $is_vl_applicable_discover; then
                    m5out_name_discover="${m5out_base}_${size}_vl${vl_discover}"
                    current_label_discover="${target_name}_${size}_vl${vl_discover}"
                else
                    m5out_name_discover="${m5out_base}_${size}"
                    current_label_discover="${target_name}_${size}"
                fi
                full_m5out_path_discover="${LOCAL_STATS_DIR}/${m5out_name_discover}"

                if [ -d "${full_m5out_path_discover}" ]; then
                    echo "      Found existing data for ${current_label_discover} at ${full_m5out_path_discover}"
                    current_size_plot_dirs+=("${full_m5out_path_discover}")
                    current_size_plot_labels+=("${current_label_discover}")
                else
                    echo "      INFO: Expected data for ${current_label_discover} not found at ${full_m5out_path_discover}. It will not be plotted."
                fi
            done
        done
        echo ""
    fi 

    echo "--- Plotting Results for Size: ${size} ---"

    if [ ${#current_size_plot_dirs[@]} -eq 0 ]; then
        echo "      WARNING: No data (neither generated nor found existing) to plot for size ${size}. Skipping plot generation." >&2
        continue
    fi

    echo "      Generating comparison plot using directories:"
    printf "        %s\n" "${current_size_plot_dirs[@]}"
    echo "      Using labels:"
    printf "        %s\n" "${current_size_plot_labels[@]}"

    plot_output_file="${LOCAL_PICTURES_DIR}/comparison_plot_size_${size}.png"
    table_output_file="${LOCAL_TABLES_DIR}/summary_table_size_${size}.csv"

    STATS_TO_PLOT=( simTicks simSeconds simInsts simOps system.cpu.numCycles system.cpu.ipc system.cpu.cpi system.cpu.commitStats0.numInsts system.cpu.commitStats0.committedInstType::MatrixOP system.cpu.commitStats0.numVecInsts system.mem_ctrl.readReqs system.mem_ctrl.writeReqs system.mem_ctrl.avgRdBWSys system.mem_ctrl.avgWrBWSys system.mem_ctrl.dram.readRowHitRate system.mem_ctrl.dram.writeRowHitRate system.mem_ctrl.requestorReadAvgLat::cpu.inst system.mem_ctrl.dram.rank0.totalEnergy system.mem_ctrl.dram.rank1.totalEnergy )

    (
        echo "        Setting up plotting environment in subshell..."
        cd "${LOCAL_QKV_DIR}" 

        echo "        Activating plotting venv: ${LOCAL_PLOT_VENV_ACTIVATE}"
        if [ -f "${LOCAL_PLOT_VENV_ACTIVATE}" ]; then
            source "${LOCAL_PLOT_VENV_ACTIVATE}"
        else
            echo "        ERROR: Plotting venv activation script not found at ${LOCAL_PLOT_VENV_ACTIVATE}" >&2
            exit 1
        fi

        PLOT_SCRIPT_PATH="${LOCAL_PLOT_SCRIPT_DIR}/plot_gem5_comparison_perf.py"
        if [ ! -f "${PLOT_SCRIPT_PATH}" ]; then
            echo "        ERROR: Plotting script not found at ${PLOT_SCRIPT_PATH}" >&2
            exit 1
        fi

        echo "        Starting plotting script: ${PLOT_SCRIPT_PATH}"
        python "${PLOT_SCRIPT_PATH}" "${current_size_plot_dirs[@]}" \
            -s "${STATS_TO_PLOT[@]}" \
            -o "${plot_output_file}" \
            -l "${current_size_plot_labels[@]}" \
            --summary-output "${table_output_file}" \
            --stats-filename "stats.txt"

        echo "        Plotting script finished in subshell."
    ) 
    echo "      Comparison plot for size ${size} saved to ${plot_output_file}"
    echo "      Summary table for size ${size} saved to ${table_output_file}"
    echo ""

done

echo "######################################"
echo "### Pipeline finished successfully! ###"
echo "######################################"
if [ "$SKIP_SIMULATIONS" = false ]; then
    echo "Check ${LOCAL_STATS_DIR} for m5out directories (now including VL)."
fi
echo "Check ${LOCAL_TABLES_DIR} for summary tables per size."
echo "Check ${LOCAL_PICTURES_DIR} for plots generated per matrix size (comparing targets and VLs)."