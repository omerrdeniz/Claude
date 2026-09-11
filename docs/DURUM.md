# Durum ve devir notu

Bu dosya, sohbet geçmişi olmayan yeni bir oturumun projeyi kaldığı yerden
sürdürebilmesi için yazıldı. Son güncelleme: vuruş geri bildirimi eklendi;
kütüphane 18 parçaya indirildi.

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

Dal: **`main`**, ve tek dal o. Bir dönem her oturum kendi dalını açtı ve
proje hiç `main`'e girmedi (`main` boş bir "Initial commit"ten ibaretti);
geriye birbirinin içinde duran dört dal kaldı. Hepsi `main`'de toplandı,
gerisi silindi.

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
- **Çarpma süslemesi (acciaccatura) tek dokunuş, ve bir fiske.** Oyuncunun
  isteği: *"bu tarz piyano tekniklerine farklı mekanikler eklemek, hem
  oynanışı çeşitlendirmiş oluruz."* İlk teknik bu.

  **Önce bir hata vardı.** Gnossienne No. 1'in yüz süslemesi ayrı birer
  dokunuş olarak duruyordu: aynı elde **63 ms** arayla iki basış. İnsan eli
  bunu yapamaz, yani o yüz nota sistematik olarak kaçıyordu ve oyuncu sebebini
  bilmiyordu. (Nüshada süsleme komutuyla değil gerçek süreli kısa notalar
  olarak yazıldıkları için `ScoreImport`'un süsleme ayıklayıcısı da onları
  görmüyordu.)

  **Tanıma kuralı** (`Chart._crushOrnaments`, `Tap.graceSeconds` = 0.12 sn,
  `Tap.graceMainSeconds` = 0.25 sn): kendisi kısa olan, aynı elde **duran** bir
  notadan bir nefes önce düşen nota bir süslemedir. İki eşik de saniye
  cinsinden. Gnossienne kuralı kendisi veriyor — yüz süslemesinin **hepsi**
  63 ms uzunluğunda ve 63 ms önce. İkinci şart olmazsa hızlı figürler süsleme
  sanılıyor: Handel'in Passacaglia'sında gevşek kural 119 buluyordu, doğrusu
  26.

  Kütüphanede 140 tane var: Gnossienne 100, Passacaglia 26, Nokturn 9,
  Für Elise 3, Chopin valsi 2. Hızlı parçalarda (Kanon, Entertainer, Prelüd)
  tek bir yanlış tanıma yok.

  **Ses:** süsleme asıl notaya bağlanır (`Tap.grace`), tek dokunuş ikisini de
  çalar, **aradaki 63 ms'yi oyun verir** — el değil. Süsleme biraz daha hafif
  vurulur (`_graceWeight` = 0.8); acciaccatura'nın ağırlığı asıl notadadır.

  **Fiske:** dokunduktan sonra parmağı süslemenin eğildiği yöne ~%4 ekran
  genişliği kaydırmak bir *süs* kazandırır (`PlaySession.flick`, 50 puan,
  0.3 sn pencere). **Toplama değil ekleme:** düz basmak da iki notayı çalar ve
  tam puan alır; fiske yalnız üstüne ekler. Puan doğruluğa (`accuracy`)
  girmez — doğruluk zamanlama sorusudur, bu değil.

  **Yön gerçek, mesafe değil.** Süslemelerin %70'i aşağı, %30'u yukarı eğiliyor
  — yani yön okunacak bir bilgi. Ama çoğu 1-2 yarım ses uzakta, ki perdeden yer
  üreten bu ekranda 7 piksel eder. Onun için hem mekanik hem çizim yalnızca
  **yönü** kullanıyor: ekranda süsleme gerçek perdesine değil, notanın yanında
  sabit bir adıma konuyor. İlk hâli gerçek perdesine koymuştu ve süsleme
  notanın altında kayboluyordu.

  **Koşu mekaniğinin hatasını tekrarlamaz.** Orada hareket *miktarı* sürekli
  ölçülüyordu ve parmak yön değiştirmek için durduğunda nota düşüyordu. Fiske
  tek bir anda olup biten tek bir hareket; ölçtüğü şey "ne tarafa", "ne kadar
  sürekli" değil.

  **Yol üstünde bulunan ikinci hata:** Kolay moddaki seyreltme süslemeyi tutup
  **asıl melodi notasını atıyordu** — çünkü süsleme önce geliyor ve seyreltme
  ilk gördüğünü tutuyor. Yani Kolay'da oyuncu süsü çalıyor, ezgiyi oyun
  çalıyordu. `_divideVoices` artık süslemeyi kendi başına bir an saymıyor:
  bağlı olduğu notayla birlikte kalıyor ya da birlikte gidiyor.
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

  **Kuyruğu kısa kalan nota hiç tutmalı çizilmez.** Oyuncu bildirdi: *"bazı
  basılı tutmalı notalar görsel olarak çok kısa olmuş ve basılı tutmalı gibi
  göstermek anlamsız olmuş"* — Gnossienne No. 1'de. Sebebi yukarıdaki iki
  kuralın çarpımı: nota 1.9 saniye çınlıyor olabilir ama çubuğu elin bir
  sonraki işine kadar çiziliyor (`drawnEndBeat`), ve oradan bir de 1.6
  yarıçaplık açıklık düşüyor. Geriye notanın kendisinden kısa bir güdük
  kalıyordu: "burada bekle" diyen, beklenemeyecek kadar kısa bir şey.

  Eşik yeni bir sayı değil, çizimin zaten sorduğu soru: çubuk **kendi
  kalınlığının iki katından** kısaysa o dokunuş sıradan nota olarak çiziliyor
  — ne çubuk, ne çizgide durma (`StageGeometry.holdReadsAsBar`, çizerdeki
  `_Dot.isHold`). Eskiden asgari çubuk boyu kalınlığın yarısıydı, yani
  boyundan geniş bir çubuk.

  **Ses ve yargı hiç değişmiyor:** `Tap.isHold` ve `Tap.sustains` oldukları
  gibi duruyor. Değişiklik güvenli, çünkü kuyruğu kısa olan nota **tam
  olarak** sustain'i olan notadır (el zaten alınıyor) ve o notanın sesi parmak
  kalkınca zaten kesilmiyordu. `test/stage_geometry_test.dart` bunu tüm
  kütüphane üzerinde kilitliyor.

  Kapsam: 1568 tutmanın 149'u (%9.5), üç parçada — Prelüd 66 (134'ün yarısı),
  Passacaglia 69, Gnossienne 14. Diğer on parçada tek nota değişmiyor;
  Kanon'un yürüyen bası kasten tutmalı ve öyle kalıyor.

  **Karar piksel cinsinden, ve bu bilerek.** İniş süresi hıza bakmaksızın
  1.9 saniye (`approachSeconds`), yani kuyruğun ekrandaki boyu doğrudan
  gerçek saniyeye bağlı: telefonda eşik 0.32 saniyeye denk geliyor. Şarkıyı
  %40 hıza aldığınızda aynı nota 0.8 saniyelik kuyruk çiziyor ve yine tutmalı
  görünüyor — çalışma hızında yapının görünmesi doğru olan.
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

  **Altıncı tur — birleştirme geri alındı.** Oyuncu: *"3'lüler ile diğerleri
  arasında boşluk var, birleştirmesek daha iyi olurdu."* Haklı: 273 ms'lik
  nefes gerçek bir boşluk ve ipi onun içinden geçirmek müziği yanlış
  gösteriyor. Sürdürme eşiği (`runCarrySeconds`) kaldırıldı; tek eşik kaldı.
  Kanon yine 31 koşu, 3'ten 11 notaya. Kısa koşular artık sorun değil, çünkü
  parmak ele bağlı ve yakalanacak bir şey yok.

  **Beşinci tur — iki eşik, bir tane değil (geri alındı, yukarıya bakın).** Oyuncu Kanon'daki üçlülerin
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

