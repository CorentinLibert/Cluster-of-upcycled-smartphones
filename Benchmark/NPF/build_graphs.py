import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

path_to_data = ""
path_to_graph = "graphs/"

file_names = ["results_4s", "results_c", "result_alone"]
experiment_names = ["Requests per second for a cluster of 4 smartphones (1 server + 3 agents)\n for different number of replicas.",
                    "Requests per second for a cluster with differents number of nodes and replicas.",
                    "Requests per second for a smartphone alone (without K3S)."]

for j, file in enumerate(file_names):
    df = pd.read_csv(path_to_data+file+'.csv')

    # Create a boxplot using Seaborn
    plt.figure(figsize=(10, 6))
    sns.boxplot(x='n_replicas', y='requests_per_sec', data=df)
    plt.xlabel('Number of Replicas')
    plt.ylabel('Requests per Second')
    plt.title(f'{experiment_names[j]}')

    plt.tight_layout()

    plt.savefig(path_to_graph+file+'.png')
