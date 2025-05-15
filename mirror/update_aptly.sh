#!/bin/bash
set -euo pipefail

# CONFIGURATION
export APTLY_HOME="/home/username/.aptly"          # ← adapte si besoin
MIRROR_MAIN="plucky"                            # miroir distant Ubuntu
LOCAL_REPOS=(common-extra dev-extra admin-extra sec-extra)   # dépôts locaux par profil
ARCHS="amd64"
RETENTION_DAYS=7                                # conserver 7 jours de snapshots
TODAY=$(date +%Y%m%d-%H%M)

# 1 ─ Mise à jour du miroir principal
echo "Update mirror $MIRROR_MAIN"
aptly mirror update "$MIRROR_MAIN"

# 2 ─ Mise à jour des dépôts locaux (si nouveaux paquets .deb ajoutés)
for repo in "${LOCAL_REPOS[@]}"; do
  echo "Checking local repo $repo"
  aptly repo show "$repo" >/dev/null 2>&1 || {
    echo "Local repo $repo not found, skipping."
    continue
  }
  # Pas de commande 'update' pour un repo local, on se contente de le snapshotter
done

# 3 ─ Création des snapshots datés
echo "Creating snapshots"
SNAP_MAIN="${MIRROR_MAIN}-snap-${TODAY}"
aptly snapshot create "$SNAP_MAIN" from mirror "$MIRROR_MAIN"

declare -A SNAP_EXTRA
for repo in "${LOCAL_REPOS[@]}"; do
  SNAP_EXTRA[$repo]="${repo}-${TODAY}"
  aptly snapshot create "${SNAP_EXTRA[$repo]}" from repo "$repo"
done

# 4 ─ Fusion par profil
echo "Merging snapshots"
SNAP_COMMON="common-merged-${TODAY}"
SNAP_DEV="dev-merged-${TODAY}"
SNAP_ADMIN="admin-merged-${TODAY}"
SNAP_SEC="sec-merged-${TODAY}"

aptly snapshot merge -latest "$SNAP_COMMON"   "$SNAP_MAIN"   "${SNAP_EXTRA[common-extra]}"
aptly snapshot merge -latest "$SNAP_DEV"   "$SNAP_MAIN"   "${SNAP_EXTRA[dev-extra]}"
aptly snapshot merge -latest "$SNAP_ADMIN" "$SNAP_MAIN"   "${SNAP_EXTRA[admin-extra]}"
aptly snapshot merge -latest "$SNAP_SEC"   "$SNAP_MAIN"   "${SNAP_EXTRA[sec-extra]}"

# 5 ─ Publication multi-composants
echo "Publishing distribution plucky (components: main,common,dev,admin,sec)"
aptly publish drop plucky || true   # ignore si pas encore publié

aptly publish snapshot \
      -component=main,common,dev,admin,sec \
      -distribution=plucky \
      -architectures="$ARCHS" \
      "$SNAP_MAIN" "$SNAP_COMMON" "$SNAP_DEV" "$SNAP_ADMIN" "$SNAP_SEC"

# 6 ─ Permissions Web
chmod o+x "$APTLY_HOME/public"
chmod -R o+r "$APTLY_HOME/public"

# 7 ─ Nettoyage snapshots trop anciens
echo "Cleaning snapshots older than $RETENTION_DAYS days"
CUTOFF=$(date -d "$RETENTION_DAYS days ago" +%s)
aptly snapshot list -raw | while read snap; do
  # Extrait la date AAAAMMJJ à la fin du nom
  DATE=$(echo "$snap" | grep -oE '[0-9]{8}$' || true)
  if [[ -n "$DATE" ]]; then
      TS=$(date -d "$DATE" +%s)
      if (( TS < CUTOFF )); then
          echo "  - dropping $snap"
          aptly snapshot drop "$snap"
      fi
  fi
done

echo "Publish complete — your mirror is up to date."
