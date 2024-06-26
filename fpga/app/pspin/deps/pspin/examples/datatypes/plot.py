#!/usr/bin/env python3

import csv
import argparse
import re
import numpy as np
import pandas as pd
import scipy.stats as st
import sys
from math import ceil

from os import listdir
from os.path import isfile, join, isdir

from si_prefix import si_format

from plot_lib import *

parser = argparse.ArgumentParser(
    prog='plot.py',
    description='Plot data generated by the datatypes benchmark',
    epilog='Report bugs to Pengcheng Xu <pengxu@ethz.ch>.'
)

parser.add_argument('--data_root', help='root of the CSV files from the datatypes benchmark', default=None)
parser.add_argument('--query', action='store_true', help='query data interactively')

args = parser.parse_args()

def dim_to_gflops(dim, iter, elapsed):
    return 2 * dim ** 3 * iter / elapsed / 1e9
def rtt_to_mbps(sbuf_sz, num_parallel, rtt):
    return sbuf_sz * 8 * num_parallel / rtt / 1e6

slmp_payload_size = 1462 // 4 * 4
elem_size = 110592 # one element
data_pkl = 'data.pkl'

def consume_trials(key, dt_idx, trials):
    # https://stackoverflow.com/a/42837693/5520728
    def append_iperf(par, mbps):
        global data
        entry = pd.DataFrame.from_dict({
            'parallelism': [par],
            'mbps_iperf': [mbps],
        })
        data = pd.concat([data, entry], ignore_index=True)

    def append_mpich(par, sbuf_size, is_vanilla, mbps, dtype_idx):
        global data
        entry = pd.DataFrame.from_dict({
            'key': [key],
            'parallelism': [par],
            'msg_size': [sbuf_size],
            'is_vanilla': [is_vanilla],
            'mbps_mpich': [mbps],
            'datatype': [dtype_idx],
        })
        data = pd.concat([data, entry], ignore_index=True)

    def append_overlap(par, sbuf_size, dtype_idx, mbps_ref, mbps_overlap, gflops_theo, gflops_ref, gflops_overlap, overlap_ratio, poll_time):
        global data
        entry = pd.DataFrame.from_dict({
            'key': [key],
            'parallelism': [par],
            'msg_size': [sbuf_size],
            'datatype': [dtype_idx],
            'mbps_ref': [mbps_ref],
            'mbps_overlap': [mbps_overlap],
            'gflops_theo': [gflops_theo],
            'gflops_ref': [gflops_ref],
            'gflops_overlap': [gflops_overlap],
            'overlap_ratio': [overlap_ratio],
            'poll_time': [poll_time],
        })
        data = pd.concat([data, entry], ignore_index=True)

    if key == 'i':
        # iperf theoretical data
        iperf_dat = [9.22, 10.4, 8.36, 8.49, 7.75, 8.66, 7.63, 8.60, 8.70, 7.89, 7.92, 8.16, 7.87, 8.07, 7.31, 7.78]
        for par, gbps in enumerate(iperf_dat):
            append_iperf(par + 1, gbps * 1000)

        return

    for t in trials:
        base_regex = key + r'-([0-9]+)\.csv'
        baseline = False
        if m := re.match(base_regex, t):
            val = m.group(1)
        elif m := re.match('b' + base_regex, t):
            val = m.group(1)
            baseline = True
            vanilla = False
        elif m := re.match('v' + base_regex, t):
            val = m.group(1)
            baseline = True
            vanilla = True
        else:
            continue
        val = float(val)

        fname = join(args.data_root, dt_idx, t)
        print(f'Consuming {fname}')
        with open(fname, 'r') as f:
            reader = csv.reader(f)
            if baseline:
                # MPICH
                assert next(reader) == ['elements', 'parallel', 'streambuf_size', 'types_idx', 'types_str']
                *params, types_idx, types_str = next(reader)
                elem, par, sbuf_size = map(int, params)

                assert next(reader) == []
                assert next(reader) == ['elapsed']
                for dat in reader:
                    elapsed, = map(float, dat)
                    append_mpich(par, sbuf_size, vanilla, rtt_to_mbps(sbuf_size, par, elapsed), types_idx)

            else:
                try:
                    assert next(reader) == ['gflops_theo', 'gflops_ref', 'dim', 'streambuf_size', 'par', 'types_idx']
                except StopIteration:
                    continue
                *params, types_idx = next(reader)
                tg, rg, dim, sbuf_size, par = map(float, params)
                num_packets = ceil(sbuf_size / slmp_payload_size)

                # append_row(val, dgemm_theo_label, tg)
                # append_row(val, dgemm_ref_label, rg)
                assert next(reader) == []

                assert next(reader) == ['dgemm', 'iters', 'dt_ref_rtt',
                                        'dt_ref_pkt', 'dt_ref_msg', 'dt_rtt', 'dt_pkt', 'dt_msg']
                for data_tuple in reader:
                    # dgemm w/ dt, dt w/o dgemm, dt w/ dgemm
                    # RTT in float seconds
                    dgemm_overlap, dgemm_iter, dt_ref_rtt, dt_ref_pkt, dt_ref_msg, dt_rtt, dt_pkt, dt_msg = map(float, data_tuple)
                    dt_pkt *= num_packets
                    dt_ref_pkt *= num_packets

                    append_overlap(par, sbuf_size, types_idx,
                        rtt_to_mbps(sbuf_size, par, dt_ref_rtt),
                        rtt_to_mbps(sbuf_size, par, dt_rtt),
                        tg, rg,
                        dim_to_gflops(dim, dgemm_iter, dgemm_overlap),
                        dgemm_overlap / dt_rtt,
                        dt_rtt - dgemm_overlap)

