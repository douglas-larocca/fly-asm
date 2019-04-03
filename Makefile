.POSIX:
.SUFFIXES: .el .elc

EMACS   = emacs
LDFLAGS = -L lib/nasm-mode
BATCH   = $(EMACS) -Q -batch -L . $(LDFLAGS)
COMPILE = $(BATCH) -f batch-byte-compile
VERSION = 0.1.3

EL = fly-asm.el
ELC = $(EL:.el=.elc)
PKG = fly-asm-pkg.el
DIST = $(PKG) $(EL) fly-asm.rcp README.md UNLICENSE

compile: $(ELC)
all: compile package
package: fly-asm-$(VERSION).tar

fly-asm-$(VERSION): $(DIST)
	mkdir -p $@
	cp $(DIST) $@/
	touch $@/

fly-asm-$(VERSION).tar: fly-asm-$(VERSION)
	tar cf $@ fly-asm-$(VERSION)/
	rm -rf fly-asm-$(VERSION)

compile: $(ELC)

run: compile
	$(EMACS) -Q -L . $(LDFLAGS) \
		-l fly-asm.elc \
		--eval "(fly-asm-mode 1)"

clean:
	rm -rf fly-asm-$(VERSION) fly-asm-$(VERSION).tar $(ELC)

.el.elc:
	$(COMPILE) $<
