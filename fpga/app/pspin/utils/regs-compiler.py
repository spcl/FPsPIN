#!/usr/bin/env python3

from jinja2 import Environment, FileSystemLoader
from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter
from os.path import join, realpath, dirname, isdir
from math import ceil
from datetime import datetime
from collections import deque
import sys

GRPID_SHIFT = 12

parser = ArgumentParser(description='Compile templates for the PsPIN registers.', formatter_class=ArgumentDefaultsHelpFormatter)
parser.add_argument('name', type=str, help='name of the template to compile')
parser.add_argument('output', type=str, help='output file path')
parser.add_argument('--base-addr', type=int, help='register base address', default=0)
parser.add_argument('--word-size', type=int, help='size of native word', default=4)
parser.add_argument('--all', action='store_true', help='generate all with name as extension')

args = parser.parse_args()
word_width = args.word_size * 8

class RegSubGroup:
    next_alloc = 0

    def __init__(self, name, readonly, count, signal_width=args.word_size*8, reset=0, expand_id=None):
        self.name = name
        self.readonly = readonly
        self.count = count
        # only used when also generating Verilog ports
        # if > word_size, registers would be split
        # width is for a single register
        self.signal_width = signal_width
        self.reset = reset

        if signal_width:
            self.num_words = int(ceil(self.signal_width / word_width))
        else:
            self.num_words = 1

        if not expand_id:
            self.glb_idx = RegSubGroup.next_alloc
            RegSubGroup.next_alloc += self.count * self.num_words
        else:
            parent_id, rank = expand_id
            self.glb_idx = parent_id + rank * self.count

        # not populated yet
        self.base = None
        self.parent = None

        self.expanded = None

        # aux data for templates
        self.aux = None

    def set_aux(self, data):
        self.aux = data
        return ''

    def clone_single(self):
        return RegSubGroup(self.name, self.readonly, 1, self.signal_width)
    
    def get_base_addr(self):
        global args
        if self.base >= (1 << GRPID_SHIFT):
            raise ValueError(f'base address {self.base:#x} exceeded regid field (12 bits)')
        return args.base_addr + (self.parent.grpid << GRPID_SHIFT) + self.base

    def get_signal_name(self):
        return f'{self.parent.name}_{self.name}'.upper()

    def expand(self):
        if not self.is_extended():
            ret = [self]
        else:
            self.expanded = []
            for idx in range(self.num_words):
                self.expanded.append(RegSubGroup(
                    f'{self.name}_{idx}',
                    self.readonly,
                    self.count,
                    signal_width=None, # we only use signal width from unexpanded subgroups
                    expand_id=(self.glb_idx, idx),
                ))
            ret = self.expanded
        return ret

    def __repr__(self):
        if self.base is not None and self.signal_width:
            # normal register
            ret = f'<SubGroup "{self.name}" {self.readonly} x{self.count} @{self.base:#x} (width {self.signal_width})>'
        elif self.base and not self.signal_width:
            # expanded child
            ret = f'\t<ExpSubGroup "{self.name}" @{self.base:#x}>\n'
        else:
            # expanded parent
            ret = f'<SubGroup "{self.name}" {self.readonly} x{self.count} (width {self.signal_width})\n{self.expanded}>'
        return ret

    def is_extended(self):
        return self.num_words > 1

class RegGroup:
    next_alloc = 0

    def __init__(self, name, subgroups):
        global args

        self.name = name

        # used to generate signals
        self.subgroups = subgroups

        self.grpid = RegGroup.next_alloc
        RegGroup.next_alloc += 1

        # expand to concrete subgroups
        self.expanded = sum(map(lambda sg: sg.expand(), self.subgroups), start=[])
        self.dict = {sg.name: sg for sg in self.expanded}

        # store parent reference for address calculation
        cur_base = 0
        for sg in self.expanded:
            sg.parent = self
            sg.base = cur_base
            cur_base += sg.count * args.word_size

    def set_aux(self, data):
        for sg in self.expanded:
            sg.set_aux(data)
        return ''

    def reg_count(self):
        return sum(map(lambda sg: sg.count, self.expanded))

    def __repr__(self):
        return '\n[' + ', \n'.join(map(str, self.subgroups)) + ']'
    
params = {
    'UMATCH_WIDTH': 32,
    'UMATCH_ENTRIES': 4,
    'UMATCH_RULESETS': 4,
    'UMATCH_MODES': 2,
    'HER_NUM_HANDLER_CTX': 4,
}

