# Bugün sıfırdan kursam ne değişirdi

Bu belge bir **düşünce denemesi**, bir plan değil. Soru şuydu: "Piano Flow'u
bugünkü bilgiyle baştan yazsan nasıl yazardın?" Cevap kod olarak değil, not
olarak verildi — çünkü çalışan bir oyunu (6.489 satır kod, 4.159 satır test)
ve 941 satırlık `DURUM.md` birikimini atmanın bedeli, kazanılacak olandan
büyük.

Yöntem: mimariyi okudum, "sıfırdan olsa neyi farklı kurardım" diye listeledim,
sonra her maddeyi `DURUM.md`'ye karşı denetledim. Üçüncü bölüm o denetimin
sonucu ve belgenin en öğretici kısmı.

---

## 1. Aynı kalırdı

Çoğu şey. Bunlar baştan kurulsa yine böyle kurulurdu:

- **Katman ayrımı.** `music/` (veri) → `game/` (kural) → `render/` + `screens/`
  (görüntü) → `audio/` (ses). Flutter'a bağımlı olmayan çekirdek, bağımlı olan
  kabuk. Testlerin 4.159 satıra çıkabilmesinin sebebi bu.
- **`Chart.build`'in bir kez çalışması.** Şarkı + zorluk → dokunuş listesi,
  önden hesaplanıp donduruluyor. Kare içinde karar verilmiyor. Doğru.
- **`rootBundle`'ın tek bir yerde olması** (`song_library.dart`). Varlık okuma
  sızarsa test edilemez hâle gelir.
- **Üretilmiş katalog** (`tool/catalog.dart` → `catalog.g.dart`). Şarkı
  eklemenin tek kapısı olması iyi.
- **Şarkının tembel yüklenmesi** (`SongTile._open`). Kütüphane büyürken
  açılış süresi sabit kalıyor.
- **`SongLibrary` alanlarının `static final` olması.** Getter'ken her
  `setState` 4.7 ms ödüyordu. Bu ders zaten öğrenilmiş.

Kısacası: **mimari sağlam.** Aşağıdaki maddeler onarım değil, rötuş.

---

## 2. Farklı kurardım — ve bunlar gerçekten değerli

### 2.1 Ayarlar tek bir nesne olurdu · **en değerlisi**

Bugün altı ayar (`difficulty`, `speed`, `tolerance`, `quantize`,
`fillMissed`, `latencyOffsetMs`) üç katmandan **elle** geçiriliyor:

```
SongListScreen (durum) → SongTile (alan) → PlayScreen (alan) → PlaySession
```

Her ayar bu üç dosyada ortalama **12 kez** geçiyor. `PlayScreen`'in
yapıcısında hepsinin bir varsayılanı var — yani birini geçirmeyi unutmak
**sessizce** eski değere düşüyor, hata vermiyor.

`DURUM.md` bunu zaten biliyor: *"`MaterialPageRoute` her ayarı `PlayScreen`'e
geçirmeli. **İki kez unutuldu.**"* Çözüm olarak bir test yazılmış
(`song_list_test.dart`).

Sıfırdan kursam test yerine **yapı** koyardım:

```dart
class PlaySettings {
  const PlaySettings({ ... });   // varsayılanlar burada, tek yerde
  final Difficulty difficulty;
  final double speed;
  // ...
}
```

`PlayScreen({required this.song, required this.settings})`. Böylece bir ayar
eklemek **tek dosyada** değişiklik olur ve unutmak derleme hatası verir —
testin yakalamasını beklemek yerine.

- Kazanç: bir hata sınıfı tamamen ortadan kalkar; yeni ayar eklemek ucuzlar
  (5. ve 6. adımlar yeni ayarlar getirecek).
- Maliyet: 3 dosyada mekanik değişiklik, davranış değişmez.
- Risk: düşük. Mevcut test zaten koruyor.

### 2.2 `PlaySession` ikiye bölünürdü · **dikkatli**

825 satır ve en az sekiz sorumluluk: şarkı saati, dokunuş eşleme, tutma
(`_Hold`), sürükleme (`_Drag`), koşular (`RunBead`), eşlik çalma, kaçırılanı
doldurma, nota bırakma zamanlaması.

Sıfırdan kursam **jest takibini** (tutma/sürükleme/koşu — parmağın ekranda ne
yaptığı) saat ve değerlendirmeden ayırırdım. O üç yapı birbirine benziyor ama
`PlaySession`'ın içine dağılmış durumda.

