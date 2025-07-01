import re
import argparse
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.style as style
import sys
import os
import math
import warnings
import matplotlib
try:
    from packaging import version 
except ImportError:
    print("Warning: 'packaging' library not found. Matplotlib version check might be less precise.", file=sys.stderr)
    version = None 

import matplotlib.ticker as mticker
from matplotlib.patches import Patch 
import numpy as np 

try:
    style.use('seaborn-v0_8-colorblind')
except OSError:
    print("Warning: 'seaborn-v0_8-colorblind' style not found. Using default.", file=sys.stderr)


def parse_run_label_gem5(label):
    """
    Parses labels like 'sme_softmax_256_vl128' into ('sme_softmax', '256_vl128').
    Parses 'sve_128_vl256' into ('sve', '128_vl256').
    Parses 'naive_128' into ('naive', '128').
    Returns (group, subgroup) tuple.
    """
    match = re.match(r"(.+)_(\d+_vl\d+)$", label)
    if match:
        return match.group(1), match.group(2)

    match = re.match(r"(.+)_(\d+)$", label)
    if match:
        if not match.group(1).endswith('_vl'):
            return match.group(1), match.group(2)

    print(f"Warning: Could not parse label '{label}' into group/subgroup. Using full label as group.", file=sys.stderr)
    return label, "N/A" 



def sort_key_gem5(x):
    """Helper function to sort subgroup labels like '128_vl128' or '256'."""
    vl_match = re.search(r'vl(\d+)$', x)
    num_match = re.search(r'^(\d+)', x) 
    vl_num = int(vl_match.group(1)) if vl_match else -1 
    base_num = int(num_match.group(1)) if num_match else -1 
    return (base_num, vl_num)

def format_value_label(v):
    """Formats a number for display on the plot."""
    if pd.isna(v):
        return ""
    
    if abs(v) < 1e-9: 
        return ""
    elif 0 < abs(v) < 0.01:
        return f"{v:.1e}" 
    elif abs(v) >= 1e12: 
        return f"{v/1e12:.1f}T"
    elif abs(v) >= 1e9:
        return f"{v/1e9:.1f}G"
    elif abs(v) >= 1e6:
        return f"{v/1e6:.1f}M"
    elif abs(v) >= 1e3:
        return f"{v/1e3:.1f}k"
    elif v == int(v): 
        return f"{int(v):,d}" if abs(v) >= 10000 else f"{int(v):d}"
    else:
        if abs(v) < 10:
            return f"{v:.3f}"
        else: 
            return f"{v:.2f}"


