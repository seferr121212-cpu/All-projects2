# Ufuk Yolu / Horizon Road — Yol Haritası

Her aşama **çalışır halde** biter: Godot komut satırından (headless + gerekirse
pencereli) çalıştırılır, hata/uyarı çıktısı temizlenir, sonra commit atılır ve
kısa rapor verilir.

Genel doğrulama araçları:
- `godot --headless --path . --import` → içe aktarma/parse hataları
- `godot --headless --path . --quit-after N` → sahne yükleme ve çalışma zamanı hataları
- Headless test sahneleri (`tests/`) → sistem mantığı (zaman, ekonomi, kayıt) için assert'ler
- Ekran görüntüsü (`--write-movie` veya viewport capture) → görsel kontrol

---

## Aşama 0 — Kurulum ve belgeler ✅
- Proje iskeleti, `project.godot`, klasör yapısı, GDD.md, PLAN.md.
- **Bitti:** belgeler onaylandı, Godot 4.7 sürümü doğrulandı.

## Aşama 1 — İskelet + karavan + Karadeniz yaylası (boş ama güzel) ✅
- Autoload'lar: GameState, TimeManager, WeatherManager, SaveManager (stub),
  Localization, AudioManager.
- InputMap (KB+M + gamepad): sür, fren, dön, kamera, in/bin, fotoğraf, günlük.
- Araç kontrolcüsü (onaylanan yaklaşım), takip + kokpit kamerası, yüzey çekişi.
- Bölge 1: arazi (yer tutucu mesh/heightmap), yol, çay terasları, MultiMesh ağaçlar,
  WorldEnvironment, gün döngüsü ışık eğrileri, sis, yağmur/sis/açık hava, ortam sesi.
- Debug paneli: saati hızlandır, havayı değiştir, FPS.
- **Bitti:** oyuncu karavanla bölgeyi gezebiliyor, gün döngüsü ve en az 3 hava
  durumu görsel+işitsel olarak değişiyor; konsolda hata yok; 60 FPS hedefinde.

## Aşama 2 — Fotoğraf modu + günlük albümü ✅
- Vizör UI, ızgara, DOF, pozlama, filtreler; PNG kaydı; hedef tespiti ve puanlama.
- Günlük ekranı: Albüm sekmesi.
- **Bitti:** çekilen fotoğraf `user://photos/` altında PNG olarak oluşuyor, puanı ve
  hedefleri ile albümde görünüyor; yeniden başlatınca kayıtlı.

## Aşama 2.5 — Görsel cila (kullanıcı isteği) — 1. tur ✅
- Arazi: doku/renk geçişleri, düz üçgen lekelerini yumuşatma, yol kenarı geçişleri.
- Bitki: daha fazla ağaç/çalı varyasyonu, yumuşak silüet, yakında yoğun çimen.
- Su: yansıma, kıyı köpüğü; ışık: SDFGI/SSIL (kalite ayarına bağlı), sıcak gölgeler.
- Bulut: hacimli bulut + araziye bulut gölgesi.
- Karavan: daha yuvarlak model, krom detaylar, kokpit içi; saat başına renk düzeltme.
- **Bitti:** önce/sonra ekran görüntüleriyle karşılaştırma onaylandı.

## Aşama 3 — İlk esnaf + diyalog + mini aktivite + para ✅
- JSON diyalog sistemi (TR/EN), ilişki seviyesi, isimle hitap.
- Çay üreticisi NPC + çay hasadı mini aktivitesi.
- Para (GameState), economy_config, HUD'da para göstergesi, fotoğraf satışı.
- **Bitti:** oyuncu NPC ile konuşup aktiviteyi bitiriyor, para kazanıyor, ilişki
  seviyesi artıyor; diyaloglar her iki dilde çalışıyor.

## Aşama 4 — Yükseltmeler + karavan içi + kayıt ✅
- Yükseltme verisi + mağaza UI (tamirci), yakıt.
- Karavan iç mekanı: yatak (uyku), harita masası, günlük defteri.
- SaveManager tam: otomatik + elle kayıt/yükleme.
- **Bitti:** yükseltme satın alınıp etkisi hissediliyor; uyku zamanı ilerletiyor;
  kaydet-çık-yükle döngüsü tüm durumu koruyor (headless testle doğrulanmış).

## Aşama 5 — Çizim modu ✅
- 2D tuval, fırça/renk, silik referans, PNG kaydı, günlükte Çizimler sekmesi, satış.
- **Bitti:** çizim kaydedilip günlükte görünüyor ve satılabiliyor.

