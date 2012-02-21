VERSION=0.0.0
BUILD=1

prefix=/usr/local
bindir=$(prefix)/bin
libdir=$(prefix)/lib
mandir=$(prefix)/share/man

all:

build: build-deb build-fpf

build-deb:
	@echo TODO

build-fpf:
	make install prefix=/usr DESTDIR=fpf-$(VERSION)-$(BUILD)
	bin/fpf-build -A -dfpf-$(VERSION)-$(BUILD) -nfpf -v$(VERSION)-$(BUILD) fpf-$(VERSION)-$(BUILD).fpf
	make uninstall prefix=/usr DESTDIR=fpf-$(VERSION)-$(BUILD)

clean:

install: install-bin install-lib install-man

install-bin:
	install -d $(DESTDIR)$(bindir)
	find bin -type f -printf %P\\0 | xargs -0r -I__ install bin/__ $(DESTDIR)$(bindir)/__

install-lib:
	find lib -type d -printf %P\\0 | xargs -0r -I__ install -d $(DESTDIR)$(libdir)/__
	find lib -type f -printf %P\\0 | xargs -0r -I__ install -m644 lib/__ $(DESTDIR)$(libdir)/__

install-man:
	find man -type d -printf %P\\0 | xargs -0r -I__ install -d $(DESTDIR)$(mandir)/__
	find man -type f -name \*.[12345678] -printf %P\\0 | xargs -0r -I__ install -m644 man/__ $(DESTDIR)$(mandir)/__
	find man -type f -name \*.[12345678] -printf %P\\0 | xargs -0r -I__ gzip $(DESTDIR)$(mandir)/__

man:
	find man -name \*.ronn -print0 | PATH="$(HOME)/work/ronn/bin:$(PATH)" RUBYLIB="$(HOME)/work/ronn/lib" xargs -0r -n1 ronn --manual=FPF --roff --style=toc

test:
	find test -name \*.sh -print0 | PATH=$(PWD)/bin:$(PATH) xargs -0r -n1 sh -ex

uninstall: uninstall-bin uninstall-lib uninstall-man

uninstall-bin:
	find bin -type f -printf %P\\0 | xargs -0r -I__ rm -f $(DESTDIR)$(bindir)/__
	rmdir -p --ignore-fail-on-non-empty $(DESTDIR)$(bindir) || true

uninstall-lib:
	find lib -type f -printf %P\\0 | xargs -0r -I__ rm -f $(DESTDIR)$(libdir)/__
	find lib -depth -mindepth 1 -type d -printf %P\\0 | xargs -0r -I__ rmdir $(DESTDIR)$(libdir)/__ || true
	rmdir -p --ignore-fail-on-non-empty $(DESTDIR)$(libdir) || true

uninstall-man:
	find man -type f -name \*.[12345678] -printf %P\\0 | xargs -0r -I__ rm -f $(DESTDIR)$(mandir)/__.gz
	find man -depth -mindepth 1 -type d -printf %P\\0 | xargs -0r -I__ rmdir $(DESTDIR)$(mandir)/__ || true
	rmdir -p --ignore-fail-on-non-empty $(DESTDIR)$(mandir) || true

.PHONY: all build clean install install-bin install-lib install-man man test uninstall uninstall-bin uninstall-lib uninstall-man
