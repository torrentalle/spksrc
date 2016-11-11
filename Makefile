
AVAILABLE_TCS = $(notdir $(wildcard toolchains/syno-*))
AVAILABLE_ARCHS = $(notdir $(subst syno-,/,$(AVAILABLE_TCS)))
SUPPORTED_SPKS = $(patsubst spk/%/Makefile,%,$(wildcard spk/*/Makefile))


all: $(SUPPORTED_SPKS)

clean: $(addsuffix -clean,$(SUPPORTED_SPKS)) 
clean: native-clean

dist-clean: clean
dist-clean: toolchain-clean

native-clean:
	@for native in $(dir $(wildcard native/*/Makefile)) ; \
	do \
	    (cd $${native} && $(MAKE) clean) ; \
	done

toolchain-clean:
	@for tc in $(dir $(wildcard toolchains/*/Makefile)) ; \
	do \
	    (cd $${tc} && $(MAKE) clean) ; \
	done

cross-clean:
	@for cross in $(dir $(wildcard cross/*/Makefile)) ; \
	do \
	    (cd $${cross} && $(MAKE) clean) ; \
	done

spk-clean:
	@for spk in $(dir $(wildcard spk/*/Makefile)) ; \
	do \
	    (cd $${spk} && $(MAKE) clean) ; \
	done

%: spk/%/Makefile
	cd $(dir $^) && env $(MAKE)

%-clean: spk/%/Makefile
	cd $(dir $^) && env $(MAKE) clean

prepare: downloads
	@for tc in $(dir $(wildcard toolchains/*/Makefile)) ; \
	do \
	    (cd $${tc} && $(MAKE)) ; \
	done

downloads:
	@for dl in $(dir $(wildcard cross/*/Makefile)) ; \
	do \
	    (cd $${dl} && $(MAKE) download) ; \
	done

natives:
	@for n in $(dir $(wildcard native/*/Makefile)) ; \
	do \
	    (cd $${n} && $(MAKE)) ; \
	done

.PHONY: toolchains kernel-modules
toolchains: $(addprefix toolchain-,$(AVAILABLE_ARCHS))
kernel-modules: $(addprefix kernel-,$(AVAILABLE_ARCHS))

toolchain-%:
	-@cd toolchains/syno-$*/ && MAKEFLAGS= $(MAKE)

kernel-%:
	-@cd kernel/syno-$*/ && MAKEFLAGS= $(MAKE)

setup: local.mk dsm-5.2

local.mk:
	@echo "Creating local configuration \"local.mk\"..."
	@echo "PUBLISH_URL=" > $@
	@echo "PUBLISH_API_KEY=" >> $@
	@echo "MAINTAINER?=" >> $@
	@echo "MAINTAINER_URL=" >> $@
	@echo "DISTRIBUTOR=" >> $@
	@echo "DISTRIBUTOR_URL=" >> $@
	@echo "REPORT_URL=" >> $@
	@echo "DEFAULT_TC=" >> $@

dsm-%: local.mk
	@echo "Setting default toolchain version to DSM-$*"
	@sed -i "s|DEFAULT_TC.*|DEFAULT_TC=$*|" local.mk

setup-synocommunity: setup
	@sed -i -e "s|PUBLISH_URL=.*|PUBLISH_URL=https://api.synocommunity.com|" \
		-e "s|MAINTAINER?=.*|MAINTAINER?=SynoCommunity|" \
		-e "s|MAINTAINER_URL=.*|MAINTAINER_URL=https://synocommunity.com|" \
		-e "s|DISTRIBUTOR=.*|DISTRIBUTOR=SynoCommunity|" \
		-e "s|DISTRIBUTOR_URL=.*|DISTRIBUTOR_URL=https://synocommunity.com|" \
		-e "s|REPORT_URL=.*|REPORT_URL=https://github.com/SynoCommunity/spksrc/issues|" \
		local.mk

.PHONY: travis
travis: .travis.yml

%-travis-env: spk/%/Makefile
	@cd $(dir $^) && env $(MAKE) list-all-supported 
	@cd $(dir $^) && cat work/list-all-supported |  awk \
	  '{print "  - SPK=$* SYNOARCH=" $$1 }' >> ../../.travis.yml.tmp

.travis.yml:
	@echo "Generating .travis.yml file"
	@echo "#Generated automatically using make travis" > $@.tmp
	@echo "sudo: required" >> $@.tmp
	@echo "language: false" >> $@.tmp
	@echo "services:" >> $@.tmp
	@echo "  - docker" >> $@.tmp
	@echo "env:" >> $@.tmp
	@for SPK in $(SUPPORTED_SPKS) ; \
	do \
	  env $(MAKE) $$SPK-travis-env ; \
	done
	@echo "script:" >> $@.tmp
	@echo '  - docker pull synocommunity/spksrc'
	@echo '  - docker run -it -v `pwd`:/spksrc synocommunity/spksrc /bin/bash -c "cd /spksrc && make setup && cd spk/$$SPK && make arch-$$SYNOARCH && exit $$?" ' >> $@.tmp
	@mv $@.tmp  $@
