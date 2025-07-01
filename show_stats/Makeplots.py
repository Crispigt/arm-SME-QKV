import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import os
import sys
from matplotlib.patches import Patch


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

        # Normalize all values so Naive is 100
        bar_data = (bar_data.T / bar_data[:, 0] * 100).T

        group_centers = []

        for i in range(bar_data.shape[0]):
            group_start = i * (bars_per_group * bar_width + group_spacing)
            bars = []

            for j, label in enumerate(bar_labels):
                x = group_start + j * bar_width
                height = bar_data[i][j]
                bar = ax.bar(x, height, bar_width, color=colors[label])
                bars.append(bar)

            for j in range(1, 3):
                ax.bar_label(
                    bars[j],
                    labels=[f"{bar_data[i][j]:.1f}%"],
                    padding=2,
                    fontsize=8,
                    rotation=55,
                )

            group_center = group_start + (bars_per_group * bar_width) / 2
            group_centers.append(group_center)

        ax.set_xticks(group_centers)
        ax.set_xticklabels(column_numbers, rotation=0, ha="center", fontsize=9)
        ax.set_ylim(0, 120)  

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
    data_type = sys.argv[1]
    row_type = sys.argv[2]
    print_plot(data_type, row_type)