- **Elden bırakılmak zorunda kalınan nota kesilmez.** Bir elde bir tutmalı
  nota sürerken aynı ele başka bir nota geliyorsa, oyuncunun tek parmağı var
  ve bırakmaktan başka seçeneği yok. O yüzden böyle notalar (`Tap.sustains`)
  parmak kalkınca susmuyor: yazılı sonuna kadar çalmaya devam ediyor ve
  ekranda çizgide sabit kalıyor.

  Oyuncu bildirdi ve ölçüm doğruladı: Prelüd'ün 134 tutmalı notasının **66'sı**,
  Gnossienne No. 1'in 324'ünün **194'ü** böyle. Yani o parçalarda kural
  neredeyse her zaman devredeydi ve oyuncu doğru oynadığı için cezalandırılıyordu.

  Ardından hiçbir şey gelmeyen notada eski davranış duruyor: erken bırakırsan
  nota kesilir. Öğretici olan kısım orada kalıyor, müziğin izin verdiği yerde.
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

Aynısı **Mariage d'Amour** için de geçerli (Paul de Senneville, 1978, telif
Coronet-Delphine Music). Yaygın olarak Chopin'e atfedilir — "Spring Waltz"
diye dolaşır — ama Chopin değil ve kamu malı değil.

Üçüncü istek **Rush E** (Andrew Wrangell / Sheet Music Boss, 2018). Aynı
kapıya çıkıyor: telifli bir beste, Mutopia'da da KernScores'ta da yok, ve
zaten hafızadan yazılabilecek bir parça değil — on binlik nota yoğunluğu
notasıyla birlikte gelir ya da hiç gelmez.

