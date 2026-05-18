# typora-rpm

Wraps the official Typora Linux tarball into an RPM package, so it can be installed and upgraded through the package manager.

## How it works

This package is an **installer!** It does not contain the Typora binary itself. Instead, it provides a hosted RPM repository whose package, on installation, downloads the official Typora tarball from [https://downloads.typora.io](https://downloads.typora.io), verifies its SHA256, unpacks it into `/opt/typora` and adds a desktop entry.

The repository is published at [https://victorfaurschou.github.io/typora-rpm/](https://victorfaurschou.github.io/typora-rpm/) by a scheduled CI job that re-runs `bump.sh` daily and republishes if upstream has changed.

Redistribution is avoided while still preserving package management semantics, albeit in a manner that diverges significantly from established RPM packaging best practices.

> [!NOTE]
> Tested on Fedora 43 (x86_64). Similar distributions and architectures (aarch64) may work but are not guaranteed. Your mileage may vary.

## Usage

### Install

```sh
sudo curl -fsSL -o /etc/yum.repos.d/typora.repo \
    https://victorfaurschou.github.io/typora-rpm/typora.repo
sudo dnf install typora
```

`dnf install typora` installs the package, which:
1. Downloads the official Typora tarball
2. Verifies its SHA256
3. Unpacks it into `/opt/typora`
4. Adds a desktop entry

### Uninstall

```sh
sudo dnf remove typora
```

Optionally, remove the repository file:
```sh
sudo rm /etc/yum.repos.d/typora.repo
```

### Update

```sh
sudo dnf upgrade typora
```

Updates are pulled in automatically via the hosted repository. A scheduled CI job runs `bump.sh` daily; if upstream Typora has changed, a new RPM is built and published, and the next `dnf upgrade` picks it up.

## Disclaimer

This project is not affiliated with, endorsed by, or associated with Typora or its developer. [Typora](https://typora.io) is proprietary commercial software developed by [AppMakes](https://appmakes.io), and its licensing terms apply independently.