**Ama:** `DURUM.md`'deki **tek saat kuralı** tam da bu sınırdan geçiyor.
Eşleme, değerlendirme ve silme üçünün de `_judgedBeat` kullanması zorunlu;
bir dönem yalnız biri gecikmeyi telafi ettiği için oyun "bazen algılıyor
bazen algılamıyor" hâline gelmişti. Yanlış yerden bölmek o hatayı geri
getirir.

Dolayısıyla: **saat ve değerlendirme birlikte kalır**, yalnızca jest
defterleri dışarı çıkar. Ve ancak 5-7. adımlar sırasında bu dosyaya zaten
dokunmak gerekirse yapılır — kendi başına bir iş olarak değil.

### 2.3 Gecikme telafisi tipi olurdu · küçük

`_judgedBeat`, `latencyOffsetMs`, `audio.latencyMs`, `_totalLatencyMs` —
hepsi çıplak `double`. Milisaniye mi, vuruş mu, saniye mi olduğu adından
anlaşılıyor ama derleyici bilmiyor.

`DURUM.md`'de *"Vuruş değil saniye — **üçüncü kez**"* diye bir başlık var.
Aynı hata üç kez yapılmış.

Sıfırdan kursam `extension type Beats(double)` / `Millis(double)` kullanırdım:
birim karıştırmak derleme hatası olurdu. Dart 3'te bunun çalışma zamanı
maliyeti yok.

- Risk: orta — çok yere dokunur. **Kendi başına yapılmaz.** Ama dördüncü kez
  aynı hata olursa gerekçe hazır.

---

## 3. Farklı kurardım — ama `DURUM.md` bunları zaten reddetmiş

Bu bölüm belgenin asıl amacı. Mimariyi "temiz kafayla" okuyunca
önereceklerim şunlardı:

| Önereceğim | Neden önerirdim | Neden yanlış |
|---|---|---|
| **AudioWorklet'e geç** | `ScriptProcessorNode` deprecated | Ölçüldü: blok doldurma **155 µs**, ürettiği ses **46 ms** — gerçek zamanın binde üçü. Kazanılacak CPU yok. Üstelik GitHub Pages COOP/COEP başlığı sunmadığı için `SharedArrayBuffer` yolu kapalı. |
| **`StagePainter`'ı katmanlara böl** | 737 satır, tek `paint` | Ölçüldü: tüm çizim **314 µs/kare**, 16700 µs bütçenin %1.9'u. Darboğaz değil; bölmek yalnızca okunurluk için olurdu, 3. kural "bozuk olmayanı refactor etme" diyor. |
| **Akor yayılımını kareden çıkar** | Yapısal olarak doğru | Aynı 314 µs. Ayrıca `Chart`'a bilerek uzak durduğu ekran boyutunu vermeyi gerektirir. |
| **Şeritli (lane) düzen** | Ritim oyunlarının standardı | Oyuncu denedi ve reddetti: "Magic Piano'da şerit yok." |
| **Perdeye göre renklendirme** | Alışılmış | Reddedildi. Renk **akorun kaç nota olduğunu** anlatıyor — bilgi taşıyan bir kanal, süs değil. |

**Sonuç:** Beş öneriden beşi yanlış olurdu. Hepsi "genel iyi pratik" olarak
doğru, bu projede yanlış — çünkü ya ölçülüp elenmişler ya da oyuncu geri
bildirimiyle reddedilmişler.

Bu tablo, "baştan yazalım" fikrinin neden riskli olduğunun somut cevabı:
sıfırdan kurulan bir sürüm bu beş kararı büyük ihtimalle yeniden alırdı.

---

## 4. Karar

Baştan yazma **yok**. Üç maddelik bir liste çıktı, ikisi zaten sıradaki işin
içinde yapılabilir:

1. **`PlaySettings` nesnesi** — yapılsın. Küçük, riski düşük, bir hata
   sınıfını kapatıyor, 5-9. adımlar yeni ayar getirecek.
2. **Jest takibinin ayrılması** — bekletilsin. Ancak 5-7. adımlarda
   `play_session.dart`'a zaten dokunmak gerekirse, ve tek saat kuralına
   dokunmadan.
3. **Zaman birimi tipleri** — bekletilsin. Dördüncü birim hatası olursa
   gerekçe burada.

Ölçü: yol haritasındaki 5-9. adımlar mevcut mimari üzerinde, `CLAUDE.md`
kurallarıyla yazılır.
