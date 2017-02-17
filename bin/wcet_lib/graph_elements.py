from smt2_env import *

###
### Node
###

class Node:
    """class Node, a wrapper for a node in a source code graph."""

    def __init__(self, bvar, label, cost, dominator, graph, preds = None, succs = None):
        """Init:
            - bvar      : node's boolean term, true iff the node concurs to the objective value
            - label     : toolchain generated label for block of code associated to this node
            - cost      : cost of executing the block of code associated to the node
            - dominator : the closest common ancestor of node that is included in all incoming paths
            - preds     : uids of predecessors
            - succs     : uids of successors
        """
        self._label = label
        self._bvar = bvar
        self._uid = int(bvar.split('_')[1])
        self._cost_var = "c" + str(self._uid)
        self._cost = int(cost)
        self._dominator = int(dominator) # '< 0' for starting block
        self._preds = [] if preds is None else preds
        self._succs = [] if succs is None else succs
        self._graph = graph

    def add_successor(self, succ_block):
        self._succs.append(succ_block)

    def add_predecessor(self, pred_block):
        self._preds.append(pred_block)

    def add_node_to_env(self, env, encoding, args = None):
        """encodes the node as a piece of SMT2 formula, and adds it to the input `env`"""
        if (ENC_DIFFERENCE_LOGIC == encoding):
            env.declare_fun(self._cost_var, Environment.INT)
            big_or = []
            for pred_uid in self._preds:
                pred_node = self._graph.get_node(pred_uid)
                edge_uid = Edge.get_edge_uid(pred_uid, self._uid)
                cvalue = self._cost + self._graph.get_edge(edge_uid).get_cost()
                f = make_leq(make_diff(self._cost_var, pred_node.get_cost_var()), cvalue)
                big_or.append(f)
            if len(big_or) == 0:
                f = make_leq(self._cost_var, self._cost)
                env.assert_formula(f)
            else:
                f = make_imply(self._bvar, make_or(big_or))
                env.assert_formula(f)

        elif (ENC_ASSERT_SOFT == encoding):
            assert(args is not None and "id" in args.keys())
            asoft_id = args["id"]
            if self._cost > 0:
                env.assert_soft_formula(make_not(self._bvar), self._cost, asoft_id)

        elif (ENC_DEFAULT_BAD == encoding):
            env.declare_fun(self._cost_var, Environment.INT)
            if self._dominator < 0: # no ITE simplification allowed
                f = make_equal(self._cost_var, self._cost)
            else:
                f = make_equal(self._cost_var, make_ite(self._bvar, self._cost, "0"))
            env.assert_formula(f)

        else:
            env.declare_fun(self._cost_var, Environment.INT)
            if self._dominator < 0 or int(self._cost) == 0:
                f = make_equal(self._cost_var, self._cost)
            else:
                f = make_equal(self._cost_var, make_ite(self._bvar, self._cost, "0"))
            env.assert_formula(f)
        return

    def get_label(self):
        return self._label

    def get_bvar(self):
        return self._bvar

    def get_uid(self):
        return self._uid;

    def get_cost_var(self):
        return self._cost_var

    def set_cost(self, cost):
        self._cost = int(cost)

    def get_cost(self):
        return self._cost

    def get_dominator(self):
        return self._dominator

    def get_predecessors(self):
        return self._preds

    def get_successors(self):
        return self._succs

    def get_num_predecessors(self):
        return len(self._preds)

    def get_num_successors(self):
        return len(self._succs)


###
### Cut
###