### Nota kaynağı ararken: bakılacak yerlerin sırası

Passacaglia'da sırayla KernScores ve Mutopia'ya bakıp "makine okunur nüsha
yok" dendi. Oyuncu ısrar etti, **IMSLP'de vardı** — ve IMSLP kütüphanenin en
büyük kaynağı olarak duruyordu. Sıra şu olmalı:

1. **Mutopia** — LilyPond kaynağı, `url:` ile doğrudan derlenir.
2. **KernScores** — `**kern`, `midiUrl:` ile MIDI olarak iner.
3. **IMSLP** — en geniş katalog. Dosyalar bir yönlendirme sayfasının
   arkasında; doğrudan adres dosya adının md5'inden türüyor:
   `…/usimg/<h[0]>/<h[0:2]>/IMSLP<no>-<ad>` (h = md5(ad)). Sayfada
   sentezlenmiş MIDI varsa `midiUrl:` ile alınır.
4. **Elle yazmak** — `arrangement:` ile `.notes`. Ancak hiçbiri yoksa.

Ve bir ayrım daha: **aynı eserin iki katmanı olabilir.** Handel'in HWV
432/6'sı ile Halvorsen'in 1893 düzenlemesi aynı numarayı taşıyor ama farklı
parçalar; tanınan hal Halvorsen'inki. Oyuncu "Passacaglia" derken hangisini
kastettiği sorulmadan eklendi, yanlış çıktı. Şimdi üçü de kütüphanede:
Handel'in kendisi, Halvorsen'inki ve elle yazılmış kolay hal.

### Dizgi olarak gelen müzik

Halvorsen'inki sonunda bir **Online Sequencer dizgisinden** geldi
(oyuncu gösterdi). Sitenin verisi protobuf: nota başına perde, başlangıç,
süre, gürlük. Perde numarası MIDI'nin iki üstünde; zaman birimi bir
onaltılık. Çevirici `tool/onlinesequencer_to_midi.py`, `Score.localMidi`
alanı da bunun için — nüsha olarak değil dizgi olarak gelen müzik.

Dizginin künyesi yok, kimin yaptığı yazmıyor. Oyuncuya söylendi, riski
bilerek eklenmesini istedi. Künye alanında nereden geldiği yazıyor.

Yasal yol **MIDI içe aktarma** (yol haritası adım 8): dosya oyuncunun
cihazında kalır, repoya da yayına da girmez. Okuyucu ve dönüştürücü hazır,
eksik olan sadece dosya seçme ekranı. Oyuncuya iki kez önerildi, ilkinde
"şimdilik gerek yok" dedi; Rush E ile birlikte üçüncü kez gündemde.

Bunun yerine kütüphaneyi **klasik dışına** açtık: Joplin'in ragtime'ı ve
Satie. İkisi de kamu malı, ikisi de mevcut repertuvara hiç benzemiyor.
Aynı raftaki diğer adaylar: Debussy'nin Clair de Lune'ü (Mutopia'da var,
ama nüshada sayısal tempo yok ve 9/8 — vuruş birimi elle verilmeli),
Arabesque 1 ve 2, Satie'nin Gnossienne 2 ve 3'ü, Joplin'in dokuz ragtime'ı
daha.

### Vuruşun kendisi bir olay

