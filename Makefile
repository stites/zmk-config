ZEPHYR_BASE := config

# have a persistent pipeline:
# https://stackoverflow.com/questions/16233196/makefile-to-execute-a-sequence-of-steps
STEPDIR := target/build_steps
CONFDIR := target/config
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

$(ZEN_STEPS): %: $(STEPDIR)/%

all: # these cannot be run in parallel
	make zen-3x6
	make zen-3x5

zen-3x5:
	make LAYOUT=3x5 $(STEPDIR)/full-corne-ish_zen-3x5

zen-3x6:
	make LAYOUT=3x6 $(STEPDIR)/full-corne-ish_zen-3x6

# we want this step which includes the transient init and clean steps
$(STEPDIR)/full-corne-ish_zen-$(LAYOUT):
	make $(STEPDIR)/zen-$(LAYOUT)-init
	make $(STEPDIR)/prebuild # if west.yml splits repos, you'll have to cache
	make SIDE=left LAYOUT=$(LAYOUT) zen-shield
	make SIDE=right LAYOUT=$(LAYOUT) zen-shield
	make $(STEPDIR)/zen-$(LAYOUT)-clean

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

$(STEPDIR)/zen-$(LAYOUT)-init: $(CONFDIR)/zen-$(LAYOUT)/corneish_zen.keymap $(CONFDIR)/zen-$(LAYOUT)/corneish_zen.conf $(CONFDIR)/zen-$(LAYOUT)/corneish_zen_left.keymap $(CONFDIR)/zen-$(LAYOUT)/corneish_zen_right.keymap $(CONFDIR)/zen-$(LAYOUT)/west.yml
	@echo "moving files for Corne-ish Zen ($(LAYOUT))"
	rm -f $(STEPDIR)/zen-$(LAYOUT)-clean
	mkdir -p config/corneish_zen/$(LAYOUT)/
ifeq ($(LAYOUT),3x5)
	cat config/corneish_zen/generic.keymap.in | sed 's/<<<TYPE>>>/five_column/' | sed 's/<<<EXTRA>>>//g'       > config/corneish_zen/$(LAYOUT)/corneish_zen.keymap
else
	cat config/corneish_zen/generic.keymap.in | sed 's/<<<TYPE>>>/default/'     | sed 's/<<<EXTRA>>>/\&none/g' > config/corneish_zen/$(LAYOUT)/corneish_zen.keymap
endif
# should just make this part of the build artifacts but I am lazy
	cp config/corneish_zen/generic.conf            config/corneish_zen/$(LAYOUT)/corneish_zen.conf
	cp config/corneish_zen/generic_left.keymap.in  config/corneish_zen/$(LAYOUT)/corneish_zen_left.keymap
	cp config/corneish_zen/generic_right.keymap.in config/corneish_zen/$(LAYOUT)/corneish_zen_right.keymap
	cp config/corneish_zen/generic_west.yml        config/corneish_zen/$(LAYOUT)/west.yml
	cp config/corneish_zen/$(LAYOUT)/* config/
	@touch $@

$(CONFDIR)/zen-$(LAYOUT)/corneish_zen.keymap:
ifeq ($(LAYOUT),3x5)
	cat config/corneish_zen/generic.keymap.in | sed 's/<<<TYPE>>>/five_column/' | sed 's/<<<EXTRA>>>//g'       > $(CONFDIR)/zen-$(LAYOUT)/corneish_zen.keymap
else
	cat config/corneish_zen/generic.keymap.in | sed 's/<<<TYPE>>>/default/'     | sed 's/<<<EXTRA>>>/\&none/g' > $(CONFDIR)/zen-$(LAYOUT)/corneish_zen.keymap
endif
$(CONFDIR)/zen-$(LAYOUT)/corneish_zen.conf:
	cp config/corneish_zen/generic.conf            $(CONFDIR)/zen-$(LAYOUT)/corneish_zen.conf
$(CONFDIR)/zen-$(LAYOUT)/corneish_zen_left.keymap:
	cp config/corneish_zen/generic_left.keymap.in  $(CONFDIR)/zen-$(LAYOUT)/corneish_zen_left.keymap
$(CONFDIR)/zen-$(LAYOUT)/corneish_zen_right.keymap:
	cp config/corneish_zen/generic_right.keymap.in $(CONFDIR)/zen-$(LAYOUT)/corneish_zen_right.keymap
$(CONFDIR)/zen-$(LAYOUT)/west.yml:
	cp config/corneish_zen/generic_west.yml        $(CONFDIR)/zen-$(LAYOUT)/west.yml

$(STEPDIR)/zen-$(LAYOUT)-clean:
	@echo "cleaning files from Corne-ish Zen ($(LAYOUT))"
ifneq (,$(wildcard $(STEPDIR)/zen-$(LAYOUT)-init))
	test -f $(STEPDIR)/zen-$(LAYOUT)-init
	rm -f config/corne-ish_zen*.keymap config/corne-ish_zen.conf west.yml
	@touch $@
else
	@echo "...$(STEPDIR)/zen-$(LAYOUT)-init not found! Aborting!"
	exit 1
endif

zen-shield: $(STEPDIR)/prebuild
	@echo "building Corne-ish Zen ($(LAYOUT) $(SIDE))"
ifeq ($(LAYOUT),3x5)
	#west build --pristine -s zmk/app -b corneish_zen_v2_$(SIDE) -- -DZMK_CONFIG="$(CURDIR)/config"
	west build --pristine -s zmk/app -b corneish_zen_v2_$(SIDE) -- -DZMK_CONFIG="$(CURDIR)/config"
else
	west build --pristine -s zmk/app -b corneish_zen_v1_$(SIDE) -- -DZMK_CONFIG="$(CURDIR)/config"
endif
	mkdir -p target/
	cp build/zephyr/zmk.uf2 target/corneish_zen_$(LAYOUT)_$(SIDE).uf2
	@touch $(STEPDIR)/zen-$(LAYOUT)-$(SIDE)

# use this if you want stats from your board
report:
	@echo "DTS file"
	cat -n build/zephyr/zephyr.dts.pre
	@echo "Corne-ish Zen Left Kconfig file"
	cat build/zephyr/.config | grep -v "^#" | grep -v "^$"
	make zen-3x6-right

clean-3x6:
	rm -f ./target/build_steps/zen-3x6*
	rm -f ./config/corneish_zen/3x6/*

clean-3x5:
	rm -f ./target/build_steps/zen-3x5*
	rm -f ./config/corneish_zen/3x5/*

clean:
	make clean-3x5
	make clean-3x6
	rm -f target/*.uf2
	rm -f config/*.keymap config/*.conf
	fd '[^i][^n][^i][^t]' ./target/build_steps/ -x rm

clean-all: clean
	git clean -f -e .envrc -e .direnv -d -x
	rm -rf modules zephyr zmk target/build_steps/
