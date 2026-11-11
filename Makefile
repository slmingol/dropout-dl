RED     := $(shell tput setaf 1 2>/dev/null)
GREEN   := $(shell tput setaf 2 2>/dev/null)
YELLOW  := $(shell tput setaf 3 2>/dev/null)
BLUE    := $(shell tput setaf 4 2>/dev/null)
CYAN    := $(shell tput setaf 6 2>/dev/null)
MAGENTA := $(shell tput setaf 5 2>/dev/null)
BOLD    := $(shell tput bold 2>/dev/null)
RESET   := $(shell tput sgr0 2>/dev/null)

IMAGE   ?= ghcr.io/slmingol/dropout-dl:overlay
QUALITY ?= 720p
OUT     ?= $(PWD)/out
LOGIN   ?= $(PWD)/login
SESSION ?= $(PWD)/session
PREFIX  ?=
COOKIE  ?= $(shell test -f $(SESSION) && cat $(SESSION) || true)
DOCKER  ?= $(shell command -v docker 2>/dev/null || command -v podman 2>/dev/null || echo docker)

# Default Firefox profile detection (macOS) — pick whichever profile has cookies.sqlite
FIREFOX_PROFILE ?= $(shell find "$(HOME)/Library/Application Support/Firefox/Profiles" -maxdepth 2 -name "cookies.sqlite" 2>/dev/null | head -1 | sed 's|/[^/]*$$||')

BASE    := https://watch.dropout.tv

_SHOW_URL    = $(BASE)/$(SHOW)
_SEASON_URL  = $(BASE)/$(SHOW)/season:$(SEASON)
_EPISODE_URL = $(BASE)/$(SHOW)/season:$(SEASON)/videos/$(EPISODE)

# If COOKIE is set, use --force-cookies instead of the login file
_COOKIE_FLAG = $(if $(COOKIE),--force-cookies $(COOKIE),)

_RUN = $(DOCKER) run --rm -it \
	$(if $(COOKIE),,\-v $(LOGIN):/app/login) \
	-v $(OUT):/Downloads \
	$(IMAGE) \
	$(_COOKIE_FLAG) \
	--output-directory /Downloads \
	--captions \
	--quality $(QUALITY)

_LIST = $(DOCKER) run --rm -i \
	$(if $(COOKIE),,\-v $(LOGIN):/app/login) \
	$(IMAGE) \
	$(_COOKIE_FLAG)

UPSTREAM ?= https://github.com/mosswg/dropout-dl

.PHONY: help pull build episode season series list-shows list-seasons list-episodes sync sync-upstream clean get-session

