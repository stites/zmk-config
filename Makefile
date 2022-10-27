ZEPHYR_BASE := config
# have a persistent pipeline:
# https://stackoverflow.com/questions/16233196/makefile-to-execute-a-sequence-of-steps
STEPDIR := target/build_steps
ZEN_STEPS := prebuild zen-left zen-right


# runs entire pipeline
zen: $(STEPDIR)/prebuild $(STEPDIR)/zen-left $(STEPDIR)/zen-right

.PHONY: $(ZEN_STEPS) zen init zen-shield
$(ZEN_STEPS): %: $(STEPDIR)/%

$(STEPDIR)/prebuild:
	@echo "updating west, you may have to make init if you see an error"
	west update
	west zephyr-export
	mkdir -p $(STEPDIR)
	@touch $@

zen-shield: $(STEPDIR)/prebuild
	@echo "building Corne-ish Zen ($(SIDE))"
	west build --pristine -s zmk/app -b corne-ish_zen_$(SIDE) # -- -DZMK_CONFIG="${GITHUB_WORKSPACE}/config"
	mkdir -p target/
	cp build/zephyr/zmk.uf2 target/corneish_zen_$(SIDE).uf2
	@touch $(STEPDIR)/zen-$(SIDE)

$(STEPDIR)/zen-left: $(STEPDIR)/prebuild
	make SIDE=left zen-shield

$(STEPDIR)/zen-right: $(STEPDIR)/zen-left
	make SIDE=right zen-shield

# use this if starting from a fresh repo
init:
	west init -l config

# use this if you want stats from your board
report:
	@echo "DTS file"
	cat -n build/zephyr/zephyr.dts.pre
	@echo "Corne-ish Zen Left Kconfig file"
	cat build/zephyr/.config | grep -v "^#" | grep -v "^$"
	make zen-right
