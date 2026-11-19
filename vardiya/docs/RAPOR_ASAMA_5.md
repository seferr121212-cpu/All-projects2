# VARDİYA — Aşama 5 Raporu (Beş son, final sahneleri, kredi)

Sürüm: 0.5.0 · Godot 4.7 · Compatibility renderer

## 1. Ne yapıldı

### Oyunun sonu artık tam bir akış
1. Bölüm 8'in son düğümü `next_chapter: "@ending"` ile bitiyor.
2. Son, `data/endings.json` kurallarıyla seçiliyor ve `ending` hikâye bayrağına yazılıyor.
3. Bölüm 8 karar haritası gösteriliyor. Alt satırda "Ulaşılan son: … Final sahnesi başlıyor." yazıyor.
4. O sona ait **final sahnesi (epilog)** oynanıyor.
5. **Son kartı** geliyor: başlık, açıklama, üç karakterin akıbeti (Hayatta / Öldü / Kayıp-tutuklu), karar ve sessizlik sayısı, oynama süresi, "Açılan sonlar n/5" ve gerekiyorsa "Yeni son açıldı".
6. **Kredi** kendiliğinden kayıyor. Devam tuşu basılı tutulursa hızlanıyor, Duraklat/Geri tuşu atlatıyor.
7. Ana menüye dönülüyor.

### Beş final sahnesi (`data/chapters/ep0*.json`)
| Son | Epilog | Mekân | Kimin gözünden | Neye göre değişiyor |
|---|---|---|---|---|
| Dayanışma | `ep01_solidarity` | Bir yıl sonra onarım kooperatifi (üretim holü) | Defne, Defne yoksa Kemal | Her karakter için hayatta / ölü / kayıp satırı; Selim yaşıyor mu; şirket suçlandı mı. Hayatta olanlar sahnede duruyor. |
| Ayrılık | `ep02_separation` | Taşınma günü, aile evi → kartpostallar | Defne | Anahtarı bırak ya da sakla seçimi kapanış satırını değiştiriyor; Karaliman'dan gitme kararı. |
| Acı Hesap | `ep03_bitter` | Fabrika kapısında anma | İlk hayatta olan | Akıbet satırları, `harm_done`, şirket suçlandı mı. **Kimse kalmadıysa** sahnenin yerine Nevin ve Selim'le anlatılan bir kart geliyor. |
| İhanet | `ep04_betrayal` | Emniyet, son ifade | İhbarı yapan karakter | İhbarcı ölü ya da kayıpsa anlatılan kart geliyor. Diğerlerinin tepkileri. İmzala ya da yırt (yırtarsa tutuklanıyor). |
| Gizli Son: Sessiz Sofra | `ep05_secret` | Aile evi, sessiz masa | Defne (bu sonda üçü de hayatta) | Sessizliği bozmaya çalışmak ya da elini masaya koymak. |

- Her epilogda kısa bir keşif (2-3 nesne, günlük notu) ve **küçük bir son seçim** var. Bu seçim sonu değiştirmiyor, yalnızca kapanış satırını ve ruh hâlini değiştiriyor.
- Epiloglar büyük karar kuralından muaf.
- Toplam 75 düğüm ve yaklaşık 950 kelimelik TR metin eklendi; EN çevirisi tam.

### Sonlar galerisi ve profil
- `user://profile.json` dosyası kayıt yuvalarından bağımsız. Atomik yazılıyor. Ulaşılan sonları ve kredinin görülüp görülmediğini tutuyor.
- Ana menüye **Sonlar** ve **Emeği Geçenler** eklendi.
- Galeride açılmış sonların başlığı ve açıklaması görünüyor. Kilitli sonlar "? ? ?" ve bir ipucu (`ending.*.hint`) gösteriyor. Liste tamamen gamepad ile geziliyor.
- Kredi metni `data/credits.json` dosyasında. Rol adları çevriliyor, özel isimler olduğu gibi kalıyor.

### Düzeltmeler
- **`SaveSystem.begin_chapter`:** listede olmayan bir bölüme (epilog) girildiğinde bütün bölüm anlık görüntüleri siliniyordu. Artık epilog tüm hikâye bölümlerinden sonra sayılıyor ve önceki bölümlere "baştan oyna" korunuyor. Bir hikâye bölümü baştan oynanınca epilog görüntüsü siliniyor.
- **`chapter_info`:** epilogları da tanıyor. Kayıt menüsü, epilogda kaydedilmiş bir yuvanın başlığını gösterebiliyor.
- **Üretim holü:** Selim artık yalnızca yaşıyorsa sahnede. Ana karakterler yalnızca Dayanışma epilogunda oraya konuyor.

