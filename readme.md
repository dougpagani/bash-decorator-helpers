# bash-decorator-helpers (NYI)

*NYI: not yet implemented; this is just to catch some ideas of a long-chewed thought. If you have any recommendations for improving design, or do any implementation work, I'd be happy to look it over & incorporate. I've got it like ~50% finished if anyone wants to take it the extra mile. This will be built out iteratively, with this doc to serve as a target-design-specification for iterative implementation over time as I slowly convert my own instances of cmd-decorations into this standardized format, on a important-enough-case-by-case basis.*

These decorator helpers deal with modifying/extending execution of a SUBJECT on the cmdline.

The main purpose of this is to obviate/replace the rather brittle & annoying need to do wiring based on `cmd, cmd-default(), alias cmd=cmd-default`-patterning.

... thus making cmdline-package-monkey-patching more pleasant & maintainable, as any cmd-mods will be composable, decomposable, and recomposable.

## Uses:

- pre/post hooks to argv-sensitive cmdline invocations
- overrides
- intelligent argument-translations
- cmd-extensions (eg `git copy-remote`)
- safety guards for pre-conditions of dangerous or annoying invocations
- opt/arg defaults (eg default to human readable, unless something else is specified)
- self-notes on certain tricky behavior of certain args

## Examples:

Note: These were not tested, just some examples to illustrate the intent of design & usage using real-ish world scenarios.

```bash
_validate-in-repo() { test -d .git || { cd .. &>/dev/null && _validate-in-repo; }; }
@@guard git _validate-in-repo 
#^ Note: you wouldn't want to actually do this as-is since git has a target-dir option

_log-git-usage() { echo "git $*" > /tmp/git-audit.log; }
@@pre git _log-git-usage

# Specifying some decspecs in one big block:
@@cmd git init \
    @@guard '[[ ! _validate-in-repo ]]' \
    @@pre 'echo "> git-initializing in dir: ${2:-PWD}"' \
    @@post 'cd $2' \
    @@post 'git commit --alow-empty -m "root commit"' \
    @@post 'git checkout -b trunk"' \
    @@post 'git branch -d master"' \
    @@post 'gh repo create' \
    @@post 'git remote set-head origin trunk' \
    @@post 'git push -u origin $(git rev-parse --abbrev-ref HEAD)' \
    @@end # not necessary, but can be syntactically-convenient so you don't have the trailing-\ problem when modifying code.

# We can also just declare it as such, redundantly, allowing for postpend-comments instead of needing to EOL-escape with `\':

@@cmd git init @@guard '[[ ! _validate-in-repo ]]' # Look Ma', no eol-escape!

@@cmd git init @@post 'gh repo create' # Look Ma', no (impingement on editorial control)!

