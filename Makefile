all::

man:
	find man -name \*.ronn | PATH="$(HOME)/work/ronn/bin:$(PATH)" RUBYLIB="$(HOME)/work/ronn/lib" xargs -n1 ronn --manual=FPF --style=toc

.PHONY: all man