## Aşama 6 — Ege bölgesi + hava/mevsim çeşitliliği + geçiş ✅
- Ege balıkçı köyü sahnesi, balıkçı NPC + ağ toplama aktivitesi.
- Bölge geçişi (yol + yükleme perdesi), bölge başına palet/mevsim profili, fırtına ve kar.
- **Bitti:** iki bölge arasında kayıpsız geçiş; her bölgenin kendi atmosferi var.

## Aşama 7 — Ses, müzik, menüler, ayarlar, yerelleştirme, cila, build ✅
- Ana menü, duraklat, ayarlar (grafik/ses/dil/tuş/gün uzunluğu), müzik katmanları.
- Tüm metinler CSV'de; eksik anahtar taraması.
- Windows export (export templates gerekir).
- **Bitti:** Windows .exe başlıyor, ana menüden oyun tamamen oynanabiliyor.

## Aşama 8 — Görsel cila 3, Kapadokya, Doğu Anadolu, ikinci işler, gezici kafe ✅
- Görsel: yuvarlak, parlak boyalı karavan (pencereler, conta, kapı çizgileri, gece iç ışık),
  karlı/kayalık uzak dağlar (ayrı shader), çayır yamalı renkleri, iki parçalı renk geçişli
  çimen, şeffaf kenarlı yollar, daha temiz hava (daha az pus), vinyet.
- Kapadokya: tüf yamaçlar ve kanyonlar, peri bacası kümeleri (çarpışmalı), şafak balonları
  (hava uygunsa uçar), kesme taş köy, kavaklar, bağlar; Zeynep Usta + çömlek oyunu.
- Doğu Anadolu: geniş yayla, Büyük/Küçük Ağrı, dağ gölü, göçer çadırları, arı kovanları,
  koyun sürüsü; Ferhat Amca + sürüyü ağıla toplama (3B).
- İkinci işler (dostluk 1. seviyeden sonra): çay demleme, traktör ayarı, ağ onarma.
- Gezici kafe (yükseltme), bölgeye göre menü, bahşiş, müşteri NPC'leri.
- Model paketleri için `AssetLibrary` + `data/assets/asset_overrides.json`.
- **Bitti:** dört bölge arasında seyahat; 136 otomatik kontrol geçiyor; tüm yeni akışlar
  DevCli ile uçtan uca doğrulandı (`--job=...`, `--cafe`).

---

## Alınan kararlar
1. Araç fiziği: `CharacterBody3D` arcade kontrolcü (onaylandı).
2. Godot 4.7: bulut ortamında resmî Linux sürümü kullanılıyor (onaylandı).
3. CC0 siteleri ağdan engelli → Aşama 1 varlıkları kodla üretildi (bkz. ASSETS.md).

## Aşama 1 notları
- Test: `godot --headless --path . res://tests/test_runner.tscn` (23 kontrol).
- Görsel kontrol: `godot --path . -- --hour=18.9 --weather=fog --shot=out.png`
  (tüm seçenekler `scripts/dev/dev_cli.gd` başında). Ekran görüntüleri `docs/screenshots/`.
- Bilinen sorunlar:
  - Gerçek GPU'da FPS ölçülmedi (ortamda yalnızca yazılımsal Vulkan var).
    Ağır kalemler: hacimli sis, 60k çimen öbeği, 4 bölmeli gölge. Ayarlar ekranında
    kalite seçenekleri Aşama 7'de; şimdilik `VegetationScatter.density_scale` ile düşürülebilir.
  - Kokpit kamerasında iç mekân yok (Aşama 4: karavan içi).
  - Yağmur karavan çatısından içeri yağabilir (parçacık çarpışması yok).
  - Çıkışta dummy ses sürücüsüne bağlı zararsız "ObjectDB leaked" uyarısı.

## Aşama 2 notları
- F: fotoğraf modu (oyuncuya 8 m bağlı serbest kamera), J: günlük.
- Puan = içerik %45 + kompozisyon %30 + pozlama %15 + odak %10 + özel an bonusu;
  ayarlar `data/photo/photo_config.tres`. Minimum puan var, ceza yok.
- Albüm `user://photos/album.json` + PNG/JPG küçük resim; kayıt slotlarından bağımsız
  (eski kaydı yüklemek fotoğrafları silmez).
