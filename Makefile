RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
CYAN   := \033[0;36m
MAGENTA := \033[0;35m
BOLD   := \033[1m
RESET  := \033[0m

IMAGE   ?= ghcr.io/slmingol/dropout-dl:overlay
QUALITY ?= 720p
OUT     ?= $(PWD)/out
LOGIN   ?= $(PWD)/login
PREFIX  ?=

BASE    := https://watch.dropout.tv

_SHOW_URL    = $(BASE)/$(SHOW)
_SEASON_URL  = $(BASE)/$(SHOW)/season:$(SEASON)
_EPISODE_URL = $(BASE)/$(SHOW)/season:$(SEASON)/videos/$(EPISODE)

_RUN = docker run --rm -it \
	-v $(LOGIN):/app/login \
	-v $(OUT):/Downloads \
	$(IMAGE) \
	--output-directory /Downloads \
	--captions \
	--quality $(QUALITY)

_LIST = docker run --rm -i \
	-v $(LOGIN):/app/login \
	$(IMAGE)

UPSTREAM ?= https://github.com/mosswg/dropout-dl

.PHONY: help pull build episode season series list-shows list-seasons list-episodes sync sync-upstream clean

help:
	@printf "$(BOLD)$(CYAN)dropout-dl$(RESET) — dropout.tv downloader\n\n"
	@printf "$(BOLD)Download:$(RESET)\n"
	@printf "  $(GREEN)make episode$(RESET)       $(YELLOW)SHOW=<slug> SEASON=<n> EPISODE=<slug>$(RESET)\n"
	@printf "  $(GREEN)make season$(RESET)        $(YELLOW)SHOW=<slug> SEASON=<n>$(RESET)\n"
	@printf "  $(GREEN)make series$(RESET)        $(YELLOW)SHOW=<slug>$(RESET)\n"
	@printf "\n$(BOLD)Browse:$(RESET)\n"
	@printf "  $(GREEN)make list-shows$(RESET)                                List all shows\n"
	@printf "  $(GREEN)make list-seasons$(RESET)  $(YELLOW)SHOW=<slug>$(RESET)                 List all seasons\n"
	@printf "  $(GREEN)make list-episodes$(RESET) $(YELLOW)SHOW=<slug> SEASON=<n>$(RESET)      List all episodes\n"
	@printf "\n$(BOLD)Git:$(RESET)\n"
	@printf "  $(GREEN)make sync$(RESET)             Pull latest from fork\n"
	@printf "  $(GREEN)make sync-upstream$(RESET)    Pull upstream (mosswg) changes into fork\n"
	@printf "\n$(BOLD)Image:$(RESET)\n"
	@printf "  $(GREEN)make pull$(RESET)    Pull latest image from GHCR\n"
	@printf "  $(GREEN)make build$(RESET)   Build local image from source\n"
	@printf "  $(GREEN)make clean$(RESET)   Remove local image\n"
	@printf "\n$(BOLD)Variables:$(RESET)\n"
	@printf "  $(CYAN)IMAGE$(RESET)    = $(IMAGE)\n"
	@printf "  $(CYAN)QUALITY$(RESET)  = $(QUALITY)  (360p 480p 720p 1080p)\n"
	@printf "  $(CYAN)OUT$(RESET)      = $(OUT)\n"
	@printf "  $(CYAN)LOGIN$(RESET)    = $(LOGIN)\n"
	@printf "  $(CYAN)PREFIX$(RESET)   = $(if $(PREFIX),$(PREFIX),(unset))  set to 1 to prefix filenames with S##E##\n"
	@printf "\n$(BOLD)Example workflow:$(RESET)\n"
	@printf "  make list-shows\n"
	@printf "  make list-seasons  SHOW=crowd-control\n"
	@printf "  make list-episodes SHOW=crowd-control SEASON=2\n"
	@printf "  make episode       SHOW=crowd-control SEASON=2 EPISODE=3\n"
	@printf "  make episode       SHOW=crowd-control SEASON=2 EPISODE=3 PREFIX=1\n"
	@printf "  make season        SHOW=crowd-control SEASON=2 QUALITY=1080p\n\n"

pull:
	@printf "$(BLUE)>>$(RESET) Pulling $(CYAN)$(IMAGE)$(RESET)...\n"
	@docker pull $(IMAGE)
	@printf "$(GREEN)✓$(RESET) Done\n"

build:
	@printf "$(BLUE)>>$(RESET) Building local image...\n"
	@docker build -t dropout-dl:local .
	@printf "$(GREEN)✓$(RESET) Built $(CYAN)dropout-dl:local$(RESET)\n"

clean:
	@printf "$(RED)>>$(RESET) Removing $(CYAN)dropout-dl:local$(RESET)...\n"
	@docker rmi dropout-dl:local 2>/dev/null || true
	@printf "$(GREEN)✓$(RESET) Done\n"

episode:
ifndef SHOW
	@printf "$(RED)✗$(RESET) SHOW required: $(YELLOW)make episode SHOW=crowd-control SEASON=2 EPISODE=<n|slug>$(RESET)\n" && exit 1
endif
ifndef SEASON
	@printf "$(RED)✗$(RESET) SEASON required: $(YELLOW)make episode SHOW=$(SHOW) SEASON=<n> EPISODE=<n|slug>$(RESET)\n" && exit 1
endif
ifndef EPISODE
	@printf "$(RED)✗$(RESET) EPISODE required: $(YELLOW)make list-episodes SHOW=$(SHOW) SEASON=$(SEASON)$(RESET) to browse\n" && exit 1
endif
	@if echo "$(EPISODE)" | grep -qE '^[0-9]+$$'; then \
		slug=$$(docker run --rm -i -v $(LOGIN):/app/login $(IMAGE) --list -s "$(_SEASON_URL)" \
			| sed -n '$(EPISODE)p' | awk -F'\t' '{print $$2}' | sed 's|.*/||'); \
		if [ -z "$$slug" ]; then \
			printf "$(RED)✗$(RESET) Episode $(EPISODE) not found in season — run $(YELLOW)make list-episodes SHOW=$(SHOW) SEASON=$(SEASON)$(RESET)\n"; exit 1; \
		fi; \
		printf "$(BLUE)>>$(RESET) Downloading $(CYAN)$(BASE)/$(SHOW)/season:$(SEASON)/videos/$$slug$(RESET)\n"; \
		printf "$(BLUE)>>$(RESET) Quality: $(YELLOW)$(QUALITY)$(RESET)  Output: $(YELLOW)$(OUT)$(RESET)\n\n"; \
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
		printf "$(BLUE)>>$(RESET) Downloading $(CYAN)$(_EPISODE_URL)$(RESET)\n"; \
		printf "$(BLUE)>>$(RESET) Quality: $(YELLOW)$(QUALITY)$(RESET)  Output: $(YELLOW)$(OUT)$(RESET)\n\n"; \
		if [ -n "$(PREFIX)" ]; then \
			epnum=$$(docker run --rm -i -v $(LOGIN):/app/login $(IMAGE) --list -s "$(_SEASON_URL)" 2>/dev/null \
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
	@printf "$(RED)✗$(RESET) SHOW required: $(YELLOW)make season SHOW=crowd-control SEASON=2$(RESET)\n" && exit 1
endif
ifndef SEASON
	@printf "$(RED)✗$(RESET) SEASON required: $(YELLOW)make season SHOW=$(SHOW) SEASON=<n>$(RESET)\n" && exit 1
endif
	@printf "$(BLUE)>>$(RESET) Downloading $(CYAN)$(_SEASON_URL)$(RESET)\n"
	@printf "$(BLUE)>>$(RESET) Quality: $(YELLOW)$(QUALITY)$(RESET)  Output: $(YELLOW)$(OUT)$(RESET)\n\n"
	@$(_RUN) -s "$(_SEASON_URL)"

series:
ifndef SHOW
	@printf "$(RED)✗$(RESET) SHOW required: $(YELLOW)make series SHOW=crowd-control$(RESET)\n" && exit 1
endif
	@printf "$(BLUE)>>$(RESET) Downloading $(CYAN)$(_SHOW_URL)$(RESET)\n"
	@printf "$(BLUE)>>$(RESET) Quality: $(YELLOW)$(QUALITY)$(RESET)  Output: $(YELLOW)$(OUT)$(RESET)\n\n"
	@$(_RUN) -S "$(_SHOW_URL)"

sync:
	@printf "$(BLUE)>>$(RESET) Syncing overlay from origin...\n"
	@git checkout overlay 2>/dev/null || true
	@git pull --rebase origin overlay
	@printf "$(GREEN)✓$(RESET) Up to date\n"

sync-upstream:
	@printf "$(BLUE)>>$(RESET) Pulling upstream (mosswg) into main, rebasing overlay...\n"
	@git remote get-url upstream 2>/dev/null || git remote add upstream $(UPSTREAM)
	@git fetch upstream
	@git checkout main
	@git rebase upstream/main
	@git push origin main
	@git checkout overlay
	@git rebase main
	@git push origin overlay
	@printf "$(GREEN)✓$(RESET) main and overlay synced with upstream\n"

list-shows:
	@printf "$(BLUE)>>$(RESET) Shows on dropout.tv\n\n"
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
	@printf "$(RED)✗$(RESET) SHOW required: $(YELLOW)make list-seasons SHOW=crowd-control$(RESET)\n" && exit 1
endif
	@printf "$(BLUE)>>$(RESET) Seasons in $(CYAN)$(SHOW)$(RESET)\n\n"
	@$(_LIST) --list -S "$(_SHOW_URL)" 2>/dev/null | awk -F'\t' '{printf "%-40s %s\n", $$1, $$2}'

list-episodes:
ifndef SHOW
	@printf "$(RED)✗$(RESET) SHOW required: $(YELLOW)make list-episodes SHOW=crowd-control SEASON=2$(RESET)\n" && exit 1
endif
ifndef SEASON
	@printf "$(RED)✗$(RESET) SEASON required: $(YELLOW)make list-episodes SHOW=$(SHOW) SEASON=<n>$(RESET)\n" && exit 1
endif
	@printf "$(BLUE)>>$(RESET) Episodes in $(CYAN)$(SHOW)$(RESET) season $(CYAN)$(SEASON)$(RESET)\n\n"
	@$(_LIST) --list -s "$(_SEASON_URL)" 2>/dev/null | awk -F'\t' '{printf "%-55s %s\n", $$1, $$2}'
