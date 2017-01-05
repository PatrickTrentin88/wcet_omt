import argparse
from smt2_env import *
from graph import *

###
###
###

def main():
    """Enriches the input SMT2 formula with the encoding of the cost
    function associated to the input source code graph, optionally
    adding cuts of various types to significantly reduce the search
    time taken by an SMT solver."""
    opts = get_cmdline_options();

    # load file containing smt2 formula + source code blocks generated by pagai
    try:
        with open(opts.filename, 'r') as fd:
            smt_txt, graph_txt = fd.read().rsplit('-------', 1)
    except Exception:
        print(";; ERROR: file `" + opts.filename + "` does not exist or can not be read, quitting.\n")
        quit()

    # preload initial environment and graph
    env = preload_smt_env(smt_txt)
    graph = preload_graph(graph_txt)

    # Update costs with Matching File, if available
    if (opts.matchingfile):
        try:
            with open(opts.matchingfile, 'r') as fd:
                matchings = fd.read()
                graph.update_costs_with_matchings(matchings)
        except Exception:
            print(";; ERROR: matching file does not exist, ignored.")
            quit()

    # Compute and add cuts
    if not opts.nosummaries:
        graph.add_dominator_cuts()
        graph.add_semantic_cuts(opts.cutsfile, opts.recursivecuts)
        graph.compute_longest_syntactic_path(not opts.nosummaries)

    # Dump Relevant Information into files, if needed
    if opts.smtmatching:
        graph.dump_label2vars(opts.smtmatching)
    if opts.printlongestsyntactic:
        graph.dump_longest_syntactic_path(opts.printlongestsyntactic)
    if opts.printcutslist:
        graph.dump_cuts_list(opts.printcutslist)

    # Dump Graph over Environment
    graph.add_graph_to_env(env, opts.encoding)

    if opts.timeout:
        env.set_option("timeout", str(opts.timeout) + ".0")

    # Dump SMT2 Formula
    env.dump()


###
### Help Functions
###

def get_cmdline_options():
    """parses and returns input parameters"""
    parser = argparse.ArgumentParser(description='wcet_generator')
    parser.add_argument("filename", type=str, help="the file name")
    parser.add_argument("--nosummaries", help="do not add extra information to the SMT formula", action="store_true")
    parser.add_argument("--recursivecuts", help="add automatic recursive cuts", action="store_true")
    parser.add_argument("--matchingfile", type=str, help="name of the matching file")
    parser.add_argument("--smtmatching", type=str, help="name of the file matching labels to booleans")
    parser.add_argument("--cutsfile", type=str, help="name of the cuts file")
    parser.add_argument("--printlongestsyntactic", type=str, help="name of the file storing the longest syntactic path")
    parser.add_argument("--printcutslist", type=str, help="name of the file that lists the different cuts, in order of difficulty")
    parser.add_argument("--encoding", type=int, help="0: default, 1: assert-soft, 2: difference logic")
    parser.add_argument("--timeout", type=int, help="Timeout value (seconds)")
    return parser.parse_args()

def preload_smt_env(smt_formula):
    """parses input smt2 formula, storing it into an SMT2 environment object,
    returned to the caller.

    The current implementation relies on the particular format adopted by pagai,
    that is: DECLS, (ASSERT (AND ...)), in particular no option and command should
    appear and only one assert is allowed. """
    # NOTE: anything more sophisticated, at the time being, would be a waste of time
    env = Environment()
    decls, f = smt_formula.split('(assert')
    for d in decls.strip().split('\n'):
        if d[0:2] == '//':
            continue # ignore comments
        elif 'declare-fun' in d:
            env.add_declaration(d)
        else:
            raise Exception("Unsupported declaration: " + d)
    # NOTE: I won't waste time trying to format better the bloat of SMT2 code
    # I receive as input, even though it's ugly and hard to follow due to poor
    # inlining
    f = "(assert " + f
    f = '\n'.join([l for l in f.split('\n') if l.strip() != '']) # remove ugly empty space
    env.assert_formula(f)
    return env

def preload_graph(graph_txt):
    """parses input source code graph generated with pagai, storing into a
    SourceCodeGraph instance, returned to the caller."""
    graph = SourceCodeGraph()
    graph.parse_graph(graph_txt)
    return graph

###
###
###

if (__name__ == "__main__"):
	main()