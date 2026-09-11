# Piano Flow

Akan notalara dokunarak piyano çalınan bir ritim oyunu. Flutter; iOS ve Android.

Çekirdek kural: **dokunuş her zaman doğru notayı çalar.** Oyuncu yanlış perde
çalamaz, sadece yanlış an seçebilir. Piyano bilmeyen biri ilk denemede
"çalıyorum" hissi alır.

## Durum

> Yeni bir oturuma başlıyorsanız önce **[docs/DURUM.md](docs/DURUM.md)**
> dosyasını okuyun: nerede kalındığı, alınan ve reddedilen tasarım kararları,
> ortam kurulumu ve yayınlama adımları orada.


Oynanabilir çekirdek hazır: notalar akıyor, dokunuş notayı çalıyor, zamanlama
değerlendiriliyor, seri ve puan işliyor.

| Adım | Durum |
|---|---|
| 1. Ses motoru | ✅ |
| 2. Şarkı verisi + MIDI okuyucu | ✅ |
| 3. Oyun ekranı | ✅ |
| 4. Bağlama: dokunuş, değerlendirme, puan | ✅ |
| 5. Adaptif tempo + eşlik AI | ⏳ |
| 6. Zorluk kademeleri | ⏳ |
| 7. Cila: efektler, temalar, gecikme kalibrasyonu | ⏳ |
| 8. Şarkı kütüphanesi ekranı + MIDI içe aktarma | ⏳ |
| 9. App Store hazırlığı | ⏳ |

## Geliştirme

Flutter 3.35+ gerekir.

```bash
flutter pub get
flutter run          # cihazda veya emülatörde
flutter test         # testler
flutter analyze      # statik analiz
```

### Cihazsız doğrulama

Sesi duymadan ve ekranı görmeden geliştirmek zorunda kalırsan iki araç var:

```bash
dart run tool/render_demo.dart demo.wav        # sentezleyici gösterimi
dart run tool/render_song.dart fur-elise a.wav # bir şarkıyı çal ve WAV'a yaz
flutter test test/stage_painter_test.dart      # oyun alanını build/screens/*.png olarak bas
```

## Klasörler

```
lib/
  audio/     sentez ses motoru ve hoparlör bağlantısı
  music/     nota/şarkı modeli, nota yazım dili, MIDI okuyucu
  game/      dokunuş eşleme, değerlendirme, puan, sahne geometrisi
  render/    oyun alanı çizimi
  screens/   ekranlar
  widgets/   klavye, puan göstergesi
  data/      telifsiz şarkı kütüphanesi
docs/        Magic Piano mekanik incelemesi
tool/        WAV üretici geliştirme araçları
```

## Müzik hakları

Kütüphanedeki parçalar kamu malı (Beethoven, Bach); düzenlemeler bu projeye
ait. Ses örnek dosyasıyla değil sentezle üretiliyor, yani üçüncü taraf ses
lisansı yok. Oyuncu kendi MIDI dosyasını da yükleyebilir.
