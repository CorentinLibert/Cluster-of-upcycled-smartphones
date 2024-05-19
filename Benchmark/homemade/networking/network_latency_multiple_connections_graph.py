import os
import sys
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.ticker import FormatStrFormatter
from IPython.display import display

relative_graph_folder = "/graphs"

def args_handler():
    if (len(sys.argv) < 2):
        print(f"Usage: python3 {sys.argv[0]} DATA_PATH MEDIUM_TYPE")
    path_to_data_file = sys.argv[1]
    metdium_type = sys.argv[2]
    return path_to_data_file, metdium_type

def data_to_dataframe(path_to_data_file: str) -> pd.DataFrame:
    data = pd.read_csv(path_to_data_file)
    data['n_devices'] = data['n_devices'] / 2
    return data

def build_graph(df: pd.DataFrame, metdium_type: str, filename: str):
    plt.figure(figsize=(10, 6))
    sns.set_style("whitegrid")
    sns.boxplot(data=df, x='n_devices', y='latency_ms')
    plt.title(f"Latency between two devices connected over {metdium_type}\nfor an increasing number of connected devices.")
    plt.xlabel('Number of simultaneous connections')
    plt.ylabel('Latency (in ms)')
    # plt.legend(title='Device type of sender and receiver')
    plt.gca().yaxis.set_major_formatter(FormatStrFormatter('%.2f'))
    # plt.ylim(0, 100) # For better interpretation
    # plt.xticks(rotation=45)  
    plt.tight_layout()
    
    path_to_graphs_dir = os.path.dirname(__file__) + relative_graph_folder
    if not os.path.exists(path_to_graphs_dir):
        os.makedirs(path_to_graphs_dir)

    filename = filename.split('.')[0] + ".pdf"
    plt.savefig(os.path.join(path_to_graphs_dir, filename))


def main():
    path_to_data_file, metdium_type = args_handler()
    df = data_to_dataframe(path_to_data_file)
    build_graph(df, metdium_type, os.path.basename(path_to_data_file))


if __name__ == "__main__":
    main()