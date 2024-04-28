import os
import sys
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.ticker import FormatStrFormatter


def args_handler():
    if (len(sys.argv) < 2):
        print(f"Usage: python3 {sys.argv[0]} PATH_TO_DATA_DIR PATH_TO_GRAPHS_DIR")
    path_to_data_dir = sys.argv[1]
    path_to_graphs_dir = sys.argv[2]
    return path_to_data_dir, path_to_graphs_dir

# Inspired by: https://github.com/tbarbette/npf/blob/master/modules/cpuload.npf
def prepocessing(path_to_data_dir: str) -> pd.DataFrame:
    times = []
    cpu_usages = []
    line_count = 0
    # last_idle = 0
    # last_total = 0

    with open(path_to_data_dir+"/cpu_usage_results.txt") as f:
        for line in f.readlines():
            if (line_count % 2 == 0):
                times.append(int(line))
            else:
                fields = line.strip().split()
                fields = [float(column) for column in fields[1:]]
                idle, total = fields[3], sum(fields)
                # idle_delta, total_delta = idle - last_idle, total - last_total
                # last_idle, last_total = idle, total
                # cpu_usages.append(100.0 * (1.0 - idle_delta / total_delta))
                cpu_usages.append(100.0 * (1.0 - (idle / total)))

            line_count += 1

    df = pd.DataFrame({"Time": times, "CPU_Usage": cpu_usages})
    return df

def build_graph(df: pd.DataFrame, path_to_graphs_dir: str):
    plt.figure(figsize=(10, 6))
    sns.lineplot(data=df, x="Time", y="CPU_Usage", marker='o', linestyle='-')
    plt.title("CPU usage over time")
    plt.xlabel("Time (in seconds)")
    plt.ylabel("CPU usage (in %)")
    plt.gca().yaxis.set_major_formatter(FormatStrFormatter('%.2f'))
    plt.ylim(0, 100) # For better interpretation
    plt.xticks(rotation=45)  
    plt.tight_layout()

    if not os.path.exists(path_to_graphs_dir):
        os.makedirs(path_to_graphs_dir)

    plt.savefig(os.path.join(path_to_graphs_dir, 'cpu_usage_graph.pdf'))


def main():
    path_to_data_dir, path_to_graphs_dir = args_handler()
    df: pd.DataFrame = prepocessing(path_to_data_dir)
    build_graph(df, path_to_graphs_dir)

if __name__ == "__main__":
    main()