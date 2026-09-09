# Magic Piano (Smule) incelemesi

Piano Flow'un referans aldığı oyunun nasıl çalıştığı, nerede tıkandığı ve bizim
nereden farklılaşacağımız. Kaynaklar belgenin sonunda.

> Kapsam notu: burada oyunun **mekaniği** inceleniyor. Smule'un kodu, görselleri,
> ses dosyaları, ismi ve şarkı kataloğu bu projeye alınmaz; mekanik yeniden
> yazılır.

## 1. Çekirdek mekanik

Ekranın üstünden aşağı doğru **ışık huzmeleri** iner. Huzmelerin üzerinde
**ışık topları** (notalar) akar. Ekranın alt tarafında, yaklaşık **2/3
yüksekliğinde yatay bir vuruş çizgisi** vardır.

Oyuncu topa dokunur; uygulama o an **doğru notayı** çalar. Yani yanlış perde
çalma diye bir şey yok — oyuncunun kontrol ettiği şey **ne zaman** çalındığı.

Bunun iki sonucu var:

- **Tempo oyuncunun elindedir.** Şarkıyı hızlı da yavaş da çalabilirsin, müzik
  yine doğru çıkar. Piyano bilmeyen biri ilk denemede "çalıyorum" hissi alır.
- **Zorluk ritimdedir, perdede değil.** Oyuncu şarkının ritmini bilmiyorsa
  doğru zamanlamayı kestirmesi zor olur.

Piano Tiles'tan farkı tam da burası: Piano Tiles'ta kaçırırsan ölürsün, ritim
sabittir. Magic Piano'da kaçırmak şarkıyı bozmaz, sadece puanı düşürür.

## 2. Puanlama

- Puan **zamanlama isabetine** bağlı: top tam vuruş çizgisindeyken dokunursan
  en yüksek puan, uzaklaştıkça daha az.
- **Seri (streak)** puan çarpanı büyütür. Yüksek skorun yolu seriyi korumaktan
  geçer.
- Şarkı sonunda harf/yıldız notu verilir.

## 3. Modlar

| Mod | Ne yapar |
|---|---|
| Şarkı çalma | Huzmelerdeki notalara dokunarak parçayı çalmak — ana mod |
| Solo / Freestyle | Piyano klavyesine benzeyen serbest çalma alanı |
| Smule Jams | Smule topluluğundaki gerçek vokallere eşlik etme |
| Duet | Başka bir oyuncuyla aynı parçayı bölüşerek çalma |

## 4. Kullanıcıların şikâyet ettiği yerler

App Store ve Trustpilot yorumlarında tekrar eden başlıklar:

1. **Ödeme duvarı.** Ücretsiz içerik yıllar içinde ciddi şekilde daraltılmış;
   neredeyse her şey abonelik veya oyun içi para ("Smoola") arkasında.
2. **Reklamlar.** Ücretsiz oynayanlar için rahatsız edici seviyede.
3. **Para biriktirme hızı.** Oyun içi para çok yavaş kazanılıyor, oyuncu aynı
   birkaç şarkıyı tekrar tekrar çalmak zorunda kalıyor.
4. **Tempo sorunu.** Şarkılar orijinal temposuyla senkron değil; parçayı doğru
   hızda çalan oyuncu düşük not alabiliyor.
5. **Eski sürüm nostaljisi.** Uzun süredir oynayanlar oyunun eskiden daha
   cömert ve daha iyi olduğunu söylüyor.

## 5. Piano Flow bunlardan ne çıkarıyor

Şikâyetlerin çoğu oynanışla değil, **iş modeliyle** ilgili. Bizim avantajımız
da burada.

| Sorun | Piano Flow'un yaklaşımı |
|---|---|
| Ücretsiz içerik yok denecek kadar az | Telifsiz klasik repertuvarı baştan açık; şarkı kilidi yok |
| Şarkı kataloğu lisansa bağımlı | Kullanıcı **kendi MIDI dosyasını** yükleyip oynayabilir — katalog sınırsız |
| Tempo senkron değil | Adaptif tempo: eşlik oyuncunun vuruşunu takip eder, tersi değil |
| Aynı şarkıyı tekrar çalma zorunluluğu | İlerleme para değil, beceri üzerinden: aynı parçanın zorluk kademeleri |
| Ritmi bilmeyen oyuncu tıkanıyor | Çalışma modu: yavaşlatma, bölüm döngüsü, ritim rehberi |

## 6. Klonlanacak mekaniğin teknik özeti

Uygulamamızın çekirdeğinde şunlar olmalı:

1. **Şarkı verisi** — nota listesi: `(zaman, perde, süre, hangi el)`. MIDI'den
   üretilebilir.
2. **Huzme atayıcı** — notaları perdeye göre 2–4 huzmeye dağıtan katman;
   zorluk seviyesi huzme sayısını ve çalınacak nota yoğunluğunu belirler.
3. **Akış motoru** — notaları vuruş çizgisine doğru taşıyan zamanlayıcı.
   Yaklaşma süresi (~2 sn) tempodan bağımsız tutulmalı.
4. **Dokunma çözümleyici** — dokunulan noktayı en yakın bekleyen notayla
   eşleştirir, sapmayı ms cinsinden ölçer.
5. **Değerlendirme** — sapmaya göre Mükemmel / İyi / Kaçtı; seri ve çarpan.
6. **Ses** — dokunma anında doğru perdeyi çalar; dokunma sertliği/konumu tınıya
   yansır. Eşlik (sol el) otomatik çalar.
7. **Görsel geri bildirim** — vuruşta parçacık patlaması, huzme parlaması.

Bunların hiçbiri Smule'a özgü değil; hepsi sıfırdan yazılacak.

## Kaynaklar

- [Magic Piano — App Store](https://apps.apple.com/us/app/magic-piano-game-by-smule/id421254504)
- [Magic Piano App Review — Common Sense Media](https://www.commonsensemedia.org/app-reviews/magic-piano)
- [Magic Piano by Smule Review — Educational App Store](https://www.educationalappstore.com/app/magic-piano-by-smule)
- [Review: Magic Piano (iOS) — The Game Knot](https://moodmatrixer.wixsite.com/thegameknot/post/review-magic-piano)
- [Smule kullanıcı yorumları — Trustpilot](https://www.trustpilot.com/review/smule.com)
- [Magic Piano kullanıcı yorumları — App Store](https://apps.apple.com/us/app/magic-piano-game-by-smule/id421254504?see-all=reviews)
