#!/bin/bash
# Bitirme kancasi (Stop): cevap kapatilmadan once bir kez durdurur ve oz denetim ister.
# Ikinci tetiklemede (stop_hook_active = true) gecer; sonsuz dongu olmaz.
# Bulut konteyneri icin bash surumu; yerel Windows'ta esdegeri
# ~/.claude/hooks/kural-denetim.ps1. JSON'u Node okur (konteynerde ve yerelde var).
raw=$(cat)
command -v node > /dev/null 2>&1 || exit 0

# Node: stop_hook_active ise "SKIP"; degilse kullanicinin son metin mesajindan
# sonraki ILK asistan metnini bulur ve A1 kontrolunu yapar. Cikti: bulgu satiri.
bulgu=$(printf '%s' "$raw" | node -e '
let raw = "";
process.stdin.on("data", d => raw += d);
process.stdin.on("end", () => {
  let inp; try { inp = JSON.parse(raw); } catch { process.stdout.write("SKIP"); return; }
  if (inp.stop_hook_active === true) { process.stdout.write("SKIP"); return; }
  let first = null;
  try {
    const fs = require("fs");
    const lines = fs.readFileSync(inp.transcript_path, "utf8").split("\n").slice(-600);
    let afterUser = false;
    for (const line of lines) {
      let e; try { e = JSON.parse(line); } catch { continue; }
      if (e.type === "user") {
        const c = e.message && e.message.content;
        let isText = typeof c === "string";
        if (!isText && Array.isArray(c)) for (const b of c) if (b.type === "text") isText = true;
        if (isText) { afterUser = true; first = null; }
      } else if (e.type === "assistant" && afterUser && first === null) {
        const c = e.message && e.message.content;
        if (Array.isArray(c)) for (const b of c) {
          if (b.type === "text" && b.text && b.text.trim().length > 0) { first = String(b.text); break; }
        }
      }
    }
  } catch { first = null; }
  if (first === null) first = String(inp.last_assistant_message || "");
  const ok = /^\s*Anlad\S{0,6}m\s*:/m.test(first);
  process.stdout.write(ok ? "bicimsel eksik yok" : "A1: ilk satir '"'"'Anladigim:'"'"' yok");
});
')
[ "$bulgu" = "SKIP" ] && exit 0

cat >&2 <<REASON
[OZ DENETIM - cevabi kapatmadan once]
Yazdigin cevabi su listeyle karsilastir: A1 'Anladigim:' ilk satir | A2 kaynak etiketleri | A3 secenekler basitten | A4 tek konu, tek soru, is teklifi yok | A5 sade Turkce | is varsa B1-B6 (gerekce, plan+onay, alt ajan cumlesi, adimda dur, kendi denetimi, karar kullanicida). B5 icin: 'bitti' diyorsan plandaki denetim maddelerinden (bes soru: kaynak, genisletme, varsayilan, sinir, sahiplik) TEK TURDA gectin mi?
Betigin bulgusu: $bulgu
Eksik varsa: eksigi gideren kisa duzeltmeyi yaz. Eksik yoksa: YALNIZCA tek satir iz yaz, ornek: "Kurallar: A1 + A2 + A3 - A4 + A5 + | B: is yok". Baska hicbir sey ekleme.
REASON
exit 2
