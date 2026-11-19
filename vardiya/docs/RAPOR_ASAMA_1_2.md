# VARDİYA — Aşama 1 ve 2 Raporu

Sürüm: 0.2.0 · Motor: Godot 4.7 · Renderer: `gl_compatibility` (Compatibility)

## 1. Ne yapıldı

### Aşama 1 — İskelet
- `project.godot`: 1920×1080, `canvas_items` ölçekleme, Compatibility renderer, MSAA/SSAA kapalı, vsync açık, 60 FPS üst sınır, fizik 30 Hz, kullanıcı verisi klasörü `vardiya`.
- Autoload'lar (yükleme sırasıyla): `InputRouter`, `Localization`, `AudioBus`, `GameState`, `DecisionManager`, `SaveSystem`, `DialogueRunner`, `SceneLoader`, `PerfMonitor`.
- **Gamepad eşleme** (`InputRouter`): tüm eylemler çalışma anında kaydedilir. Hareket ve kamera sol/sağ çubuk + WASD; etkileşim A/E; devam A/Boşluk/Enter/sol tık; seçimler elmas düzeninde: üst Y, sağ B, alt A, sol X (yön tuşları ve 1-4 / ok tuşları da çalışır); duraklat START/Esc; günlük SELECT/J; QTE A/Boşluk. `ui_*` eylemlerine D-pad, sol çubuk, A ve B eklenir. Aygıt değişimi algılanır, istemler (A, 1, Space…) etkin aygıta göre yazılır, gamepad kullanılırken fare imleci gizlenir. Kontrolcü bağlantısı koparsa oyun duraklar.
- **Dil**: tüm metin `data/locale/tr.json` ve `en.json` içinde (123 anahtar). Ana menüde RB/R ile anında dil değişimi; Ayarlar'dan da değişir. Metinler `TranslationServer`'a da yüklendiği için menüler yeniden başlatmadan güncellenir.
- **Ana menü**: Devam Et, Yeni Oyun, Kayıtlar ve Bölümler, Ayarlar, Çık. Tamamı gamepad ile gezilebilir (görünür odak çerçevesi, B = geri).
- **Asenkron sahne yükleme**: `SceneLoader` (`ResourceLoader.load_threaded_request` + yükleniyor katmanı, yükleme süresi ms olarak tutulur).