help:
	@echo "$(BOLD)$(CYAN)dropout-dl$(RESET) — dropout.tv downloader"; echo
	@echo "$(BOLD)Download:$(RESET)"
	@echo "  $(GREEN)make episode$(RESET)       $(YELLOW)SHOW=<slug> SEASON=<n> EPISODE=<slug>$(RESET)"
	@echo "  $(GREEN)make season$(RESET)        $(YELLOW)SHOW=<slug> SEASON=<n>$(RESET)"
	@echo "  $(GREEN)make series$(RESET)        $(YELLOW)SHOW=<slug>$(RESET)"
	@echo ""; echo "$(BOLD)Browse:$(RESET)"
	@echo "  $(GREEN)make list-shows$(RESET)                                List all shows"
	@echo "  $(GREEN)make list-seasons$(RESET)  $(YELLOW)SHOW=<slug>$(RESET)                 List all seasons"
	@echo "  $(GREEN)make list-episodes$(RESET) $(YELLOW)SHOW=<slug> SEASON=<n>$(RESET)      List all episodes"
	@echo ""; echo "$(BOLD)Git:$(RESET)"
	@echo "  $(GREEN)make sync$(RESET)             Pull latest from fork"
	@echo "  $(GREEN)make sync-upstream$(RESET)    Pull upstream (mosswg) changes into fork"
	@echo ""; echo "$(BOLD)Session:$(RESET)"
	@echo "  $(GREEN)make get-session$(RESET)   Extract _session cookie from Firefox -> saves to $(SESSION)"
	@echo "                     Requires: log into watch.dropout.tv + pick a profile in Firefox"
	@echo ""; echo "$(BOLD)Image:$(RESET)"
	@echo "  $(GREEN)make pull$(RESET)    Pull latest image from GHCR"
	@echo "  $(GREEN)make build$(RESET)   Build local image from source"
	@echo "  $(GREEN)make clean$(RESET)   Remove local image"
	@echo ""; echo "$(BOLD)Variables:$(RESET)"
	@echo "  $(CYAN)IMAGE$(RESET)    = $(IMAGE)"
	@echo "  $(CYAN)QUALITY$(RESET)  = $(QUALITY)  (360p 480p 720p 1080p)"
	@echo "  $(CYAN)OUT$(RESET)      = $(OUT)"
	@echo "  $(CYAN)LOGIN$(RESET)    = $(LOGIN)"
	@echo "  $(CYAN)SESSION$(RESET)  = $(SESSION)  (auto-read as COOKIE when present)"
	@echo "  $(CYAN)PREFIX$(RESET)   = $(if $(PREFIX),$(PREFIX),(unset))  set to 1 to prefix filenames with S##E##"
	@echo ""; echo "$(BOLD)Example workflow:$(RESET)"
	@echo "  make list-shows"
	@echo "  make list-seasons  SHOW=crowd-control"
	@echo "  make list-episodes SHOW=crowd-control SEASON=2"
	@echo "  make episode       SHOW=crowd-control SEASON=2 EPISODE=3"
	@echo "  make episode       SHOW=crowd-control SEASON=2 EPISODE=3 PREFIX=1"
	@echo "  make season        SHOW=crowd-control SEASON=2 QUALITY=1080p"; echo

pull:
	@echo "$(BLUE)>>$(RESET) Pulling $(CYAN)$(IMAGE)$(RESET)..."
	@$(DOCKER) pull $(IMAGE)
	@echo "$(GREEN)✓$(RESET) Done"

build:
	@echo "$(BLUE)>>$(RESET) Building local image..."
	@$(DOCKER) build -t dropout-dl:local .
	@echo "$(GREEN)✓$(RESET) Built $(CYAN)dropout-dl:local$(RESET)"

clean:
	@echo "$(RED)>>$(RESET) Removing $(CYAN)dropout-dl:local$(RESET)..."
	@$(DOCKER) rmi dropout-dl:local 2>/dev/null || true
	@echo "$(GREEN)✓$(RESET) Done"

get-session:
	@if [ -z "$(FIREFOX_PROFILE)" ]; then \
		echo "$(RED)✗$(RESET) No Firefox profile found. Set $(CYAN)FIREFOX_PROFILE$(RESET)=<path>"; exit 1; \
	fi
	@echo "$(BLUE)>>$(RESET) Reading _session cookie from Firefox profile..."
	@tmp=$$(mktemp /tmp/cookies.XXXXXX.sqlite); \
	cp "$(FIREFOX_PROFILE)/cookies.sqlite" "$$tmp"; \
	val=$$(sqlite3 "$$tmp" \
		"SELECT value FROM moz_cookies WHERE host LIKE '%dropout.tv%' AND name='_session' LIMIT 1;"); \
	rm -f "$$tmp"; \
	if [ -z "$$val" ]; then \
		echo "$(RED)✗$(RESET) No _session cookie found — log into watch.dropout.tv and pick a profile in Firefox first"; exit 1; \
	fi; \
	printf '%s' "$$val" > "$(SESSION)"; \
	echo "$(GREEN)✓$(RESET) Session saved to $(CYAN)$(SESSION)$(RESET)"

episode:
ifndef SHOW
	@echo "$(RED)✗$(RESET) SHOW required: $(YELLOW)make episode SHOW=crowd-control SEASON=2 EPISODE=<n|slug>$(RESET)" && exit 1
endif
ifndef SEASON
	@echo "$(RED)✗$(RESET) SEASON required: $(YELLOW)make episode SHOW=$(SHOW) SEASON=<n> EPISODE=<n|slug>$(RESET)" && exit 1
