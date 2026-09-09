# Durum ve devir notu

Bu dosya, sohbet geçmişi olmayan yeni bir oturumun projeyi kaldığı yerden
sürdürebilmesi için yazıldı. Son güncelleme: `a6614d0` derlemesi.

## Proje

**Piano Flow** — App Store'daki Magic Piano (Smule) oyununun daha gelişmiş bir
sürümü. Flutter, iOS + Android, ayrıca test için web.

Çekirdek kural: **dokunuş her zaman doğru notayı çalar.** Oyuncu yanlış perde
çalamaz, yalnızca yanlış an seçebilir.

Dal: `claude/magic-piano-app-store-py724t`. Tüm geliştirme burada.

## Oynanış kararları

Bunlar oyuncunun (proje sahibinin) geri bildirimiyle şekillendi. **Yeniden
tartışmaya açmadan önce buraya bakın** — bir kısmı zaten denenip reddedildi.

### Kabul edilenler

- **Şerit yok.** Notalar ekranın herhangi bir yerinden gelir, konumu perdeden
  türetilir. (Önce 4 şeritli bir düzen yapıldı, oyuncu "Magic piano'da şerit
  yok" diyerek reddetti.)
- **Renk = akorun kaç nota olduğu.** Tekli mor, ikili sarı, üçlü mavi, dörtlü
  yeşil. Perdeye göre renk **yok**. `Tap.voices` bunu tutar ve dokunuş değil
  **nota** sayar; yani kolay modda akor tek parmakla basılsa bile üçlü akor
  mavi görünür.
- **Akorun her notası ayrı çizilir.** Tek parmakla basılsa bile üç nota üç
  daire olarak görünür (`Tap.noteAcross`), arkalarında onları birleştiren bir
  şerit/bant vardır.
- **Normal zorlukta hiçbir şey kendi kendine çalmaz.** Oyuncu "şarkının benim
  çalmadığım kısımları var" dedi; yalnızca Kolay modda seyreltme yapılır
  (yarım vuruşta bir moment kalır, gerisi `autoNotes`'a gider).
- **Eller ayrılır.** Ekranın sol yarısı sol el, sağ yarısı sağ el. Zorluğun
  asıl anlamı bu:
  - Kolay: tek alan, akor tek parmakla, seyreltme var.
  - Normal: eller ayrı, akor her elde tek parmakla.
  - Zor: eller ayrı, akorun her notası ayrı parmakla.
- **Basılı tutma** mekaniği var. Tutma çubuğu, tutulması gereken süre kadar
  uzundur ve kuyruğu çizgiyi geçene kadar ekranda kalır.
- **Tolerans bir ayardır.** `TimingTolerance { wide, normal, tight }` —
  çarpanlar 1.8 / 1.0 / 0.6. Erken basışlar kuyruğa alınıp **kendi vuruşunda**
  seslendirilir (quantize anahtarı), geç basışlar hemen çalar.
- **Hem dikey hem yatay** oynanabilir.
- **Şarkılar kendi temposunda.** Hız seçici kaldırıldı (`speed` parametresi
  `PlaySession`'da duruyor ama arayüzde yok).

### Reddedilenler — tekrar önermeyin

- Şeritli (lane) düzen.
- "Yelpaze" düzeni — oyuncunun gönderdiği ekran görüntüsündeki arka plan
  süsünden yanlışlıkla türetilmişti.
- Notaların arkasındaki dikey izler (hold trail çizgileri).
- Perdeye göre renklendirme.

### Açık soru

Normal zorlukta da akorun her notası ayrı parmak istemeli mi? Şu an istemiyor
(tek parmak yeterli); oyuncuya soruldu, yanıt bekleniyor.

## Kod haritası

```
lib/audio/     sentez motoru (saf Dart, additive + inharmonicity + hammer noise)
               pcm_output*: iOS/Android'de flutter_pcm_sound, web'de Web Audio
lib/music/     note/song modeli, nota yazım dili (notation.dart), MIDI okuyucu
lib/game/      chart.dart      Difficulty, Tap, el bölgeleri, seyreltme
               play_session.dart  şarkı saati, dokunuş eşleme, tutma, gecikme telafisi
               judgement.dart  Judge, TimingTolerance, Scoreboard
               stage_geometry.dart  düz düzen, vuruş çizgisi 0.68
lib/render/    stage_painter.dart  tüm oyun alanı çizimi
lib/screens/   song_list_screen.dart (zorluk/tolerans/quantize seçimi), play_screen.dart
lib/data/      song_library.dart  telifsiz şarkılar
tool/          render_song.dart, render_demo.dart  WAV üretici
docs/          magic-piano-analiz.md  mekanik incelemesi
```

### Dikkat edilecek noktalar

- `song_list_screen.dart` içindeki `MaterialPageRoute` **her ayarı**
  `PlayScreen`'e geçirmeli. İki kez unutuldu, oyun ayarları görmezden geldi.
  `test/song_list_test.dart` bunu doğruluyor.
- Çalınmışlık durumu dokunuş indeksiyle değil `Set<(beat, midi)>` ile tutulur;
  aksi halde cihaz döndürülünce bozuluyordu.
- Ses yolundaki gecikme `audio.latencyMs` ile telafi edilir, yoksa her dokunuş
  geç sayılır.
- iOS'ta ses için her `onPointerDown`'da `_audio.nudge()` çağrılır (AudioContext
  kullanıcı hareketiyle uyanmalı).

## Şarkılar

| id | Ad | BPM | Kapsam |
|---|---|---|---|
| `ode-to-joy` | Neşeye Övgü | 120 | 16 ölçülük tam tema |
| `fur-elise` | Für Elise | 132 | Ana tema iki kez (8'lik = vuruş, 3/8) |
| `prelude-in-c` | Prelüd, Do Majör | 66 | İlk 19 ölçü |

**Uyarı:** Bu nota verisi hafızadan yazıldı; bu ortamdan partisyona bakılamıyor
(ağ kısıtı). Doğrulama kulakla, `tool/render_song.dart` ile üretilen WAV'lar
üzerinden yapılıyor. Kalıcı çözüm: **MIDI içe aktarma arayüzü** (yol haritası
adım 8) — `lib/music/midi_reader.dart` format 0/1, running status, tempo ve el
ataması okuyabiliyor, eksik olan yalnızca dosya seçme ekranı.

## Ortam kurulumu

Konteynerde Flutter **kurulu gelmiyor**, her yeni oturumda kurmak gerekir:

```bash
git clone --depth 1 -b 3.35.1 https://github.com/flutter/flutter.git /opt/flutter
export PATH="$PATH:/opt/flutter/bin"
git config --global --add safe.directory /opt/flutter
flutter config --no-analytics
flutter pub get
```

Flutter 3.35.1 / Dart 3.9.0 ile geliştirildi. root olarak çalıştığı için uyarı
verir, sorun değil.

```bash
flutter analyze     # temiz olmalı
flutter test        # 210 test geçiyor
```

## Cihazsız doğrulama

Elde cihaz yok; her değişiklik şöyle doğrulanıyor:

```bash
dart run tool/render_song.dart fur-elise /tmp/a.wav   # şarkıyı çal, WAV'a yaz
flutter test test/stage_painter_test.dart             # oyun alanını build/screens/*.png yap
```

Üretilen WAV ve PNG'ler oyuncuya gönderiliyor.

## Yayınlama (GitHub Pages)

Oyuncu iPhone'dan oynuyor, Mac/Xcode yok. Web derlemesi
**https://omerrdeniz.github.io/Claude/** adresinde yayında; kaynağı `gh-pages`
dalı.

```bash
SHA=$(git rev-parse --short HEAD)
flutter build web --release --base-href /Claude/ \
  --pwa-strategy=none --dart-define=BUILD_ID=$SHA
git worktree add /tmp/pages gh-pages
rm -rf /tmp/pages/*            # .git hariç
cp -r build/web/* /tmp/pages/
echo "$SHA" > /tmp/pages/.last_build_id
git -C /tmp/pages add -A
git -C /tmp/pages commit -m "Piano Flow web derlemesi $SHA"
git -C /tmp/pages push origin gh-pages
```

`--pwa-strategy=none` ve `web/index.html` içindeki service worker kaldırma
betiği **şart**: yoksa telefonda eski derleme kalıyor ve saatlerce yanlış
sürüm test ediliyor. Derleme kimliği (`BUILD_ID`) şarkı listesi ekranının
altında yazıyor; oyuncudan "ekranda hangi kod yazıyor" diye teyit alın.

## Yol haritası

| Adım | Durum |
|---|---|
| 1. Ses motoru | ✅ |
| 2. Şarkı verisi + MIDI okuyucu | ✅ |
| 3. Oyun ekranı | ✅ |
| 4. Dokunuş, değerlendirme, puan | ✅ |
| 5. Adaptif tempo + eşlik | ⏳ |
| 6. Zorluk kademeleri | ✅ (eller/parmaklar olarak) |
| 7. Cila: efektler, temalar, gecikme kalibrasyonu | ⏳ |
| 8. Şarkı kütüphanesi ekranı + MIDI içe aktarma | ⏳ |
| 9. App Store hazırlığı | ⏳ |

## Sıradaki iş

1. Oyuncu üç WAV'ı dinleyip yanlış notaları bildirecek.
2. MIDI içe aktarma arayüzü — şarkı verisini hafızadan yazma sorununu bitirir.
3. Normal zorlukta akor parmaklama sorusu yanıtlanacak.
