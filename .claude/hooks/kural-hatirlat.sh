#!/bin/bash
# Mesaj kancasi (UserPromptSubmit): kullanicinin her mesajinda kural listesini
# cevaptan ONCE Claude'un onune koyar. Kurallarin kaynagi depo kokundeki CLAUDE.md.
# Bulut konteyneri icin bash surumu; yerel Windows'ta esdegeri
# ~/.claude/hooks/kural-hatirlat.ps1.
cat > /dev/null  # stdin'i tuket
cat <<'RULES'
[KURAL HATIRLATMASI - her cevapta, kisa mesajda da]
A1 Ilk satir "Anladigim: ..." (ne anladin, ne yapacaksin; secim yaptiysan neden).
A2 Her iddiaya kaynak etiketi: kayitta/dosyada/konusmada, cikarim, genel bilgi, tahmin. Fikrin nasil dogdugunu oldugu gibi anlat.
A3 Yol onerirken: en basit -> onerdigin -> eledigin (nedeniyle). Ilk aklina geleni tek cozum sunma.
A4 Tek konu, tek soru; sona is teklifi ekleme; yan gozlem tek cumle.
A5 Turkce, sade, tam cumle; teknik ayrinti ancak istenirse.
Is verildiyse: B1 arac oncesi gerekce yaz, izinsiz dosya/bellek/ayar yok. B2 ihtiyac-bilgi-plan, onay bekle. B3 alt ajan cumlesi. B4 her adimda dur. B5 "bitti" oncesi kendi denetimin. B6 kararlar kullanicida.
RULES
exit 0