Oyun bir **öğretme aracı değil**, oynarken keyif alınacak bir oyun. Oyuncu
bunu açıkça söyledi ve sıradaki iş listesi buna göre yeniden yazıldı: tek el
modu, ölçüden başlama, hız merdiveni gibi öğretim fikirleri **istenmiyor**.

Eksik olan, saniye saniye hissedilen şeydi. Bir nota vurulduğunda olan tek
şey elin tarafında soluk bir parıltı ve bir kelimeydi; elli seri ile üç seri
aynı görünüyordu.

- **Kıvılcımlar** (`lib/render/hit_sparks.dart`). Her çalan nota, kendi
  yerinde çizgide kısa bir parlama bırakıyor: azıcık açılıp olduğu yerde
  sönüyor, ilk anında beyaz bir çekirdek. Akorun her notası ayrı bir kıvılcım
  — üç notalık akor üç şey olmalı, çünkü öyle.

  **Dışa yayılan halka denendi ve geri alındı.** Saniyede bir düzine
  atıldığında halkalar birbirini ve üstteki notaları kesiyor, çizgi su
  üstündeki dalgalara dönüşüyor; oyuncu "karışık, dalga dalga yayılma gibi"
  dedi. İstenen şey "o nota burada patladı" — tek bir yerde olan bir şey.
  Ömür 420 ms'den 260'a, sınır 24'ten 16'ya indi.

  Saf veri + saat: Flutter yok, rastgelelik yok, çizim yok. Nasıl göründüğü
  çizerin işi. **Sayısı sınırlı (24)**: yoğun bir geçit saniyede bir düzine
  atıyor ve sınırsız bir liste, oyunun tam da en iyi hissetmesi gereken
  yerde takılmasının yolu.
- **Çalınan nota çizgide biter.** Eskiden basılan da basılmayan da aynı
  şekilde çizgiyi geçip soluyordu; ekran oyuncunun bir şey yapıp yapmadığı
  hakkında hiçbir şey söylemiyordu. Artık vurulan nota çizgide harcanıyor
  (ışık patlaması onun yerine geçiyor), yalnızca kaçırılan akıp gidiyor.
- **Seri sayacı sayıyor.** Her notada bir tekme, seri uzadıkça daha büyük;
  puntosu ve rengi de seriyle birlikte artıyor.
- **Sahne ısınıyor.** Zemindeki ışık havuzu, vuruş çizgisinin parlaklığı ve
  kalınlığı seriyle büyüyor; çarpan tavana vurduğunda tam ısıda.

Bulanıklık (blur) yok — ölçülmüştü, kare başına ekranın geri kalanının
tamamından pahalı. Her şey halka ve disk.

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

On sekiz parça, hepsi kamu malı, hepsi basılı nüshadan. Liste **en sakinden
en yoğuna** sıralı ve her satırın yanında saniyede kaç dokunuş istediği yazıyor.

| Ad | Besteci | BPM | Nota | Süre | Dokunuş/sn |
|---|---|---|---|---|---|
| Gymnopédie No. 2 | Satie | 66 | 371 | 2:57 | 1.1 |
| Prelude Op. 28 No. 20 | Chopin | 42 | 286 | 1:14 | 1.5 |
| Sonata K. 331 (theme) | Mozart | 112 | 476 | 1:55 | 2.8 |
| Gnossienne No. 1 | Satie | 100 | 832 | 3:16 | 3.2 |
| Canon in D | Pachelbel | 55 | 818 | 4:05 | 3.3 |
| Canon in D (run test) | Pachelbel | 55 | 624 | 2:51 | 3.6 |
| Menuett, WoO 82 | Beethoven | 112 | 1160 | 3:15 | 3.7 |
| Ode to Joy | Beethoven | 160 | 149 | 0:24 | 3.8 |
| Prelude in C, BWV 846 | Bach | 60 | 549 | 2:20 | 3.9 |
| Nocturne Op. 9 No. 2 | Chopin | 132 | 1231 | 3:22 | 4.0 |
| Minuet in G minor, BWV Anh. 115 | Petzold | 140 | 398 | 1:22 | 4.6 |
| Melodie, Op. 68 No. 1 | Schumann | 92 | 303 | 1:02 | 4.7 |
| Minuet in G, BWV Anh. 114 | Petzold | 140 | 408 | 1:22 | 4.9 |
| La Candeur, Op. 100 No. 1 | Burgmüller | 152 | 340 | 1:00 | 4.9 |
| The Entertainer | Joplin | 72 | 2621 | 4:12 | 5.4 |
| Für Elise | Beethoven | 144 | 1038 | 2:35 | 5.9 |
| L'Arabesque, Op. 100 No. 2 | Burgmüller | 152 | 357 | 0:43 | 6.2 |
| Albumblatt, Op. 12 No. 3 | Grieg | 112 | 614 | 1:08 | 6.7 |