if args.data_root:
    datatypes_indices = [d for d in listdir(args.data_root) if isdir(join(args.data_root, d))]

    data = pd.DataFrame(columns=[
        'key',
        'parallelism',
        'msg_size',
        'is_vanilla',
        'datatype',
        'gflops_theo',
        'gflops_ref',
        'gflops_overlap',
        'mbps_iperf',
        'mbps_mpich',
        'mbps_ref',
        'mbps_overlap',
        'overlap_ratio',
        'poll_time'])
    consume_trials('i', None, None)

    for d in datatypes_indices:
        trials = [f for f in listdir(join(args.data_root, d)) if isfile(join(args.data_root, d, f))]
        consume_trials('p', d, trials)
        consume_trials('m', d, trials)

    data.to_pickle(data_pkl)

set_style()

dp: pd.DataFrame = pd.read_pickle(data_pkl)
if args.query:
    import code
    code.InteractiveConsole(locals=globals()).interact()
    sys.exit(0)

color_dict = {}
next_color = 0
def get_color(name):
    global color_dict, next_color
    if name not in color_dict:
        color_dict[name] = f'C{next_color}'
        next_color += 1
    return color_dict[name]

def line_x(x_col, ax, y_col, trial, lbl, lb=None):
    # only use data from the right set
    is_baseline = lbl == 'IPerf3' or lbl == 'GEMM Theo.'
    if not is_baseline:
        trial = trial[trial['key'] == x_col[0]]
    else:
        data = trial[y_col].dropna().mean()

    x = []
    y_median = []
    y_left = []
    y_right = []
    for xx, rows in trial.groupby(x_col):
        x.append(xx)
        vals = rows[y_col].dropna()
        # print(y_col, rows[y_col])
        med = vals.median()
        y_median.append(med)
        if len(vals) > 1:
            bootstrap_ci = st.bootstrap((vals,), np.median, confidence_level=0.95, method='percentile')
            ci_lo, ci_hi = bootstrap_ci.confidence_interval
            y_left.append(med - ci_lo)
            y_right.append(ci_hi - med)
        else:
            y_left.append(0)
            y_right.append(0)

    if is_baseline:
        # print(x, y_median)
        linestyle = '--' if lbl == 'IPerf3' else '-.'
        ax.axhline(data, linestyle=linestyle, color='purple')
    else:
        ax.errorbar(x, y_median, yerr=(y_left, y_right), ecolor='black', color=get_color(cat + lbl))
    
    if lb:
        lb.push(cat, lbl, ax.lines[-1])

