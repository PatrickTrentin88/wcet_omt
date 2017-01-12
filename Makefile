###                                           ###
### resource location                         ###
###                                           ###

WCET_OMT_DIR	:= $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
WCET_RUN		:= $(WCET_OMT_DIR)/bin/run_experiment.sh
WCET_SETUP		:= $(WCET_OMT_DIR)/bin/setup_env.sh
WCET_TOOLS_DIR	:= $(WCET_OMT_DIR)/tools

###                                           ###
### user customizable variables               ###
###                                           ###

WCET_TIMEOUT	?= 60							# seconds, 0: disabled

WCET_BENCH_DIR	?= $(WCET_OMT_DIR)/bench		# default benchmarks directory
WCET_STATS_DIR	?= $(WCET_OMT_DIR)/stats/bench	# default statistics directory

WCET_RUN_FLAGS	:= -f -s 2						# default:
												# -f   : print general information
												# -s 2 : do not overwrite any file except result statistics

WCET_RUN_FLAGS  += -t $(WCET_TIMEOUT)

ifeq ($(DEBUG), 1)
	WCET_RUN_FLAGS	+= -c -w					# debug:
endif											# -c   : print calls to external commands
												# -w   : print warnings

###                                           ###
### nothing below here should require editing ###
### unless new handlers are added             ###
###                                           ###

# commands
MKDIR = mkdir -p
RM    = rm -rfv
MV    = mv -f
LN    = ln -f

#defs
define run-experiment
	@ $(MKDIR) $(WCET_STATS_DIR)
	@ $(WCET_RUN) $(strip $(WCET_RUN_FLAGS)) $(strip $(WCET_BENCH_DIR)) $(strip $(WCET_STATS_DIR)) $%
endef

# rules
.PHONY : default install clean default_all

default : ;

install :
	# interactive installation
	$(WCET_SETUP) 0 1

default_all : \
	z3_0 \
	z3_0_cuts \
	optimathsat_0 \
	optimathsat_0_cuts \
	optimathsat_1_sn \
	optimathsat_1_cuts_sn \
	optimathsat_2 \
	optimathsat_2_cuts \
	optimathsat_2_dl_1 \
	optimathsat_2_cuts_dl_1 \
#	optimathsat_2_dl_2 \
#	optimathsat_2_cuts_dl_2 \
#	optimathsat_2_dl_3 \
#	optimathsat_2_cuts_dl_3

z3_0:
	$(run-experiment) $@
z3_0_cuts:
	$(run-experiment) $@
optimathsat_0:
	$(run-experiment) $@
optimathsat_0_cuts:
	$(run-experiment) $@
optimathsat_1_sn:
	$(run-experiment) $@
optimathsat_1_cuts_sn:
	$(run-experiment) $@
optimathsat_2:
	$(run-experiment) $@
optimathsat_2_cuts:
	$(run-experiment) $@
optimathsat_2_dl_1:
	$(run-experiment) $@
optimathsat_2_cuts_dl_1:
	$(run-experiment) $@
optimathsat_2_dl_2:
	$(run-experiment) $@
optimathsat_2_cuts_dl_2:
	$(run-experiment) $@
optimathsat_2_dl_3:
	$(run-experiment) $@
optimathsat_2_cuts_dl_3:
	$(run-experiment) $@

clean :

print-% : ; $(info $* is $(flavor $*) variable set to [$($*)]) @true