endif
ifndef EPISODE
	@echo "$(RED)✗$(RESET) EPISODE required: $(YELLOW)make list-episodes SHOW=$(SHOW) SEASON=$(SEASON)$(RESET) to browse" && exit 1
endif
	@if echo "$(EPISODE)" | grep -qE '^[0-9]+$$'; then \
		slug=$$($(_LIST) --list -s "$(_SEASON_URL)" \
			| sed -n '$(EPISODE)p' | awk -F'\t' '{print $$2}' | sed 's|.*/||'); \
		if [ -z "$$slug" ]; then \
			echo "$(RED)✗$(RESET) Episode $(EPISODE) not found in season — run $(YELLOW)make list-episodes SHOW=$(SHOW) SEASON=$(SEASON)$(RESET)"; exit 1; \
		fi; \
		echo "$(BLUE)>>$(RESET) Downloading $(CYAN)$(BASE)/$(SHOW)/season:$(SEASON)/videos/$$slug$(RESET)"; \
		echo "$(BLUE)>>$(RESET) Quality: $(YELLOW)$(QUALITY)$(RESET)  Output: $(YELLOW)$(OUT)$(RESET)"; echo; \
		if [ -n "$(PREFIX)" ]; then \
			spads=$$(printf '%02d' $(SEASON)); epads=$$(printf '%02d' $(EPISODE)); \
			pfx="S$${spads}E$${epads}_"; outdir="$(OUT)"; \
			mkdir -p "$$outdir"; marker="$${outdir}/.pfx_marker_$$$$"; touch "$$marker"; \
			$(_RUN) -e "$(BASE)/$(SHOW)/season:$(SEASON)/videos/$$slug"; \
			find "$$outdir" -maxdepth 1 -type f -newer "$$marker" ! -name '.pfx_marker_*' | \
				while IFS= read -r f; do mv "$$f" "$$(dirname "$$f")/$${pfx}$$(basename "$$f")"; done; \
			rm -f "$$marker"; \
		else \
			$(_RUN) -e "$(BASE)/$(SHOW)/season:$(SEASON)/videos/$$slug"; \
		fi; \
	else \
		slug=$(EPISODE); \
		echo "$(BLUE)>>$(RESET) Downloading $(CYAN)$(_EPISODE_URL)$(RESET)"; \
		echo "$(BLUE)>>$(RESET) Quality: $(YELLOW)$(QUALITY)$(RESET)  Output: $(YELLOW)$(OUT)$(RESET)"; echo; \
		if [ -n "$(PREFIX)" ]; then \
			epnum=$$($(_LIST) --list -s "$(_SEASON_URL)" 2>/dev/null \
				| awk -F'\t' '{print $$2}' | sed 's|.*/||' \
				| awk "/^$$slug$$/{print NR; exit}"); \
			spads=$$(printf '%02d' $(SEASON)); epads=$$(printf '%02d' $${epnum:-0}); \
			pfx="S$${spads}E$${epads}_"; outdir="$(OUT)"; \
			mkdir -p "$$outdir"; marker="$${outdir}/.pfx_marker_$$$$"; touch "$$marker"; \
			$(_RUN) -e "$(_EPISODE_URL)"; \
			find "$$outdir" -maxdepth 1 -type f -newer "$$marker" ! -name '.pfx_marker_*' | \
				while IFS= read -r f; do mv "$$f" "$$(dirname "$$f")/$${pfx}$$(basename "$$f")"; done; \
			rm -f "$$marker"; \
		else \
			$(_RUN) -e "$(_EPISODE_URL)"; \
		fi; \
	fi

season:
ifndef SHOW
	@echo "$(RED)✗$(RESET) SHOW required: $(YELLOW)make season SHOW=crowd-control SEASON=2$(RESET)" && exit 1
endif
ifndef SEASON
	@echo "$(RED)✗$(RESET) SEASON required: $(YELLOW)make season SHOW=$(SHOW) SEASON=<n>$(RESET)" && exit 1
