# New Linux Setup

## Table of Contents

- [New Linux Setup](#new-linux-setup)
  - [Table of Contents](#table-of-contents)
  - [Github Login](#github-login)
  - [Bash customizations](#bash-customizations)

## Github Login

- Download and install latest [git-credential-manager](https://github.com/git-ecosystem/git-credential-manager/)

- setup git to use secretservice as the default credential store

```sh
git config --global credential.credentialStore secretservice
```

- Clone a repo and login using browser

## Bash customizations

- Clone https://github.com/melbeltagy/lolo-koki to your home folder

```sh
cd ~
git clone https://github.com/melbeltagy/lolo-koki
```

- Run this command to apply customizations to bash.  
  The command will add all files with extension `.bashrc` to the `.bashrc` file.

```sh
../bash/customization/apply.sh
```
