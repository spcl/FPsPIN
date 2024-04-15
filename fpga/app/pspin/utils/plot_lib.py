import matplotlib.pyplot as plt
import matplotlib.text as mtext
import matplotlib.colors as colors
from matplotlib.ticker import FuncFormatter, ScalarFormatter
from matplotlib.cm import ScalarMappable
from matplotlib import container, colormaps

pspin_freq = 40e6 # 40 MHz
num_hpus = 16
def cycles_to_us(cycles):
    return 1e6 / pspin_freq * cycles

def set_style():
    params = {
        'font.family': 'Helvetica Neue',
        'font.weight': 'light',
        'font.size': 9,
        'axes.titlesize': 'small',
        'axes.titleweight': 'light',
        'figure.autolayout': True,
    }
    plt.rcParams.update(params)

def figsize(aspect_ratio):
    figwidth=5.125
    return (figwidth, figwidth/aspect_ratio)

# https://stackoverflow.com/a/71540238/5520728
class LegendTitle(object):
    def __init__(self, text_props=None):
        self.text_props = text_props or {}
        super(LegendTitle, self).__init__()

    def legend_artist(self, legend, orig_handle, fontsize, handlebox):
        x0, y0 = handlebox.xdescent, handlebox.ydescent
        title = mtext.Text(x0, y0, orig_handle, **self.text_props)
        handlebox.add_artist(title)
        return title

class TitledLegendBuilder:
    def __init__(self):
        self.legend_dict = {}

    def push(self, title, name, shape):
        self.legend_dict.setdefault(title, {})[name] = shape

    def draw(self, fig):
        graphics, texts = [], []
        first = True

        # plot the empty category first
        if '' in self.legend_dict:
            kv = self.legend_dict['']
            for kk, vv in kv.items():
                graphics.append(vv)
                texts.append(kk)

            graphics.append('')
            texts.append('')

        for k, kv in self.legend_dict.items():
            # skip the empty category
            if k == '':
                continue

            if not first:
                graphics.append('')
                texts.append('')
            else:
                first = False

            graphics.append(k)
            texts.append('')

            for kk, vv in kv.items():
                graphics.append(vv)
                texts.append(kk)

        fig.legend(graphics, texts, handler_map={str: LegendTitle({'weight': 'normal'})}, bbox_to_anchor=(1, .5), loc='center right')


class RegularLegendBuilder:
    def __init__(self):
        self.legend_dict = {}

    def push(self, title, name, shape):
        self.legend_dict[name] = shape

    def draw(self, fig):
        texts, graphics = zip(*self.legend_dict.items())
        fig.legend(graphics, texts, bbox_to_anchor=(1, .5), loc='center right')