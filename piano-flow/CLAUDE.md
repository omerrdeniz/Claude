# CLAUDE.md — Piano Flow

> Genel çalışma kuralları deponun kökündeki `CLAUDE.md` dosyasındadır; bu
> dosya yalnızca Piano Flow'a özgü kuralları içerir. Proje `piano-flow/`
> alt klasöründedir; `flutter`, `dart run tool/...` ve `tool/deploy.sh`
> komutları bu klasörün içinden çalıştırılır.

## Önce oku

**Kod yazmadan önce [`docs/DURUM.md`](docs/DURUM.md).** Bu projenin hafızası
orada: alınan kararlar, denenip **reddedilenler**, ölçülmüş maliyetler ve
tekrarlanmış hatalar. Bir öneride bulunmadan önce "Reddedilenler — tekrar
önermeyin" bölümüne bakın; oradaki maddelerin çoğu cihazda denendi ve
gerekçesiyle elendi.

Bir karar DURUM.md'ye aykırıysa önce bunu söyleyin, sonra devam edin.
İşiniz bittiğinde öğrendiğiniz yeni şeyi DURUM.md'ye yazın.

## Çekirdek kural

**Dokunuş her zaman doğru notayı çalar.** Oyuncu yanlış perde çalamaz,
yalnızca yanlış an seçebilir. Buna aykırı hiçbir şey eklenmez.

İkinci kural: **oyuncu basmadan ses çıkmaz.** (`fillMissed` bunun tek
istisnası ve varsayılan olarak kapalı.)

---

# Projeye özgü kurallar

## Ölçmeden optimize etme

DURUM.md'deki **"Ölçülmüş maliyetler"** tablosuna bakın. 60 fps bütçesi kare
başına 16700 µs; çizim 314 µs, ses 155 µs harcıyor. **Ne çizim ne ses
darboğaz.** Performans gerekçesiyle bir değişiklik önereceksen önce ölç.

## Tek saat kuralı

Dokunuşu notayla eşleme, isabeti değerlendirme ve kaçmış notayı silme —
üçü de `PlaySession._judgedBeat` kullanır. Biri gecikmeyi telafi edip
diğeri etmezse aralarında sessiz bir bant kalır ve oyun "bazen algılıyor
bazen algılamıyor" hâle gelir. `test/play_session_test.dart` içindeki
"with a latency to compensate for" grubu bunu kilitler.

## Vuruş değil saniye

Zamanlama toleransları saniye cinsindendir, vuruş cinsinden değil. Bu hata
üç kez yapıldı.

## Üretilmiş dosyalara elle dokunma

`lib/data/catalog.g.dart` ve `assets/songs/` üretilir. Şarkı
`tool/catalog.dart`'a eklenir, sonra `dart tool/build_library.dart` çalışır.

## Ayarları geçirmeyi unutma

`lib/screens/song_list/song_tile.dart` içindeki `MaterialPageRoute`
**her ayarı** `PlayScreen`'e geçirmeli. İki kez unutuldu.
`test/song_list_test.dart` doğruluyor.

## Kontroller sahayı dinlemez, sesi kendileri uyandırır

`PlayScreen`'de dokunuşu dinleyen `Listener` **yalnız oyun sahasını** sarar;
düğmeler ve paneller `Stack`'te onun üstünde ayrı çocuklardır. İçine alınırsa
ata dinleyici olayı her hâlükârda alır: duraklat düğmesine basmak bir nota
çalar ve puan yazar. Üstte kalan süs katmanları `IgnorePointer` ile sarılır —
`ColoredBox` ve metin (`RenderParagraph.hitTestSelf`) dokunuşu yutar, yani
ilerleme çubuğu ve başlık yazısı sarılmazsa sahaya giden parmağı engeller.

Bunun karşılığı olarak düğmeler sesi **kendileri** uyandırır: `_audio.nudge()`
`_togglePause` ve `_restart` başında çağrılır (tarayıcı sesi yalnız bir
dokunuşun içinden açar). Bu iki satırı kilitleyen test yok; `PlayScreen`
`PianoAudio`'yu kendi kuruyor.

`test/play_screen_test.dart` → "reaching for a control does not also play a note".

## Kalibrasyon testlerinde `pumpAndSettle` yok

Ekran durduğu sürece bir ticker çalışır, hiç durulmaz, test zaman aşımına
uğrar. Açık `pump` kullanın (`test/calibration_screen_test.dart` →
`settleRoute`).

## Her değişiklikten sonra

```bash
flutter analyze
flutter test
```

İkisi de temiz olmadan iş bitmiş sayılmaz. Cihazsız doğrulama adımları
DURUM.md'deki "Cihazsız doğrulama" bölümünde.