**Adlar orijinal dilinde ya da yerleşik İngilizcesiyle**, Türkçeleştirilmiyor.
Künye metinleri Türkçe — onlar ad değil, cümle.

### Bir kez 38'e çıkıp 18'e döndü

Bir partide yirmi "yaygın" klasik parça eklendi: Ay Işığı, Pathétique,
Rondo alla Turca, K545, Clair de Lune, Arabesque, Fantaisie-Impromptu, üç
Chopin prelüdü, Minute Waltz, Dağ Kralı, Träumerei, envansiyon, Schubert
impromptusü, Liszt Consolation'ı, Brahms valsi, iki Gymnopédie.

Oyuncu kaldırttı. Sebebi ölçülebilir: "yaygın" diye seçilmişlerdi, ama yaygın
çalınabilir demek değil. Fantaisie-Impromptu saniyede **14,9** dokunuş
istiyordu, Minute Waltz 11,0 — bu oyunun hedefi ise hiç piyano çalmamış
birinin iyi ses çıkarması. Kararı geri almak `tool/catalog.dart`'tan yirmi
kaydı silip aracı yeniden çalıştırmak oldu.

Kalıcı olarak kalan iki şey: **dokunuş/saniye ölçüsü** (`SongInfo.tapCount`,
liste onunla sıralanıyor ve her satırda Sakin/Akıcı/Hızlı/Çok hızlı yazıyor)
ve o parti sırasında araca eklenen bütün nüsha temizliği — `\layout` ve
`\paper` blokları, yorumlar, eski Scheme çağrıları, otomatik `\unfoldRepeats`.

### Sonra 19'a çıkıp 9'a döndü

Aynı şey bir kez daha oldu: KernScores'tan on parça girdi (Ay Işığı,
Pathétique Adagio, K545, Rondo alla Turca, iki Chopin prelüdü, iki Chopin
valsi, Promenade, Schubert impromptusü), oyuncu yine beğenmedi, yine
kaldırıldı. Kütüphane **dokuz** parçada: Mutopia baskıları, kendi
düzenlemelerimiz ve Chopin'in A minör valsi.

Buradan çıkan ders, kaydedilmezse dördüncü kez tekrarlanacak olan şu:
**parça toplu eklenmiyor.** "Yaygın klasik" bir seçim ölçütü değil; oyuncu
parçaları tek tek beğeniyor. Bir sonraki aday önce tek başına eklenip
sorulmalı.

`song_ground_test` bu partiyle birlikte bir şey daha öğretti: kaldırılan
parçaya isimle bağlı testler sessizce değil, `Bad state: No element` ile
patlıyor. Anahtar tablosu kalanlara indirildi, konusuz kalan test silindi.

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

Araç nüshalardaki eskimiş sözdizimini kendi temizliyor — yirmi parça
eklerken çıkanların hepsi kalıcı olarak çözüldü, çünkü hepsi bir sonraki
partide yine çıkacak cinsten:

- **`\layout` ve `\paper` blokları atılıyor.** İkisi de yalnız basılı sayfayı
  ilgilendiriyor ve ikisi de MIDI yazıldıktan *sonra* derlemeyi düşürüyor —
  okunması en zor hata türü.
- **Yorumlar atılıyor.** Süs değil: bir nüsha MIDI bloğunu yorum içinde
  saklıyor ve onu gerçek sanmak tekrar-açmayı yanlış score'a gönderiyor.
- **Eski Scheme çağrıları** (`override-auto-beam-setting`,
  `revert-auto-beam-setting`, `set-octavation`, `\applyMusic #unfold-repeats`)
  ayıklanıyor. Hepsi ya çizimle ilgili ya da bizim zaten yaptığımız şey.
- **`convert-ly` başarısızlığı ölümcül değil**: `\version`'ı olmayan bir
  include dosyasına takılıyor, ki yükseltilecek bir şeyi de yok.
