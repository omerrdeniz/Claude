# Durum ve devir notu

Bu dosya, sohbet geçmişi olmayan yeni bir oturumun projeyi kaldığı yerden
sürdürebilmesi için yazıldı. Son güncelleme: sürükleme mekaniği baştan
yazıldı — artık takip edilen bir boncuk var.

## Proje

**Piano Flow** — App Store'daki Magic Piano (Smule) oyununun daha gelişmiş bir
sürümü. Flutter.

**Oyun bugün yalnızca web'de çalışıyor** ve oyuncu onu iPhone'unda ana
ekrandan açıyor. `ios/` ve `android/` klasörleri duruyor ve kod ikisini de
hedefliyor, ama **hiç derlenmediler**: bu konteynerde ne Xcode var (zaten
Linux) ne de Android SDK. Yani "iOS + Android" bir niyet, henüz bir gerçek
değil — ayrıntısı aşağıda "App'e geçiş"te.

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
- **Normal zorlukta hiçbir nota oyuncudan alınmaz.** Oyuncu "şarkının benim
  çalmadığım kısımları var" dedi; yalnızca Kolay modda seyreltme yapılır
  (yarım vuruşta bir moment kalır, gerisi `autoNotes`'a gider).
- **Kaçırılanı doldurma bir seçenek, varsayılan DEĞİL.**
  (`PlaySession.fillMissed`, varsayılan **kapalı**; şarkı listesinde
  "Kaçırdıklarım da duyulsun".)

  Neden eklendi: Normal'de iki el de oyuncunun ve Nokturn'ün notalarının
  **%63'ü sol el** (Neşeye Övgü %58, Für Elise %42, Prelüd %24). Sadece
  melodiyi çalan biri Nokturn'ün üçte ikisini duymuyordu; oyuncu bunu
  "notalar kesik, aralarında boşluk var" diye bildirdi.

  Neden varsayılan kapalı: açıkken oyuncu hemen fark etti — **"ben
  basmadığımda neden müzik çalıyor?"** Doldurma, oyuncunun deneyip
  denemediğine bakmıyor; notanın anı geçtiyse çalıyor. Yani hiç basmayan biri
  şarkının kendi kendine çaldığını duyuyor, ki bu projenin en eski kuralına
  aykırı.

  **Bu iki şikâyet aynı kadranın iki ucu.** "Kaçırdığım yerde delik olmasın"
  ile "ben basmadan hiçbir şey çalmasın" aynı anda sağlanamaz. O yüzden
  seçenek olarak duruyor, karar oyuncunun.

  **Zamanlaması kritik:** doldurma, yargı penceresinde değil **mükemmel**
  penceresinde yapılır (`_fillDelayBeats`). Yargı penceresi en genişinde
  378 ms; sekizlikleri 450 ms olan bir parçada o kadar geç gelen nota deliği
  doldurmaz, yanlış nota gibi duyulur. Doldurma notayı **çözmez**: geç kalan
  el hâlâ bulur, hâlâ puan alır ve kendi dokunuşu notayı yine çalar.
- **Eller ayrılır.** Ekranın sol yarısı sol el, sağ yarısı sağ el. Zorluğun
  asıl anlamı bu:
  - Kolay: tek alan, akor tek parmakla, seyreltme var.
  - Normal: eller ayrı, akor her elde tek parmakla.
  - Zor: eller ayrı, akorun her notası ayrı parmakla.
- **Basılı tutma** Guitar Hero gibi: nota vuruş çizgisine gelince **orada
  durur**, arkasındaki çubuk kuyruğu yetiştikçe kısalır. Eskiden nota çizgiyi
  geçip aşağı süzülüyordu, bu da parmak hâlâ basılıyken notanın bitmiş
  olduğunu söylüyordu. `StageGeometry.headProgressFor`.
  **Ama yalnızca gerçekten basıldıysa.** Yakalanmayan uzun nota çizgide
  beklemez; diğer notalar gibi akıp gider, kuyruğuyla birlikte kaybolur.
  Hangi notanın basılı olduğunu `PlaySession.heldNotes` söylüyor
  (`(beat, midi)` kümesi), `StagePainter.heldNotes` olarak geçiyor.

  **Çubuk notanın bittiği yere kadar çizilmez**, biraz önce biter
  (`StageGeometry.holdBarTop`, nota yarıçapının 1.6 katı). Nota yazılı
  uzunluğu kadar sürer — ses odur — ama uç uca çizilince çubuklar üstteki
  notanın arkasına giriyor ve bir el dolusu tutma tek bir merdiven gibi
  okunuyordu. Bu yalnızca resimdeki bir boşluk; sesle ilgisi yok.
- **Nota boyutu sabit.** Eskiden yaklaşırken büyüyüp çizgiyi geçince
  küçülüyordu; oyuncu sabit olmasını istedi. Uzaklık artık yalnız solgunlukla
  anlatılıyor — "ne zaman" demeye çalışan bir resimde bir şeyin daha
  kıpırdaması fazlaydı. `StageGeometry.noteRadius` (artık parametresiz).
- **Akorun notaları üst üste binmez.** Yer perdeden geliyor, yakın aralıklı
  bir akor (üçlü, beşli) notaları ekranın yüzde birkaçı içine sıkıştırıyor ve
  tek bir leke gibi çiziliyordu. `StageGeometry.spreadChord` yalnızca
  **asgari** aralığı zorluyor: zaten açık duran bir akor (oktav, onlu) perdenin
  koyduğu yerde kalıyor, sıra hiç değişmiyor, hiçbir nota diğer elin yarısına
  itilmiyor.
- **Hızlı geçitler bir boncuğu takip ederek çalınır.** Oyuncunun isteği:
  *"çok sayıda nota arka arkaya belirli bir hızın üzerinde geliyorsa tek tek
  basmak zor oluyor... ilk notaya basalım, sonra basılı tutmaya devam ederek
  sağa veya sola sürükleyerek sonraki notalara basmış olalım."*

  Aynı elde, aralarında **150 ms veya daha az** olan **en az 3** nota bir
  "koşu" (`Chart.runs`) sayılır.

  **İlk sürüm başarısızdı ve nedenleri kayda değer.** Oyuncu dört şikâyeti
  birden işaretledi: notalar arası kopuyor, ben bir şey yapmıyormuşum gibi,
  koşuya giremiyorum, zamanlama parmağıma uymuyor. Dördü de aynı üç yanlış
  karardan çıkıyordu:

  1. **Hareket miktarı ölçülüyordu.** Her nota için belirli bir mesafe
     isteniyordu ve sayaç her notada sıfırlanıyordu. Parmak yön değiştirirken
     bir an duruyor — tam o anda nota düşüyordu. "Kopuyor" buydu.
  2. **Nota, parmak hareketi olayında çalınıyordu**, saatte değil; kare başına
     en fazla bir nota.
  3. **Takip edilecek bir şey yoktu.** Ekranda koşunun ipi vardı ama "şu an
     neredeyiz" diyen hiçbir şey yoktu. Parmak sadece "hâlâ oynuyor mu"
     sorusuna cevap veriyordu; oyuncunun "bir şey yapmıyormuşum gibi" demesi
     bundan.

  **Şimdiki hâli — boncuk.** Koşunun o an çalınması gereken notası vuruş
  çizgisinin üstünde bir halka olarak duruyor ve perde değiştikçe çizgi
  boyunca kayıyor (`PlaySession.runBeads`, `RunBead`). Oyun şu:

  - **Konum önemli, hareket değil.** Notalar saatten çalınıyor
    (`_playRuns`, `update` içinde); parmak sadece o notaya yakın mı diye
    bakılıyor (`dragReach` = ekran genişliğinin %15'i, telefonda bir parmak
    genişliği kadar iki yana). Duran parmak da çalar — ama koşunun boncuğu
    elin bölgesinin çoğunu kat ettiği için duran parmak koşuyu kaybeder.
    Yön değiştirmek artık bedava.
  - **Koşuya her yerinden girilir.** İlk notayı tutturmak şart değil;
    boncuğun üstüne parmak koymak yeter (`beginDrag`). Eskiden ilk notayı
    kaçıran tüm geçidi kaybediyordu.
  - **Boncuk koşudan önce geliyor.** İlk notadan `dragLeadMs` = 500 ms önce
    çizgide beliriyor — değerlendirme penceresinden (210 ms) uzun, çünkü
    kimsenin basamayacağı bir geçide dalmak değil, önceden raya girmek
    gerekiyor.
  - **Geri bildirim.** Boncuk boşken koyu zeminli, vurgu renginde bir halka
    ("buraya parmak koy"); parmak üstündeyken beyaz, dolu ve haleli. Her
    çalan nota vuruş çizgisini de yakıyor.

  Zamanı hâlâ şarkı veriyor. Parmağın hızının müziği hızlandırması denenmedi
  ve **istenmiyor**: sol el şarkının saatinde çalıyor, koşu ondan kopamaz.
  Parmağa uyan şey zamanlama değil, takip edilecek görünür bir şey olması.

  Toplama değil, ekleme: koşunun notalarına tek tek basmak hâlâ mümkün ve
  aynı şekilde puanlanıyor.

  **Üçüncü düzeltme turu — kısa koşular kaldırıldı.** Oyuncu: *"sürüklemelerin
  başlangıcını yakalamak çok zor, özellikle 3'lü olanları %60 hızda bile
  yakalayamıyorum."* Üç ayrı sebep vardı:

  1. **Kütüphanede iki tür hızlı geçit var, arada hiçbir şey yok:** çeyrek
     saniyede biten 3 notalık çırpıntılar (26 tane) ve 11–62 notalık, 1–6
     saniye süren gerçek koşular (13 tane). Çırpıntılar sürükleme olarak
     sunuluyordu; 273 ms'de hareket eden bir halkaya parmak koymak yazı tura
     ve üç dokunuş zaten üç dokunuş. Artık bir koşunun **en az 0.6 saniye**
     sürmesi gerekiyor (`Chart.runSeconds`). Geriye kalan her koşu 11 nota
     ve üstü.
  2. **Boncuğa nişan almak gerekiyordu.** Artık o eldeki herhangi bir yere
     dokunmak koşuyu alıyor. Girişi zorlaştırmanın koruduğu bir şey yok —
     koşuya girmek yalnızca zaten çalamayacağın notaları ekliyor; mekaniğin
     asıl istediği beceri *takipte kalmak*, onu `dragReach` hâlâ istiyor.
  3. **Yavaşlatmak işe yaramıyordu.** `dragLeadMs` gerçek milisaniye
     cinsindendi, yani %60 hızda da boncuk ilk notadan 500 ms önce
     beliriyordu. Şimdi şarkının kendi zamanında (900 ms), yani %60'ta 1.5
     saniye. Bir şey yakalanamayacak kadar hızlıysa insanın uzandığı ayar
     bu; hiçbir şey yapmıyor olması kabul edilemezdi.

  **Dördüncü tur — parmak koşuya değil ele bağlandı.** Oyuncu: *"hâlâ bozuk
  gibi, yakalamak çok zor ve bazen içi boş iki tane daire çıkıyor."* İki
  belirti, tek kök:

  - Kanon'un koşuları **arka arkaya sekiz tane** ve aralarında 818 ms var.
    Parmak tek bir koşuya bağlıydı, yani o koşu bitince bırakılıyordu — ve
    yeni bir koşuya girmenin tek yolu `beginDrag`, o da yalnızca parmak
    **yeniden basıldığında** çağrılıyor. Parmağını kaldırmayan biri ilk
    koşudan sonra hiçbir şey çalamıyordu; sekiz koşu boyunca sekiz kez, 818
    ms'lik boşluklara denk getirerek kaldırıp basmak gerekiyordu. "Yakalamak
    çok zor" buydu.
  - Boncuğun öne gelme süresi (900 ms) o boşluktan (818 ms) uzun olduğu için
    bir sonraki koşunun halkası, mevcut koşu bitmeden beliriyordu. **İki içi
    boş daire** buydu — ve parmak bastığında yanlış olanı alabiliyordu.

  Şimdi **bir parmak bir koşuya değil bir ele bağlı**: o elde hangi koşu
  varsa, şimdi ya da birazdan, onu takip ediyor. Her elde de en fazla bir
  halka var (çalınmakta olan, yoksa gelmekte olan). Parmağını basılı tutan
  biri sekiz koşuyu da kesintisiz çalıyor.

  **Beşinci tur — iki eşik, bir tane değil.** Oyuncu Kanon'daki üçlülerin
  neden kaybolduğunu sordu. Doğru cevap "geri getirelim" değildi: o üçlüler
  hiç ayrı bir şey değildi. Kanon'un on altılık varyasyonları dört notada bir
  nefes alıyor — komşuları 136 ms iken o aralık 273 ms — ve tek eşikli kural
  on ölçülük kesintisiz semiquaver'ı **otuz bir parçaya** bölüyordu, çoğu üç
  notalık. Sürüklenemeyecek kadar kısa olmalarının sebebi buydu.

  Artık iki eşik var: `runGapSeconds` (150 ms) bir koşuyu **başlatıyor**,
  `runCarrySeconds` (300 ms) onu **sürdürüyor**. Aynı on ölçü şimdi 79 ve 112
  notalık iki koşu; en uzunu 17 saniye kesintisiz takip.

  Sürdürme eşiği, sadece hızlı bir parçada koşu başlatacak aralığın altında
  kalmak zorunda: Für Elise'in on altılıkları 208 ms arayla ve orada koşu
  başlatan bir eşik şarkının %90'ını tek bir sürüklemeye çevirirdi. Sürdürme
  olarak 300 ms onu %14'te bırakıyor.

  Bu arada 0.6 saniyelik asgari süre kuralı kaldırıldı. O kural, kısa
  koşuları yakalamak imkânsız olduğu için konmuştu; parmak artık ele bağlı
  olduğundan yakalanacak bir şey kalmadı.

  Kapsam (Normal): Kanon 2 koşu (79 ve 112 nota, %23), Für Elise 4 (5, 8, 52,
  62 — %14), Nokturn 5 (3, 3, 5, 14, 14 — %5), diğerleri yok.

- **Basılı tutma eşiği saniye cinsinden.** Bir nota, sesi 0.7 saniyeden uzun
  sürüyorsa basılı tutmalı sayılıyor (`Tap.holdSeconds`); `Chart.build` bunu
  parçanın temposundan vuruşa çeviriyor.

  Eskiden eşik **vuruş** cinsindeydi (1.25 vuruş) ve bu her parçada başka bir
  süre demekti: Neşeye Övgü'de 469 ms, Kanon'da 1364 ms. El vuruş nedir
  bilmez. Oyuncu farkı Kanon'da yakaladı: zemin bası ♩=55'te dörtlük, yani
  1.09 saniye çınlıyor ve kulağa basılı tutmalı geliyor, ama eşiğin altında
  kaldığı için tek dokunuş çiziliyordu. 818 dokunuşun 5'i tutmalıydı; şimdi
  293'ü, ki parçanın gerçekten olduğu şey bu.

  Aynı hatanın ikizi Kolay moddaki seyreltmede duruyor, henüz düzeltilmedi
  (aşağıda, "Sıradaki iş").
- **Tolerans bir ayardır.** `TimingTolerance { wide, normal, tight }` —
  çarpanlar 1.8 / 1.0 / 0.6. Erken basışlar kuyruğa alınıp **kendi vuruşunda**
  seslendirilir (quantize anahtarı), geç basışlar hemen çalar.
- **Hem dikey hem yatay** oynanabilir.
- **Hız seçici var**, varsayılanı **Tam hız**. Bir kez kaldırılmıştı, oyuncu
  geri istedi: gerçek tempolarında bazı parçalar elin yetişemeyeceği kadar
  hızlı. Şarkılar kendi temposunda yazılı kalıyor; yavaşlatma bir çalışma
  aracı. `%40 / %60 / %80 / Tam hız`.

### Telifli şarkılar

Oyuncu güncel bir pop şarkısı istedi (Manifest & Ajda Pekkan, "Hileli", 2025).
Eklenemez ve bu bir tercih değil: repo açık ve her değişiklik `gh-pages`'ten
herkese servis ediliyor, yani katalogda duran her şey dağıtılıyor. Notaların
yasal bir kaynağı da yok — Mutopia ya da IMSLP'de 2025 tarihli bir parça
bulunmaz.

Yasal yol **MIDI içe aktarma** (yol haritası adım 8): dosya oyuncunun
cihazında kalır, repoya da yayına da girmez. Okuyucu ve dönüştürücü hazır,
eksik olan sadece dosya seçme ekranı. Oyuncuya önerildi, "şimdilik gerek yok"
dedi.

Bunun yerine kütüphaneyi **klasik dışına** açtık: Joplin'in ragtime'ı ve
Satie. İkisi de kamu malı, ikisi de mevcut repertuvara hiç benzemiyor.
Aynı raftaki diğer adaylar: Debussy'nin Clair de Lune'ü (Mutopia'da var,
ama nüshada sayısal tempo yok ve 9/8 — vuruş birimi elle verilmeli),
Arabesque 1 ve 2, Satie'nin Gnossienne 2 ve 3'ü, Joplin'in dokuz ragtime'ı
daha.

### Reddedilenler — tekrar önermeyin

Oynanış:

- Şeritli (lane) düzen.
- "Yelpaze" düzeni — oyuncunun gönderdiği ekran görüntüsündeki arka plan
  süsünden yanlışlıkla türetilmişti.
- Notaların arkasındaki dikey izler (hold trail çizgileri).
- Perdeye göre renklendirme.

Teknik:

- **AudioWorklet'e geçmek.** ScriptProcessorNode kullanımdan kalkmış olsa da
  geçiş burada işe yaramıyor. Worklet kendi iş parçacığında çalışır ama
  sentezleyici Dart'ta ve ana iş parçacığında kalır; örneklerin karşıya
  geçmesi gerekir. İki yol da tıkalı: SharedArrayBuffer sayfanın
  cross-origin isolated olmasını, o da COOP/COEP başlıklarını ister —
  GitHub Pages bunları sunmuyor. Mesajla tampon göndermek ise aynı kuyruğu
  bir port arkasına taşır, ana iş parçacığı takılınca yine boşalır; sağlamlık
  ancak kuyruğu derinleştirerek gelir ki o da yine gecikme demek. Gerçek
  çözüm motoru worklet içinde JavaScript'e taşımak, o ayrı bir proje.
  **Ölçüm:** on ses çalarken bir bloğu doldurmak 155 µs, ürettiği ses 46 ms
  — gerçek zamanın binde üçü. Kazanılacak CPU yok.
- **Örnekleri notadan notaya eşitlemek.** Ayrıntısı aşağıda, piyano sesi
  bölümünde: eğri dik ve dışbükey olduğu için komşu ortalaması tizi yukarı
  çekiyor ve kaydın getirdiği ayrımın yarısını geri veriyor.
- **Akor yayılımını çizim karesinden çıkarmak.** Yapısal olarak doğru olurdu
  ama tüm çizim 16700 µs'lik bütçenin 314'ünü harcıyor ve taşımak `Chart`'a
  bilerek uzak durduğu ekran boyutunu vermeyi gerektirir.

### Açık soru

Normal zorlukta da akorun her notası ayrı parmak istemeli mi? Şu an istemiyor
(tek parmak yeterli); oyuncuya soruldu, yanıt bekleniyor.

## Ses — kayıt, sentez değil

**Oyun artık gerçek piyano kaydı çalıyor.** `assets/piano/salamander.bin` —
Alexander Holm'un Salamander Grand Piano'su (bir Yamaha C5), CC BY 3.0,
`tool/fetch_samples.dart` ile paketleniyor. Minör üçlü aralıklarla 30 nota,
22050 Hz mono, 2.53 MB.

Neden: sentez tizde çözülemedi. Sorun tek bir notanın tınısı değil,
**notaların birbirine göre dengesiydi**. Ölçüm (orta Do'ya göre):

| nota | sentez | kayıt |
|---|---|---|
| Do5 (72) | −1.0 dB | **−9.2 dB** |
| Do6 (84) | −2.0 dB | **−10.0 dB** |
| Si♭6 (94) | −7.9 dB | **−13.9 dB** |
| Re#7 (99) | −10.8 dB | **−18.9 dB** |

Nokturn'ün melodisi tam bu aralıkta yaşıyor. Sentezleyici istenen genliği
aynen veriyordu; gerçek piyano tizde çok daha sessiz.

Denenip **atılan** bir şey: notaları komşularına göre eşitlemek. Eğri dik ve
dışbükey olduğu için komşu ortalaması her tiz notayı yukarı çekiyor —
kazanılan ayrımın yarısını geri veriyordu (Do6, −10 dB'den −6 dB'ye). Kalan
notadan notaya dalgalanma kaydın kendi vuruş farkı; gerçek bir enstrüman
böyle duyulur.

`SynthEngine.trebleGain` **yalnız sentez yedeğinde** geçerli. Kayıtta
uygulanmıyor: kaydın kendi eğrisi zaten daha dik ve daha doğru.

### Notaların birbirine bağlanması

- **Kapı (gate) kaldırıldı.** Her nota yazılı uzunluğunun %92-95'ine
  kısaltılıyordu; gerekçesi "aynı perde tekrar basılınca yeniden seslensin"di.
  O gerekçe geçersiz: `SynthEngine.noteOn` zaten çalmakta olan bir perdeyi
  yeniden başlatıyor. Tek yaptığı, parçadaki **her notanın altına bir boşluk
  koymak**tı — ölçüldü, ardışık nota çiftlerinin ~%100'ünde 30-211 ms.
- **Bırakma pedallı piyano gibi** (`_Voice._pedalTau`): 80 ms yerine 350 ms
  (tizde) / 550 ms (baste). Bu repertuvar pedal için yazılmış.

**Ölçemediğim şey, ve neden peşine düşmeyin:** "notalar arası düşüş"
diye bir ölçüt yazdım (zarfın vuruş tepesine göre ne kadar çukura indiği).
Nokturn'de ortanca −13.6 dB çıkıyordu, kulağa "kesik" gelmesinin sebebi bu
sanıldı. Ama **hiç `noteOff` göndermeden** render alınca −10.6 çıktı, yani
neredeyse aynı. Ölçtüğüm şey piyanonun kendi vuruş tepesiyle sürdürmesi
arasındaki fark; bir kusur değil. Bırakma süresini uzatmak bu sayıyı
kurtarmaz, uğraşmayın.

### Yükleme ve yedek

`PianoAudio.loadSamples()` beklenmeden çağrılıyor; banka gelene kadar (ve
okunamazsa temelli) sentezleyici çalıyor, yani oyun asla sessiz kalmıyor.
Banka bir kez ayrıştırılıp `PianoAudio._bank`'ta paylaşılıyor — her şarkı
için yeniden okumak takılmaya sebep olurdu. Şarkı listesi ekranı, oyuncu
seçim yaparken bankayı önden ısıtıyor.

Bankayı yeniden üretmek için ağ ve iki araç gerekir:

```bash
apt-get install -y mpg123 sox
dart run tool/fetch_samples.dart
```

**Lisans:** CC BY 3.0, atıf zorunlu. Şarkı listesi ekranının altında yazıyor
(`song_list_screen.dart`), ayrıca `assets/piano/SALAMANDER-CC-BY.txt`.
ShareAlike yok, yani App Store için sorun değil — Nokturn'ün nüshasından
farklı olarak.

## Kod haritası

```
lib/audio/     sample_bank.dart  kayıtlı piyano (asıl ses kaynağı)
               synth_engine.dart sentez + örnek çalma; banka yoksa yedek
               pcm_output*: iOS/Android'de flutter_pcm_sound, web'de Web Audio
lib/music/     note/song modeli, nota yazım dili (notation.dart), MIDI okuyucu
lib/game/      chart.dart      Difficulty, Tap, el bölgeleri, seyreltme, koşular
               play_session.dart  şarkı saati, dokunuş eşleme, tutma, sürükleme,
                                  gecikme telafisi
               judgement.dart  Judge, TimingTolerance, Scoreboard
               stage_geometry.dart  düz düzen, vuruş çizgisi 0.68, sabit nota
                                    boyutu, akor yayılımı, tutmanın çizgide durması
lib/render/    stage_painter.dart  tüm oyun alanı çizimi; nota fırçaları önbellekli,
                                   koşuların üstünden geçen ip
lib/screens/   song_list_screen.dart  ekran ve ayarların durumu
               song_list/settings.dart  ChoiceRow<T>, QuantizeSwitch, LatencyPicker
               song_list/song_tile.dart  listedeki bir şarkı; oyuna geçişi bu yapar
               play_screen.dart  oyun alanı, saat, dokunuş yönlendirme
lib/widgets/   score_hud.dart  oyun sırasındaki puan ve seri
               result_panel.dart  şarkı sonu
lib/data/      song_library.dart  şarkıyı varlıktan okur; rootBundle'ın tek yeri
               song_info.dart     bir şarkı hakkında, açmadan bilinenler
               score_import.dart  nüshadan gelen MIDI'yi oyuna uydurur
               catalog.g.dart     ÜRETİLMİŞ — şarkıların künyesi
assets/songs/  ÜRETİLMİŞ — şarkıların kendisi, MIDI olarak
tool/          catalog.dart       ŞARKI BURAYA EKLENİR
               build_library.dart nüshaları indirir, varlıkları ve künyeyi üretir
               scores/            kendi düzenlemelerimiz (.ly)
               render_song.dart, render_demo.dart  WAV üretici
               fetch_samples.dart piyano kaydını indirir, salamander.bin üretir
               inspect_midi.dart  MIDI'yi ölçü ölçü döker, nüshayla karşılaştırmak için
docs/          magic-piano-analiz.md  mekanik incelemesi
```

### Ölçülmüş maliyetler

Bir tahminle uğraşmadan önce buraya bakın. 60 fps bütçesi kare başına
16700 µs.

| iş | maliyet |
|---|---|
| `StagePainter.paint` (Nokturn, 18 dokunuş görünür) | 314 µs/kare (%1.9) |
| `Chart.visibleAt` | 41 µs/kare |
| Ses üretimi, örnek yolu, 10 ses | 155 µs / 46 ms blok (%0.33) |
| Ses üretimi, sentez yedeği | 664 µs / blok (%1.4) |
| `Chart.build` (Nokturn, zor) | 11.7 ms, bir kez |
| `SongLibrary.all` ilk çağrı | 55 ms, bir kez |

Yani **çizim de ses de darboğaz değil.** Nota fırçaları önbelleğe alındı
(367 → 314 µs); akor yayılımını kareden çıkarmak da denenebilir ama ölçüm
buna değmediğini söylüyor ve `Chart`'a ekran boyutu vermeyi gerektirir.

### Dikkat edilecek noktalar

- `song_list/song_tile.dart` içindeki `MaterialPageRoute` **her ayarı**
  `PlayScreen`'e geçirmeli. İki kez unutuldu, oyun ayarları görmezden geldi.
  `test/song_list_test.dart` bunu doğruluyor.
- Çalınmışlık durumu dokunuş indeksiyle değil `Set<(beat, midi)>` ile tutulur;
  aksi halde cihaz döndürülünce bozuluyordu.
- **Tek saat kuralı.** Dokunuşu notayla eşleme, ne kadar isabetli olduğuna
  karar verme ve kaçmış notayı silme — üçü de `PlaySession._judgedBeat`
  kullanmak zorunda. Bir dönem yalnız karar verme gecikmeyi telafi ediyordu;
  arada gecikme genişliğinde bir bant kalıyordu: dokunuş bir notaya eşleniyor,
  sonra o notaya uzak sayılıp `null` dönüyordu — ne ses ne geri bildirim.
  Oyuncu bunu "bazen algılıyor bazen algılamıyor" diye bildirdi.
  `test/play_session_test.dart` içindeki "with a latency to compensate for"
  grubu bunu kilitliyor.
- Ses yolundaki gecikme `audio.latencyMs` ile telafi edilir, yoksa her dokunuş
  geç sayılır. **Web'de `outputLatency` okunmalı, `baseLatency` değil**:
  ikincisi yalnız ses grafiğinin iç tamponu (birkaç ms), hoparlöre giden yolu
  hiç saymaz. iOS'ta o yol 100 ms'nin çok üstünde, Bluetooth'ta daha da fazla.
  Yanlış olanı okuduğumuz sürece oyun kendini 50 ms geride sanıyordu, gerçekte
  300 ms geride olabiliyordu — her dokunuş geç sayılıyordu.
- Cihazın bildirdiği hiçbir zaman tam değil (Bluetooth'u, oyuncunun kendi elini
  bilemez). Bu yüzden şarkı listesinde **elle zamanlama ayarı** var
  (`song_list/settings.dart` içindeki `LatencyPicker` →
  `PlayScreen.latencyOffsetMs` → `PlaySession`), yanında da **"Ölç"** düğmesi:
  `CalibrationScreen` metronoma vurdurup gerçek değeri ölçüyor.
- **Kalibrasyon ekranı kendi saatini okur, karenin saatini değil.** Kare 16 ms
  geniş, ölçülen şey ondan küçük; ikisi için de karenin damgasını almak
  cevaba bir kare kayma koyardı. Saat bu yüzden `Stopwatch`. Ama widget
  testinde `pump` sahte bir saati ilerletir, `Stopwatch` kıpırdamaz — o
  yüzden `CalibrationScreen.nowMs` diye bir dikiş var. Onsuz ekranın hiçbir
  parçası test edilemiyordu.
- **Kalibrasyon ekranında `pumpAndSettle` kullanmayın.** Ekran durduğu sürece
  bir ticker çalışıyor, hiçbir zaman durulmuyor; test zaman aşımına uğrar.
  Açık `pump` ile ilerletin (`test/calibration_screen_test.dart`'taki
  `settleRoute`).
- iOS'ta ses için her `onPointerDown`'da `_audio.nudge()` çağrılır (AudioContext
  kullanıcı hareketiyle uyanmalı).
- **`SongLibrary` alanları getter olmamalı.** Getter'ken her okuyuş dört
  şarkıyı sıfırdan kuruyordu — base64, MIDI ayrıştırma, 2818 nota — ve şarkı
  listesi bunu `build()` içinde okuyor. Çağrı başına 4.7 ms; her `setState`
  bedeli ödüyordu. `static final` olarak Dart bir kez kuruyor.
- **Web ses bloğu 1024 kare** (`pcm_output_web.dart`). Bu, gecikmeye bu
  düğümün kendi katkısı: 23 ms. 2048'di, kayıtlı piyano sentezleyicinin
  yerini alınca (blok doldurma 664 → 155 µs) yarıya indirildi. Telefonda
  cırtlama duyulursa geri çıkarılacak sayı budur — bedeli 23 ms gecikme.

## Şarkılar

| id | Ad | BPM | Nota | Süre | Kaynak |
|---|---|---|---|---|---|
| `canon-run-test` | Kanon — koşu denemesi | 55 (♩) | 624 | 2:51 | Kanon'un 18. ölçüsünden |
| `ode-to-joy` | Neşeye Övgü | 160 (♩) | 149 | 0:24 | Piano Flow düzenlemesi |
| `canon-in-d` | Kanon, Re Majör | 55 (♩) | 818 | 4:05 | Mutopia + Piano Flow düzenlemesi |
| `fur-elise` | Für Elise | 144 (♪) | 1038 | 2:35 | Mutopia WoO 59 |
| `prelude-in-c` | Prelüd, Do Majör | 60 (♩) | 549 | 2:20 | Mutopia BWV 846 |
| `entertainer` | The Entertainer | 72 (♩) | 2621 | 4:12 | Mutopia, Joplin 1902 |
| `gnossienne-1` | Gnossienne No. 1 | 100 (♩) | 832 | 3:16 | Mutopia, Satie 1890 |
| `nocturne-op9-no2` | Nokturn, Mi Bemol Majör | 132 (♪) | 1231 | 3:22 | Mutopia Op. 9 No. 2 |

### Şarkı eklemek

**Bir şarkı eklemek `tool/catalog.dart`'a bir kayıt eklemektir.** En azı:

```dart
Score(
  id: 'moonlight-1',
  title: 'Ay Işığı Sonatı, 1. bölüm',
  composer: 'Ludwig van Beethoven',
  url: 'https://www.mutopiaproject.org/ftp/.../moonlight.ly',
  credit: 'Kamu malı (Op. 27 No. 2, 1801). Mutopia baskısı ...',
),
```

sonra

```bash
dart run tool/build_library.dart
```

Araç indirir, `convert-ly` ile günceller, MIDI'ye çevirir,
`assets/songs/<id>.mid` yazar ve `lib/data/catalog.g.dart`'ı yeniden üretir.
**Nüshadan okunabilen her şey nüshadan okunur:** tempo, ölçü, uzunluk, ses
aralığı, nota sayısı. `SongLibrary` içinde hiçbir şarkı adı geçmez; liste
kendiliğinden büyür.

Elle verilmesi gereken yalnızca üç şey var, çünkü nüsha bunları söylemiyor:

- `beatsPerQuarter` — parça sekizliklerle sayılıyorsa 2 (3/8, 12/8), yoksa 1.
  Tempo da bundan çıkıyor: nüshanın dörtlük işareti çarpı bu.
- `rightVelocity` / `leftVelocity` — nüshada nüans yok, MIDI'de her nota aynı
  gürlükte. Kalın bir sol el (Chopin'inki neredeyse her sekizlikte üç nota)
  ezginin altına çekilmezse üstüne biniyor.
- `credit` — ne olduğu ve hangi lisansla geldiği. CC bir baskı için bu nezaket
  değil, kullanma şartı.

Araç dört tür kaynak biliyor:

| | ne verilir |
|---|---|
| tek `.ly` | `url` |
| parçalardan oluşan zip | `url` + `entry` |
| başkasının nüshasına yama olarak yayımlanmış düzenleme | `url` + `patchUrl` + `entry` |
| kendi düzenlememiz | `local`, ya da arşivin parçalarını kullanan bir montaj için `url` + `assemble` |

Son ikisi `tool/scores/` altındaki kendi `.ly` dosyalarımız.

Üretilen MIDI `tool/.cache/` altında saklanıyor ve anahtarı onu değiştirebilecek
her şey; yani yüz şarkılık bir kataloğa bir şarkı eklemek bir şarkı kadar
sürüyor. Önbellek commit edilmiyor, **varlıklar ediliyor** — uygulamayı
derlemek için ne bu araç ne internet gerekiyor.

### Deneme parçaları — `fromBar`

Bir kayda `fromBar` verilirse şarkı o ölçüden başlıyor; öncesi atılıyor ve
kalan başa çekiliyor (`SongInfo.startBeat`, `ScoreImport` uyguluyor).

Sebebi somut: **sürükleme mekaniği Kanon'da 79. saniyede başlıyor.** Onu
denemek için her seferinde bir buçuk dakika kanon çalmak gerekiyordu.
`canon-run-test` 18. ölçüden başlıyor, ilk koşu 4,6 saniyede geliyor ve
listenin başında duruyor.

Kalıcı bir kütüphane parçası değil; mekanik oturunca silinebilir. Testler
onun gerçekten aynı müzik olduğunu — sadece daha geç başladığını —
doğruluyor, ve diğer bütün şarkıların `startBeat`'inin sıfır kaldığını.

Bu aslında bir çalışma özelliğinin yarısı: "N. ölçüden başla" öğrenen
herkesin istediği şey. Eksik olan yalnızca arayüzü.

### Neden base64 değil, varlık

Notalar önce base64 olarak Dart'a gömülüydü. Dört şarkı için sorun değildi;
yüz şarkı için ~1.5 MB Dart kaynağı demek ve **hepsi ilk şarkının ilk
notasından önce indiriliyor**. Varlık olarak bir şarkı seçilene kadar hiçbir
şeye mal olmuyor.

Bunun bedeli `SongLibrary.load`'un asenkron olması. Karşılığında `SongLibrary.all`
senkron ve ucuz kaldı — liste ekranının ihtiyacı olan her şey
(`SongInfo`: ad, besteci, tempo, süre, nota sayısı, ses aralığı) üretilmiş
sabit bir listede duruyor, notalar değil.

`lib/data/song_library.dart` `rootBundle` kullanan **tek** yer; onu import
etmek `dart:ui` getiriyor, o yüzden komut satırı araçları ve testlerin çoğu
`catalog` ile `ScoreImport.read`'e gidip aynı dosyayı diskten okuyor.

`test/song_library_test.dart` katalogla varlıkların birbirini tutmasını
kontrol ediyor: her şarkının dosyası var mı, her dosya katalogda mı, katalogun
söylediği nota sayısı/süre/aralık nüshanınkiyle aynı mı. Araç çalıştırılmayı
unutulursa oyun sessizce yanlış tempoda çalar; bu testler onu yakalar.

### Kanon: neden kendi düzenlememiz

Eser **üç keman ve bas** için yazılmış, yani kopyalanacak bir klavye nüshası
yok. Önce Isaac David'in Mutopia nüshasına yama olarak yayımladığı
transkripsiyonu aldık: dört partiyi iki porteye katlıyor, sadık, ve her
sekizlikte sağ el dört nota kalınlığında. Okuma partisyonu, piyano parçası
değil — oyuncu haklı olarak "bu Canon in D'nin piyano hâli değil" dedi.

Şimdiki hâli arşivin kendi parti dosyalarından kuruluyor
(`tool/scores/canon-in-d.ly`): **sağ el birinci keman, sol el zemin bas.**
İkisi de nüshadan olduğu gibi; hiçbir nota uydurulmadı, sadece seçildi.
İkinci ve üçüncü kemanlar dışarıda, çünkü birinciyi aynı oktavda kovalıyorlar;
klavyede uyum değil çakışma oluyor.

1947 notadan 818'e indi ve `chordsOf(melody)` en fazla iki nota kalın — testte
kilitli.

`score_import.dart` nüshaya yalnızca şunları yapar — hepsi testli:

- **Vuruş birimi** (`beatsPerQuarter`). Für Elise 3/8; vuruş sekizliktir,
  o yüzden MIDI'nin dörtlükleri 2 ile çarpılır.
- **Süslemeler atılır.** LilyPond `\grace`/`\appoggiatura` notalarına
  kırıntı kadar süre verir (0.026–0.055 dörtlük); gerçek en kısa nota
  otuz ikiliktir (0.125). Für Elise'de üç tane var. Bunlar ayrı bir
  dokunuş olamaz — süsledikleri notadan milisaniyelerle önce gelirler.
- **Izgaraya oturtma**: dörtlüğün 1/48'i. Otuz ikilikleri de üçlemeleri de
  tam tutar. Yoksa akorun notaları birkaç ondalık tick arayla düşüp ayrı
  dokunuşlar olarak çizilirdi.
- **El başına gürlük.** Nüshada nüans yok; MIDI'de her nota aynı hızda.

Bir uyarı: **arşivdeki her `.ly`/`.ily` `convert-ly`'den ve MIDI'ye
hazırlamadan geçmeli.** LilyPond kaynakları birbirini include ediyor ve iki
dosya öteki bayat bir `\layout` hâlâ gravür motorunu çağırıp derlemeyi
düşürüyor.
### Lisans — hepsi aynı lisansta değil

Müziğin kendisi hepsinde kamu malı. Ama **baskılar aynı lisansta değil**:

- Für Elise ve Prelüd: dizgiciler baskıyı kamu malına bırakmış.
- **Nokturn: CC BY-SA 3.0.** Dizgicinin (Renato Biolcati Rinaldi) adı
  anılmalı ve baskıdan türetilen her şey — `scores.g.dart`'taki MIDI ve
  ondan çıkan nota verisi dahil — aynı lisansı taşır.
- **Kanon: CC BY 4.0** (Michael Fischer v. Mollard'ın nüshası). Atıf ister,
  share-alike istemez. Piyano düzenlemesi artık bizim, ama notalar onun
  nüshasından geldiği için atıf yine gerekiyor.
- **Gnossienne: CC BY-SA 4.0** (Knute Snortum). Nokturn'le aynı durum.
- The Entertainer: dizgici baskıyı kamu malına bırakmış.

Şu an uyumluyuz: `source` alanında dizgici ve lisans yazıyor, oyun içinde
şarkı listesinde görünüyor, `song_library_test.dart` bunu kontrol ediyor.
**App Store hazırlığında (yol haritası adım 9) buna tekrar bakılmalı**;
katı biçimde yalnız kamu malı isteniyorsa Nokturn için başka bir baskı
bulunmalı.

### Elle yazılmış veride bulunan hata

Prelüd'ün tamamı bir oktav aşağıdaydı (`G3 C4 E4` yazılmıştı, doğrusu
`G4 C5 E5`). Nüshadan okuyunca düzeldi; `song_library_test.dart` bunu artık
kilitliyor.

### Tempolar

Aşağıdakiler eserin **yazılı** temposu. Oyunda hız seçici var (varsayılanı
Tam hız) ve bunları oranlıyor; şarkı verisi her zaman gerçek tempoda durur.

- Neşeye Övgü: Beethoven'ın kendi metronom işareti, Allegro assai,
  yarım nota = 80, yani ♩ = 160.
- Kanon: nüsha ♩ = 55 diyor.
- Für Elise: nüsha ♩ = 72 diyor, 3/8 olduğu için ♪ = 144.
- Prelüd: nüsha ♩ = 60 diyor.
- Nokturn: nüsha doğrudan ♪ = 132 diyor (Andante, 12/8).

Neşeye Övgü hâlâ bizim düzenlememiz: tema önce viyolonsel ve kontrbas için
yazılmış, kopyalanacak bir piyano nüshası yok. Beethoven'ın Re majörü yerine
Do majörde, ezgi beyaz tuşlarda kalsın diye.

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
flutter test        # 280 test geçiyor
```

## Cihazsız doğrulama

Elde cihaz yok; her değişiklik şöyle doğrulanıyor:

```bash
dart run tool/render_song.dart fur-elise /tmp/a.wav   # şarkıyı çal, WAV'a yaz
flutter test test/stage_painter_test.dart             # oyun alanını build/screens/*.png yap
dart run tool/inspect_midi.dart score.mid 1.5         # MIDI'yi ölçü ölçü dök
```

Üretilen WAV ve PNG'ler oyuncuya gönderiliyor.

## Ana ekrana ekleme (telefonda app gibi)

Oyun `display: standalone` bir web app. iPhone'da Safari → Paylaş → **Ana
Ekrana Ekle**; sonra kendi ikonuyla, Safari çubuğu olmadan açılıyor.

`web/index.html` içinde bunun için duran ve **silinmemesi gereken** şeyler:

- **`viewport` meta.** Yoktu. Yokken telefon sayfayı 980 piksellik varsayılan
  genişlikte kurup küçültüyor; oyun yanlış ölçekte çiziliyor ve dokunuşlar da
  o ölçekte geliyor. Muhtemelen uzun süredir görülen düzen tuhaflıklarının
  bir kısmı buydu.
- **`viewport-fit=cover` bilerek YOK.** Kapalı bırakılınca iOS sayfayı güvenli
  alanın içinde tutuyor. Bu oyunun vuruş çizgisi ekranın altına yakın (0.68);
  tüm ekrana yayılsa o çizgi ana ekran çubuğunun altına düşer ve oradaki
  kaydırma nota çalmak yerine uygulamadan çıkar.
- **`touch-action: manipulation`** ve arkadaşları: çift dokunuşla yakınlaştırma
  (ve onu beklemekten gelen gecikme), uzun basınca metin seçme/menü, iki
  parmakla yakınlaştırma — hepsi oyunun ortasında tetikleniyordu. `none`
  değil `manipulation`, çünkü şarkı listesinin kaydırılması gerekiyor.
- **`gesturestart` engelleme:** Safari `user-scalable=no`'yu düzensiz
  uyguluyor. Bu oyun tasarımı gereği ikinci parmağı istiyor (her el bir yan),
  o parmak yakınlaştırma yapmamalı.

**Service worker hâlâ yok ve olmamalı.** Ana ekrana ekleme onu gerektirmiyor.
Bedeli çevrimdışı oynama (zaten hiç olmadı), kazancı düzeltmelerin telefona
gerçekten ulaşması.

İkonlar `tool/make_icons.py` ile üretiliyor (Pillow gerekir). Flutter'ın
şablonundan gelenler Flutter logosuydu; ana ekranda o görünüyordu.

## App'e geçiş — ne gerekiyor

Oyuncu bunu bir kez sordu ("kusurlar tarayıcıdan olabilir mi?") ve cevabın
bir kısmı evet çıktı; şimdilik ana ekrana ekleme seçildi. Gerçek app'e
geçilirse tablo şu:

| Yol | Maliyet | Buradan yapılabilir mi | Ses gecikmesi |
|---|---|---|---|
| Ana ekrana ekle (şimdiki) | yok | evet, yapıldı | tarayıcı yolu, ~23 ms + cihaz |
| TestFlight'tan iOS app | Apple Developer **$99/yıl** | CI kurulur; hesap ve sertifika oyuncudan | 10-20 ms |
| Android APK | yok | Android SDK kurulursa evet | 10-20 ms |

**Repo public**, yani GitHub Actions'ın macOS makineleri ücretsiz — Mac
olmadan iOS derlemesi mümkün. Tıkanan yer derleme değil, **imzalama**:
telefona kurmak için ya TestFlight (ücretli hesap) ya da Mac'te Xcode ile
ücretsiz 7 günlük provisioning gerekiyor. Oyuncuda Mac yok.

Android APK burada üretilebilir ama oyuncu iPhone kullanıyor; yalnızca
"native ses gerçekten fark ediyor mu" sorusunu para harcamadan yanıtlamak
için anlamlı.

## Yayınlama (GitHub Pages)

Oyuncu iPhone'dan oynuyor, Mac/Xcode yok. Web derlemesi
**https://omerrdeniz.github.io/Claude/** adresinde yayında; kaynağı `gh-pages`
dalı. Tek komut:

```bash
tool/deploy.sh
```

Derler, damgalar, `gh-pages`'e ve çalışılan dala iter, sonuçta sürümü yazar.
Çalışma dizini temiz değilse çalışmayı reddediyor — yayınlanan şeyin hangi
commit olduğu belli olmalı.

**Sürüm numarası.** Dalın commit sayısı (`git rev-list --count HEAD`), yani
her yayında bir artıyor ve bakışta karşılaştırılabiliyor: v51'in v50'den yeni
olduğu bellidir, iki commit hash'inin hangisinin yeni olduğu belli değildir.
Yanında commit hash'i de duruyor, asıl kimlik o. İkisi de şarkı listesinin
üstünde yazıyor (`versionLabel`), ve **her değişiklikten sonra oyuncuya
söyleniyor** — bir düzeltmenin işe yaramadığını, hiç ulaşmadığından ayırmanın
başka yolu yok.

`--pwa-strategy=none` ve `web/index.html` içindeki service worker kaldırma
betiği **şart**: yoksa telefonda eski derleme kalıyor ve saatlerce yanlış
sürüm test ediliyor.

## Yol haritası

| Adım | Durum |
|---|---|
| 1. Ses motoru | ✅ (kayıtlı piyano; sentez yedek) |
| 2. Şarkı verisi + MIDI okuyucu | ✅ (şarkılar basılı nüshadan) |
| 3. Oyun ekranı | ✅ |
| 4. Dokunuş, değerlendirme, puan | ✅ |
| 5. Adaptif tempo + eşlik | ⏳ |
| 6. Zorluk kademeleri | ✅ (eller/parmaklar olarak) |
| 7. Cila: efektler, temalar, gecikme kalibrasyonu | ⏳ (kalibrasyon ✅) |
| 8. Şarkı kütüphanesi ekranı + MIDI içe aktarma | ⏳ |
| 9. App Store hazırlığı | ⏳ |

## Park edilenler

Başlanmış ama oyuncunun isteğiyle bırakılmış işler. Fikir olarak yeniden
"keşfedilmesin" diye burada:

- **Silinen klavye arayüzü.** `SoundCheckScreen` ve `PianoKeyboard` hiçbir
  yerden erişilemediği için silindi; gerçekten istenirse `4fa9039^`
  commit'inden çıkarılır.

## Sıradaki iş

1. **Parmağın yetişemediği yerler — büyük ölçüde çözüldü, denenmedi.**
   Tam hızda bazı geçitler dokunma hızının üstünde kalıyor:

   | Şarkı | En dar aralık | Kaç dokunuş |
   |---|---|---|
   | Nokturn | 76 ms (ölçü 16 ve 24, otuz ikilik üçlemeler) | 408'de 9 tanesi 100 ms altı |
   | Für Elise | 104 ms (doruktaki otuz ikilik iniş) | — |
   | Prelüd | 250 ms | yok |

   Cevap sürükleme mekaniği oldu (yukarıda, "Kabul edilenler"). Kimseden
   nota alınmıyor, kendi kendine hiçbir şey çalmıyor, tek tek basmak da
   hâlâ mümkün — yalnızca ikinci bir yol açıldı. **Ama henüz gerçek
   telefonda oynanmadı** (ilk iki sürümü oynandı ve reddedildi; yukarıya
   bakın). Bakılacaklar: `dragReach` (%15) çok mu geniş/dar; `dragLeadMs`
   (900 ms) raya girmeye yetiyor mu.

   Eşik ölçümü (oyuncu sordu, karar verilmedi): nota araları kuantize
   olduğu için 150 ile 200 ms arasında neredeyse hiçbir şey yok — 200'ün
   tek kazancı Nokturn'de bir koşu, tek maliyeti Neşeye Övgü'de olmaması
   gereken iki koşu, ve **210 ms'de uçurum var**: Für Elise'in on
   altılıkları oraya düşüyor ve şarkının %90'ı tek bir sürüklemeye
   dönüşüyor. 175 ms güvenli duruyor. Minimum uzunluğu 3'ten 4'e çıkarmak
   Kanon'daki kısa ipleri temizler; Kanon kendi düzenlememize geçince
   3'lük koşular 58'den 23'e zaten düştü.
2. **Delik/kendi çalma ikilemi çözülmedi, sadece seçeneğe bağlandı.**
   Doldurma kapalı gelirse Nokturn'ün üçte ikisi sessiz; açılırsa oyun
   basmadığınız her şeyi çalıyor. Üçüncü bir yol olabilir ve zorluk
   kademesine bağlanabilir: Kolay'da sol eli oyun çalsın (zaten seyreltiyor),
   Normal ve Zor'da hiçbir şey çalmasın. O zaman kadranın hangi ucunda
   olduğunuzu zorluk söyler ve ayrı bir anahtar gerekmez. Oyuncuya
   sorulmalı.
3. Normal zorlukta akor parmaklama sorusu yanıtlanacak.
4. MIDI içe aktarma **arayüzü** (yol haritası adım 8) — okuyucu ve dönüştürücü
   hazır, eksik olan yalnızca dosya seçme ekranı. Oyuncu kendi MIDI'lerini
   ekleyebilsin diye.
5. Kolay moddaki seyreltme (`Chart._divideVoices`, `minGap = 0.5` vuruş) vuruş
   birimine bağlı: Für Elise'de vuruş sekizlik olduğu için 0.5 vuruş bir
   on altılığa denk geliyor ve pek seyreltmiyor. Saniyeye çevrilmesi gerekebilir.