### Araçlar
- **`story_sim.py --game`:** Bölüm 8 sonundaki her durum için sonu hesaplıyor ve ilgili epilogu o durumlardan oynatıyor. Ölü ya da kayıp karaktere kamera verilirse hata veriyor.
- **Doğrulayıcı yeni kurallar:**
  - `next_chapter` index sırasındaki bir sonraki bölüm olmalı.
  - `@ending` yalnızca son hikâye bölümünde kullanılabilir.
  - Epilog oyunu bitirmeli (`null`).
  - Her sonun listelenmiş bir epilogu ve ipucu metni olmalı.
  - Hiçbir sona ait olmayan epilog uyarı veriyor.
  - Bir son simülasyonda bulunduğu hâlde epilogu oynanmadıysa hata veriyor.
  - Kredi ve son ekranı metinlerinin çevirisi denetleniyor.

## 2. Nasıl çalıştırılır
```bash
godot --path vardiya
```
Sonlara hızlı ulaşmak için yollar `docs/SON_TEST_YOLLARI.md` dosyasında. Her sonun altına artık final sahnesinin adı da yazıldı.

## 3. Test sonuçları (bu ortamda)
| Test | Sonuç |
|---|---|
| Doğrulayıcı (katı mod + tüm oyun + epiloglar, yaklaşık 27 sn) | **0 hata**, 2 uyarı. Uyarılar önceki aşamayla aynı: bilinçli olarak koşullu seçenekler. |
| Tüm oyun simülasyonu | 5 sonun hepsine ulaşılıyor. Her epilog kendi sonunun gerçek final durumlarından oynandı (112-1129 başlangıç durumu). Epiloglarda ulaşılamayan düğüm, seçenek ya da nesne yok; ölüye kamera verilmiyor. |
| Python testleri | **27/27 geçti**. 5 yeni test: sonu olmayan epilog, yanlış yerde `@ending`, oyunu bitirmeyen epilog, epilogların büyük karar muafiyeti, epilogda ölüye kamera. |
| GDScript `gdparse` + `gdlint` | Temiz. Test dosyası için `max-public-methods` sınırı 60'a çıkarıldı. |
| Motor içi testler (40 grup) | **ÇALIŞTIRILAMADI**. Godot'yu çalıştırma izni hâlâ yok. 8 grup yeni: `@ending` çözümü ve kilit açma, profilin yuvalardan bağımsızlığı, epilogda anlık görüntülerin korunması, 5 epilogun iki farklı seçim dizisiyle sonuna kadar oynanması, akıbete göre değişen satırlar, ihanet epilogunda bakış açısı, galeri satırları, kredi verisi. |
| Kare süresi | **ÖLÇÜLEMEDİ**. Epiloglar mevcut mekânları kullanıyor, yeni geometri ya da ışık yok. Yük önceki aşamayla aynı olmalı. |

Motor testleri için:
```bash
godot --headless --path vardiya res://tests/test_runner.tscn
```

## 4. Varsayımlar
1. Epiloglar kısa (her biri 2-4 dakika). Sonu değiştiren karar yok; "geri alınamaz" ilkesine uygun olarak son, Bölüm 8 bitince kesinleşiyor.
2. Ayrılık ve Gizli Son yalnızca üç karakter de hayattayken oluşuyor. Bunun nedeni `endings.json` öncelikleri: iki ya da daha az hayatta kalan önce Acı Hesap'a düşüyor. Bu iki epilog bu yüzden doğrudan Defne'nin gözünden açılıyor. Öncelikler değiştirilirse doğrulayıcı, ölüye kamera verilmesini hata olarak yakalar.
3. Galeri ipuçları sonu tarif ediyor ama kesin koşulu vermiyor.
4. Kredide "Geliştirme desteği: Claude Code (Anthropic)" satırı var. İstenmezse `data/credits.json` dosyasından tek satır silinmesi yeterli.
5. Oynama süresi hâlâ 4-5 saat hedefinin altında: tahminen 1,5-2,5 saat. Metin ve sahne genişletmesi Aşama 6-7'de yapılacak.

## 5. Sonraki aşama (6: sanat geçişi) için öneriler
- Gri kutuların yerine stilize düşük poligon modeller (512 piksel doku, pişirilmiş ışık), karakter siluetleri ve basit animasyonlar.
- Epilog sahneleri için ışık ve renk tonları: şafak, gece, kooperatif atölyesi.
- Telifsiz ve kendi üretimimiz yer tutucu ses ve müzik.