class Cut:
    """class Cut, a wrapper for a cut connecting two nodes in a source code graph.
    NOTE: a cut is exactly like an edge, only that it stores additional information
    on the nodes/edges that can appear along the path src_node --> dst_node"""

    def __init__(self, src_uid, dst_uid, cost, node_uids, edge_uids, graph):
        """Init:
            - src_uid   : the uid of the source node
            - dst_uid   : the uid of the destination node
            - cost      : maximum cost of any path from src_uid to dst_uid in the source code graph
            - node_uids : node uids in the sub-graph `src_uid-...->dst_uid`
            - edge_uids : edge uids in the sub-graph `src_uid-...->dst_uid`
            - graph     : the graph owning the cut 
        """
        assert(src_uid in node_uids)
        assert(dst_uid in node_uids)
        assert(len(edge_uids) > 0)
        self._cost = int(cost)
        self._src_node_uid = src_uid
        self._dst_node_uid = dst_uid
        self._uid = Cut.get_cut_uid(self._src_node_uid, self._dst_node_uid)
        self._cost_var = "cut_" + self._uid
        self._node_uids = node_uids
        self._edge_uids = edge_uids
        self._graph = graph

    @staticmethod
    def get_cut_uid(src_uid, dst_uid): # static
        return str(src_uid) + "_" + str(dst_uid)

    def add_cut_to_env(self, env, encoding):
        """encodes the cut as a piece of SMT2 formula, and adds it to the input `env`"""

        if (ENC_DIFFERENCE_LOGIC == encoding):
            src_node = self._graph.get_node(self._src_node_uid)
            dst_node = self._graph.get_node(self._dst_node_uid)
            # c_dst - c_src <= max_path + cost(dst)
            cvalue = self._cost + dst_node.get_cost()
            f = make_leq(make_diff(dst_node.get_cost_var(), src_node.get_cost_var()), cvalue)
            env.assert_formula(f)

        elif (ENC_ASSERT_SOFT == encoding):
            cost = env.declare_fun(self._cost_var, Environment.REAL)
            opts = { "id" : cost }
            for node_uid in self._node_uids:
                node = self._graph.get_node(node_uid)
                node.add_node_to_env(env, encoding, opts)
            for edge_uid in self._edge_uids:
                edge = self._graph.get_edge(edge_uid)
                edge.add_edge_to_env(env, encoding, opts)
            f = make_leq(cost, self._cost)
            env.assert_formula(f)

        elif (ENC_DEFAULT_BAD == encoding):
            # collect cvars
            cvars = []
            for node_uid in self._node_uids:
                node = self._graph.get_node(node_uid)
                node_cost = node.get_cost()
                cvars.append(node.get_cost_var()) # 0-cost variables added all the same
            for edge_uid in self._edge_uids:
                edge = self._graph.get_edge(edge_uid)
                edge_cost = edge.get_cost()
                cvars.append(edge.get_cost_var()) # 0-cost variables added all the same

            env.declare_fun(self._cost_var, Environment.INT)
            if len(cvars) > 1:
                f = make_equal(self._cost_var, make_plus(cvars))
            elif len(cvars) == 1:
                f = make_equal(self._cost_var, cvars[0])
            else:
                f = make_equal(self._cost_var, 0)
            env.assert_formula(f)
            f = make_leq(self._cost_var, self._cost)
            env.assert_formula(f)

        else:
            # collect cvars
            cvars = []
            for node_uid in self._node_uids:
                node = self._graph.get_node(node_uid)
                node_cost = node.get_cost()
                if node_cost != 0:
                    cvars.append(node.get_cost_var())
            for edge_uid in self._edge_uids:
                edge = self._graph.get_edge(edge_uid)
                edge_cost = edge.get_cost()
                if edge_cost != 0:
                    cvars.append(edge.get_cost_var())

            env.declare_fun(self._cost_var, Environment.INT)
            if len(cvars) > 1:
                f = make_equal(self._cost_var, make_plus(cvars))
            elif len(cvars) == 1:
                f = make_equal(self._cost_var, cvars[0])
            else:
                f = make_equal(self._cost_var, 0)
            env.assert_formula(f)
            f = make_leq(self._cost_var, self._cost)
            env.assert_formula(f)
        return

    def get_uid(self):
        return self._uid

    def get_cost_var(self):
        return self._cost_var

    def get_cost(self):
        return self._cost


###
### Edge
###

class Edge:
    """class Edge, a wrapper for an edge connecting two nodes in the source code graph."""

    def __init__(self, src_var, dst_var, cost, graph):
        """Init:
            - src_var : the boolean var associated with source node
            - dst_var : the boolean var associated with destination node
            - cost    : cost of traversing this edge
        """
        # NOTE: do not use block labels as inputs, only block's boolean variables
        self._cost = int(cost)
        self._src_node_uid = int(src_var.split('_')[1])
        self._dst_node_uid = int(dst_var.split('_')[1])
        self._uid = Edge.get_edge_uid(self._src_node_uid, self._dst_node_uid)
        self._cost_var = "c_" + self._uid
        self._bvar = "t_" + self._uid       # true in SMT2 model if edge taken
        self._graph = graph

    @staticmethod
    def get_edge_uid(src_uid, dst_uid): # static
        return str(src_uid) + "_" + str(dst_uid)

    def add_edge_to_env(self, env, encoding, args=None):
        """encodes the edge as a piece of SMT2 formula, and adds it to the input `env`"""
        if (ENC_DIFFERENCE_LOGIC == encoding):
            assert(args is not None and "edge_implies_nodes" in args.keys())
            env.declare_fun(self._cost_var, Environment.INT)
            src_node = self._graph.get_node(self._src_node_uid)
            dst_node = self._graph.get_node(self._dst_node_uid)
            # b_edge => c_dst - c_src <= cost(edge) + cost(dst)
            cvalue = self._cost + dst_node.get_cost()
            f = make_imply(self._bvar, make_leq(make_diff(dst_node.get_cost_var(), src_node.get_cost_var()), cvalue))
            env.assert_formula(f)
            # b_edge => b_src & b_dst
            if args["edge_implies_nodes"]:
                f = make_and([make_imply(self._bvar, src_node.get_bvar()),
                              make_imply(self._bvar, dst_node.get_bvar())])
                env.assert_formula(f)

        elif (ENC_ASSERT_SOFT == encoding):
            assert(args is not None and "id" in args.keys())
            asoft_id = args["id"]
            if self._cost > 0:
                env.assert_soft_formula(make_not(self._bvar), self._cost, asoft_id)

        elif (ENC_DEFAULT_BAD == encoding):
            env.declare_fun(self._cost_var, Environment.INT)
            # no ITE semplification
            f = make_equal(self._cost_var, make_ite(self._bvar, self._cost, "0"))
            env.assert_formula(f)

        else:
            env.declare_fun(self._cost_var, Environment.INT)
            if self._cost != 0:
                f = make_equal(self._cost_var, make_ite(self._bvar, self._cost, "0"))
            else:
                f = make_equal(self._cost_var, "0")
            env.assert_formula(f)
        return

    def set_cost(self, cost):
        self._cost = int(cost)

    def get_cost(self):
        return self._cost

    def get_src_uid(self):
        return self._src_node_uid

    def get_dst_uid(self):
        return self._dst_node_uid

    def get_uid(self):
        return self._uid

    def get_cost_var(self):
        return self._cost_var

    def get_bvar(self):
        return self._bvar

###
###
###

if (__name__ == '__main__'):
    # TODO: unit-testing
    pass