### Aşama 2 — Hikâye motoru
- **Veri biçimi** (`data/chapters/<id>.json`): düğüm türleri `line` (konuşmacı, metin anahtarı, koşullu `variants`), `choice` (2-4 seçenek, `timer`, `timeout` = susma seçeneği, `major`), `branch`, `effect`, `checkpoint`, `location`, `end` (`next_chapter`).
- **Koşullar**: `flag`, `counter`, `decision`, `status`, `mood`, `trust`, `avg_trust`, `alive_count`, `dead_count` + `eq/ne/gt/gte/lt/lte/in`, `all/any/not`. **Etkiler**: `set_flag`, `add_counter`, `trust`, `trust_mutual`, `status`, `mood`, `journal`; her etki kendi `if` koşulunu alabilir.
- **GameState**: üç karakter için yaşam durumu (`alive/dead/missing`), yönlü güven (-5…+5, sınırlanır), ruh hâli; bildirilmiş bayraklar (`data/story_flags.json`), sayaçlar, kimlikli karar geçmişi (`b0_kahvalti` gibi), günlük, oynama süresi. Tamamı JSON'a dönüştürülebilir.
- **DecisionManager**: koşul değerlendirme, etki uygulama, karar kaydı, bölüm sonu karar özeti (ziyaret edilen / seçilen / kaçırılan), son çözümleme (`data/endings.json`, öncelik sıralı kurallar + tek yedek kural).
- **DialogueRunner**: grafiği yürütür; seçim süresi 8 sn (ayarlardan 1,5x / 2x). Süre biterse `timeout` seçeneği karar olarak kaydedilir ("silence"), `silence` sayacı artar. Duraklatmada süre durur.
- **Zamanlı seçim arayüzü**: elmas düzeninde 2-4 seçenek, küçülen ve kırmızılaşan süre çubuğu, "ÖNEMLİ KARAR" etiketi, "Susmak da bir seçimdir" ipucu; yanlışlıkla seçimi önlemek için 0,25 sn giriş koruması. Altyazılar harf harf açılır, devam tuşu tamamlar. Altyazı boyutu ayarlanabilir.
- **Kayıt** (`SaveSystem`): 3 yuva, `format_version` = 1 ve göç fonksiyonu (eski biçim yükseltilir, daha yeni biçim reddedilir), geçici dosyaya yazıp yeniden adlandırma (yarım kayıt oluşmaz). Otomatik kayıt: bölüm başında, her `checkpoint` düğümünde ve her büyük karardan sonra. Elle kayıt yok (geri alma yok). Her bölüm başlangıcının anlık görüntüsü saklanır → "Bölüm başından yeniden oyna"; bu durumda sonraki ilerleme silinir (onay sorulur).
- **Deneme bölümü** `ch00_test` "Sabah Çayı" (Kemal, Defne, Rıza): 2 büyük karar, 4 susma/zaman aşımı yolu, önceki karara bağlı gizli seçenek, ruh hâline bağlı replik varyantı, ortalama güvene göre 3 farklı kapanış.
- **Bölüm sonu ekranı**: karar başına seçilen, kaçırılan, hiç ulaşılmayan dallar ve keşif yüzdesi (metin hâlinde akış şeması; grafik akış şeması Aşama 3'te).
- **Doğrulayıcı** `tools/validate_data.py` (Godot gerektirmez): TR/EN anahtar eşliği, boş metin, `{yer tutucu}` eşliği, kodda kullanılan anahtarlar, kırık `next` bağlantıları, ulaşılamayan düğümler, sona hiç varamayan döngüler, bilinmeyen tür/karakter/bayrak/ruh hâli, yinelenen karar kimliği, bölüm başına en az 2 büyük karar, ve **ulaşılamayan son** (bölüm verisinin üretebileceği durum uzayından 40 000 örnek; kural önceliği yüzünden gölgede kalan sonları da yakalar).
- **Konsol paketi**: `packaging/manifest.json` (ad, sürüm, diller, çalıştırma komutu, kapak 600×900, afiş 1920×620, kayıt alanı, kart etiketi `VARDİYA · HİKÂYE`), yer tutucu görseller, `export_presets.cfg` (Linux x86_64). Oyun kabuktan bağımsız çalışır.
- **Performans ölçümü**: `PerfMonitor` ortalama / p95 / p99 / en kötü kare süresi, statik bellek, video belleği, çizim çağrısı ve son sahne yükleme süresini toplar; F3 katmanı, `-- --benchmark` otomatik oynatıp `perf_report.json` yazar.

## 2. Nasıl çalıştırılır
README'deki komutlar. Kısaca: `godot --path vardiya` (oyun), `godot --headless --path vardiya res://tests/test_runner.tscn` (motor testleri), `python3 vardiya/tools/validate_data.py` (veri doğrulama).

## 3. Neyi test ettim (bu ortamda)

| Test | Sonuç |
|---|---|
| `validate_data.py` gerçek veride | **0 hata**, 4 uyarı (beklenen: yalnız deneme bölümü var, 4 son henüz ulaşılamaz → doğrulayıcı bunu doğru yakalıyor) |
| Doğrulayıcı birim testleri (11 adet) | **11/11 geçti**: eksik çeviri, yer tutucu uyuşmazlığı, kırık dal, yetim düğüm, sonsuz döngü, bildirilmemiş bayrak, seçenek sayısı, büyük karar sayısı, katı modda 4 ulaşılamaz son, tam veriyle 5 sonun hepsine ulaşma, öncelik yüzünden gölgede kalan son |
| Tüm `.gd` dosyaları `gdparse` (Godot 4 dil bilgisi) | 19/19 ayrıştı |
| `gdlint` | sorun yok |
| Motor içi testler `tests/test_runner.gd` (16 test grubu: dil, güven sınırı, koşullar, etkiler, durum gidiş-dönüş, tam yol, susma, gizli seçenek, varyant, **kayıt→yükleme aynı durum**, bölüm başına dönüş, göç, 5 son, özet, gamepad eşlemeleri) | **ÇALIŞTIRILAMADI** (aşağıya bakın) |
| Kare süresi | **ÖLÇÜLEMEDİ** (aşağıya bakın) |

**Engel:** Godot 4.7 Linux ikili dosyasını indirdim, ancak bu bulut ortamında indirilen bir ikiliyi çalıştırma isteği otomatik izin denetimince reddedildi. Bu yüzden motor içi testleri ve kare süresi ölçümünü kendim koşturamadım. İzin verirseniz ya da kendi makinenizde/NexDrive cihazında şu iki komutu çalıştırırsanız sonuçlar kesinleşir:

```bash
godot --headless --path vardiya res://tests/test_runner.tscn
```

```bash
godot --path vardiya --resolution 1920x1080 --fullscreen -- --benchmark
```

Beklenti (ölçüm değil, tahmin): Aşama 2 yalnız 2D arayüzden oluşuyor (~30-60 çizim çağrısı); Vega 6'da 60 FPS sınırında ve 16,7 ms'nin çok altında kalması beklenir. Gerçek kare bütçesi Aşama 3'teki 3D gri kutu sahnelerle anlamlı hâle gelir.

## 4. Varsayımlar
1. Proje deposu boş değildi; oyunu ayrı bir boş klasörde, `vardiya/` altında kurdum.
2. Godot 4.7'de `class_name` önbelleğine güvenmemek için betikler birbirini `preload` ile yüklüyor (editör açılmadan da çalışsın diye).
3. Ek iki autoload ekledim: `SceneLoader` (asenkron yükleme) ve `PerfMonitor` (ölçüm). İstenen yedi autoload aynen var.
4. Güven yönlüdür (Kemal'in Defne'ye güveni ≠ Defne'nin Kemal'e güveni). "Ortalama güven" yalnız hayatta olan çiftlerden hesaplanır.
5. Sonların öncelik sırası: üçü de öldü → Acı Hesap; ihbar → İhanet; Gizli Son; Dayanışma (ortalama güven ≥ 2, en az 2 kişi hayatta); Acı Hesap (en az biri bedel ödedi ya da `harm_done`); Ayrılık (ortalama güven ≤ 1); yedek → Ayrılık. Eşikler `data/endings.json` içinde.
6. "Gizli Son — hiç konuşmuyorlar" için tanım: üçü hayatta + final sahnesinde `final_silence` bayrağı + oyun boyunca en az 6 kez susma (zaman aşımı). Kolayca değiştirilebilir.
7. Seçim süresi erişilebilirlik için 1,5x / 2x uzatılabilir ama kapatılamaz (susma seçeneği korunur).
8. Elle kayıt yok; otomatik kayıt bölüm başı + checkpoint + büyük karar sonrası. "Bölüm başından oyna" sonraki bölümlerin ilerlemesini siler.
9. Kayıt yeri `user://` = Linux'ta `~/.local/share/vardiya/`; manifestte `$XDG_DATA_HOME/vardiya` olarak yazdım. NexDrive kabuk şartnamesi elimde olmadığı için manifest alan adları taslaktır.
10. Yazı tipi olarak Godot'nun yerleşik yazı tipi kullanılıyor (Türkçe karakterleri içerdiğini varsaydım; Aşama 6'da OFL lisanslı bir yazı tipi gömülecek); ses dosyası yok, `AudioBus` eksik dosyaları sessizce atlar. Ayrıntı: `assets/LICENSES.md`.
11. Klavye tuş adları (Space, Enter…) işletim sisteminden gelir; gamepad simgeleri yerelleştirme dosyasındadır. Performans katmanındaki sayılar geliştirici aracı olduğundan çevrilmez.
12. Doğrulayıcı Python ile yazıldı (CI'da Godot olmadan çalışsın diye); koşul semantiği `DecisionManager` ile birebir aynıdır.

## 5. Bilinen eksikler / sonraki aşama (Aşama 3) için notlar
- Grafik akış şeması, 3D gri kutu mekânlar, karakter hareketi, kamera, keşif ve günlük ekranı Aşama 3'te.
- QTE düğüm türü henüz yok (ayarları ve giriş eylemleri hazır).
- Doğrulayıcının son erişilebilirliği örnekleme tabanlıdır (yol ilişkilerini göz ardı eder, yani iyimserdir). Aşama 5'te her son için gerçek karar yolu üreten yol arayıcı eklenecek.