endif
	@echo "$(BLUE)>>$(RESET) Downloading $(CYAN)$(_SEASON_URL)$(RESET)"
	@echo "$(BLUE)>>$(RESET) Quality: $(YELLOW)$(QUALITY)$(RESET)  Output: $(YELLOW)$(OUT)$(RESET)"; echo
	@$(_RUN) -s "$(_SEASON_URL)"

series:
ifndef SHOW
	@echo "$(RED)✗$(RESET) SHOW required: $(YELLOW)make series SHOW=crowd-control$(RESET)" && exit 1
endif
	@echo "$(BLUE)>>$(RESET) Downloading $(CYAN)$(_SHOW_URL)$(RESET)"
	@echo "$(BLUE)>>$(RESET) Quality: $(YELLOW)$(QUALITY)$(RESET)  Output: $(YELLOW)$(OUT)$(RESET)"; echo
	@$(_RUN) -S "$(_SHOW_URL)"

sync:
	@echo "$(BLUE)>>$(RESET) Syncing overlay from $(shell git remote get-url fork 2>/dev/null && echo fork || echo origin)..."
	@remote=$$(git remote get-url fork 2>/dev/null && echo fork || echo origin); \
	 git fetch $$remote; \
	 git checkout overlay 2>/dev/null || git checkout -b overlay $$remote/overlay; \
	 git rebase $$remote/overlay
	@echo "$(GREEN)✓$(RESET) Up to date"

sync-upstream:
	@echo "$(BLUE)>>$(RESET) Pulling upstream (mosswg) into main, rebasing overlay..."
	@git remote get-url upstream 2>/dev/null || git remote add upstream $(UPSTREAM)
	@git fetch upstream
	@git checkout main
	@git rebase upstream/main
	@git push origin main
	@git checkout overlay
	@git rebase main
	@git push origin overlay
	@echo "$(GREEN)✓$(RESET) main and overlay synced with upstream"

list-shows:
	@echo "$(BLUE)>>$(RESET) Shows on dropout.tv"; echo
	@curl -s "https://watch.dropout.tv/sitemap.xml" \
		| grep -o '<loc>[^<]*</loc>' \
		| sed 's|<loc>https://watch.dropout.tv/||;s|</loc>||' \
		| grep -v '/' \
		| sed '/^$$/d;/^browse$$/d;/^login$$/d;/^checkout/d;/^buy\//d;/^plans$$/d;/^privacy$$/d;/^tos$$/d;/^cookies$$/d;/^help$$/d;/^faq$$/d;/^featured$$/d;/^dropout-24-7$$/d' \
		| sed -e 's/-season-[0-9][0-9]*//' -e '/-the-complete-experience/d' -e '/-complete-experience/d' \
		| sed '/^new-releases$$/d;/^trailers$$/d' \
		| sed 's/-new$$//' \
		| sort -u

list-seasons:
ifndef SHOW
	@echo "$(RED)✗$(RESET) SHOW required: $(YELLOW)make list-seasons SHOW=crowd-control$(RESET)" && exit 1
endif
	@echo "$(BLUE)>>$(RESET) Seasons in $(CYAN)$(SHOW)$(RESET)"; echo
	@$(_LIST) --list -S "$(_SHOW_URL)" 2>/dev/null | awk -F'\t' '{printf "%-40s %s\n", $$1, $$2}'

list-episodes:
ifndef SHOW
	@echo "$(RED)✗$(RESET) SHOW required: $(YELLOW)make list-episodes SHOW=crowd-control SEASON=2$(RESET)" && exit 1
endif
ifndef SEASON
	@echo "$(RED)✗$(RESET) SEASON required: $(YELLOW)make list-episodes SHOW=$(SHOW) SEASON=<n>$(RESET)" && exit 1
endif
	@echo "$(BLUE)>>$(RESET) Episodes in $(CYAN)$(SHOW)$(RESET) season $(CYAN)$(SEASON)$(RESET)"; echo
	@$(_LIST) --list -s "$(_SEASON_URL)" 2>/dev/null | awk -F'\t' '{printf "%-55s %s\n", $$1, $$2}'
