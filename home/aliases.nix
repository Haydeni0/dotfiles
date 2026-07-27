# oh-my-zsh-style aliases, curated for daily use.
# Sourced from omz's common-aliases + git plugins, cherry-picked to avoid
# framework overhead (omz's compinit, lib/*.zsh). Defined here so the full
# set is visible and tracked in the repo, not hidden behind a plugin load.
# Personal aliases (cc, ll, la, l, cat, add, push, pull, m) stay in shell.nix;
# Nix's module system merges both attrsets, and shell.nix's win on conflict.
# Reference: https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/directories.zsh
#            https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/git/git.plugin.zsh
{ ... }:

{
  programs.zsh.shellAliases = {
    # ls family (from lib/directories.zsh + common-aliases; ll/la/l kept in shell.nix)
    lsa = "ls -lah";
    lr = "ls -tRFh";
    lt = "ls -ltFh";
    lS = "ls -1FSsh";
    lart = "ls -1Fcart";
    lrt = "ls -1Fcrt";
    lsr = "ls -lARFh";
    lsn = "ls -1";
    ldot = "ls -ld .*";

    # directory navigation (global aliases, used inline as pipes)
    "..." = "../..";
    "...." = "../../..";
    "....." = "../../../..";
    md = "mkdir -p";
    rd = "rmdir";

    # common-aliases misc
    grep = "grep --color";
    h = "history";
    p = "ps -f";
    dud = "du -d 1 -h";

    # git: core (g = git, gst = status)
    g = "git";
    gst = "git status";
    gss = "git status --short";
    gsb = "git status --short --branch";

    # git: add
    ga = "git add";
    gaa = "git add --all";
    gau = "git add --update";

    # git: branch
    gb = "git branch";
    gba = "git branch --all";
    gbd = "git branch --delete";
    gbD = "git branch --delete --force";
    gbm = "git branch --move";
    gbr = "git branch --remote";
    gbl = "git blame -w";

    # git: checkout / switch
    gco = "git checkout";
    gcb = "git checkout -b";
    gcm = "git checkout main";
    gsw = "git switch";
    gswc = "git switch --create";
    gswm = "git switch main";

    # git: clone
    gcl = "git clone --recurse-submodules";

    # git: commit
    gc = "git commit --verbose";
    gca = "git commit --verbose --all";
    gcam = "git commit --all --message";
    gcmsg = "git commit --message";
    "gca!" = "git commit --verbose --all --amend";
    "gc!" = "git commit --verbose --amend";

    # git: diff
    gd = "git diff";
    gdc = "git diff --cached";
    gds = "git diff --staged";
    gdw = "git diff --word-diff";

    # git: fetch
    gf = "git fetch";
    gfo = "git fetch origin";

    # git: log
    glo = "git log --oneline --decorate";
    glog = "git log --oneline --decorate --graph";
    gloga = "git log --oneline --decorate --graph --all";
    glg = "git log --stat";
    glgp = "git log --stat --patch";

    # git: merge
    gm = "git merge";
    gma = "git merge --abort";
    gmff = "git merge --ff-only";

    # git: pull / push
    gl = "git pull";
    gpr = "git pull --rebase";
    gp = "git push";
    gpd = "git push --dry-run";
    gpf = "git push --force-with-lease";
    gpv = "git push --verbose";

    # git: rebase
    grb = "git rebase";
    grba = "git rebase --abort";
    grbc = "git rebase --continue";
    grbi = "git rebase --interactive";

    # git: remote / reset / restore / revert
    gr = "git remote";
    grv = "git remote --verbose";
    gra = "git remote add";
    grrm = "git remote remove";
    grh = "git reset";
    grhh = "git reset --hard";
    grs = "git restore";
    grst = "git restore --staged";
    grev = "git revert";

    # git: stash
    gsta = "git stash push";
    gstp = "git stash pop";
    gstl = "git stash list";
    gstd = "git stash drop";

    # git: tag
    gta = "git tag --annotate";
    gtv = "git tag | sort -V";

    # git: misc
    gcount = "git shortlog --summary --numbered";
    gsh = "git show";
    gsi = "git submodule init";
    gsu = "git submodule update";
    gignore = "git update-index --assume-unchanged";
    gunignore = "git update-index --no-assume-unchanged";
    gignored = "git ls-files -v | grep \"^[[:lower:]]\"";
    gfg = "git ls-files | grep";
  };
}