def parse_stats(stats_file_path):
    """ Parses a gem5 stats.txt file """
    stats = {}
    try:
        with open(stats_file_path, 'r', encoding='utf-8') as f:
            for line in f:
                line_no_comment = line.split('#')[0].strip()
                if not line_no_comment or line_no_comment.startswith('---'):
                    continue

                parts = line_no_comment.split()
                if len(parts) >= 2:
                    stat_name = parts[0]
                    if not re.match(r'^[a-zA-Z0-9_.:-]+$', stat_name):
                        continue 

                    stat_value_str = parts[1]
                    try:
                        stat_value = float(stat_value_str)
                        if 'e' not in stat_value_str.lower() and '.' not in stat_value_str:
                             try: 
                                 int_val = int(stat_value_str)
                                 stats[stat_name] = int_val
                             except ValueError: 
                                 stats[stat_name] = float(stat_value) 
                        elif stat_value.is_integer():
                           stats[stat_name] = int(stat_value)
                        else:
                           stats[stat_name] = stat_value

                    except ValueError:
                        pass
    except FileNotFoundError:
        print(f"Error: Stats file not found at '{stats_file_path}'", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Error reading or parsing stats file '{stats_file_path}': {e}", file=sys.stderr)
        return None

    if not stats:
        print(f"Warning: No statistics were successfully parsed from '{stats_file_path}'.", file=sys.stderr)
    return stats


def plot_comparison_subplots_grouped(df_stats_orig, stats_to_plot, output_filename="gem5_stats_grouped_subplots.png"):
    """
    Creates a grid of grouped bar charts with CONSISTENT colors and legend for gem5 stats.
    Groups runs using parse_run_label_gem5 function.
    Uses pivot_table for robustness.
    """
    stats_found = [stat for stat in stats_to_plot if stat in df_stats_orig.index]
    stats_not_found = [stat for stat in stats_to_plot if stat not in df_stats_orig.index]

    if not stats_found:
        print("Error: None of the requested statistics found in the provided data.", file=sys.stderr)
        if stats_not_found: print(f"  Specifically missing: {', '.join(stats_not_found)}", file=sys.stderr)
        return
    if stats_not_found:
        print(f"Warning: The following requested statistics were not found in data: {', '.join(stats_not_found)}", file=sys.stderr)

    units = {
        'simTicks': 'Ticks', 'simSeconds': 'Seconds', 'simInsts': 'Count', 'simOps': 'Count',
        'system.cpu.numCycles': 'Cycles', 'system.cpu.ipc': 'IPC', 'system.cpu.cpi': 'CPI',
        'system.cpu.commitStats0.numInsts': 'Count', 'system.cpu.commitStats0.committedInstType::MatrixOP': 'Count',
        'system.cpu.commitStats0.numVecInsts': 'Count', 'system.mem_ctrl.readReqs': 'Count',
        'system.mem_ctrl.writeReqs': 'Count', 'system.mem_ctrl.avgRdBWSys': 'BW', 
        'system.mem_ctrl.avgWrBWSys': 'BW', 'system.mem_ctrl.dram.readRowHitRate': 'Rate',
        'system.mem_ctrl.dram.writeRowHitRate': 'Rate', 'system.mem_ctrl.requestorReadAvgLat::cpu.inst': 'Latency',
        'system.mem_ctrl.dram.rank0.totalEnergy': 'Energy',
        'system.mem_ctrl.dram.rank1.totalEnergy': 'Energy',
    }
    default_unit = 'Value'

    df_stats = df_stats_orig.loc[stats_found].copy()
    df_stats_T = df_stats.T 

    parsed_labels = [parse_run_label_gem5(label) for label in df_stats_T.index]
    df_stats_T['Group'] = [g for g, s in parsed_labels]
    df_stats_T['Subgroup'] = [s for g, s in parsed_labels]

    df_stats_T['Group'] = df_stats_T['Group'].replace({'sme_full': 'SME'})
    df_stats_T['Group'] = df_stats_T['Group'].replace({'sve': 'SVE'})
    df_stats_T['Group'] = df_stats_T['Group'].replace({'naive': 'Naive'})

    all_subgroups = sorted(df_stats_T['Subgroup'].unique(), key=sort_key_gem5)
    color_cycle = plt.rcParams['axes.prop_cycle'].by_key()['color']
    color_map = {subgroup: color_cycle[i % len(color_cycle)] for i, subgroup in enumerate(all_subgroups)}

    num_stats = len(stats_found)
    ncols = math.ceil(math.sqrt(num_stats))
    if num_stats > 4 and num_stats != 6 : ncols = min(math.ceil(num_stats / 2), 4)
    nrows = math.ceil(num_stats / ncols)

    base_col_width = 6; base_row_height = 4.5
    max_total_width = 28; max_total_height = 22
    min_total_width = 8; min_total_height = 6
    fig_width = min(max(base_col_width * ncols, min_total_width), max_total_width)
    fig_height = min(max(base_row_height * nrows, min_total_height), max_total_height)

    fig, axes = plt.subplots(nrows=nrows, ncols=ncols, figsize=(fig_width, fig_height), squeeze=False)
    axes_flat = axes.flatten()

    print(f"Generating {nrows}x{ncols} grid for {num_stats} statistics (using grouped bars)...")

    has_bar_label = True

    for i, stat_name in enumerate(stats_found):
        ax = axes_flat[i]
        try:
            df_pivot = pd.pivot_table(df_stats_T, values=stat_name, index='Group', columns='Subgroup', aggfunc=np.mean)

            if df_pivot.empty or df_pivot.isna().all().all():
                print(f"Warning: Pivot table for statistic '{stat_name}' is empty or all NaN. Skipping plot.", file=sys.stderr)
                ax.set_title(f"{stat_name}\n(No valid data after pivot)", fontsize=10, wrap=True)
                ax.text(0.5, 0.5, "No Data", ha='center', va='center', transform=ax.transAxes)
                continue

            current_pivot_groups = df_pivot.index.tolist()
            desired_main_order = ["Naive", "SVE", "SME"]

            final_ordered_groups = []
            for group_name in desired_main_order:
                if group_name in current_pivot_groups:
                    final_ordered_groups.append(group_name)

            remaining_groups = sorted([g for g in current_pivot_groups if g not in final_ordered_groups])
            final_ordered_groups.extend(remaining_groups)

            df_pivot = df_pivot.reindex(index=final_ordered_groups)


            df_pivot = df_pivot.reindex(columns=all_subgroups)


            plot_colors = [color_map.get(col, '#808080') for col in df_pivot.columns] 
            df_pivot.plot(kind='bar', ax=ax, rot=0, legend=False, width=0.8, color=plot_colors)

        except KeyError as ke:
            print(f"Error: KeyError during pivot_table for statistic '{stat_name}'. Missing column? {ke}", file=sys.stderr)
            ax.set_title(f"{stat_name}\n(Error: Missing data/KeyError)", fontsize=10, wrap=True)
            ax.text(0.5, 0.5, "KeyError during pivot", ha='center', va='center', transform=ax.transAxes, color='red')
            continue
        except Exception as e:
            print(f"Error: Could not create pivot_table for statistic '{stat_name}'. Error: {e}", file=sys.stderr)
            ax.set_title(f"{stat_name}\n(Error creating pivot_table)", fontsize=10, wrap=True)
            ax.text(0.5, 0.5, "Pivot Table Error", ha='center', va='center', transform=ax.transAxes, color='red')
            continue

        stat_unit = units.get(stat_name, default_unit)
        ax.set_title(f"{stat_name} ({stat_unit})", fontsize=11, wrap=True, y=1.15)
        ax.set_ylabel(stat_unit, fontsize=10)
        ax.set_xlabel(None)
        ax.tick_params(axis='x', rotation=30, labelsize=9)
        ax.tick_params(axis='y', labelsize=9)
        ax.grid(axis='y', linestyle=':', alpha=0.6)
        ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: format_value_label(x)))

        if hasattr(ax, 'containers') and ax.containers:
            try:
                valid_pivot_data = df_pivot.dropna(axis=1, how='all')
                if not valid_pivot_data.empty:
                    min_val = np.nanmin(valid_pivot_data.values)
                    max_val = np.nanmax(valid_pivot_data.values)
                else:
                    min_val = np.nan
                    max_val = np.nan

                if pd.notna(min_val) and pd.notna(max_val): 
                    padding_factor = 1.5

                    if min_val >= 0:
                        final_bottom = 0 
                    else: 
                        data_range = max_val - min_val
                        if data_range == 0: data_range = abs(min_val) * 0.1 if min_val != 0 else 0.1
                        final_bottom = min_val - data_range * (padding_factor - 1)

                    data_range = max_val - min_val

                    if data_range == 0: data_range = abs(max_val) * 0.1 if max_val != 0 else 0.1
                    final_top = max_val + data_range * (padding_factor - 1)

                    if max_val <= 0 :
                        final_top = max(final_top, data_range * (padding_factor -1) * 0.1) 

                    if final_top <= final_bottom:
                        final_top = final_bottom + (abs(final_bottom * 0.1) if final_bottom != 0 else 0.1)

                    ax.set_ylim(bottom=final_bottom, top=final_top)

                elif pd.notna(max_val): 
                     padding = abs(max_val * 0.15) if max_val != 0 else 0.1 
                     final_bottom = 0 if max_val >= 0 else max_val - padding
                     final_top = max_val + padding
                     if max_val < 0: final_top = 0 
                     if final_top <= final_bottom: final_top = final_bottom + padding * 0.1 + 1e-9 
                     ax.set_ylim(bottom=final_bottom, top=final_top)


            except Exception as e_ylim:
                print(f"Warning: Could not adjust y-limits for {stat_name}. Error: {e_ylim}", file=sys.stderr)


            if has_bar_label:
                for container in ax.containers:
                    valid_indices = [idx for idx, v in enumerate(container.datavalues) if pd.notna(v)]
                    labels_for_valid_bars = [format_value_label(container.datavalues[idx]) for idx in valid_indices]

                    all_labels = [""] * len(container.patches)
                    for i, real_idx in enumerate(valid_indices):

                        all_labels[real_idx] = labels_for_valid_bars[i]

                    try:
                        ax.bar_label(container, labels=all_labels, rotation=90, padding=3, fontsize=7, label_type='edge', fmt='%s')
                    except Exception as e_barlabel:
                        print(f"Warning: ax.bar_label failed for {stat_name}. Error: {e_barlabel}. Trying fallback.", file=sys.stderr)
                        has_bar_label = False 

            if not has_bar_label: 
                num_subgroups = len(df_pivot.columns)
                bar_width_total = 0.8 

                num_groups = len(df_pivot.index)
                num_subgroups_total = len(df_pivot.columns) 

                for group_idx, group_name in enumerate(df_pivot.index):
                    group_data = df_pivot.loc[group_name].dropna()
                    num_bars_in_group = len(group_data)
                    if num_bars_in_group == 0: continue 

                    single_bar_width = bar_width_total / num_bars_in_group

                    group_start_offset = - bar_width_total / 2

                    bar_counter = 0
                    for sub_idx, sub_name in enumerate(df_pivot.columns): 
                        val = df_pivot.iloc[group_idx, sub_idx]
                        if pd.notna(val): 
                            x_pos = group_idx + group_start_offset + (bar_counter + 0.5) * single_bar_width
                            label_text = format_value_label(val)
                            ax.text(x_pos, val, label_text, ha='center', va='bottom', rotation=90, fontsize=7, xytext=(0, 3), textcoords='offset points')
                            bar_counter += 1


        ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
        ax.tick_params(axis='x', which='major', length=0) 


    present_subgroups = df_stats_T['Subgroup'].unique()
    subgroups_for_legend = [sg for sg in all_subgroups if sg in present_subgroups]
    legend_handles = [Patch(facecolor=color_map[subgroup], label=subgroup) for subgroup in subgroups_for_legend]

    if legend_handles:
        fig.legend(handles=legend_handles,
                    title="Size / Vector Length", 
                    loc='lower center', bbox_to_anchor=(0.5, 0.01), 
                    ncol=min(len(subgroups_for_legend), 6),
                    fontsize=9, title_fontsize=10)

    for i in range(num_stats, len(axes_flat)): axes_flat[i].axis('off') 
    fig.suptitle('Gem5 Statistics Comparison', fontsize=16, y=0.98) 

    try:

        fig.tight_layout(rect=[0.02, 0.10, 0.98, 0.94]) 
    except ValueError:
        print("Warning: tight_layout failed. Using subplots_adjust.", file=sys.stderr)
        plt.subplots_adjust(hspace=0.50, wspace=0.3, top=0.92, bottom=0.18, left=0.07, right=0.97)

    try:
        plt.savefig(output_filename, dpi=300, bbox_inches='tight')
        print(f"Grouped subplots comparison saved successfully as '{output_filename}'")
    except Exception as e:
        print(f"Error saving plot '{output_filename}': {e}", file=sys.stderr)
    finally:
        plt.close(fig) 


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Compare and visualize statistics from multiple gem5 runs using grouped subplots.")
    parser.add_argument("run_dirs", nargs='+', help="List of directories containing stats.txt (m5out dirs).")
    parser.add_argument("-s", "--stats", nargs='+', required=True, help="List of statistic names to parse and plot.")
    parser.add_argument("-o", "--output", default="gem5_stats_grouped_subplots.png", help="Output filename for the plot.")
    parser.add_argument("-l", "--labels", nargs='*', 
                        help="List of labels for the runs (must match the number of run_dirs). If not provided, labels derived from dir names.")
    parser.add_argument("--stats-filename", default="stats.txt", help="Statistics filename within run dirs (default: stats.txt).")
    parser.add_argument("--summary-output", help="Optional filename to save the summary table (e.g., summary.csv, summary.md).")

    args = parser.parse_args()

    if args.labels and len(args.labels) != len(args.run_dirs):
        print(f"Error: Number of labels ({len(args.labels)}) does not match number of run directories ({len(args.run_dirs)}).", file=sys.stderr)
        sys.exit(1)

    collated_stats = {}
    run_labels_ordered = [] 

    for i, run_dir in enumerate(args.run_dirs):
        if not os.path.isdir(run_dir):
            print(f"Warning: '{run_dir}' not a directory. Skipping.", file=sys.stderr)
            continue

        stats_file_path = os.path.join(run_dir, args.stats_filename)

        run_label = ""
        if args.labels:
            run_label = args.labels[i]
        else:
            run_label = os.path.basename(run_dir)
            run_label = run_label.replace("m5out_", "")
            run_label = run_label.strip('_.- ')
            if i == 0: 
                print("Warning: No labels provided via -l. Using directory names as labels.", file=sys.stderr)

        print(f"Processing run: '{run_label}' (from {stats_file_path})...")

        if run_label in collated_stats:
            print(f"Warning: Duplicate run label '{run_label}'. Overwriting previous data.", file=sys.stderr)
            if run_label in run_labels_ordered: run_labels_ordered.remove(run_label)
            run_labels_ordered.append(run_label)
        else:
            run_labels_ordered.append(run_label)

        stats_data = parse_stats(stats_file_path)

        if stats_data is not None and stats_data: 
            collated_stats[run_label] = stats_data
        else:
            print(f"--> Failed to parse meaningful stats for run '{run_label}'. Excluded from results.", file=sys.stderr)
            if run_label in run_labels_ordered: run_labels_ordered.remove(run_label)
            if run_label in collated_stats: del collated_stats[run_label] 


    if not collated_stats:
        print("\nError: No statistics data loaded successfully from any run directory. Cannot generate plots or table.", file=sys.stderr)
        sys.exit(1)

    df_all_stats = pd.DataFrame(collated_stats)
    valid_columns = [lbl for lbl in run_labels_ordered if lbl in df_all_stats.columns]

    if len(valid_columns) != len(run_labels_ordered):
        print("Warning: Some runs listed were not found as columns in the final DataFrame (likely due to parsing errors).", file=sys.stderr)
        print(f"  Labels expected (in order): {run_labels_ordered}", file=sys.stderr)
        print(f"  Columns found: {df_all_stats.columns.tolist()}", file=sys.stderr)

    if not valid_columns:
        print("\nError: No valid run data columns found in DataFrame after processing. Cannot proceed.", file=sys.stderr)
        sys.exit(1)

    df_all_stats = df_all_stats[valid_columns] 
    with warnings.catch_warnings():
        warnings.simplefilter(action='ignore', category=FutureWarning)
        warnings.simplefilter(action='ignore', category=UserWarning)
        plot_comparison_subplots_grouped(df_all_stats, args.stats, args.output)

    print("\n--- Summary Table ---")
    stats_in_df = df_all_stats.index.tolist()
    stats_to_print = [s for s in args.stats if s in stats_in_df]

    if stats_to_print:
        df_selected = df_all_stats.loc[stats_to_print]
        with pd.option_context('display.max_rows', None, 'display.max_columns', None,'display.width', 150, 'display.float_format', '{:,.4f}'.format): print(df_selected.to_string())
        if args.summary_output:
            try:
                filename = args.summary_output
                _, extension = os.path.splitext(filename)
                extension = extension.lower()
                if extension == '.csv':
                    df_selected.to_csv(filename, float_format='%.6g') 
                    print(f"\nSummary table saved as '{filename}' (CSV).")
                elif extension == '.md':
                    df_selected.to_markdown(filename)
                    print(f"\nSummary table saved as '{filename}' (Markdown).")
                else:
                    with open(filename, 'w', encoding='utf-8') as f:
                        f.write(df_selected.to_string())
                    print(f"\nSummary table saved as '{filename}' (Plain Text).")
            except Exception as e: print(f"\nError saving summary table: {e}", file=sys.stderr)
    else: print("(No requested stats found in data for table)")