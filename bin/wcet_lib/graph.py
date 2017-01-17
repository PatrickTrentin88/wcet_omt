import copy
from smt2_env import *
from graph_elements import *

###
### SourceCodeGraph
###

class SourceCodeGraph:
    """class SourceCodeGraph, stores the source code graph generated from a *loop-free*
    piece of code."""

    def __init__(self):
        self.reset()

    def reset(self):
        self._var2label = {}    # mapping from bvars to labels [nodes]
        self._label2var = {}    # mapping from labels to bvars [nodes]
        self._label2uid = {}    # mapping from labels to uids  [nodes]
        self._nodes = {}        # map of nodes in the graph
        self._edges = {}        # map of edges in the graph
        self._start_var = None  # bvar of graph's start node
        self._end_var = None    # bvar of traph's end node
        self._start_uid = -1    # uid of graph's start node
        self._end_uid = -1      # uid of graph's end node
        self._cuts = {}         # map of cuts augmenting the graph
        return

    def get_node(self, uid):
        return self._nodes[uid]

    def get_edge(self, uid):
        return self._edges[uid]

    def parse_graph(self, graph_str):
        """parses a piece of string representing a source code graph (toolchain generated)
        into an instance of SourceCodeGraph"""
        blocks = graph_str.strip().split('BasicBlock ')
        
        # 1st iteration: collect block labels and node's bvars
        for block in blocks:
            if len(block) == 0: # skip empty lines
                continue

            block_var, instructions = block.split(':', 1)

            if instructions.find('<label>:') != -1:
                #raise Exception("Not supported") # NOTE: legacy error, need to check when it happens though
                label = instructions.split('<label>:')[1].split(' ')[0]
            else:
                label = instructions.split('\n', 1)[1].split(':')[0]

            if "bd_" in block_var: # only bd_ blocks can be start/end nodes
                                   # 'b' stands for block, 'd' for dominant
                if self._start_var is not None:
                    self._end_var = block_var
                else:
                    self._start_var = block_var

            self._label2var[label] = block_var
            self._var2label[block_var] = label

        # 2nd iteration: collect nodes and edges
        for block in blocks:
            if len(block) == 0: # skip empty lines
                continue

            # collect node
            block_var, instructions = block.split(':', 1)
            block_label = self._var2label[block_var]
            block_cost = int(instructions.split(' ')[1])
            block_dominator = instructions.split('Dominator = ', 1)[1].split('\n', 1)[0]
            if block_dominator == 'NULL':
                block_dominator = "-1"
            else:
                block_dominator = block_dominator.split('_')[1]

            if block_var == self._start_var:
                block_var = block_var.replace("bd_", "bs_")
            # NOTE: should be equivalent to previous branch [?assumptions?]
            if block_var == "bd_0":
                block_var = "bs_0"
            # NOTE: rationale unknown [?assumptions?]
            if block_var == "bd_1":
                block_var = "bs_1"

            b = Node(block_var, block_label, block_cost, block_dominator, self)

            self._nodes[b.get_uid()] = b
            self._label2uid[block_label] = b.get_uid()

            # collect edges
            if instructions.find('br ') != -1:
                for succ in instructions.split('br ')[1].strip().split('label'):
                    succ = succ.strip()
                    if len(succ) >= 2 and succ[0] == '%':
                        dst_label = succ[1:] if succ[-1] != ',' else succ[1:-1]
                        dst_var = self._label2var[dst_label]
                        e = Edge(block_var, dst_var, 0, self)
                        self._edges[e.get_uid()] = e

        # update start/end uids
        self._start_uid = self._label2uid[self._var2label[self._start_var]]
        self._end_uid = self._label2uid[self._var2label[self._end_var]]

        # update nodes with ingoing/outgoing edges
        for edge_uid in self._edges.keys():
            edge = self._edges[edge_uid]
            src_block_uid = edge.get_src_uid()
            dst_block_uid = edge.get_dst_uid()
            self._nodes[src_block_uid].add_successor(dst_block_uid)
            self._nodes[dst_block_uid].add_predecessor(src_block_uid)
        return

    def update_costs_with_matchings(self, matchings):
        """updates cost of nodes and edges in the graph with the values specified
        in the input matching string (toolchain generated)."""
        lines = matchings.split('\n')
        updated_node_uids = []
        for line in lines:
            if len(line) <= 0:
                continue
            for offending_symbol in "()\n% ": # ignore pychecker: iteration over string is intended
               line = line.replace(offending_symbol, "")
            src_label, dst_label, cost = line.split(',')
            if dst_label == "":
                src_uid = self._label2uid[src_label]
                self._nodes[src_uid].set_cost(cost)
                updated_node_uids.append(src_uid)
            else:
                src_uid = self._label2uid[src_label]
                dst_uid = self._label2uid[dst_label]
                edge_id = str(src_uid) + "_" + str(dst_uid)
                self._edges[edge_id].set_cost(cost)
        # NOTE: rationale unknown
        for node_uid in self._nodes.keys():
            if node_uid not in updated_node_uids:
                self._nodes[node_uid].set_cost(0)
        return

    def dump_graph(self):
        """prints the graph on stdout"""
        # TODO
        return

    def add_graph_to_env(self, env, encoding):
        """encodes the graph as a piece of SMT2 formula, and adds it to the input `env`"""

        cost = None

        if (ENC_DIFFERENCE_LOGIC == encoding):
            cost = self._add_graph_to_env_with_difference_logic(env, encoding)
        elif (ENC_ASSERT_SOFT == encoding):
            cost = self._add_graph_to_env_with_assert_soft(env, encoding)
        else:
            cost = self._add_graph_to_env_default(env, encoding)

        # add cuts
        uids = self._cuts.keys()
        uids.sort()
        for cut_uid in uids:
            cut = self._cuts[cut_uid]
            cut.add_cut_to_env(env, encoding)

        # extra assertion
        f = make_and([self._nodes[self._start_uid].get_bvar(),
                      self._nodes[self._end_uid].get_bvar()])
        env.assert_formula(f)

        longest_path, max_path_cvars, node_cvars, edge_cvars = self.compute_longest_syntactic_path(False)
        f = make_and([make_leq(0, cost), make_leq(cost, longest_path)])
        env.assert_formula(f)
        env.maximize(cost, 0, longest_path)

        # add comments
        no_paths = self._compute_paths_among(self._start_uid, self._end_uid)
        env.add_comment("ENCODING = " + str(encoding))
        env.add_comment("NB_PATHS = " + str(no_paths))
        env.add_comment("NB_PATHS_DIGITS = " + str(len(str(no_paths))))
        env.add_comment("NB_CUTS = " + str(len(self._cuts.keys()))) # includes cut from start to end node
        env.add_comment("LONGEST_PATH = " + str(longest_path))

        return

    def _add_graph_to_env_default(self, env, encoding):
        """uses the original encoding used in LCTES14: cost = SUM cost(node_i) + SUM cost(edge_i)"""
        csum = []
        cost = env.declare_fun("cost", Environment.INT)

        # add nodes
        uids = self._nodes.keys()
        uids.sort()
        for node_uid in uids:
            node = self._nodes[node_uid]
            if (node.get_cost() != 0):
                csum.append(node.get_cost_var())
            node.add_node_to_env(env, encoding)

        # add edges
        uids = self._edges.keys()
        uids.sort()
        for edge_uid in uids:
            edge = self._edges[edge_uid]
            if (edge.get_cost() != 0):
                csum.append(edge.get_cost_var())
            edge.add_edge_to_env(env, encoding)

        # add objective function
        f = make_equal(cost, make_plus(csum))
        env.assert_formula(f)

        return cost

    def _add_graph_to_env_with_assert_soft(self, env, encoding):
        """replaces Pseudo-Boolean sums with assert-soft based encoding.
        NOTE: the encoding is incompatible with z3."""
        cost = env.declare_fun("cost", Environment.REAL)

        opts = {
            "id" : cost
        }

        # add nodes
        uids = self._nodes.keys()
        uids.sort()
        for node_uid in uids:
            node = self._nodes[node_uid]
            if (node.get_cost() != 0):
                node.add_node_to_env(env, encoding, opts)

        # add edges
        uids = self._edges.keys()
        uids.sort()
        for edge_uid in uids:
            edge = self._edges[edge_uid]
            if (edge.get_cost() != 0):
                edge.add_edge_to_env(env, encoding, opts)

        return cost

    def _add_graph_to_env_with_difference_logic(self, env, encoding):
        """applies a Difference Logic based encoding to the graph."""
        opts = {
            "mutex_edges" : False,
            "edge_implies_nodes" : False,
        }

        # add nodes
        uids = self._nodes.keys()
        uids.sort()
        for node_uid in uids:
            node = self._nodes[node_uid]
            # difference logic edges need to be present even when cost is 0
            node.add_node_to_env(env, encoding, opts)

        # add edges
        uids = self._edges.keys()
        uids.sort()
        for edge_uid in uids:
            edge = self._edges[edge_uid]
            edge.add_edge_to_env(env, encoding, opts)

        return self._nodes[self._end_uid].get_cost_var()

    def _load_semantic_cuts_from_file(self, file):
        """parses file containing a list of pre-computed semantic cuts for the graph,
        and returns a list of these cuts"""
        semantic_cuts = []
        with open(file, 'r') as fd:
            semantic_cuts = [{
                "head_uids" : [],
                "tail_uids" : [],
            }]
            for line in fd:
                if "#" in line:
                    semantic_cuts.append({
                        "head_uids" : [],
                        "tail_uids" : [],
                    })
                else:
                    for offending_symbol in "% \n": # ignore pychecker: iteration over string is intended
                       line = line.replace(offending_symbol, "")
                    head_label, tail_label = line.split(',')
                    head_uid = self._label2uid[head_label]
                    tail_uid = self._label2uid[tail_label]
                    semantic_cuts[-1]["head_uids"].append(head_uid)
                    semantic_cuts[-1]["tail_uids"].append(tail_uid)
        return semantic_cuts        

    def _compute_semantic_cuts(self):
        """retuns a list of candidate semantic cuts computed on-the-fly over the graph"""
        # back-ward collect dominators as candidate merging points
        merging_points = [self._end_uid]
        cur_uid = self._end_uid
        while cur_uid != self._start_uid:
            cur_node = self._nodes[cur_uid]
            dominator_uid = cur_node.get_dominator()
            merging_points.append(dominator_uid)
            cur_uid = dominator_uid
        # create additional candidate couples
        semantic_cuts = []
        mp_len = len(merging_points)
        step = 2
        while step < mp_len:
            k = 0
            done = False
            while not done:
                tail_uid = merging_points[k]
                if k + step < mp_len:
                    head_uid = merging_points[k + step]
                else:
                    head_uid = merging_points[mp_len - 1]
                    done = True
                if head_uid != tail_uid:
                    semantic_cuts.append({
                        "head_uids" : [head_uid],
                        "tail_uids" : [tail_uid],
                    })
                k += step
            step *= 2
        return semantic_cuts

    def _get_semantic_cuts(self, cuts_file, compute_recursive_cuts):
        """returns a list of semantic cuts, including both those taken from
        file and those computed on-the-fly.""" 
        sc1 = []
        sc2 = []
        if cuts_file is not None:
            sc1 = self._load_semantic_cuts_from_file(cuts_file)
        if compute_recursive_cuts:
            sc2 = self._compute_semantic_cuts()
        return sc1 + sc2

    def _compute_longest_path_cut(self, src_uid, dst_uid):
        """returns the maximal cost of a path connecting src_uid to dst_uid,
        the list of node uids appearing over the path of maximal syntactic cost,
        and the list of uids of nodes/edges appearing anywhere in the sub-graph
        starting from `src_uid` and ending to `dst_uid`.

        The function assumes that the graph contains no loop, and that src_uid is
        an actual dominator of dst_uid. If these assumptions are unattended, the
        result is undefined.
        """
        # NOTE: at the time being the reason why it was chosen to include edges
        #   that belong to any path to the returned list, is unclear to me.
        to_visit_uids = [dst_uid]
        node_costs = {}
        node_succs = {}
        subgraph_edge_uids = []
        subgraph_node_uids = [src_uid]
        dsp = 0

        # NOTE: the generated block graph might contain dead ends, thus
        # visited_uids must be pre-computed
        visited_uids = copy.deepcopy(self._nodes.keys())
        lvisited_uids = []
        while len(to_visit_uids) > 0:
            cur_uid = to_visit_uids[0]
            cur_node = self._nodes[cur_uid]

            if cur_uid in visited_uids:
                visited_uids.remove(cur_uid)

            for pred_uid in cur_node.get_predecessors():
                if pred_uid not in to_visit_uids and pred_uid not in lvisited_uids:
                    to_visit_uids.append(pred_uid)

            to_visit_uids = to_visit_uids[1:]
            lvisited_uids.append(cur_uid)

        to_visit_uids = [dst_uid]

        # reverse graph exploration
        while 0 < len(to_visit_uids):
            assert(dsp < len(to_visit_uids))	# dead ends!

            cur_uid = to_visit_uids[dsp]
            cur_node = self._nodes[cur_uid]

            assert(cur_uid != src_uid)
            assert(cur_uid not in visited_uids)	# loop!

            # skip node for which there is still some unexplored successor
            skip_uid = False
            for succ_uid in cur_node.get_successors():
                if not succ_uid in visited_uids:
                    skip_uid = True

            if skip_uid:
                dsp += 1
                continue
            else:
                dsp = 0

            if cur_uid == dst_uid:
                node_costs[cur_uid] = cur_node.get_cost()

            for pred_uid in cur_node.get_predecessors():
                pred_node = self._nodes[pred_uid]
                # get edge pred_uid ---> cur_uid
                edge_uid = Edge.get_edge_uid(pred_uid, cur_uid)
                edge = self._edges[edge_uid]
                edge_cost = edge.get_cost()
                if edge_uid not in subgraph_edge_uids:
                    subgraph_edge_uids.append(edge_uid)

                # update node distance
                pred_node_cost = node_costs[cur_uid] + edge_cost + pred_node.get_cost()
                if pred_uid not in node_costs or pred_node_cost > node_costs[pred_uid]:
                    node_costs[pred_uid] = pred_node_cost
                    node_succs[pred_uid] = cur_uid

                # update to_visit_uids, a node cannot be visited more than once
                if (pred_uid != src_uid) and (pred_uid not in visited_uids) \
                        and (pred_uid not in to_visit_uids):
                    to_visit_uids.append(pred_uid)

            to_visit_uids.remove(cur_uid)
            visited_uids.append(cur_uid)
            subgraph_node_uids.append(cur_uid)

        # construct path from src_node to dst_node
        cur_uid = src_uid
        maxpath_node_uids = [cur_uid]
        while cur_uid != dst_uid:
            cur_uid = node_succs[cur_uid]
            cur_node = self._nodes[cur_uid]
            if cur_uid not in maxpath_node_uids:
                maxpath_node_uids.append(cur_uid)
            else:
                raise Exception("invalid input source code graph: loop detected")

        max_cost = node_costs[src_uid]
        return max_cost, maxpath_node_uids, subgraph_node_uids, subgraph_edge_uids

    def add_dominator_cuts(self):
        """adds cuts connecting each node with its dominator to the graph."""
        node_uids = self._nodes.keys();
        node_uids.sort()
        for node_uid in node_uids:
            node = self._nodes[node_uid]
            dominator_uid = node.get_dominator()
            if node.get_num_predecessors() > 1:
                cut_uid = Cut.get_cut_uid(dominator_uid, node_uid)
                if cut_uid in self._cuts.keys(): # avoid repeating work
                    continue
                max_cost, maxpath_node_uids, subgraph_node_uids, subgraph_edge_uids = self._compute_longest_path_cut(dominator_uid, node_uid)
                c = Cut(dominator_uid, node_uid, max_cost, subgraph_node_uids, subgraph_edge_uids, self)
                self._cuts[cut_uid] = c
        return

    def add_semantic_cuts(self, cuts_file, compute_recursive_cuts):
        """adds semantic cuts connecting two nodes to the graph."""
        semantic_cuts = self._get_semantic_cuts(cuts_file, compute_recursive_cuts)
        for sc in semantic_cuts:
            head_uids = sc["head_uids"]
            tail_uids = sc["tail_uids"]
            assert(len(head_uids) == len(tail_uids))
            idx = 0
            ub_idx = len(head_uids)
            while idx < ub_idx:
                head_uid = head_uids[idx]
                tail_uid = tail_uids[idx]
                idx += 1
                cut_uid = Cut.get_cut_uid(head_uid, tail_uid)
                if cut_uid in self._cuts.keys(): # avoid repeating work
                    continue
                max_cost, maxpath_node_uids, subgraph_node_uids, subgraph_edge_uids = self._compute_longest_path_cut(head_uid, tail_uid)
                c = Cut(head_uid, tail_uid, max_cost, subgraph_node_uids, subgraph_edge_uids, self)
                self._cuts[cut_uid] = c
        return

    def compute_longest_syntactic_path(self, add_cut):
        """computes, and optionally adds to the graph, the longest syntactic cut connecting
        the start and end node in the source code graph"""
        max_cost, maxpath_node_uids, subgraph_node_uids, subgraph_edge_uids = self._compute_longest_path_cut(self._start_uid, self._end_uid)
        cut_uid = Cut.get_cut_uid(self._start_uid, self._end_uid)
        if add_cut and cut_uid not in self._cuts.keys():
            c = Cut(self._start_uid, self._end_uid, max_cost, subgraph_node_uids, subgraph_edge_uids, self)
            self._cuts[c.get_uid()] = c
        return max_cost, maxpath_node_uids, subgraph_node_uids, subgraph_edge_uids

    def _compute_paths_among(self, src_uid, dst_uid):
        """computes the number of paths from src_uid to dst_uid."""
        to_visit_uids = [dst_uid]
        paths = {}
        idx = 0
        dsp = 0

        # NOTE: the generated block graph might contain dead ends, thus
        # visited_uids must be pre-computed
        visited_uids = copy.deepcopy(self._nodes.keys())
        lvisited_uids = []
        while len(to_visit_uids) > 0:
            cur_uid = to_visit_uids[0]
            cur_node = self._nodes[cur_uid]

            if cur_uid in visited_uids:
                visited_uids.remove(cur_uid)

            for pred_uid in cur_node.get_predecessors():
                if pred_uid not in to_visit_uids and pred_uid not in lvisited_uids:
                    to_visit_uids.append(pred_uid)

            to_visit_uids = to_visit_uids[1:]
            lvisited_uids.append(cur_uid)

        to_visit_uids = [dst_uid]

        while idx < len(to_visit_uids):
            assert(idx + dsp < len(to_visit_uids))

            cur_uid = to_visit_uids[idx + dsp]
            cur_node = self._nodes[cur_uid]

            assert(cur_uid != src_uid)
            assert(cur_uid not in visited_uids)

            # skip node for which there is still some unexplored successor
            skip_uid = False
            for succ_uid in cur_node.get_successors():
                if succ_uid not in visited_uids:
                    skip_uid = True

            if skip_uid:
                dsp += 1
                continue
            else:
                dsp = 0

            if cur_uid == dst_uid:
                paths[cur_uid] = 1

            for pred_uid in cur_node.get_predecessors():
                if pred_uid not in paths:
                    paths[pred_uid] = paths[cur_uid]
                else:
                    paths[pred_uid] += paths[cur_uid]

                # a node cannot be visited more than once
                if pred_uid != src_uid and pred_uid not in visited_uids \
                        and pred_uid not in to_visit_uids:
                    to_visit_uids.append(pred_uid)

            to_visit_uids.remove(cur_uid)
            visited_uids.append(cur_uid)

        return paths[src_uid]

    def dump_label2vars(self, file_name):
        """dumps the mapping from labels to variables into the specified file."""
        assert(file_name is not None)
        with open(file_name, 'w') as fd:
            for label in self._label2var.keys():
                fd.write(self._label2var[label] + "," + label + "\n")
        return

    def dump_longest_syntactic_path(self, file_name):
        """dumps the longest syntactic path in the specified file."""
        assert(file_name is not None)
        with open(file_name, 'w') as fd:
            longest_path, maxpath_node_uids, subgraph_node_uids, subgraph_edge_uids = self.compute_longest_syntactic_path(False)
            for cur_uid in maxpath_node_uids:
                cur_node = self._nodes[cur_uid]
                s = ""
                if cur_uid != self._start_uid:
                    s += ", " + cur_node.get_label() + ")\n"
                if cur_uid != self._end_uid:
                    s += "(" + cur_node.get_label()
                fd.write(s)
        return

    def dump_cuts_list(self, file_name):
        """dumps all the cuts used in the graph in the specified file."""
        assert(file_name is not None)
        with open(file_name, 'w') as fd:
            uids = self._cuts.keys()
            uids.sort()
            for cut_uid in uids:
                cut = self._cuts[cut_uid]
                fd.write(cut.get_cost_var() + " " + str(cut.get_cost()) + "\n")
        return

###
###
###

if (__name__ == '__main__'):
    # TODO: unit-testing requires hard-coded input
    pass