# TODO: document each register
groups = [
    RegGroup('cl', [
        RegSubGroup('ctrl',     False, 2),
        RegSubGroup('fifo',     True,  1),
    ]),
    RegGroup('stats', [
        RegSubGroup('cluster',  True,  2),
        RegSubGroup('mpq',      True,  1),
        RegSubGroup('datapath', True,  2),
    ]),
    RegGroup('me', [
        RegSubGroup('valid',    False, 1, 1),
        # reset: mode=0 idx=0 mask=0 start=1 end=0 ==> bypass
        RegSubGroup('mode',     False, params['UMATCH_RULESETS'], (params['UMATCH_MODES']-1).bit_length()),
        RegSubGroup('idx',      False, params['UMATCH_RULESETS'] * params['UMATCH_ENTRIES'], params['UMATCH_WIDTH']),
        RegSubGroup('mask',     False, params['UMATCH_RULESETS'] * params['UMATCH_ENTRIES'], params['UMATCH_WIDTH']),
        RegSubGroup('start',    False, params['UMATCH_RULESETS'] * params['UMATCH_ENTRIES'], params['UMATCH_WIDTH'], reset=1),
        RegSubGroup('end',      False, params['UMATCH_RULESETS'] * params['UMATCH_ENTRIES'], params['UMATCH_WIDTH']),
    ]),
    RegGroup('her', [
        RegSubGroup('valid',              False, 1, 1),
        RegSubGroup('ctx_enabled',        False, params['HER_NUM_HANDLER_CTX'], 1),
    ]),
    RegGroup('her_meta', [
        RegSubGroup('handler_mem_addr',   False, params['HER_NUM_HANDLER_CTX']),
        RegSubGroup('handler_mem_size',   False, params['HER_NUM_HANDLER_CTX']),
        RegSubGroup('host_mem_addr',      False, params['HER_NUM_HANDLER_CTX'], 64),
        RegSubGroup('host_mem_size',      False, params['HER_NUM_HANDLER_CTX']),
        RegSubGroup('hh_addr',            False, params['HER_NUM_HANDLER_CTX']),
        RegSubGroup('hh_size',            False, params['HER_NUM_HANDLER_CTX']),
        RegSubGroup('ph_addr',            False, params['HER_NUM_HANDLER_CTX']),
        RegSubGroup('ph_size',            False, params['HER_NUM_HANDLER_CTX']),
        RegSubGroup('th_addr',            False, params['HER_NUM_HANDLER_CTX']),
        RegSubGroup('th_size',            False, params['HER_NUM_HANDLER_CTX']),
        RegSubGroup('scratchpad_0_addr',  False, params['HER_NUM_HANDLER_CTX']),
        RegSubGroup('scratchpad_0_size',  False, params['HER_NUM_HANDLER_CTX']),
        RegSubGroup('scratchpad_1_addr',  False, params['HER_NUM_HANDLER_CTX']),
        RegSubGroup('scratchpad_1_size',  False, params['HER_NUM_HANDLER_CTX']),
        RegSubGroup('scratchpad_2_addr',  False, params['HER_NUM_HANDLER_CTX']),
        RegSubGroup('scratchpad_2_size',  False, params['HER_NUM_HANDLER_CTX']),
        RegSubGroup('scratchpad_3_addr',  False, params['HER_NUM_HANDLER_CTX']),
        RegSubGroup('scratchpad_3_size',  False, params['HER_NUM_HANDLER_CTX']),
    ]),
]
    
# construct dict for template use
groups = {rg.name: rg for rg in groups}

templates_dir = join(dirname(realpath(__file__)), 'templates/')
print(f'Search path for templates: {templates_dir}', file=sys.stderr)
environment = Environment(loader=FileSystemLoader(templates_dir))
template_args = {
    'groups': groups,
    'num_regs': sum(map(lambda rg: rg.reg_count(), groups.values())),
    'params': params,
    'args': args,
    'RegGroup': RegGroup,
}

def gen_single(name):
    template = environment.get_template(name)
    content = template.render(template_args)

    if name.endswith(('.c', '.v', '.h')):
        comment_f = lambda c: f'/* {c} */\n'
    else:
        comment_f = lambda c: f'# {c}\n'

    content = comment_f(f'Generated on {datetime.now()} with: {" ".join(sys.argv)}') + '\n' + content

    if args.output == '-':
        filename = 'stdout'
        print(content)
    else:
        if isdir(args.output):
            filename = join(args.output, name)
        else:
            filename = args.output
        with open(filename, mode='w', encoding='utf-8') as f:
            f.write(content)

    print(f'Written output to {filename}', file=sys.stderr)

if args.all:
    if not isdir(args.output):
        print('Output can only be a dir with --all', file=sys.stderr)
        sys.exit(1)
    deque(map(gen_single, environment.list_templates(args.name)), maxlen=0)
else:
    gen_single(args.name)