- **`\unfoldRepeats` artık elle verilmiyor.** Araç `\midi` içeren `\score`
  bloğunu bulup müziği onun içinde sarıyor. Eskiden her parça için "hangi
  metnin önüne" diye bir alan vardı; sessizce yanlış score'a koymak için
  birebir uygun bir tasarım. (`\score` ararken kelime sınırı şart: yarım
  Chopin nüshası müziğini `\scoreAll` adlı bir değişkende tutuyor.)

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

### Vuruş değil saniye — üçüncü kez

Bu oyunda üç ayrı eşik vuruş cinsinden yazılmıştı ve üçü de her parçada
başka bir süre anlamına geliyordu. El vuruş nedir bilmez.

| Eşik | Vuruşken | Şimdi |
|---|---|---|
| Basılı tutma (`Tap.holdSeconds`) | 469–1364 ms arası | 0.7 sn |
| Aynı anda sayılma (`Chart.onsetSeconds`) | 14–33 ms arası | 0.03 sn |
| Kolay modda seyreltme (`Chart._divideVoices`) | **188–545 ms arası** | **hâlâ vuruş** |

Sonuncusu duruyor: "Kolay", Kanon'da 545 ms, Ode to Joy'da 188 ms aralık
bırakıyor — yani en kolay şarkının Kolay modu en zorunkinden üç kat sıkı.
Aynı düzeltme, aşağıda "Sıradaki iş"te.

Aynı anda sayılma eşiği yirmi parça eklenince patladı: Chopin'in çapraz
ritimleri gerçekten iki eli on beş milisaniye arayla koyuyor
(Fantaisie-Impromptu), Minute Waltz'ın süslemesi yirmi iki milisaniye. Bunlar
bozuk içe aktarma değil, müziğin kendisi.

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
- Petzold menuetleri, Beethoven'ın menueti, iki Burgmüller, Mozart'ın KV 331
  teması, Chopin'in 20. prelüdü, Gymnopédie No. 2, The Entertainer: dizgiciler
  baskıyı kamu malına bırakmış.