# ... etc.
```

## Decorator types:


- @@cmd -- can be composed with most of rest of decorators on a subcmd-targeted basis.
    - Note: if you happen to have an argument with "@@" as its first two characters, you can double them as "@@@@" and it will make it through appropriately. This should be more-or-less reliable, as the decorator-helpers all have deterministic/fixed-arity.
- @@addcmd -- receives args after `<subcmd>`-match. Will do its best to ignore root-`--flag`s, but in the real world this is highly-dependent on how the tool decided to implement its argv-parsing.

### Exec Hooks:
- @@guard -- executed before SUBJECT; can block by exit-code
    - SPECIALIZED:
        - @@block-match
        - @@block-subcmd
        - @@guard-none PREDICATE -- run & validated to fail for every arg
        - @@guard-all PREDICATE -- run & validated to succeed for every arg
- @@pre -- executed before SUBJECT; will not block 
- @@post -- executed after SUBJECT on success
- @@finally -- executed after SUBJECT, regardless of success

### True Wrappers:
- @@wrap -- responsible for calling cmd, modifying args as necessary
    - Note: This is the highly-generalized decorator, as most people are normally accustomed to. It will have to call SUBJECT itself.
    - ... feels like maybe this is ambiguous design, wherein one should get
      passed the function-name, as is the normal signature of decorators, and
      another should just be a clobber/replace.
- @@match -- match ALL (so as to avoid specification-errors) & run provided function instead
    - Note: highly brittle
- @@sub -- match-exact the contiguous text & replace with the given text
    - Note: highly brittle

### Arg modifiers:
- @@prepend -- add an extra arg as `$1`
- @@postpend -- add an extra arg as `$($#)`
- `@@inject-after <WORD> <INJECTION>`
- `@@inject-before <WORD> <INJECTION>`

### Pipe wraps:
These are especially nice because with normal alias-styled-wraps, you can't both preserve arguments-passing-transparency AND pipe downstream into some kind of aesthetic filter.
- @@pipe-input -- still pass the args into the SUBJECT, but first filters any `stdin` through the supplied command.
    - Note: If the cmd is never run in a pipe naturally, this really doesn't make sense and you shouldn't use it.
    - aka @@pipe-stdin
- @@pipe-output -- filter output of SUBJECT after all is said & done thorugh the supplied cmdish
    - eg `@@pipe-output git diff -- diff-so-fancy`
    - eg `@@pipe-output git add --patch -- diff-so-fancy # dodging the historic problems of doing this in gitconfig via pager` 
    - aka @@pipe-stdout
- @@pipe-error -- filter stderr
    - eg `@@pipe-error find prune-find-noise-on-SIP-dirs`
    - aka @@pipe-stderr
    - Note: implemented with a process subshell (` 2> >(...)`) by necessity
    - Tip: good for reducing noise
- @@shove-error -- send stderr "somewhere else" so it doesn't clutter the current shell. It will be both pre-noted so you can tail it, and post-noted so you don't accidentally confuse yourself with a cmd silently fails.
    - Note: this should not be trusted with `@@pipe-error`
    - eg `@@shove-error find [/explicit/path/for/error.log]`

### Meta decorator helpers:

Print Control:
- @@quiet -- doesn't print decoration-advisories
- @@verbose -- reverses a previous @@quiet (this is the default)

Debug your decspecs:
- @@debug -- prints the decorations-configuration for a given command
- @@print-synthetic-body -- "compiles" the decorations into some holistic & portable function-def+alias-def which wraps a call to the SUBJECT.
    - Note: the likelihood of this ever getting implemented is minimal, but it's a thought & good clarifier of design (as it shouldn't ever be a matter _whether_ it can be implemented). Maybe using something like `python -m shlex`, since bash doesn't provide a parser for itself, and eval-parsing-hacks are hacky. `@@debug` is probably sufficient 99% of the time instead of having to see it "naturally" as compiled souce.

Niche/Optimize:
- @@lockspecs -- generate a `/tmp/decspecs` "bundle" so that the dynamic, on-shell-init, derivation of your decspec-constructions doesn't have to be run everytime. This will turn every `@@<helper>` function, after sourcing this package as per normal, into a speedy no-op (eg `@@pre() { :; }`) so your source still sources. This caches build, basically, so as in any case with cache, the logic of when you'd like to invalidate your cache is a matter of your workflow characteristics (ie make an intelligent decision). You can put it at the "end" of your shell-profile, wherever that may be, and just remove the tmp-file when you'd like to reload. Or if you want to over-complicate things, you can have a git-index-change hook or filesystem-watcher targeted against all the files that you may have decspecs within. Or just have a single file. Again, this is entirely situation-dependent-strategy and there is no right answer or answer that comes completely without frustrations, so if your shell-init isn't noticeably faster without this, don't do it. 

Activation Control:
- `@@off <cmdname|cmdline>` -- if `cmdname`, turn-off in current shell for cmdname. if `cmdname`
    - This exists so you can easily do `^A @@off` to quickly toggle-off a suspicious decoration
    - Or just: `command CMD` or `\CMD` also works for this, since the decoration is implemented with a simple alias
