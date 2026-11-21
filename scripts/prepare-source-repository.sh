#!/bin/zsh
# Run once in Terminal. This deliberately refuses to relocate a repository with history.
set -eu
cd "${0:A:h}/.."
[[ ! -e .git ]] || { echo 'The root already has Git metadata; inspect it before continuing.' >&2; exit 1; }
[[ -d landing/.git ]] || { echo 'Expected landing/.git.' >&2; exit 1; }
[[ -z "$(git -C landing for-each-ref)" ]] || { echo 'History exists: use a history-preserving subtree import instead.' >&2; exit 1; }
[[ -z "$(git -C landing ls-files)" ]] || { echo 'The nested index is not empty; inspect it before relocating.' >&2; exit 1; }
[[ -z "$(git -C landing remote)" ]] || { echo 'A remote exists; inspect its history before relocating.' >&2; exit 1; }
git -C landing fsck --full
backup="dist/repository-backups/landing-git-$(date +%Y%m%d-%H%M%S).tar"
mkdir -p dist/repository-backups
tar -cf "$backup" landing/.git
mv landing/.git .git
echo "Moved Git metadata without deleting it. Backup: $backup"
git status --short --branch
