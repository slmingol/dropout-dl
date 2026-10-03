<div align="center">
    <img src="https://raw.githubusercontent.com/mosswg/dropout-dl/main/assets/dropout_dl_logo.png" width="50%" />
</div>

* [Installation](#installation)
  * [GHCR (recommended)](#ghcr-recommended)
  * [Docker (build locally)](#docker-build-locally)
  * [How to Build](#how-to-build)
  * [Dependencies](#Dependencies)
* [Usage](#how-to-use)
  * [Makefile (quick start)](#makefile-quick-start)
  * [Options](#options)
  * [Login](#login)
  * [Cookies](#cookies)



# Installation
## GHCR (recommended)

Pre-built images are published to GitHub Container Registry on every push to `main`.

```shell
docker pull ghcr.io/slmingol/dropout-dl:main
```

Clone the repo and use the Makefile to drive everything — no local build required:

```shell
git clone https://github.com/slmingol/dropout-dl
cd dropout-dl
make pull          # pull latest image
```

## Docker (build locally)

Build the image yourself if you need local changes:

```shell
docker build -t dropout-dl:local .
# or via Makefile:
make build
```

## How to Use
### Makefile quick start

The `Makefile` wraps the container and constructs dropout.tv URLs from simple variables — no need to type full URLs.

**1. Create a `login` file** (email on line 1, password on line 2):
```
email@example.com
password123
```

**2. Browse then download:**
```shell
# List all shows on dropout.tv
make list-shows

# List all seasons for a show
make list-seasons SHOW=crowd-control

# List all episodes in a season (prints title + URL, tab-separated)
make list-episodes SHOW=crowd-control SEASON=2

# Download one episode by number or by slug
make episode SHOW=crowd-control SEASON=2 EPISODE=3
make episode SHOW=crowd-control SEASON=2 EPISODE=hal-rose-said-to-watch-this-episode

# Download a full season
make season SHOW=crowd-control SEASON=2

# Download an entire series
make series SHOW=um-actually
```

**Variables** (all overridable):

| Variable | Default | Description |
|----------|---------|-------------|
| `IMAGE`   | `ghcr.io/slmingol/dropout-dl:main` | Docker image to use |
| `QUALITY` | `720p` | Video quality (`360p` `480p` `720p` `1080p`) |
| `OUT`     | `./out` | Output directory on host |
| `LOGIN`   | `./login` | Path to login credentials file |
| `PREFIX`  | _(unset)_ | Set to `1` to prepend `S##E##_` to output filenames |

```shell
make season SHOW=dropout-mbmbam SEASON=1 QUALITY=1080p OUT=/volume2/data

# Prepend S##E## prefix to downloaded filename
make episode SHOW=smartypants SEASON=3 EPISODE=2 PREFIX=1
# → out/S03E02_Smartypants - Smartyshorts Nice to Meet You.mp4
```

Run `make help` for a full reference.

---
>
## Submodule
This repository uses [a json library](https://github.com/nlohmann/json/). Either clone the repository with the `--recurse-submodules` flag or after cloning run:
```
git submodule update --init --recursive
```

## How to Build
```
cmake -S <source-dir> -B <build-dir>
cmake --build <build-dir>
```

### Dependencies

#### Required
* [cURL](https://curl.se/libcurl/) - Required for downloading pages and videos.
#### Optional
* [SQLite](https://www.sqlite.org/index.html) - Required for retrieving cookies from browsers.
* [libgcrypt](https://www.gnupg.org/software/libgcrypt/index.html) - Used for decrypting chrome cookies retrieved from the sqlite database.

##### Debian/Ubuntu
```
sudo apt install libcurl4-gnutls-dev
```
To install the optional dependencies, run:
```
sudo apt install libsqlite3-dev libgcrypt-dev
```

##### Void Linux
```
sudo xbps-install -S libcurl
```
To install the optional dependencies, run:
```
sudo xbps-install -S sqlite-devel libgcrypt-devel
```

## How to Use
```
./dropout-dl [options] <url>
```
By default, dropout-dl will download episodes in a season with the format `<series>/<season>/<series> - S<season-num>E<episode-num> - <episode-name>.mp4` and single episodes with the format `<series>/<season>/<series> - <season> - <episode-name>.mp4`.

### Options
```
--help              -h   Display this message
--quality           -q   Set the quality of the downloaded video. Quality can be set to 'all' which
                            will download all qualities and place them into separate folders
--output            -o   Set the output filename. Only works for single episode downloads
--output-directory  -d   Set the directory where files are output
--verbose           -v   Display debug information while running
--browser-cookies   -bc  Use cookies from the browser placed in 'firefox_profile' or 'chrome_profile'
--force-cookies          Interpret the next to argument as the session cookie
--series            -S   Interpret the url as a link to a series and download all episodes from all seasons
--season            -s   Interpret the url as a link to a season and download all episodes from all seasons
--episode           -e   Interpret the url as a link to a single episode
--captions          -c   Download the captions along with the episode. Overridden by --captions-only if set.
--captions-only     -co  Download the captions only, without the episode.
--list              -l   List seasons (with -S) or episodes (with -s) instead of downloading
```

If series, season, or episode is not used, the type will be inferred based on the link format.

### Login
Login in information must be placed in a file called `login` in the same directory as the executable. The file must be email then on a new line password. For example if your email is `email@example.com` and password `password123` the file would be:
```
email@example.com
password123
```

### Cookies
If you would like to avoid logging in for any reason, cookies can be used. The option `browser-cookies` must be provided.
#### Firefox
Create a file named `firefox_profile` in the build directory and paste in your [firefox profile folder path](https://support.mozilla.org/en-US/kb/profiles-where-firefox-stores-user-data)
#### Chrome
Install libgcrypt and create a file named `chrome_profile` in the build directory and paste in your chrome profile folder path (found on [chrome://version](chrome://version))
#### Other/No Sqlite
Use the `--force-cookies` program option to manually input cookies.


## Contributing
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](https://makeapullrequest.com)
### Issues
If you have any issues or would like a feature to be added please don't hesitate to submit an issue after checking to make sure it hasn't already been submitted. Using the templates is a good place to start, but sometimes they're overkill. For example, if the program segfaults for you, you don't need to state that the intended behaviour is to not segfault. \
\
If you'd like to contribute a good place to start is looking at open issues and trying to fix one with a pull request. \

## Contributors
- [mosswg](https://github.com/mosswg)
- [SeanOMik](https://github.com/SeanOMik) - Docker support
- [Hello-User](https://github.com/Hello-User) - Skip downloading if file exists
- [MisterSheeple](https://github.com/MisterSheeple) - Optional dependency installation instructions
- [BradMJustice](https://github.com/BradMJustice) - Caption improvements
