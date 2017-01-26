#!/usr/bin/env python

import os, sys, argparse, errno
import numpy as np
import matplotlib.pyplot as plt

###
### main
###

def main():
    opts = get_options()

    if len(opts.files) <= 0:
        print("usage: stats_plot [-n title] [-d plots_dir] [-t timeout] stats_file ...")
        quit(1)

    tools = []
    results = {}
    for file in opts.files:
        collect_stats(file, tools, results)

    if opts.d is not None:
        mkdir_p(opts.d)

    plot_bars(opts.d, opts.n, tools, results, opts.t)
    
###
### help functions
###

def get_options():
    """parses and returns input options"""
    parser = argparse.ArgumentParser(description="stats_plot")
    parser.add_argument("-n", type=str, help="plot name", default="default")
    parser.add_argument("-d", type=str, help="plots directory", default=None)
    parser.add_argument("-t", type=int, help="timeout", default=600)
    parser.add_argument("files", type=str, nargs=argparse.REMAINDER)
    return parser.parse_args()

def collect_stats(file, tools, results):
    """parses statistics summary file generated by wcet_omt, saving
    the interesting values in 'tools' and 'results'"""
    try:
        with open(file, 'r') as fd:
            file = os.path.realpath(file)
            tool, ext = os.path.splitext(os.path.basename(file))
            if tool not in tools:
                tools.append(tool)

            idx = 0
            for line in fd:
                if idx != 0:
                    # parse line
                    max_path, opt_value, gain, num_cuts, \
                    real_time, status, timeout, errors, \
                    llvm_size, num_blocks, smt2_file, \
                    out_file = ''.join(line.split()).split("|")

                    bench, ext = os.path.splitext(os.path.basename(out_file))

                    if bench not in results.keys():
                        results[bench] = {}

                    results[bench][tool] = real_time

                idx += 1

    except Exception as e:
        print("error: file `" + file + "` does not exist or cannot be read, quitting.\n")
        quit(1)

def plot_bars(plots_dir, title, tools, benchmarks, timeout):
    """ plots given benchmark data """
    fig, ax = plt.subplots()

    # config

    axis_font = {'fontname' : 'Arial', 'size':'21', 'weight':'bold'}
    colors    = ('b', 'g', 'r', 'c', 'm', 'y', 'k', 'w')
    width     = 0.30
    num_bench = len(benchmarks.keys())
    l_space   = 0.10

    # plot data

    x_labels = benchmarks.keys()
    x_bars   = []
    x_vals   = []
    position = np.arange(num_bench) + l_space
    idx = 0
    for tool in tools:
        x_vals = map(lambda bench: benchmarks[bench][tool] if tool in benchmarks[bench].keys() else -10, benchmarks.keys())
        bar = ax.bar(position + width * idx, x_vals, width, color=colors[idx])
        x_bars.append(bar)
        idx += 1

    # axis config

    ax.grid(True)
    ax.set_title(title)

    ax.set_ylabel('time (s.)')
    ax.set_yscale('log', nonposy='clip')

    ax.set_xticks(position + (width * idx) / 2)
    ax.set_xticklabels(x_labels)

    # legend

    x_bars_0s = map(lambda x: x[0], x_bars)
    ax.legend(x_bars_0s, tools)

    for bar in x_bars:
        autolabel(ax, bar, timeout)

    # timeout
    plt.axhline(y=timeout, color='r', zorder=3, linestyle='dashed')

    # save, show
    if plots_dir is not None:
        file_name = "%s/%s.png" % (plots_dir, title)
        plt.savefig(file_name, bbox_inches=0)

    plt.show()
    plt.close(fig)

def autolabel(ax, rects, timeout):
    """prints numeric value on top of each rect, '-/-' is used for missing data points"""
    for rect in rects:
        height = rect.get_height()
        y = rect.get_y()
        if y >= 0:
            ax.text(rect.get_x() + rect.get_width()/2., 1.05*height,
                '%d' % int(height),
                ha='center', va='bottom')
        else:
            height = timeout
            ax.text(rect.get_x() + rect.get_width()/2., 1.05*height,
                '-/-',
                ha='center', va='bottom')

def mkdir_p(path):
    """make a directory and any missing ancestor if needed"""
    try:
        os.makedirs(path)
    except OSError as exc:  # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else:
            raise

###
###
###

if (__name__ == "__main__"):
    main()

###
###
###

# NOTE:
#   for debug reference, the following is an example of the
#   expected content of variables 'results' and 'tools' in this script
#
# results = {
#     'b1' : {
#         'z3' : 1200,
#         'optimathsat' : 100,
#         'smtopt' : 100,
#     },
#     'b2' : {
#        'z3' : 1200,
#         'smtopt' : 200,
#     },
#     'b3' : {
#         'z3' : 50,
#         'optimathsat' : 100,
#     },
# }
# 
# tools = ('z3', 'optimathsat', 'smtopt')
