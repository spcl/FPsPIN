import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt


sns.set_style("whitegrid")
data = pd.read_csv("timo_pp_data.dat", header=None, sep="\s+")
data = data.rename(columns={0: "Protocol", 1: "Mode", 2: "Size", 3: "Time"})
g = sns.FacetGrid(data=data, col="Protocol")
g.map_dataframe(sns.lineplot, x="Size", y="Time", errorbar="ci", estimator="median", err_style="bars", hue="Mode")
g.set_titles(col_template="{col_name} Ping-Pong", row_template="{row_name}")
#g.add_legend()
g.tight_layout()
g.set_axis_labels("Packet Size [B]", "RTT [us]")
plt.legend(loc='upper right', bbox_to_anchor=(0.45, 0.9))
plt.savefig("timo_ping_pong_plot.pdf", format='pdf')
plt.show()

