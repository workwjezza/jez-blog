#!/bin/zsh
set -e
cd "${0:A:h}"
if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  source "$HOME/.nvm/nvm.sh"
  nvm use 24 >/dev/null
fi
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if ! command -v node >/dev/null; then
  echo "Node 24 is required. Install it, then open this launcher again."
  exit 1
fi
if [[ ! -d node_modules ]]; then npm ci; fi
cd editor
if [[ ! -d node_modules ]]; then npm ci; fi
npm run build
exec node server/index.mjs --open