- `@@on` -- undo a previous `@@off`
- @@global-off -- turn off all wrappers. Useful when trying to "revert to normal" when building portable scripts.
    - toggle-back with `@@global-on`
- @@ixactive-only -- ask `with-decorations` to check if it is "inside" a function, and if so, revert to default behavior. 
    - to make it global, if you want: `@@ixactive-always` aka `@@global-ixactive`
    - This can help avoid "works on my machine" landmine-problems.
    - aka `@@repl-only`
- @@uchoose -- for particularly complicated commands, this can be used to first, prior to execution, place the user into an `$EDITOR` buffer & simply delete undesirable decorations on a line-by-line basis.

Deferral:
> _To prevent annoying alias-expansion-during-rc-sourcing problems._

- @@defer-mode
    - Place this after this package is sourced-in, to set a global flag to prevent premature alias binings. This can help avoid bugs to do with aliases expanding in function names, or in function source where you don't want it to, or wherever. 
- @@defer-resolve
    - Place this near the "end" of shell-source to finalize the decspec-configurations.

???:
- @@rider -- 

## Notes on behavior in general
- all decorator-modes receive all args; they vary on whether they get called or not
- no need to worry about finnicky boilerplate; this monkey-patches in an "absorbing"/self-normalizing manner, intelligently. As such, the decorators, unless within a single class (eg all @@pre) are order-irrelevant.
- verbosely printed 
- if given a 'string with spaces', since that isn't a valid function-name, it will be assumed to be a function-body & wrapped accordingly under an auto-generated name. `$@`-positional args may be used, but make sure the string is with single quotes for convenience in avoiding shell-quote-parsing.
- Although the order "matters" for pre/post commands & their variants, a decoration itself-failing will not cause a subsequent pre/post command to fail or not run, staying consistent with their effects unto the SUBJECT. If you need something like that to happen, just wrap the particular logic under a single function & decoration yourself, which should provide you that kind of control. It should be noted that regardless of, if in your composite-function, one pre-action can fail & block another, just as in the case of a "single" (opaquely to the decoration) pre-action, the whole pipeline blocking will not block SUBJECT execution. If that needs to happen, wrap both in a `@@guard`.

## Subject-Target Suggestions

- `git` -- it is anyways extendable with `git-*` executables found on path, but that has some detriments & disadvantages, and also, limitations. I don't suggest, for example, wrapping & replacing built-ins with this facility as it will be frustratingly difficult to temporarily "mute" a wrap-layer when some edge case is hit, but you just want to move forwards with whatever you were doing.
- `find` -- you can setup some logically-resilient injections & arg-transforms such that you're excluding some _"the usual suspects"_ of noise-makers, during normal operation. The arg-transform, again, by default, will be overt, so some "spooky action" you've forgotten you've configured won't trip you up. And the advisories are written to `/dev/tty` so if you need to capture or redirect or want to silence the error-output from `find`, you'll still be able to do this. I would however recommend something more modern instead of getting too wild on `-o (-a . -a )` incantations.
- `fswatch` -- setup print-stream-filters of various sorts
- Building some small normalization-adapters for quarrelsomely-different commands that vary between linux & darwin, eg `nc` vs. `netcat`, `sed` & its `-i` 
    - To do this, you'd have to use `@@wrap` and check which command is configured on path, making your option-translations wherever possible (if possible)
- 


## Dev notes:
### Viability Principle

Aliases in shellcode don't have to point to any valid targets until they resolve. Also, aliases can easily be "dodged" by either (1) replacing `CMD` with `command CMD` or (2) escaping as in `\CMD`. Also, bash has RTE-introspectives (? language-reflection) such as `type NAME` to be able to generalize the "wiring" involved with stacking multiple cmdname-riders. So, without having to mess with dependency or ordering concerns, we can just have one `with-decorations()` function which properly understands how function-like code-objects are typically extended by coders. It would look something like this:

