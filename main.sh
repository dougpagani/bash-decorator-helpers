#!/usr/bin/env bash
#####################################

NYI -- go for simplest, case-matching implementation at first-notice

###########
# Top level
###########

# NOTE: Could maybe just define these dynamically by batch, in a simple loop-eval. I don't think their implementations will actually vary; the hard part is in the execution.

@@pre() {
    TODO
    stage=@@pre
    append-decoration $cmdname $stage $decaction
}

@@post() {
    TODO
    stage=@@post
    append-decoration $cmdname $stage $decaction
}

###########
# Internals
###########

append-decoration() {
    # Usage:
    # append-decoration $cmdname $stage $decaction
}

alias-body() { alias "${1?need aliasname}" | extract-alias-body; }
extract-alias-body() { TODO; }
normalize-decorations-alias() {
    SUBJECT="$1"
    declare -n S=SUBJECT
# Crucially, @@end is our elephant-in-cairo so we can do this kind of
# full-control monkey-patching without worrying about screwing up a clean
# argv-extraction as supplied organically on the cmdline by the user f/ normal use.

    # case-1 : ERROR: not an alias
    # case-2+: >
    # alias SUBJECT='with-decorations SUBJECT
    alias_body=$(alias-body $S || mk-boilerplate-decorations-alias $S)
}

