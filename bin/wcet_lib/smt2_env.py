###
### Globals
###

ENC_DEFAULT          = 0
ENC_ASSERT_SOFT      = 1
ENC_DIFFERENCE_LOGIC = 2

###
###
###

class Environment:
    """class Environment, a wrapper for an SMT2 formula, stores everything into
    a global environment, ready for printing.

    Incrementality is not supported.

    For practical reasons, no input string is ever checked for correctness,
    smt2 language compliance and type safety.
    """

    REAL = "Real"
    INT = "Int"
    BOOL = "Bool"

    def __init__(self):
        self.reset()

    def reset(self):
        """clears the environment."""
        self._counter = 0
        self._options = {}
        self._declarations = []
        self._assertions = []
        self._soft_assertions = []
        self._objectives = []
        self._comments = []

    # options

    def set_option(self, name, value):
        self._options[name] = value

    # declarations

    def declare_fun(self, name, type):
        """adds a declaration of a function of name `name` and type
        `type` to the environment."""
        d = "(declare-fun " + str(name) + " () " + str(type) + ")"
        if (d not in self._declarations):
            self._declarations.append(d)
        return name

    def declare_private_fun(self, type):
        """adds a declaration of a function with a fresh, unique, internal
        name and type `type` to the environment, and returns the name."""
        ret = "var_" + str(self._counter)
        self._counter += 1
        self.declare_fun(ret, type)
        return ret

    def add_declarations(self, decls):
        """adds a list of declarations (unchecked) to the environment in batch mode."""
        for decl in decls:
            self.add_declaration(decl)

    def add_declaration(self, decl):
        """adds a declaration (unchecked) to the environment."""
        self._declarations.append(decl)

    # assertions

    def assert_formulas(self, terms):
        """asserts a list of terms (unchecked) to the environment."""
        for term in terms:
            self.assert_formula(term)

    def assert_formula(self, term):
        """assert a term (unchecked) to the environment."""
        if not "assert" in term:
            f = "(assert " + str(term) + ")"
            if not f in self._assertions:
                self._assertions.append(f)
        else:
            if not term in self._assertions:
                self._assertions.append(str(term))

    # soft assertions

    def assert_soft_formula(self, term, weight, id):
        """asserts a soft formula (unchecked) within the environment."""
        t = "(assert-soft " + str(term) + " :weight " + str(weight) + " :id " + id + ")"
        self._soft_assertions.append(t)

    # optimization

    def minimize(self, term, lower=None, upper=None):
        """adds `term` to the list of objectives to be minimized."""
        t = "(minimize " + str(term)
        if not lower is None:
            t += " :local-lb " + str(lower)
        if not upper is None:
            t += " :local-ub " + str(upper)
        t += ")"
        self._objectives.append(t)

    def maximize(self, term, lower=None, upper=None):
        """adds `term` to the list of objectives to be maximized."""
        t = "(maximize " + str(term)
        if not lower is None:
            t += " :local-lb " + str(lower)
        if not upper is None:
            t += " :local-ub " + str(upper)
        t += ")"
        self._objectives.append(t)

    # comments
    def add_comment(self, comment):
        """adds comment to the list of comments, which are printed at the end of the smt2 formula."""
        self._comments.append("; " + str(comment))

    # dump formula on stdout

    def dump(self):
        """prints the content of the environment on stdout."""
        get_model = False

        if "produce-models" in self._options:
            get_model = self._options["produce-models"]

        for key in self._options.keys():
            print "(set-option :" + str(key) + " " + str(self._options[key]).lower() + ")"
        for d in self._declarations:
            print d
        for f in self._assertions:
            print f
        for f in self._soft_assertions:
            print f
        for o in self._objectives:
            print o

        print "(check-sat)"

        if (get_model):
            print "(set-model -1)"
            print "(get-model)"
        else:
            print ";(set-model -1)"
            print ";(get-model)"

        print ";(get-info :all-statistics)"

        for c in self._comments:
            print c

###
### SMT Formula Construction
###

def make_times(term1, term2):
    return "(* " + str(term1) + " " + str(term2) + ")"

def make_not(term):
    return "(not " + str(term) + ")"

def make_or(terms):
    if len(terms) > 1:
        return "(or" + ''.join(map(lambda t: " " + str(t), terms)) + ")"
    else:
        return ''.join(terms)

def make_and(terms):
    if len(terms) > 1:
        return "(and" + ''.join(map(lambda t: " " + str(t), terms)) + ")"
    else:
        return ''.join(terms)

def make_plus(terms):
    if len(terms) > 1:
        return "(+" + ''.join(map(lambda t: " " + str(t), terms)) + ")"
    else:
        return ''.join(terms)

def make_leq(term1, term2):
    return "(<= " + str(term1) + " " + str(term2) + ")"

def make_lt(term1, term2):
    return make_not(make_leq(term2, term1))

def make_minus(term):
    return "(- " + str(term) + ")"

def make_diff(term1, term2):
    return "(- " + str(term1) + " " + str(term2) + ")"

def make_imply(term1, term2):
    return "(=> " + str(term1) + " " + str(term2) + ")"

def make_iff(term1, term2):
    return make_and([make_imply(term1, term2), make_imply(term2, term1)])

def make_equal(term1, term2):
    return "(= " + str(term1) + " " + str(term2) + ")"

def make_ite(bterm, term1, term2):
    return "(ite " + str(bterm) + " " + str(term1) + " " + str(term2) + ")"

###
###
###

if (__name__ == "__main__"):
        env = Environment()

        cost = env.declare_fun("cost", Environment.REAL)
        x = env.declare_fun("x", Environment.REAL)
        y = env.declare_fun("y", Environment.REAL)

        c0 = make_leq(5, x)
        c1 = make_leq(7, y)
        c2 = make_equal(cost, make_plus([x, y]))

        env.assert_formulas([c0, c1, c2])

        env.set_option("produce-models", True)

        env.minimize(cost)

        env.dump()
