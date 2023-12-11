# My Linux dotfiles

## Usage

Clone and enter this repository

```bash
git clone git@github.com:Haydeni0/dotfiles.git
cd dotfiles
```

Use GNU Stow to symbolic link the contents of this repository to your `$HOME` directory

```bash
stow .
```

If the dotfiles exist already, you can use `stow --adopt .` to adopt the existing dotfiles in the system into this repository. 
The repository can then be reverted with `git restore .`.