# diagram 1: 2 row, 2 cols
#   plot 1: dt tput - degree of parallelism
#   plot 2: dt tput - length of message
# TODO
#   plot 3: gemm tput - degree of parallelism
#   plot 4: gemm tput - length of message, sharey=True)

# title: [(name, [column], {filter_key: filter_val})]
tasks_tput = {
    '': [
        ('IPerf3', ['mbps_iperf'], {}),
        ('GEMM Theo.', ['gflops_theo'], {}),
    ],
    'Baseline MPICH': [
        # ('C. Simple', ['mbps_mpich'], {'is_vanilla': True, 'datatype': '1'}),
        # ('C. Complex', ['mbps_mpich'], {'is_vanilla': True, 'datatype': '0'}),
        ('F. Simple', ['mbps_mpich'], {'is_vanilla': False, 'datatype': '1'}),
        ('F. Complex', ['mbps_mpich'], {'is_vanilla': False, 'datatype': '0'}),
    ],
    'Datatypes/GEMM': [
        ('Ref. Simple', ['mbps_ref', 'gflops_ref'], {'datatype': '1'}),
        ('Ref. Complex', ['mbps_ref', 'gflops_ref'], {'datatype': '0'}),
        ('Ovlp. Simple', ['mbps_overlap', 'gflops_overlap'], {'datatype': '1'}),
        ('Ovlp. Complex', ['mbps_overlap', 'gflops_overlap'], {'datatype': '0'}),
    ],
}

fig, axes = plt.subplots(2, 2, figsize=figsize(1.5))
lb = TitledLegendBuilder()

for i in range(2):
    for j in range(2):
        ax = axes[j][i]
        ax.sharex(axes[0][i])
        ax.sharey(axes[j][0])

        ylabel = 'Throughput (Mbps)' if j == 0 else 'GFLOPS'
        xlabel = 'Degree of Parallelism' if i == 0 else 'Message Length (B)'

        ax.grid(which='both')
        ax.set_ylabel(ylabel)
        if j == 0:
            ax.set_yscale('log')
        if i == 1:
            x_formatter = FuncFormatter(lambda x, pos: si_format(x, precision=0))
            ax.xaxis.set_major_formatter(x_formatter)
        ax.set_xlabel(xlabel)
        ax.label_outer()

for cat, lines in tasks_tput.items():
    # print(cat, lines)
    for lbl, cols, filter_kv in lines:
        trial = dp

        for k, v in filter_kv.items():
            trial = trial[trial[k] == v]
                
        for col in cols:
            row_id = 0 if 'mbps' in col else 1

            for i in range(2):
                ax = axes[row_id][i]
                x_col = 'parallelism' if i == 0 else 'msg_size'
                line_x(x_col, ax, col, trial, lbl, lb=lb)
    
lb.draw(fig)
fig.tight_layout(rect=[0, 0, .75, 1])
fig.savefig('datatypes-tput.pdf')

# diagram 2: 1 row, 2 cols
#   plot 1: overlap ratio - length of message
#   plot 2: overlap ratio - length of message

fig, axes = plt.subplots(1, 2, figsize=figsize(2.3))

color_dict = {}
next_color = 0

lb = RegularLegendBuilder()

for i in range(2):
    ax = axes[i]
    ax.sharey(axes[0])

    if i == 1:
        x_formatter = FuncFormatter(lambda x, pos: si_format(x, precision=0))
        ax.xaxis.set_major_formatter(x_formatter)

    y_formatter = FuncFormatter(lambda y, pos: f'{int(y * 100)}%')
    ax.yaxis.set_major_formatter(y_formatter)

    xlabel = 'Degree of Parallelism' if i == 0 else 'Message Length (B)'
    ylabel = 'Overlap Ratio'

    ax.grid(which='both')
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.label_outer()

for idx, dt in enumerate(['Complex', 'Simple']):
    trial = dp[dp['datatype'] == str(idx)]

    for i in range(2):
        ax = axes[i]

        y_col = 'overlap_ratio'
        x_col = 'parallelism' if i == 0 else 'msg_size'

        line_x(x_col, ax, y_col, trial, dt, lb=lb)

lb.draw(fig)
fig.tight_layout(rect=[0, 0, .82, 1])
fig.savefig('datatypes-overlap.pdf')