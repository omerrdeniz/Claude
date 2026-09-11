# CLAUDE.md — Piano Flow

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

# Davranış kuralları

Karpathy'nin LLM kodlama hataları üzerine gözlemlerinden türetildi.
Kaynak: <https://x.com/karpathy/status/2015883857489522876>

**Denge:** Bu kurallar hızdan çok dikkati önceler. Önemsiz işlerde
(yazım hatası, tek satırlık düzeltme) muhakeme kullanın.

## 1. Önce düşün

**Varsayma. Kafa karışıklığını saklama. Ödünleşimleri söyle.**

- Varsayımlarını açıkça yaz. Belirsizlik işi anlamsızlaştıracaksa sor;
  değilse **varsayımını yazıp devam et** — küçük işlerde durup soru sorma.
- Birden fazla yorum varsa ikisini de sun, sessizce birini seçme.
- Daha basit bir yol varsa söyle. Gerekiyorsa itiraz et.

## 2. Basit tut

**Problemi çözen en az kod. Spekülatif hiçbir şey.**

- İstenmeyen özellik yok.
- Tek kullanımlık kod için soyutlama yok.
- İstenmemiş "esneklik" ya da "yapılandırılabilirlik" yok.
- İmkânsız durumlar için hata yakalama yok.
- 200 satır yazdıysan ve 50 yetiyorsa, baştan yaz.

Sor: "Kıdemli bir mühendis buna gereğinden karmaşık der mi?" Derse sadeleştir.

## 3. Sadece gerekene dokun

**Yalnızca zorunlu olanı değiştir. Yalnızca kendi dağıttığını topla.**

- Komşu kodu, yorumları, biçimlendirmeyi "iyileştirme".
- Bozuk olmayanı refactor etme.
- Mevcut stile uy, sen farklı yazacak olsan bile.
- İlgisiz ölü kod görürsen **söyle** — silme.
- Kendi değişikliğinin öksüz bıraktığı import/değişken/fonksiyonu temizle;
  önceden var olan ölü kodu istenmedikçe silme.

Test: Değişen her satır doğrudan istenen şeye kadar izlenebilmeli.

## 4. Hedef koy, doğrula

**Başarı ölçütü tanımla. Doğrulanana kadar döngüde kal.**

- "Doğrulama ekle" → "Geçersiz girdiler için test yaz, sonra geçir"
- "Bug'ı düzelt" → "Bug'ı yeniden üreten test yaz, sonra geçir"
- "X'i refactor et" → "Öncesinde ve sonrasında testler geçsin"

Çok adımlı işlerde kısa bir plan yaz:

```
1. [Adım] → doğrulama: [kontrol]
2. [Adım] → doğrulama: [kontrol]
```

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
