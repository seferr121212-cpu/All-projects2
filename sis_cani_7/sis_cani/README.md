# SİS ÇANI / FOG BELL — Godot 4.7 Projesi

Kırlangıç Adası, 1977. Tasarım belgesindeki oyunun tamamı: 3 bölüm, 2 son ve gizli epilog var. Türkçe ve İngilizce altyazı ile seslendirme desteği hazır.

## Açma

1. Godot 4.7'yi aç, **Import** ile bu klasördeki `project.godot` dosyasını seç.
2. Ana sahneyi **F5** ile çalıştır (`scenes/main.tscn`).
3. İlk açılışta ses efektleri kodla üretildiği için 1–3 saniyelik bir bekleme olabilir.

Bütün görseller `art/` klasöründeki pixel art dosyaları: karakter animasyonları, Yankılar, objeler, dokular, 3 bölümün parallax arka planları ve açılıştaki 6 hikaye paneli. Hepsi `tools/art/` içindeki Python betikleriyle üretildi. Yeniden üretmek için `python3 tools/art/build_all.py` komutunu çalıştır (PIL gerekir). Sesler şimdilik kodla sentezleniyor.

## Kontroller

| Eylem | Klavye + Fare | Gamepad |
| --- | --- | --- |
| Yürü | A / D | Sol analog |
| Koş (Yankılar seni daha uzaktan duyar) | Shift | LT |
| Zıpla | Space / W | A |
| Eğil | S / Ctrl | B |
| Lamba yönü | Fare | Sağ analog |
| Lambayı yükselt (koni + huzme) | Sol tık basılı | RT |
| Lamba modu: normal → kısık → kapalı | Sağ tık | LB |
| Etkileşim / diyaloğu geç | E | X |
| El çanı (Bölüm 2'den sonra) | Q | Y |
| Kırmızı cam (Bölüm 2'den sonra) | F | D-pad yukarı |
| Günlük | Tab | Select |
| Duraklat | Esc | Start |

## Klasör yapısı

```
project.godot            ayarlar + autoload listesi
scenes/main.tscn         tek sahne; her şey koddan kuruluyor
scripts/
  main.gd                menü, bölüm geçişleri, sonlar, jenerik
  autoload/
    loc.gd               TR/EN metin sistemi (Loc.t("ANAHTAR"))
    game_state.gd        envanter, bayraklar, kayıt (user://save.json), ayarlar, başarımlar, tuşlar
    audio_manager.gd     bus'lar (Echo/Radio filtreleri), 3 katmanlı müzik, efektler
    light_system.gd      tüm ışık kaynakları; hem görüntü hem oyun kuralı aynı veriden
    dialogue_manager.gd  altyazı + seslendirme oynatıcı
  data/strings_db.gd     OTOMATİK üretilir (tüm diyaloglar ve arayüz metinleri)
  player/kerem.gd        hareket, etkileşim, el çanı, karanlık sayacı, yakalanma
  player/lamp.gd         4 mod, yakıt, koni ışık, aynalardan seken huzme
  enemies/echo.gd        Sürünen / Taklitçi / Bekleyen
  enemies/great_echo.gd  Büyük Yankı (Hüsnü Usta) ve Son B sis duvarı
  props/                 kandil, toplanabilirler, sandık, kapı/köprü/sal, çürük tahta,
                         ayna, mercek ve mühür, kırmızı yazı, su, tetikleyiciler
  levels/
    level_base.gd        bölüm kurma yardımcıları (solid, brazier, echo, trigger ...)
    chapter_one.gd       Bölüm 1: İskele ve Köy
    chapter_two.gd       Bölüm 2: Mağaralar ve Sarnıç
    chapter_three.gd     Bölüm 3: Fener Kulesi + seçim
    ending_escape.gd     Son B'nin oynanabilir kaçış sahnesi
    darkness_overlay.gd  karanlık + sis katmanı
    background.gd        parallax arka plan
  ui/                    HUD, ana menü, duraklatma, ayarlar, günlük, telsiz mini oyunu
shaders/                 darkness.gdshader, background.gdshader
localization/            dialogue.csv, ui.csv (seslendirme ekibi için, Godot bunları içe aktarmaz)
tools/                   strings_source.py (TÜM METİNLERİN KAYNAĞI), build_strings.py
audio/                   vo/tr, vo/en, music, sfx
```

## Metinleri değiştirmek

Bütün diyaloglar `tools/strings_source.py` dosyasında duruyor. Değişiklikten sonra şunu çalıştır:

```
python3 tools/build_strings.py
```

Bu komut `scripts/data/strings_db.gd` dosyasını ve `localization/*.csv` dosyalarını yeniden üretir. `strings_db.gd`'yi elle düzenleme.

## Seslendirme eklemek

Dosyaları anahtar adıyla koy. Oyun bunları otomatik bulur:

```
audio/vo/tr/C1_010.ogg
audio/vo/en/C1_010.ogg
```

`.ogg`, `.wav` ve `.mp3` desteklenir. Ses dosyası varsa satırın süresi sesin uzunluğu olur, yoksa altyazı metin uzunluğuna göre bekler.

- Filtreyi oyun kendisi uygular, ham kayıt koymak yeterli. `echo` satırları Yankı bus'ından (reverb + delay + pitch), `radio` satırları Telsiz bus'ından (band-pass + distortion) çıkar.
- Hangi satırın kime ait olduğu ve hangi filtreyi kullandığı `localization/dialogue.csv` içinde yazıyor (`speaker`, `filter` sütunları).
- Toplam 125 satır var: diyaloglar, 12 günlük sayfası ve 3 bant.

## Müzik ve efekt dosyaları

Aşağıdaki dosyaları eklersen kodla üretilen yer tutucuların yerine bunlar çalar:

- `audio/music/safe.ogg`, `tension.ogg`, `chase.ogg`: döngülü ve aynı tempoda olmalı. Üçü aynı anda çalar, yoğunluğa göre aralarında geçiş yapılır.
- `audio/sfx/`: `bell_big`, `bell_hand`, `ignite`, `pickup`, `whisper`, `click`, `door`, `static`, `page`, `crumble`, `ambient_sea` (hepsi `.ogg`).

## Görselleri değiştirmek

- 1 sanat pikseli oyunda 2 dünya pikseli olarak çiziliyor, kamera da 1.4x yakınlaştırıyor.
- Kendi çizimini kullanmak istersen aynı adla ve aynı kare boyutunda `art/` içine koy. Kerem sayfası 24x40'lık karelerden oluşuyor, satır düzeni `tools/art/chars.py` içinde yazıyor.
- Zeminler `LevelBase.solid(..., style)` ile dokulanıyor. Kullanılabilen stiller: earth, planks, cobble, rock, brick, stone, wood.

## Dekor

- Evler `tools/art/houses.py` ile çiziliyor. Bölüm dosyalarındaki her `house(...)` çağrısı için ayrı bir bina üretiliyor: ahşap iskelet ve taş dolgu, kiremit çatı, kepenkli ışıklı pencereler, baca. Bölümlere yeni bir ev eklersen `python3 tools/art/build_all.py` komutunu tekrar çalıştır.
- Godot'suz önizleme için: `python3 tools/preview/render.py c1_village /tmp/kare.png` (ya da `c2_cave`).

- `art/decor/` içinde 31 dekor objesi var: varil, çit, fener direği, ağ, çapa, batık tekne, mezar taşı, ölü ağaç, tabela, sarkıt, kök, zincir, örümcek ağı, mum ve diğerleri.
- Bölümlerin `dress()` fonksiyonunda elle yerleştirildiler. `deco()` objeyi zemine koyar, `hang()` tavandan sarkıtır.
- Doğal zeminlere (toprak, kaldırım, kaya) ot ve taş otomatik serpiştiriliyor. Otlar ve kökler rüzgarda sallanıyor (`shaders/sway.gdshader`).
- Suyun dalgalanan yüzeyi `shaders/water.gdshader` içinde.

## Ekranda hedef ve hikaye

- Sol üstte her zaman güncel **HEDEF** yazıyor. Hedef ekran dışındaysa kenarda bir ok ve kalan mesafe görünüyor.
- Yeni oyun 6 resimli panelle açılıyor: babanın kaybolduğu gece, çalınmayan çan, kardeşlerin küslüğü ve mektuplar. Esc ile atlanabilir.

## Otomatik test

Bütün bölümleri sırayla yükleyip her birinde sağa yürüyen, lambayı kaldıran ve ekran görüntüsü alan bir test modu var:

```
godot --path . -- --autotest
```

Sonuç `user://smoke_test.txt` dosyasına ve konsola yazılır, görüntüler `user://autotest/` klasörüne kaydedilir (`menu.png`, `level_N_a.png`, `level_N_b.png`). Oyun bitince kendiliğinden kapanır. Hata ayıklama derlemesinde oyun içinden F9 aynı testi görüntüsüz çalıştırır.

## v7.1 değişiklikleri

- **Işıkta karakter okunurluğu:** Lamba ışığı artık Kerem'i turuncu bir lekeye çevirmiyor. Oyuncu ayrı bir ışık katmanında (`Art.LIGHT_MASK_PLAYER`); lamba dünyayı aydınlatıyor, Kerem'i yandan yumuşak bir "key" ışığı aydınlatıyor. Kandil ve ay ışığı ikisini de aydınlatıyor.
- **Karanlıkta siluet:** Kerem'e yalnız kendisini etkileyen zayıf, soğuk bir dolgu ışığı eklendi. Pröloğ gibi zifiri sahnelerde karakter kaybolmuyor. Oyun kuralını etkilemiyor, Yankılar bunu ışık saymıyor.
- **Lamba huzmesi:** Sert çizgi yerine lambada parlak, uca doğru sönen bir ışık sütunu, etrafında geniş bir hale ve içinde uçuşan toz zerreleri.
- **Alev canlılığı:** Lamba ışığı hiçbir zaman tam sabit durmuyor, hafifçe titriyor. Bu sadece görsel; oyundaki ışık yarıçapı değişmiyor.
- **Kamera sarsıntısı:** Kare başına rastgele zıplama yerine yumuşak ve sönümlenen bir titreşim.
- **Menü odağı:** İnce dikdörtgen kutu yerine soldan amber bir şerit ve sağa doğru sönen sıcak bir vurgu.
- **Ses altyazıları:** Diyalog kutusunun üstüne taşındı, artık portreyle çakışmıyor. Aynı altyazı art arda yığılmıyor.
- **Hata düzeltmesi:** Yeni bölüme geçince önceki bölümün hedefi ekranda kalıyordu (ör. Bölüm 1 başında "Pencereden dışarı bak").
- **Performans:** `LightSystem` geçerli ışık kaynakları listesini kare başına bir kez kuruyor. Önceden her Yankı her karede yeni bir dizi oluşturuyordu.
- **Otomatik test modu:** `-- --autotest` (yukarıda anlatıldı).

## Bilinen notlar

- Proje Godot 4.7 (stable) ile açıldı. Bütün betikler hatasız derleniyor, bütün bölümler (pröloğ, 1, 2, ara bölüm, 5, 3 ve Son B kaçışı) otomatik testte yükleniyor.
- Level geometrisi koddan kuruluyor. İstenirse sonra her bölüm `.tscn` sahnesine dönüştürülebilir.
- Kayıt dosyası `user://save.json`, ayarlar ve başarımlar `user://settings.json` içinde tutuluyor.


## Atmosfer ve his (20 iyileştirme)

1. Su birikintileri yakındaki ışıkları yansıtıyor, yağmurda halka halka dalgalanıyor.
2. Yağmur damlaları zemine çarpıp sıçrıyor.
3. Şimşek çakınca gökyüzünde çatallı bir çizgi beliriyor, ekran aydınlanıyor, gök gürlüyor.
4. Bacalardan duman tütüyor.
5. Lambanın etrafında güveler dönüyor.
6. Lamba ışığında toz zerreleri uçuşuyor.
7. Lamba yürürken sarkaç gibi sallanıyor.
8. Soğukta Kerem'in nefesi buhar oluyor.
9. Ayak altında yumuşak gölge var.
10. Kandil yanınca kıvılcım patlıyor ve ışık bir an parlıyor.
11. Donan Yankılar titreşerek parlıyor, çan çalınınca beyaz bir parlamayla dağılıyorlar.
12. Yankıların gözleri arada bir kırpışıyor.
13. Ara sahnelerde kamera Kerem'e yaklaşıyor.
14. Ara sahnelerde üstte ve altta siyah sinema bantları açılıyor.
15. Bölüm 1'de uzaktan martı sürüleri geçiyor.
16. Suyun yüzeyinde köpük var.
17. Rüzgarlı balkonda ve kaçış sahnesinde yapraklar savruluyor.
18. Her bölümün kendi ortam sesi var: deniz ve yağmur, mağarada uğultu ve damlalar, kulede rüzgar.
19. Adım sesleri var. Mağarada daha boğuk çıkıyor.
20. Sayfa, bant ve dişli bulunca ya da hedef değişince bir keşif sesi çalıyor.

## Sunum, his ve ayarlar (20 iyileştirme daha)

1. Ana menüde çan ikonlu pixel art logo var.
2. Bölümler resimli kartlarla açılıyor: gece iskele, mağara ağzı, fırtınada kule.
3. Kerem uzun süre durursa etrafına bakınıyor.
4. Yüksekten düşünce toz kalkıyor, ekran sarsılıyor, Kerem daha çok çöküyor.
5. Yakıt azalınca lamba cızırdayıp anlık sönüyor.
6. Yanan kandillerden duman yükseliyor.
7. Yankılar sisin içinden yavaşça beliriyor.
8. Yakalanınca karanlık kenarlardan içe doğru kapanıyor.
9. Avlanan bir Yankı yaklaştıkça ekran kenarında kırmızı bir nabız atıyor.
10. Aynı anda kalp atışı duyuluyor, Yankı yaklaştıkça hızlanıyor.
11. Büyük Yankı yaklaştıkça ekran renk kaymasıyla bozuluyor.
12. Son A'da fener yeniden yanıyor ve huzmesi denizin üstünde dönüyor. Son B'de sisli Boğaz'a pencereden bakılıyor. İkisi de resimli panel.
13. Jenerik hikaye panellerinin üstünde akıyor.
14. Günlük çizgili bir kağıt sayfa gibi görünüyor, yazılar el yazısına yakın italik.
15. Duraklatınca arkadaki oyun bulanıklaşıyor.
16. Arayüzde yakıtın yanında bir lamba ikonu var, lamba kapalıyken sönük görünüyor.
17. Gamepad titreşimi: çan, yakalanma, şimşek, kandil, sert iniş ve tehlike anlarında.
18. Ayarlara tam ekran, ekran sarsıntısı aç/kapa ve ana ses eklendi.
19. Altyazı boyutu küçük, orta ya da büyük seçilebiliyor.
20. Windows ve Linux için dışa aktarma ayarları hazır (`export_presets.cfg`). Godot'da Proje > Dışa Aktar menüsünden doğrudan alınabilir.

## Genişleme: 30 başlık

**Hikaye**
1. Oynanabilir pröloğ (Sinop, 1965). 14 yaşındaki Kerem çanın çalmadığını fark eder, pencereden sisi ve babasının teknesinin ışığını görür, kapıya gider. Ama "Yusuf çalar" deyip yatağına döner. Bölüm 3'teki itirafın kökü burası.
2. Oynanabilir ara bölüm (1953, Hüsnü Usta). Fener sönmüş, köylüler sisin içinde birer birer Yankıya dönüşüyor, Hüsnü kuleye koşup feneri bir saat geç yakıyor.
3. 6 köylü mektubu: muhtar, öğretmen, balıkçı, küçük Ayşe, Fatma, kahveci Rıfat. Köyün 1953 gecesini anlatıyorlar.
4. Rıza Reis'le 4 isteğe bağlı telsiz sohbeti (telsiz direklerinde). Adayı, 1953'ü ve Kerem'in babasını anlatıyor.
5. Babanın batmış teknesi "Yıldız" Bölüm 3'te kulenin dibinde.
6. Son B kaçışında Yusuf ile Kerem'in sırttaki konuşması.
7. Kerem'in 5 yeni iç sesi: sokak lambası, mezar taşları, mağara, kule penceresi, varil.
8. Bölüm sonu özet kartı: süre, sayfalar, mektuplar, kandiller, yakalanma.

**Oynanış**

9. Yeni düşman: Fısıltı. Lamba ışığı onu durdurmaz, yaklaşınca gazyağını emer. Sadece kandil ışığı ya da çan onu dağıtır.
10. Hüsnü Usta'nın odasında isteğe bağlı çan bulmacası (sırayı kırmızı cam gösteriyor).
11. 3 gizli oda (sahte duvarlar).
12. 3 fitil yükseltmesi. Her biri lamba ışığını %12 genişletiyor.
13. Zorluk seçimi: Kolay, Normal, Bekçi. Yakıt tüketimini, Yankı hızını ve karanlık süresini değiştiriyor.
14. Yankı ansiklopedisi: günlükte, gördüğün türler açıklamalarıyla açılıyor.
15. Bölüm seçiminde pröloğ ve ara bölüm de var, her bölümün sayfa sayacı görünüyor.
16. Günlük sekmeleri: Sayfalar, Mektuplar, Yankılar, Bantlar.
17. Süre sayacı (ayarlardan açılıyor).
18. Devam ederken "Kaldığın yer" hatırlatması çıkıyor.

**Sunum**

19. Diyalog portreleri: Kerem, Yusuf, Rıza, Hüsnü, çocuk Kerem ve genç Hüsnü.
20. Altyazılar daktilo efektiyle yazılıyor. İlk [E] yazının tamamını gösteriyor, ikincisi geçiyor.
21. Fotoğraf modu: [H] arayüzü gizliyor.
22. Ekran görüntüsü: [F12], `user://screenshots/` klasörüne kaydediyor.
23. Yağmurun şiddeti zamanla artıp azalıyor.
24. Otomatik kayıtta köşede yanıp sönen bir lamba ikonu görünüyor.

**Teknik**

25. Tuş atama ekranı.
26. VSync açma/kapama.
27. FPS sınırı (sınırsız, 30, 60, 120, 144).
28. Steam başarım katmanı (`scripts/steam_bridge.gd`). GodotSteam kuruluysa kendiliğinden çalışıyor.
29. Ses altyazıları: [Gök gürlüyor], [Fısıltılar] gibi.
30. Bütün yeni metinler Türkçe ve İngilizce (185 diyalog satırı).

## Son cila: 50 başlık
**Hikaye:** (1) Yusuf'un 3 kaseti (Y01-03, fener kulesi) · (2) Fatma'nın boş mezarı (köy mezarlığı) · (3) Ayşe'nin bez bebeği (mağara) · (4) Kerem'in kendi sesiyle seslenen Taklitçi (kule merdiveni) · (5) bölüm sonu iç ses kartları CE_0/1/2/4 · (6) tüm mektuplar bulunduysa ek epilog satırı EP_005 · (7) jenerikte 1953'ün kayıplarına anma · (8) menüdeki fener yalnızca Çan sonundan sonra yanar.
**Başarımlar:** (9) Köyün Hafızası · (10) Kasetçi · (11) Kulak · (12) Fitilci · (13) Görünmez · (14) Gerçek Bekçi · (15) Kalkmadım.
**Oynanış:** (16) taş atma [T]/RB, Yankıları ses gelen yere çeker · (17) nefes tutma: eğilip kıpırdamazsan Yankılar izini kaybeder · (18) yeniden doğuşta yakındaki Yankılar uzaklaştırılır · (19) Bekçi zorluğunda yön oku kapalı · (20) 75 sn takılınca bulmacaya özel ipucu · (21) gerilim müziği hemen kesilmez · (22) küçük basamaklara takılmadan çıkma · (23) etkileşimde bakılan yön öncelikli · (24) lamba yükselince kol yukarı kalkar · (25) nefes tutma ve taş ipuçları ilk kovalamada çıkar.
**Grafik:** (26) çanla dağılan Yankıdan duman patlaması · (27) saldıran Yankının göz izi · (28) yakıt azalınca Yankılar titreşir · (29) kandil yerde ışık halkası · (30) kayan yıldız · (31) suya düşünce sıçrama · (32) pencere ışığı yere vurur · (33) kule pencerelerinden ışık huzmeleri · (34) sakin anlarda HUD solar · (35) yakıt dolarken bar parlar · (36) bölüm kartında rastgele ipucu.
**Ses:** (37) lamba kaldırma hışırtısı · (38) ayna gıcırtısı · (39) sandık sürtünmesi · (40) Yankılardan konumsal fısıltı · (41) köyde uzaktan çan tınısı · (42) menü üzerine gelme / tıklama sesleri · (43) konumsal ses sistemi (`AudioManager.play_at`).
**Teknik / satış:** (44) kayıt dosyası yedeği (.bak) · (45) olay günlüğü `user://log.txt` · (46) F9 smoke test (yalnızca debug; `user://smoke_test.txt`) · (47) pencere boyutu ayarı · (48) ilk açılışta dil seçimi · (49) sürüm numarası 1.0.0 · (50) Steam görselleri ve TR/EN mağaza metni (`store/`, yeniden üretmek için `python3 tools/store/make_store.py`).

### Test notu
Bu sürüm Godot'da çalıştırılmadan hazırlandı. İlk açılışta F9 ile smoke test'i çalıştırın: `user://smoke_test.txt` hangi seviyede durduysa hata o seviyededir.

## Açılış ve görsel güncelleme
- **NexDrive Game Studio** logosu (art/ui/studio_logo.png, firma logosundan) parıltı ve ışık şeridiyle açılır.
- **SİS ÇANI başlık introsu** (scripts/ui/intro_sequence.gd): fırtınalı deniz, şimşek, fener yanar, büyük çan çalar, dönen huzme, başlık ve "Kırlangıç Adası · 1977". Herhangi bir tuşla geçilir.
- Mağara arka planı: kaya tabakaları, deniz yeşili mineral damarları ve parlayan kristaller; mağara mantarları hafifçe parlar, bazıları gerçek ışık yayar.

## Yeni bölüm ve açıklayıcı bulmacalar
- **Bölüm III: Fabrika ve Dalgakıran** (`scripts/levels/chapter_five.gd`, iç numara 5; sıra: Pröloğ → I → II → Ara Bölüm → III → IV Fener). Kuzey kıyısı, su basmış avlu (savak çarkı + sandık), fabrika salonu (1953 mesai kartları, Yusuf'un notu, babasının sesiyle seslenen Taklitçi, ayna bulmacası ve kepenk), kazan dairesi (kazanı yak, basınç dolana kadar dayan, fabrika düdüğünü çal: tüm Yankılar dağılır) ve yükselen gelgitle dalgakıran koşusu. 21 yeni TR/EN satır, 2 telsiz konuşması, yeni bölüm kartı, arka plan ve kazan/vana/saat çizimleri.
- **Hedeflerin altında "→ nasıl" satırı:** her hedefte ne yapılacağı tuşlarıyla adım adım yazar (tuş atamasına göre güncellenir).
- 20 sn ilerlenmezse yakındaki kullanılabilir nesnelerin üstünde parlayan ◆ işareti; 35 sn'de ek ipucu (Bekçi zorluğunda işaret yok).
- Kerem'in kenar ışığı artık lambaya yakınlığa göre (tüm gövde turuncu çizilmiyor). Önizleme: `python3 tools/preview/render.py c5_boiler|c5_breakwater out.png`.

## Grafik turu: 20 başlık
(1) 1953 bölümünde sepya/eski film tonu ve çizikler · (2) yağmurda ekrana düşüp kayan damlalar (görüntüyü büker) · (3) sıcak tonlu ışık parlaması · (4) şimşekte mavi-beyaz ekran parlaması ve dünyanın bir an aydınlanması · (5) ışıkta donan Yankının kenarları soğuk beyaz parlar · (6) avlanan Yankının gözleri çevresine kızıl ışık saçar · (7) kandilin üstünde sıcak hava dalgalanması · (8) kandil yanarken genişleyen ışık halkası · (9) suda yağmur halkaları · (10) su yüzeyinde sıcak ışık kırpışması · (11) her inişte ve koşarken toz; yağmurda su sıçraması · (12) Kerem geçerken eğilen otlar · (13) mağarada süzülen parlak sporlar · (14) yakıt azalınca renkler solar · (15) bölüme göre renk düzenleme (mağara deniz yeşili, kule soğuk mavi…) · (16) toplanabilirlerde ışık sütunu ve kıvılcım · (17) yakıt azalınca lamba ışığı kızarır · (18) dalgakıranda taş aralarında patlayan dalgalar · (19) yumuşak ay halesi · (20) yeniden çizilen ıslak arnavut kaldırımı.
Shader'lar: `shaders/postfx.gdshader` (sepia, rain_lens), `echo_rim.gdshader`, `heat_haze.gdshader`, `water.gdshader`. "Yüksek grafik" ayarı kapalıyken 1-4, 7, 14, 15 devre dışı kalır.

## Açılış müziği
Tamamen sentezle bestelenmiş, telifsiz üç parça (`tools/music/compose.py` ile yeniden üretilir):
- `audio/music/studio.ogg` (6.6 sn): NexDrive logosu, kabaran pad, logo belirirken çan arpeji, ışık şeridiyle parıltı.
- `audio/music/intro.ogg` (13.6 sn): sahneyle eşli; sis, 2.2 sn'de şimşek vuruşu, 3.4 sn'de fener yanarken büyük çan, ardından Re minör tema (piyano), çözülme.
- `audio/music/menu.ogg` (53 sn, kesintisiz döngü): aynı temanın müzik kutusu + piyano hali, uzaktan fener çanı. Bölüm başlayınca yumuşakça kesilir.