- Bilinen sorunlar: inekler çarpışmasız (karavan içinden geçer); fotoğraf satışı ve
  esnafa gösterme Aşama 3'te; lens yükseltmeleri (`GameState.lens_level`) Aşama 4'te.

## Aşama 3 notları
- NPC: Fadime Karaca (çay üreticisi), çaylığın kenarındaki çardakta, 06:00–21:00.
- Diyalog: `data/npcs/fadime.json` (akış) + `localization/dialogue.csv` (TR/EN metin).
  Koşullar: flag / not_flag / level_min / level_max / has_photos.
  Eylemler: meet, relationship, set_flag, start/complete_activity, open_photo_picker, sell_photo.
- İlişki: Yabancı 0 → Tanıdık 20 → Dost 50 → Yakın dost 100. Dostlukla selam değişir,
  ipuçları açılır, fotoğraflar daha pahalıya satılır.
- Çay hasadı: 15 tutam (3 altın filiz bonus), süre yok, istediğin an teslim edebilirsin.
- Ekonomi ayarları: `data/economy/economy_config.tres`. Başlangıç 50 ₺; tam sepet 98 ₺;
  fotoğraf satışı NPC başına günde 1.
- Test: `godot --path . -- --story` tüm döngüyü oynar (`--stop=intro|name|hub|harvest|deliver|picker|photo`).
- Bilinen sorunlar: karakterlerin yüz detayı yok (görsel cilada); çay çalıları çarpışmasız
  (oyuncu üstlerinden geçer); satılan fotoğraf işareti albümde kalır, eski kayıt yüklense de geri gelmez.

## Görsel cila 1. tur notları
- Yapılan: hareketli bulut gölgeleri (serin tonlu), arazide eğrilik gölgelendirmesi + ton
  çeşitliliği + yarı yumuşak normaller + yakın plan çimen dokusu, SSIL, su (Fresnel + kıyı
  köpüğü), çalı/eğrelti/huş/sazlık, 90k çimen, karakter yüzleri ve kolları, karavan detayları.
- Düzeltilen hatalar: göl seviyesinin altındaki çayırların "göl dibi" rengine boyanması,
  öğlen bile duran koyu vadi sisi.
- Karşılaştırmalar: `docs/screenshots/polish_*.jpg`.
- 2. tur adayları: hacimli bulutlar, SDFGI (yüksek kalite ayarı), karakter animasyonu,
  daha yuvarlak karavan modeli, gerçek CC0 model paketleri (ASSETS.md).

## Aşama 4 notları
- Yükseltmeler `data/upgrades/upgrades.json`: motor (2), arazi lastiği (2), farlar, yakıt deposu,
  lens (2, fotoğraf yakınlaştırması), konfor (2, iç mekâna kilim/bitki/ışık zinciri).
- Tamirci Recep Aydın (köy girişindeki atölye, 07:00–19:30): dükkân, yakıt, sohbet, fotoğraf alımı.
  Dostluk seviyesi başına %5 indirim.
- Yakıt: 45 L (büyük depo 70 L), ~2 L/km; depo boşsa araç durmaz, %35 hızla gider.
- Karavan içi: yan kapıdan girilir, birinci şahıs. Yatak (sabaha kadar uyu / 3 saat kestir,
  ardından otomatik kayıt), çaydanlık, harita masası, günlük. Oda karavanın gerçek konumunda
  kurulur; pencerelerden gerçek dünya ve hava görünür, içeride yağmur yağmaz.
- Harita: M tuşu veya harita masası; araziden çizilir, tanışılan esnaflar işaretlenir.
- Kayıt: `user://saves/*.json` (sürüm 2). Otomatik kayıt 4 dakikada bir, uyuyunca ve oyundan
  çıkarken; F5/F9 hızlı kayıt/yükleme; açılışta otomatik kayıttan devam. Sahne nesneleri
  `save_participant` grubuyla kendini kaydeder (karavan konumu, yarım kalan hasat).
- Test: 73 kontrol; `--workshop`, `--interior`, `--map`, `--continue` geliştirici akışları.
- Bilinen sorunlar: yükleme her zaman sürücü koltuğunda başlatır; iç mekânın pencerelerinde cam yok.

## Aşama 5 notları
- B: çizim modu (yürürken ya da araç dururken). O anki görüntü referans olarak dondurulur;
  dünya duraklar, kaydedince 30 dakika geçer.
