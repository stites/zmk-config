ZEPHYR_BASE := config

# have a persistent pipeline:
# https://stackoverflow.com/questions/16233196/makefile-to-execute-a-sequence-of-steps
STEPDIR := target/build_steps
CONFDIR := target/config
OUTDIR  := target
ZEN_STEPS := init prebuild \
	full-corne-ish_zen-3x5 \
	zen-3x5-init zen-3x5-clean \
	zen-3x5-left zen-3x5-right \
	full-corne-ish_zen-3x6 \
	zen-3x6-left zen-3x6-right \
	zen-3x6-init zen-3x6-clean

.PHONY: $(ZEN_STEPS) zen-shield \
	all report clean clean-all \
	zen-3x5 zen-3x6

all: # these cannot be run in parallel
	make zen-3x6
	make zen-3x5

$(ZEN_STEPS): %: $(STEPDIR)/%

zen-3x5:
	make LAYOUT=3x5 $(STEPDIR)/full-corne-ish_zen-3x5

zen-3x6:
	make LAYOUT=3x6 $(STEPDIR)/full-corne-ish_zen-3x6

# we want this step which includes the transient init and clean steps
$(STEPDIR)/full-corne-ish_zen-$(LAYOUT):
	make $(STEPDIR)/prebuild # if west.yml splits repos, you'll have to cache
	make $(STEPDIR)/zen-$(LAYOUT)-init
	make SIDE=left $(OUTDIR)/corneish_zen_$(LAYOUT)_left.uf2
	make SIDE=right $(OUTDIR)/corneish_zen_$(LAYOUT)_right.uf2

# use this if starting from a fresh repo
$(STEPDIR)/init:
	mkdir -p $(STEPDIR)
	@echo "initializing west..."
	west init -l $(ZEPHYR_BASE) || true
	@touch $@

$(STEPDIR)/prebuild: $(STEPDIR)/init
	@echo "updating west, you may have to make init if you see an error"
	west update
	west zephyr-export
	@touch $@

$(CONFDIR)/zen-$(LAYOUT):
	mkdir -p $(CONFDIR)/zen-$(LAYOUT)
$(CONFDIR)/zen-$(LAYOUT)/corneish_zen.conf:         $(CONFDIR)/zen-$(LAYOUT)
	cp config/corneish_zen/generic.conf               $(CONFDIR)/zen-$(LAYOUT)/corneish_zen.conf
$(CONFDIR)/zen-$(LAYOUT)/corneish_zen_left.keymap:  $(CONFDIR)/zen-$(LAYOUT)
	cp config/corneish_zen/generic_left.keymap.in     $(CONFDIR)/zen-$(LAYOUT)/corneish_zen_left.keymap
$(CONFDIR)/zen-$(LAYOUT)/corneish_zen_right.keymap: $(CONFDIR)/zen-$(LAYOUT)
	cp config/corneish_zen/generic_right.keymap.in    $(CONFDIR)/zen-$(LAYOUT)/corneish_zen_right.keymap
$(CONFDIR)/zen-$(LAYOUT)/west.yml:                  $(CONFDIR)/zen-$(LAYOUT)
	cp config/corneish_zen/generic_west.yml           $(CONFDIR)/zen-$(LAYOUT)/west.yml
$(CONFDIR)/zen-$(LAYOUT)/corneish_zen.keymap:       $(CONFDIR)/zen-$(LAYOUT)
ifeq ($(LAYOUT),3x5)
	cat config/corneish_zen/generic.keymap.in | sed 's/<<<TYPE>>>/five_column/' | sed 's/<<<EXTRA>>>//g'       > $(CONFDIR)/zen-$(LAYOUT)/corneish_zen.keymap
else
	cat config/corneish_zen/generic.keymap.in | sed 's/<<<TYPE>>>/default/'     | sed 's/<<<EXTRA>>>/\&none/g' > $(CONFDIR)/zen-$(LAYOUT)/corneish_zen.keymap
endif

$(STEPDIR)/zen-$(LAYOUT)-init: $(CONFDIR)/zen-$(LAYOUT)/corneish_zen.keymap $(CONFDIR)/zen-$(LAYOUT)/corneish_zen.conf $(CONFDIR)/zen-$(LAYOUT)/corneish_zen_left.keymap $(CONFDIR)/zen-$(LAYOUT)/corneish_zen_right.keymap $(CONFDIR)/zen-$(LAYOUT)/west.yml
	@echo "moving files for Corne-ish Zen ($(LAYOUT))"
	rm -f $(STEPDIR)/zen-$(LAYOUT)-clean
	@touch $@

$(STEPDIR)/zen-$(LAYOUT)-clean:
	@echo "cleaning files from Corne-ish Zen ($(LAYOUT))"
ifneq (,$(wildcard $(STEPDIR)/zen-$(LAYOUT)-init))
	test -f $(STEPDIR)/zen-$(LAYOUT)-init
	rm -f $(CONFDIR)/zen-$(LAYOUT)
	@touch $@
else
	@echo "...$(STEPDIR)/zen-$(LAYOUT)-init not found! Aborting!"
	exit 1
endif

$(OUTDIR)/corneish_zen_$(LAYOUT)_$(SIDE).uf2: $(STEPDIR)/zen-$(LAYOUT)-init
	@echo "building Corne-ish Zen ($(LAYOUT) $(SIDE))"
ifeq ($(LAYOUT),3x5)
	west build --pristine -s zmk/app -b corneish_zen_v2_$(SIDE) -- -DZMK_CONFIG="$(PWD)/$(CONFDIR)/zen-$(LAYOUT)"
else
	west build --pristine -s zmk/app -b corneish_zen_v1_$(SIDE) -- -DZMK_CONFIG="$(PWD)/$(CONFDIR)/zen-$(LAYOUT)"
endif
	mkdir -p $(OUTDIR)/
	cp build/zephyr/zmk.uf2 $(OUTDIR)/corneish_zen_$(LAYOUT)_$(SIDE).uf2
	@touch $(STEPDIR)/zen-$(LAYOUT)-$(SIDE)

# use this if you want stats from your board
#report:
#	@echo "DTS file"
#	cat -n build/zephyr/zephyr.dts.pre
#	@echo "Corne-ish Zen Left Kconfig file"
#	cat build/zephyr/.config | grep -v "^#" | grep -v "^$"
#	make zen-3x6-right

clean-$(LAYOUT):
	rm -f  $(STEPDIR)/zen-$(LAYOUT)*
	rm -rf $(CONFDIR)/zen-$(LAYOUT)
	rm -f $(OUTDIR)/corneish_zen_$(LAYOUT)_*.uf2

clean:
	rm -f target/*.uf2
	make LAYOUT=3x5 clean-3x5
	make LAYOUT=3x6 clean-3x6
	fd '[^i][^n][^i][^t]' ./target/build_steps/ -x rm

clean-all: clean
	git clean -f -e .envrc -e .direnv -d -x
	rm -rf modules zephyr zmk target/build_steps/
