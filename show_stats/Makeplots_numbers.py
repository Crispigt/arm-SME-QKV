import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import os
import sys
from matplotlib.patches import Patch
from matplotlib.ticker import ScalarFormatter

def get_data_array(source: str, size: int, row: str) -> np.ndarray:
    filepath = os.path.join(source, f"summary_table_size_{size}.csv")

    if not os.path.isfile(filepath):
        raise FileNotFoundError(f"CSV file not found: {filepath}")

    df = pd.read_csv(filepath, index_col=0)
    vls = [128, 256, 512]

    required_columns = (
        [f"naive_{size}"]
        + [f"sve_{size}_vl{vl}" for vl in vls]
        + [f"sme_full_{size}_vl{vl}" for vl in vls]
    )

    for col in required_columns:
        if col not in df.columns:
            raise ValueError(f"Missing column: {col}")
    if row not in df.index:
        raise ValueError(f"Missing row: {row}")

    naive_value = df.loc[f"{row}", f"naive_{size}"]
    output = []

    for vl in vls:
        sve_val = df.loc[f"{row}", f"sve_{size}_vl{vl}"]
        sme_val = df.loc[f"{row}", f"sme_full_{size}_vl{vl}"]
        output.append([float(naive_value), float(sve_val), float(sme_val)])

    return np.array(output)


def print_plot(data_type: str, row: str):
    if data_type == "qemu":
        data_type = "perf"

    bar_datasets = [
        get_data_array(f"tables_{data_type}_vl/", 32, row),
        get_data_array(f"tables_{data_type}_vl/", 64, row),
        get_data_array(f"tables_{data_type}_vl/", 128, row),
        get_data_array(f"tables_{data_type}_vl/", 512, row),
    ]

    bar_labels = ["Naive", "SVE", "SME"]
    column_numbers = ["vl_128", "vl_256", "vl_512"]
    n_values = [32, 64, 128, 512]

    bar_width = 0.8
    group_spacing = 1.5
    bars_per_group = len(bar_labels)

    colors = {"Naive": "tab:blue", "SVE": "tab:orange", "SME": "tab:green"}

    fig, axes = plt.subplots(2, 2, figsize=(10, 7))
    axes = axes.flatten()

    for idx, ax in enumerate(axes):
        bar_data = bar_datasets[idx]
        

        ax.ticklabel_format(style='sci', axis='y', scilimits=(-3,4))

        group_centers = []
        bars_to_label_on_this_ax = [] 
        for i in range(bar_data.shape[0]): 
            group_start = i * (bars_per_group * bar_width + group_spacing)
            
            for j, label_category in enumerate(bar_labels):
                x_position = group_start + j * bar_width
                height = bar_data[i][j] 
                bar_artist = ax.bar(x_position, height, bar_width, color=colors[label_category])
                
                if j >= 0: 
                    bars_to_label_on_this_ax.append({'artist': bar_artist, 'value': height})
            
            group_center = group_start + (bars_per_group * bar_width) / 2
            group_centers.append(group_center)

        if bar_data.size > 0:
            max_val = np.max(bar_data)
            ax.set_ylim(0, max_val * 1.2)
        else:
            ax.set_ylim(0, 1) 

        if bars_to_label_on_this_ax:
            fig.canvas.draw_idle()

            y_formatter = ax.yaxis.get_major_formatter()
            axis_scale_exponent = 0
            use_axis_scaling_for_labels = False

            if isinstance(y_formatter, ScalarFormatter):
                current_offset_text = y_formatter.get_offset()
                if current_offset_text:
                    axis_scale_exponent = y_formatter.orderOfMagnitude
                    use_axis_scaling_for_labels = True
            
            for bar_info in bars_to_label_on_this_ax:
                artist_to_label = bar_info['artist']
                value_to_label = bar_info['value'] 
                label_text = ""

                if use_axis_scaling_for_labels:
                    scaled_value = value_to_label / (10**axis_scale_exponent)
                    if scaled_value.is_integer():
                        label_text = f"{scaled_value:.3f}"
                    else:
                        label_text = f"{scaled_value:.3f}"
                else:
                    condition_for_full_sci_notation = (abs(value_to_label) >= 10000) or \
                                                      (abs(value_to_label) < 0.01 and value_to_label != 0)
                    if condition_for_full_sci_notation:
                        if value_to_label == 0: 
                            label_text = "0"
                        else:
                            label_text = f"{value_to_label:.1e}"
                    elif value_to_label.is_integer():
                        label_text = f"{value_to_label:.3f}"
                    else:
                        label_text = f"{value_to_label:.3f}"
                
                ax.bar_label(
                    artist_to_label,
                    labels=[label_text], 
                    padding=2,
                    fontsize=8,
                    rotation=55,
                )
        
        ax.set_xticks(group_centers)
        ax.set_xticklabels(column_numbers, rotation=0, ha="center", fontsize=9)
        ax.annotate(
            f"N = {n_values[idx]}",
            xy=(1.02, 0.5),
            xycoords="axes fraction",
            rotation=90,
            va="center",
            ha="left",
            fontsize=12,
            fontweight="bold",
        )

    legend_handles = [Patch(color=colors[label], label=label) for label in bar_labels]
    fig.legend(legend_handles, bar_labels, loc="upper center", ncol=3, fontsize=10)

    plt.tight_layout(rect=(0, 0, 1, 0.95))
    output_filename = f"{data_type}_{row}_plot.png"
    plt.savefig(output_filename)
    print(f"Plot saved to {output_filename}")
    plt.close(fig)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python script_name.py <data_type> <row_type>")
        print("Example: python script_name.py perf cycles")
        sys.exit(1)
    data_type = sys.argv[1]
    row_type = sys.argv[2]
    print_plot(data_type, row_type)