#!/bin/bash
# Add a KWin window rule that stops BetterGI's overlay (MaskWindow) from being maximized.
# Under Wine the overlay sometimes ends up maximized; WPF then refuses to show it
# ("Cannot show Window when ShowActivated is false and WindowState is set to Maximized"),
# every BetterGI task fails at TaskRunner.Init and BetterGI idles until the chain's timeout.
# KDE Plasma (X11) only. Remove it again in System Settings -> Window Rules.
set -e
F="$HOME/.config/kwinrulesrc"
ID=bettergi-no-maximize
KW=$(command -v kwriteconfig6 || command -v kwriteconfig5) || { echo "kwriteconfig5/6 not found (KDE only)" >&2; exit 1; }
k() { "$KW" --file "$F" --group "$ID" --key "$1" "$2"; }
k Description "BetterGI MaskWindow: never maximize (Show() crash under Wine)"
# Proton's wine names windows of programs not started by Steam "steam_proton"
k wmclass steam_proton; k wmclassmatch 1; k wmclasscomplete false
k title MaskWindow; k titlematch 1
k maximizehoriz false; k maximizehorizrule 2
k maximizevert false; k maximizevertrule 2
rules=$(kreadconfig6 --file "$F" --group General --key rules 2>/dev/null || kreadconfig5 --file "$F" --group General --key rules 2>/dev/null || true)
case ",$rules," in
  *",$ID,"*) ;;
  *) rules="${rules:+$rules,}$ID"
     "$KW" --file "$F" --group General --key rules "$rules"
     "$KW" --file "$F" --group General --key count "$(tr ',' '\n' <<<"$rules" | grep -c .)" ;;
esac
for q in qdbus6 qdbus qdbus-qt5; do
  command -v "$q" >/dev/null && "$q" org.kde.KWin /KWin reconfigure && break
done
echo "KWin rule '$ID' added"