- Araçlar: 12 renk (çizim malzemeleri 1 ile 24), kalem, yumuşak fırça (malzeme 1),
  suluboya (malzeme 2), silgi, 4 fırça boyu, geri al (Ctrl+Z, 15 adım), temizle,
  referans kapalı/silik/belirgin.
- Tuval 960x540; fırça damgaları önceden hazırlanıp C++ `blend_rect` ile basılıyor.
- Kayıt `user://drawings` (PNG + küçük resim + index.json), kayıt slotlarından bağımsız.
- Puan yok; değer = doluluk + kullanılan renk + manzarada konu varsa bonus.
- Fadime ve Recep çizim alır (kendi tepkileriyle); günlükte "Çizimler" sekmesi.
- Test: 86 kontrol; `--sketch [--stop=draw|open]` geliştirici akışı.
- Bilinen sorun: gamepad ile çizim yok (fare gerekli).

## Aşama 6 notları
- Ege Balıkçı Köyü (`regions/aegean_village`): `CoastalTerrain` (HighlandTerrain'den türetildi):
  koy, kumsal (SAND yüzeyi), turkuaz sığlık, burun, ufukta adalar; teraslı zeytinlikler,
  servi, fıstık çamı, maki; beyaz badanalı evler; taş iskele, kayıklar, ağlar, liman feneri, kediler.
- Hasan Reis (balıkçı): ağ çekme ritim oyunu (12 çekiş, ıskalamak sadece yavaşlatır),
  5 balık türü (lagos nadir), yakıt satışı, fotoğraf/çizim alımı; Fadime'yi tanıyorsan ona değinir.
- Seyahat: bölge kenarındaki yol tabelasında ya da karavan içindeki harita masasında, haritadan
  "… yoluna çık". Yolculuk perdesi; 990 km / 14 saat, deponun %60'ı. Yarım kalan işler iptal olur.
  Varışta karavan yeni bölgenin yol girişinde; otomatik kayıt.
- Kayıt bölgeye duyarlı: başka bölgede alınmış kayıt önce o bölgeyi yükler.
- Mevsimler: 7 günde bir (yaz → sonbahar → kış → ilkbahar). Bölge başına renk tonu, yerde kar
  ve hava ağırlıkları (`season_profiles`). Karadeniz kışı karlı, Ege kışı yağmurlu.
- Görsel cila 2. tur: yürüme animasyonu (kol/bacak), bulutlarda güneşe göre öz-gölge.
- Test: 104 kontrol; `--fishing`, `--travel=<bölge>`, `--season=<mevsim>`, `--curtain`.
- Bilinen sorunlar: bölge değiştirince öbür bölgedeki yarım iş kaydedilmez; NPC'ler animasyonsuz.

## Aşama 7 notları
- Başlık ekranı (canlı yayla üzerinde yavaş kamera), Esc duraklatma menüsü, yeni yolculuk
  (albüm ve çizimler korunur), son kaydı yükleme.
- Ayarlar: grafik kalitesi (Düşük/Orta/Yüksek/Ultra; MSAA, çözünürlük ölçeği, SSAO/SSIL,
  hacimli sis, SDFGI, gölge, bitki yoğunluğu), tam ekran, dikey eşitleme, FPS sınırı; 4 ses
  kanalı; dil, gün uzunluğu, fare hassasiyeti/ters Y; 19 eylem için klavye tuş atama.
- Müzik: `MusicGenerator` (Karplus-Strong telli + pad + yankı), bölge başına gündüz/gece/sürüş
  parçası, arka plan iş parçacığında üretim, parçalar arası 1–2,5 dk sessizlik.
- Yerelleştirme taraması testi: koddaki/verideki her anahtarın TR+EN karşılığı var (106 kontrol).
- Build: `export_presets.cfg` (Windows x86_64 + Linux), PCK gömülü. Linux build'i headless
  olarak tüm akışlarla doğrulandı. Windows exe burada çalıştırılamadı (wine yok).
- Bilinen sorunlar: Windows exe gerçek Windows'ta denenmedi; gamepad ile menü gezintisi kısmen
  (odak var ama tam test edilmedi); FPS gerçek GPU'da ölçülmedi.

## Aşama 8 notları
- Kenney sitesi otomatik (tarayıcı olmayan) indirmeleri reddediyor; bu engeli aşmaya
  çalışılmadı. Paketler elle indirilip `assets/models/...` altına konduğunda
  `asset_overrides.json` üzerinden otomatik kullanılır (çalışma zamanında .glb yükleme test
  edildi).
- Uzak mesafe bulanıklığı (DOF) denendi, tüm görüntüyü bulanıklaştırdığı için kaldırıldı.
- Bilinen sorunlar: kafe müşterileri basit yürür (animasyonsuz); balonlar uzaktan sisle soluk
  görünebiliyor; Kapadokya'da bazı peri bacaları tüf yamaç kenarına denk gelebiliyor.

## Notlar / varsayımlar
- Proje mevcut `All-projects2` git deposunun içinde `horizon-road/` alt klasöründe;
  ayrı iç içe depo açmak yerine bu depo kullanıldı.

## Aşama 10 — Blender yapılar ve iskeletli karakterler
- `tools/blender_structures.py`: 4 ev stili (yayla, ege, tüf, plato; camlar ayrı GLB, gece yanar), peri bacaları, kıl çadır, kayıklar.
- `tools/blender_characters.py`: iskeletli karakterler (kadın, köylü, çoban/kepenek, balıkçı, gezgin), animasyonlar idle/walk/work/talk.
- `CharacterRig` (scripts/core/character_rig.gd): NPC, kafe müşterileri ve yürüyen oyuncu bunu kullanır; rig yoksa statik meshe düşer.
- Oranlar: bel/göğüs profilli gövde, omuz, el/başparmak; kıyafet: yelek, önlük, çiçekli etek, oya, kepenek, çizgili kazak, sırt çantası.

## Aşama 11 — Hayvanlar, kamper, cila, yol görevleri (v0.9.0)
- `tools/blender_animals.py`: iskeletli inek/koyun/kedi/köpek (idle/walk/work=otlama); GrazingHerd ve sürü işi kullanır; köylere köpekler.
- Kamper: `tools/blender_camper.py` iç donanım; camlar şeffaf, sağ sürgülü kapı yaklaşınca açılır (`camper_paint` door_open).
- Cila: peri bacaları düz zemine, balonlar sisten etkilenmez, çiçekli etek.
- `QuestLog` + data/quests/quests.json: 11 yol görevi, ödül, günlükte "Yol görevleri" sekmesi.

## Aşama 12 — Derinlik, cila, gerçek-donanım testi (v1.0.0-rc)
**A. Derinlik:** her bölgeye 2. NPC (Ayşe/Murat/Ali... hikâye karakteri, iş yok), 3 bölümlük kişisel hikâye
(ilişki seviyesi 1/2/3'te açılır, seçimli diyalog, ödül), her hikâyenin sonunda "yol parçası"; 4 parça = final.
Yeni diyalog eylemleri `give:<n>`, `story:<id>`; QuestLog'a `flag` türü ve hikâye görevleri.
**B. Cila:** karakterlere parmak/yüz detayı (Blender), inek formu, konuşurken ses blip'leri, ayak sesleri.
**C. Test:** `--smoke` (tüm bölgeleri gezip hata/süre ölçer), hikâye akış testleri, F3 panelinde
"QA raporu" (FPS p50/p95, GPU, çizim sayısı, hata sayısı → user://qa_report.txt) — gerçek GPU'da senin
makinenden geri bildirim için. Windows paketi + kontrol listesi (docs/QA.md).
- Yapıldı (Aşama 12): 4 hikâye NPC'si (Ayşe/Murat/Selim/Leyla, 3 bölüm + harita parçası + final görevi), diyalog eylemleri give/story/story_piece,
  konuşma blip'leri + ayak sesleri, parmak/yüz detayı, `QaReport` + F3 "QA raporunu kaydet", `--smoke` (4 bölge PASS), docs/QA.md. Sürüm 0.10.0.

## Aşama 13 — Karavan detayı ve Quaternius paketleri (v0.11.0)
- Karavan: Blender'da lastik (tırtıl, jant, kapak), çamurluk kemerleri, basamak, ızgara, merdiven, tente, bidon, sandalye (`camper_wheel/extras`).
- İç mekân: perdeler, buzdolabı, saat, ayna, kanca/şapka/ceket, çizme, bitki-bitkisel demetler, gitar, kitaplar, fotoğraf duvarı (albümden), Quaternius sırt çantası/radyo/tencere/pusula/ilk yardım/telefon/gaz tüpü...
- Paketler: ağaçlar (yaprak kartları alfa kesmeli), çiftlik yapıları, gemi. Dönüştürücü: `tools/convert_packs.py`.
