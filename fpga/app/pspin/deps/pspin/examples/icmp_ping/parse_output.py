#!/usr/bin/env python3

import csv
import argparse
import re
import pandas as pd
import sys
from math import ceil
from itertools import chain
from os import listdir
from os.path import isfile, join

import matplotlib.pyplot as plt
import matplotlib.text as mtext
import seaborn as sns

parser = argparse.ArgumentParser(
    prog='plot.py',
    description='Plot data generated by the pingpong benchmark',
    epilog='Report bugs to Pengcheng Xu <pengxu@ethz.ch>.'
)

parser.add_argument('--data_root', help='root of the CSV files from the datatypes benchmark', default="data")

args = parser.parse_args()

icmp_baseline_label = 'ICMP Host'
icmp_pspin_label = 'ICMP FPsPIN'
icmp_combined_label = 'ICMP Host+FPsPIN'

udp_baseline_label = 'UDP Host'
udp_pspin_label = 'UDP FPsPIN'
udp_combined_label = 'UDP Host+FPsPIN'

expect_count = 1000  #we do a 1000 runs for stability testing, but use only the last 20 measurements for plots

def consume_trials(key, trials):
    prot, trial = key.split(' ')

    for l in trials:
        real_handler, host_dma, all_cycles = 0, 0, 0

        if 'FPsPIN' in trial:
            do_host = 'true' if 'Host' in trial else 'false'
            txt_name = do_host

            with open(join(args.data_root, prot.lower(), f'{do_host}-{l}.csv'), 'r') as f:
                reader = csv.reader(f)
                assert next(reader) == ['handler', 'host_dma', 'cycles']
                icmp_handler, icmp_host_dma, cycles = [float(x) for x in next(reader)]

            real_handler = icmp_handler - cycles
            if do_host == 'true':
                real_handler -= icmp_host_dma + cycles
                host_dma = icmp_host_dma - cycles
                all_cycles = cycles * 5
            else:
                all_cycles = cycles * 3
        else:
            txt_name = 'baseline'

        with open(join(args.data_root, prot.lower(), f'{txt_name}-{l}-ping.txt'), 'r') as f:
            lines = filter(
                lambda l: l.find('time=') != -1 and l.find('timeout') == -1,
                f.readlines())
            if prot == 'ICMP':
                idx = 6
            elif prot == 'UDP': # dgping
                idx = 5
        values = [float(l.split(' ')[idx].split('=')[1]) * 1000 for l in lines]

        for v in values[0:50]: #only use first 50 measurement
          print(str(key) + " " + str(l) + "  " + str(v))



if args.data_root:
    trials = range(16, 1516, 100)
    consume_trials(icmp_baseline_label, trials)
    consume_trials(icmp_combined_label, trials)
    consume_trials(icmp_pspin_label, trials)

    consume_trials(udp_baseline_label, trials)
    consume_trials(udp_combined_label, trials)
    consume_trials(udp_pspin_label, trials)