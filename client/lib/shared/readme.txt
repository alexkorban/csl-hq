=Working with lib repo

Safesite-lib repo is a standard git repo; clone, pull, push as usual.

To be able to use subrepo follow install instructions from here: https://github.com/ingydotnet/git-subrepo#readme

=To add/update library to another repo:

- in the root of the repo run
    on mobile: `git subrepo pull ./src/scripts/lib/shared/`
    on hq: `git subrepo pull ./client/lib/shared/`

-  add new library to client/lib/index.coffee
