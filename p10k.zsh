# =============================================================================
# ~/.p10k.zsh — Powerlevel10k prompt configuration
# Style  : Classic (powerline arrows, coloured segment backgrounds)
# Prompt : Two-line  |  os_icon  dir  git  ❯
#                    |  status  exec-time  jobs  python  node  time
#
# To regenerate interactively run: p10k configure
# Reference: https://github.com/romkatv/powerlevel10k
# =============================================================================

# Temporarily change options so the config can use brace expansion etc.
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  # Wipe any previously set POWERLEVEL9K variables (except gitstatus dir).
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

  # Require zsh >= 5.1
  autoload -Uz is-at-least && is-at-least 5.1 || return

  # ---------------------------------------------------------------------------
  # Icon mode — nerdfont-v3 matches the fonts installed by setup.sh
  # ---------------------------------------------------------------------------
  typeset -g POWERLEVEL9K_MODE=nerdfont-v3
  typeset -g POWERLEVEL9K_ICON_PADDING=none

  # ---------------------------------------------------------------------------
  # Prompt layout
  # ---------------------------------------------------------------------------
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true

  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    os_icon               # distro icon
    dir                   # current directory
    vcs                   # git status
    newline               # ↵ second line
    prompt_char           # ❯ / ❮ changes colour on error
  )

  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status                # exit code of last command
    command_execution_time # how long the last command took
    background_jobs       # number of background jobs
    virtualenv            # python venv
    node_version          # node version (only in node projects)
    time                  # current time
  )

  # ---------------------------------------------------------------------------
  # Segment separators — powerline arrows
  # ---------------------------------------------------------------------------
  typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR='\uE0B0'
  typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR='\uE0B2'
  typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR='\uE0B1'
  typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR='\uE0B3'
  typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL='\uE0B0'
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL='\uE0B2'
  typeset -g POWERLEVEL9K_EMPTY_LINE_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=

  # ---------------------------------------------------------------------------
  # OS icon
  # ---------------------------------------------------------------------------
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=232
  typeset -g POWERLEVEL9K_OS_ICON_BACKGROUND=7

  # ---------------------------------------------------------------------------
  # Directory
  # ---------------------------------------------------------------------------
  typeset -g POWERLEVEL9K_DIR_BACKGROUND=4
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=254
  typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=150
  typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=255
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=true

  # Shorten long paths by truncating to unique prefix
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
  typeset -g POWERLEVEL9K_SHORTEN_DELIMITER=
  typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=40
  typeset -g POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER=false

  # Show lock icon when directory is not writable
  typeset -g POWERLEVEL9K_DIR_NOT_WRITABLE_VISUAL_IDENTIFIER_EXPANSION='  '
  typeset -g POWERLEVEL9K_DIR_CLASSES=()

  # ---------------------------------------------------------------------------
  # VCS (git)
  # ---------------------------------------------------------------------------
  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON='\uF126 '

  # Clean repo
  typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND=2
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=0

  # Repo with uncommitted changes
  typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND=3
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=0

  # Repo with untracked files
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND=3
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=0
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_ICON='?'

  # Show remote tracking info (ahead/behind)
  typeset -g POWERLEVEL9K_VCS_BACKENDS=(git)
  typeset -g POWERLEVEL9K_VCS_GIT_HOOKS=(vcs-detect-changes git-untracked git-aheadbehind git-stash git-remotebranch git-tagname)

  # ---------------------------------------------------------------------------
  # Prompt character (the ❯ symbol)
  # ---------------------------------------------------------------------------
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=76
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=196
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION='❯'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VICMD_CONTENT_EXPANSION='❮'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIVIS_CONTENT_EXPANSION='V'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIOWR_CONTENT_EXPANSION='▶'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE=true
  typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=
  typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=

  # ---------------------------------------------------------------------------
  # Status (exit code)
  # ---------------------------------------------------------------------------
  typeset -g POWERLEVEL9K_STATUS_EXTENDED_STATES=true

  # Don't show a segment when the command succeeds
  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_STATUS_OK_FOREGROUND=70
  typeset -g POWERLEVEL9K_STATUS_OK_BACKGROUND=0
  typeset -g POWERLEVEL9K_STATUS_OK_PIPE=true
  typeset -g POWERLEVEL9K_STATUS_OK_PIPE_FOREGROUND=70
  typeset -g POWERLEVEL9K_STATUS_OK_PIPE_BACKGROUND=0

  # Show a red segment when the command fails
  typeset -g POWERLEVEL9K_STATUS_ERROR=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=160
  typeset -g POWERLEVEL9K_STATUS_ERROR_BACKGROUND=0
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_FOREGROUND=160
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_BACKGROUND=0
  typeset -g POWERLEVEL9K_STATUS_VERBOSE_SIGNAME=false
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND=160
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_BACKGROUND=0

  # ---------------------------------------------------------------------------
  # Command execution time
  # ---------------------------------------------------------------------------
  # Only show when command takes longer than this many seconds
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION=1
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=248
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_BACKGROUND=0
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FORMAT='d h m s'

  # ---------------------------------------------------------------------------
  # Background jobs
  # ---------------------------------------------------------------------------
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE=false
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND=70
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_BACKGROUND=0

  # ---------------------------------------------------------------------------
  # Python virtualenv
  # ---------------------------------------------------------------------------
  typeset -g POWERLEVEL9K_VIRTUALENV_FOREGROUND=37
  typeset -g POWERLEVEL9K_VIRTUALENV_BACKGROUND=0
  typeset -g POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION=false
  typeset -g POWERLEVEL9K_VIRTUALENV_SHOW_WITH_PYENV=false
  typeset -g POWERLEVEL9K_VIRTUALENV_{LEFT,RIGHT}_DELIMITER=

  # ---------------------------------------------------------------------------
  # Node.js version  (only shown inside a node project)
  # ---------------------------------------------------------------------------
  typeset -g POWERLEVEL9K_NODE_VERSION_PROJECT_ONLY=true
  typeset -g POWERLEVEL9K_NODE_VERSION_FOREGROUND=70
  typeset -g POWERLEVEL9K_NODE_VERSION_BACKGROUND=0
  typeset -g POWERLEVEL9K_NODE_ICON='\uF898'

  # ---------------------------------------------------------------------------
  # Time
  # ---------------------------------------------------------------------------
  typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M:%S}'
  typeset -g POWERLEVEL9K_TIME_FOREGROUND=66
  typeset -g POWERLEVEL9K_TIME_BACKGROUND=0
  typeset -g POWERLEVEL9K_TIME_UPDATE_ON_COMMAND=false

  # ---------------------------------------------------------------------------
  # Transient prompt
  # Replaces previous prompts with a compact one-liner to save screen space.
  # ---------------------------------------------------------------------------
  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=always

  # ---------------------------------------------------------------------------
  # Instant prompt
  # ---------------------------------------------------------------------------
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=verbose

  # Hot reload — apply config changes without restarting the shell
  typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=false

  # Reload p10k if it is already loaded
  (( ! $+functions[p10k] )) || p10k reload
}

# Restore options
(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