- Schumann'ın Melodie'si ve Grieg'in Albumblatt'ı: CC BY-SA.
- **Kanon: CC BY 4.0** (Michael Fischer v. Mollard'ın nüshası). Atıf ister,
  share-alike istemez. Piyano düzenlemesi artık bizim, ama notalar onun
  nüshasından geldiği için atıf yine gerekiyor.
- **Gnossienne: CC BY-SA 4.0** (Knute Snortum). Nokturn'le aynı durum.

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

Konteynerde Flutter **kurulu gelmiyor** — imajda Node, Ruby, Java, Gradle ve
Playwright var, Flutter ve Dart yok — ve kap her oturumda sıfırdan geliyor.
Artık bunu **oturum açılışında bir kanca yapıyor**:

- `.claude/hooks/session-start.sh` — klon (3.35.1), `safe.directory`, ilk
  çalıştırmayla Dart SDK'nın açılması, `flutter pub get`, ve PATH'in
  `$CLAUDE_ENV_FILE` üzerinden oturumun geri kalanına bırakılması.
- `.claude/settings.json` — kancayı `SessionStart`'a bağlıyor, 900 sn zaman
  aşımıyla (klon 832 MB, SDK açılımıyla birlikte birkaç dakika).

Kanca **senkron**: kurduğu şey oturumun ilk komutunun ihtiyaç duyduğu şey.
Yalnız uzak ortamda çalışıyor (`$CLAUDE_CODE_REMOTE`); yerel bir çalışma
kopyasının kendi Flutter'ı var. Elle kurmak gerekirse betiğin yaptığı budur:

```bash
git clone --depth 1 -b 3.35.1 https://github.com/flutter/flutter.git /opt/flutter
export PATH="$PATH:/opt/flutter/bin"
git config --global --add safe.directory /opt/flutter
flutter pub get
```

Flutter 3.35.1 / Dart 3.9.0 ile geliştirildi. root olarak çalıştığı için uyarı
verir, sorun değil.

**Kanca varsayılan dala girene kadar** yalnız onu taşıyan dalın oturumlarında
çalışır; kanca ayarları oturum açılırken okunuyor.

```bash
flutter analyze     # temiz olmalı
flutter test        # 420 test geçiyor
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

**Sürüm numarası.** Yayında ne varsa **onun bir fazlası**
(`gh-pages:build.json`), yani her yayında bir artıyor ve bakışta
karşılaştırılabiliyor: v51'in v50'den yeni olduğu bellidir, iki commit
hash'inin hangisinin yeni olduğu belli değildir.

Eskiden dalın commit sayısıydı ve bu sessizce **dal başına bir numaralandırma**
demekti: site v84 sunarken aynı commit'in çalışma kopyasındaki sayımı 58
çıkıyordu, ve yanlış daldan bir yayın numarayı geriye sardırırdı. Yayınlanan
tek bir site var, sayaç orada duruyor.
Yanında commit hash'i de duruyor, asıl kimlik o. İkisi de şarkı listesinin
üstünde yazıyor (`versionLabel`), ve **her değişiklikten sonra oyuncuya
söyleniyor** — bir düzeltmenin işe yaramadığını, hiç ulaşmadığından ayırmanın
başka yolu yok.

**Telefon eski derlemeyi tutuyordu.** Oyuncu sürüm değişince ana ekrandaki
uygulamaya gelip gelmediğini sordu — gelmiyor gibi görmüş, ve haklıymış.
Service worker'ı kaldırmak en kötüsünü çözüyor ama sıradan HTTP önbelleği tek
başına bir derlemeyi saatlerce servis etmeye yetiyor. Oyuncu açısından bu,
"düzeltme işe yaramadı" ile ayırt edilemez.

Üç katman:

1. `--pwa-strategy=none` ve `web/index.html` içindeki service worker kaldırma
   betiği.
2. `deploy.sh` sayfaya derleme numarasını damgalıyor, `flutter_bootstrap.js`
   ve `main.dart.js` adreslerine `?v=<sürüm>` ekliyor.
3. `index.html` açılışta `version.json`'ı önbelleksiz çekip kendi damgasıyla
   karşılaştırıyor; farklıysa sayfayı hiç önbelleğe girmemiş bir adresle
   (`?v=<sürüm>`) yeniden yüklüyor. Sürüm başına bir kez, yoksa inatçı bir
   kopya uygulamayı sonsuz döngüye sokar.

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

Oyun bir oyun; öğretme aracı değil. Sıra buna göre:

1. **Bitiş bir şey ifade etsin.** Şu an sonunda puan ve yüzde var. Yerine
   büyük bir harf/yıldız, "yeni rekor" patlaması, en uzun serinin öne
   çıkarılması.
2. **Arka plan müzikle yaşasın.** 38 parçanın hepsi aynı koyu zeminde
   geçiyor. Işık havuzu vuruşla nefes alsa, renk parçanın perdesine göre
   kaysa, her parça başka bir yerde geçiyormuş gibi olur.
3. **Kütüphane doldurulacak bir koleksiyon olsun.** Şarkı başına en iyi puan
   ve yıldız listede görünsün. Hiçbir şey saklanmıyor şu an.
4. **Uzun koşuları ödüllendir.** İp ve boncuk oyunun en gösterişli anı;
   koşuyu baştan sona takip edince ekranın patlaması, parçaların doruk
   noktalarını olay hâline getirir.

Kapanmamış eski işler:

0. **Passacaglia'da 31 ms'lik dokunuş çiftleri var.** Çarpma taraması sırasında
   çıktı: Handel'in parçasında aynı elde 31 ms arayla iki ayrı dokunuş isteyen
   yerler var. Süsleme değiller — arkalarından gelen nota kısa, yani hızlı
   figür. Basılamazlar. Ayrı bir iş, dokunulmadı.

5. **Kolay moddaki seyreltme vuruş cinsinden** (`Chart._divideVoices`,
   `minGap = 0.5` vuruş). Vuruş/saniye hatasının üçüncü ve sonuncusu:
   "Kolay" Kanon'da 545 ms, Ode to Joy'da 188 ms aralık bırakıyor. Sorulacak
   bir şey yok, düzeltilecek.
6. **Delik/kendi çalma ikilemi** seçeneğe bağlı duruyor. Zorluğa bağlamak
   üçüncü bir yol olabilir — **oyuncuya sorulmalı**, oyunun en eski kuralına
   dokunuyor.
7. **`canon-run-test`** sürükleme oturunca listeden kaldırılacak.