```bash
# resolved from an alias:
with-decorations SUBJECT @@pre _do-before-subject @@post _do-after-subject

# specified & appended to arbtrarily as such:
alias SUBJECT='with-decorations SUBJECT ...' #^ ... as per above, normalized & appended to with each @@-cmd
```

An alternative to this would be pointing to some sort of "master decorations resolver", which uses an associative array (`declare -A DECORATIONS_DB`) to configure & then execute, mapping some keyname that corresponds to command (eg `alias subjectcmd='mdr subjectcmd'; subjectcmd ... $@ ;`) and modifying its execution, dynamically, accordingly. The 'only' issue with this is t that associative arrays are finnicky, and using them as an impromptu database is even more finnicky. And not very opaque for easy interrogation of the framework as it encounters bugs.

### Workhorse Pieces

None of this is tested, it's just pseudo-code written directly into markdown though it should be syntactically valid even if missing many implementations.

Parsers are responsible for resolving array-value from array-name.

The implementation exists straddling two worlds:
- 1: **configure** (your subject-targeted decorations)
- 2: **execute** (with your decorations)

The bulk is in (2); we keep (1) simple by just deferring most disambiguation for later, and "dumbly" appending decspecs on a "order-of-appearance"-basis. This is anyways beneficial for easily interrogating resultant state of your bash source (just `alias CMD` is enough); nothing is hidden from the user behind some opaque storage database.

There is also:
- 3: **debug** (your decspecs)

... which is meant to be used interactively upon logical collisions or bugs you may encounter when attempting more complicated decorations (especially arg-transforms & pipe-chains).

```bash
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

with-decorations() {
    subject="$1"; shift;
    muddled_decspecs_and_argv=( "$@" )
    decspecs=( "$(parse-decspecs-from-muddling "${muddled_decspecs_and_argv[@]}")" )
    argv=( "$(parse-argv-from-muddling "${muddled_decspecs_and_argv[@]}")" )
    
    declare -n DS=decspecs # for convenience & readability

    # care: impedmatch: pass DS by-name not by-val
    validate-decspecs DS
    parse-pre DS
    parse-post DS
    parse-guard DS
    maybe-set-verbose DS

    argv=( "$( transform-argv DS "${argv[@]}" )" )

    # Execution
    decs-do-pre
    decs-do-guard &&
        $subject "${argv[@]}"
        ec_subject=$?
    
    # Conditional posts:
    [[ $ec_subject -eq 0 ]] \
    && decs-do-post

    # Unconditionally:
    decs-do-finally

}

decs-do-STAGE() {
    TODO -- organize code-boundaries of overt-printer vs. executor
    print-grey "$stage: $stage_action" \
    > /dev/tty
    #^ CRUCIAL POINT: this makes it so we can redirect /dev/stderr during
    # normal operation without bungling/adulterating it with these advisories.
    # This is one particularly-nice decoration-generalization that you
    # otherwise trip over constantly if you start wrapping things in your shell's
    # environment. 
    #  ...
    # You could, of course, "just remember" to always write to
    # /dev/tty everytime you do some sort of wrapper thing, but humans don't work
    # that way.
}

transform-argv() {
    dsname=$1; shift;
    argv=("$@") # working var
    declare -ra ogargv=("$@") # just to have a copy in case, eg debugging

    echo "${argv}"
    return 0
    #^ identity implementation until this advanced feature is implemented
    #> real impl:

    # Mashers:
    pre=( "$(parse-prepend $dsname)" )
    post=( "$(parse-postpend $dsname)" )

    # Injectors:
    argv=( "$(inject-befores-from $dsname "${argv[@]}")" )
    argv=( "$(inject-afters-from $dsname "${argv[@]}")" )
    #^ Note: This will suffer unto the (aimably-declarative) API a cross-decspec
    # ordering-dependent side effect. Although this is somewhat-arguably the intuitive
    # behavior, and has some end-uses that are otherwise hard to achieve, it's
    # not really an intended behavior since it isn't an explicit effect. To get
    # over this, you'd have to pre-calculate index positions, track them as
    # anchors, separately calculate the argv-injections as distinct objects, and
    # inject them in an index-shifting-agnostic way. So, inject-befores-from()
    # would have to also output some idx information to be used as the anchoring
    # for after. Or, they could be both run out of the same execution space such
    # that the indices of the injections are tracked & ignored on match-hit for
    # the afters(). No implementation is trivial and this anyways has its merits.
    # ...
    # 
    # There is one more possibility that is perhaps better, and that is a one-shot:
    # > inject-from $dsname "${argv[@]}"
    # ie:
    # argv=( "$(inject-from $dsname "${argv[@]}")" )
    # 
    # ... This would provide for an implementation that guarantees
    # order-effectful behavior that resembles multiple-pre/post-specs, in which,
    # sure, it is obvious which of a pre vs. post is executed first, as it is in
    # the name, and it doesn't matter which is parsed first, *but* here it would
    # mean an inject-after OR inject-before, when specified before or after the
    # other (take care of that precise phrasing), can affect/combine with the
    # previous/subsequent. The code would execute more-or-less as one would
    # expect, and also, it would give the user choice as to what the end-effect
    # is.

    NEWARGV=( \
        "${pre[@]}" 
        "${argv[@]}"
        "${post[@]}" 
    )
    echo 
}

parse-decorations() { TODO; }
validate-decspecs() { TODO -- help user to prevent time-sink-typos like @@psot; } 
```

### Undefined Behavior
> _Worrisome pain-points_
- targeting of aliases, with or without deferral
- wayward aliases clobbering pre-configured decspecs
- targeting of functions
- targeting of non-existent cmdnames
- mixing of @@pipe-error & @@shove-error
- pipe-chains, in general ( maybe best done in a `@@wrap` )
- @@pipe-output failing, yet the core-command having succeeded in a buried `$PIPE_ERROR` (and thus failing any post-hocs)
- meta-note: overall this package should be not really used for robust-exigencies. It's really just meant for interactive convenience, not scripting. Scripting stability will not be supported. You can always take the advisories (eg `@@resultant-line: git --with-overrides subcmd --postpend`) and weave those in on an as-needs basis into any downstream script being iterated towards.

### Logical extensions
> _Where you could go from here_

This attains a sort-of "consistent cmd-customization interface", so that actually opens the door for some downstream/emergent capabilities.

Not really planning on building this, but it could be done:
- no-hassle extension to upstream tab-completion logic
> with extra `@@cmd`s, this could be made to, in a parallel-fashion, produce a completion function which passes onto the native completion by default, but otherwise still completes on user-extensions. This is relatively trivial, though esoteric, & I have some code somewhere where I've done a "lossless" passthrough-wrap of completers. I only did that a couple times due to the immense tedium of remembering to maintain that but again, this would generalize the implementation such that you've got a consistent environment for completing as well as execution.

- Generalized add-ins: these would be things like caching, coloration, etc., which you could amplify the value of doing by way of ( write-once, use-many ).

#### Generalized add-ins

There are plenty of generalizable-enhancements that could easily be managed with, & packaged into this project. Off the top of my head:
- @@cache -- cache long-running commands commonly used during development, like curl, or find, so you can continue iterating on your pipeline
- @@color-err -- color the stderr red to easily distinguish it in a pipeline
- @@perf -- always profile the performance of a command, presumably it's something that takes a lot of time you'd like to finger the pulse on like `make` or other build-chains.
- @@elide -- ensure output is always contained to a screen-length, summarized with `[... 45 lines more, see: TMPFILE ]` in the middle of the middle-truncated-output.

Even more esoteric:
- @@split-streams-via-tmux -- send stderr to a different provisional/transient pane using a multiplexer
- @@man-split -- split a terminal multiplexer (with debounce) everytime you execute a particularly complicated command you can never remember the options for (looking at you, `strftime(3)`)


