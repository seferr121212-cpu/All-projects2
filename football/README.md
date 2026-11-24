# Futbol 3D

Godot 4.7 (GDScript, Forward+, Jolt fizik) ile yapılmış, arcade ile gerçekçi arası bir 3D futbol oyunu.
Takımlar, oyuncular ve armalar tamamen kurgusaldır; isimler ve renkler veri dosyalarından düzenlenebilir.

Sürüm: **1.0.0**

## Kurulum

### Hazır Windows sürümü
`Futbol3D.exe` tek dosyadır, kurulum gerekmez. Çift tıklayıp çalıştırın.
Windows SmartScreen "tanınmayan uygulama" uyarısı verirse **Ek bilgi → Yine de çalıştır** deyin (dosya imzasızdır).
Gereksinim: Vulkan destekli ekran kartı (son 8-10 yılın çoğu kartı).

### Kaynaktan çalıştırma
1. [Godot 4.7](https://godotengine.org/download) kurun.
2. Bu klasörü (`football/`) Godot'da açın ve **F5** ile çalıştırın.

Komut satırından:
```bash
godot --path football
```

### Windows için yeniden derleme
Godot 4.7 export şablonları kurulu olmalıdır (Editör → Proje → Dışa Aktar → Şablonları Yönet).
```bash
godot --headless --path football --export-release "Windows Desktop" ../dist/Futbol3D.exe
```

## Modlar

| Mod | Açıklama |
|---|---|
| Hızlı Maç | 11'e 11 (veya 5'e 5) maç. Takım, formasyon, kimi oynayacağınız, devre süresi (2-10 dk), zorluk, gol tekrarı ve gündüz/gece seçilir. |
| Penaltı Atışları | 5'er atış, eşitlikte ani ölüm. Atışta nişan alıp şutu basılı tutarsınız; kaledeyken vuruş anında sol/sağ ile uzanırsınız. |
| Antrenman | Rakipsiz serbest oyun, yalnızca kaleci. `T` topu ayağınıza getirir. |

## Kontroller

| Aksiyon | Klavye / Fare | Gamepad |
|---|---|---|
| Hareket | W A S D / ok tuşları | Sol çubuk |
| Sprint | Shift | RT |
| Kısa pas | Space | A |
| Ara pas | E | Y |
| Orta / havadan pas | Q | X |
| Şut (basılı tut, bırak) | F / Sol tık | B (topla) |
| Müdahale (yakında ayakta, uzakta kayarak) | C | B (topsuz) |
| Omuz | V | RB |
| Çalım | R | Sağ çubuk tık |
| Oyuncu değiştir | Tab | LB |
| Kamera değiştir | F1 | Back |
| Duraklat / tekrarı atla | Esc | Start |
| Topu getir (antrenman) | T | Sol çubuk tık |

Tüm tuşlar **Ayarlar → Kontroller** ekranından klavye ve gamepad için ayrı ayrı değiştirilebilir.
Ayarlar `user://settings.json` dosyasına kaydedilir (Windows: `%APPDATA%\Godot\app_userdata\Futbol 3D\`).

## Özellikler

- **Top fiziği:** 0.43 kg top, hava direnci, Magnus etkisi (falso), çimde yuvarlanma direnci, çarpışmalı direkler, yumuşak file.
- **Oyuncu:** ivme ve dönüş sınırı, sprint/stamina, küçük dokunuşlarla top sürme, pas türleri, güç barlı şut, müdahaleler, çalım.
- **Yapay zekâ:** formasyona göre konum alma, Hücum/Savunma/Geçiş, pres/örtme/markaj, boşa kaçma, şut-pas-sürme fayda puanlaması, kaleci (açı kapatma, uzanma, tutma/çelme, degaj), 3 zorluk seviyesi. Kararlar 10 Hz zamanlanmış tick ile.
- **Kurallar:** başlama vuruşu, taç, korner, aut, faul, sarı/kırmızı kart, serbest vuruş (baraj), penaltı, ofsayt, devre arası ve taraf değişimi, gol sonrası tekrar.
- **Görsel:** animasyonlu low-poly oyuncular (AnimationTree), tribünler ve ~7000 seyirci, gündüz/gece ışıklandırma, biçilmiş çim shader'ı.
- **Ses:** kodla sentezlenen vuruş, düdük, direk, file, seyirci uğultusu ve gol coşkusu; spiker altyapısı.
- **Dil:** Türkçe ve İngilizce.

## Verileri düzenleme

| Dosya | İçerik |
|---|---|
| `data/teams.json` | Takım adı, kısa ad, forma/deplasman/kaleci rengi, varsayılan formasyon |
| `data/players.json` | Takım başına kadro: ad, numara, mevki (GK/DEF/MID/FWD), 7 istatistik (1-99) |
| `data/formations.json` | Formasyon slotları (x: -1 kendi kale çizgisi … +1 rakip kale çizgisi, z: -1 … 1) |
| `data/settings.json` | Varsayılan devre süresi, zorluk ve zorluk seviyelerinin parametreleri |
| `data/commentary.json` | Spiker olayları: öncelik, bekleme süresi, TR/EN metin ve isteğe bağlı ses dosyası yolu |
| `assets/translations/strings.csv` | Arayüz metinleri (anahtar, tr, en) |

Oyuncu görseli `scenes/player_visual.tscn` sahnesindedir; gerçek bir model aynı arayüzle (`set_kit`, `set_number`, `set_pose`, `set_locomotion`, `play_kick`) takılabilir.

## Testler

88 otomatik test: top fiziği, gol/taç/korner/aut algılama, ofsayt, kartlar, maç akışı, AI, penaltı kuralları, ayarlar ve tuş atama, çeviriler, ses sentezi, animasyonlar ve 11'e 11 performans ölçümü.
```bash
godot --headless --path football --fixed-fps 120 -s res://tests/run_tests.gd
```

## Klasör yapısı

```
scenes/    match, player, ball, stadium, penalty_shootout, training, ui/
scripts/   ball/ player/ ai/ match/ camera/ ui/ audio/
data/      teams, players, formations, settings, commentary
assets/    shaders/ translations/
tests/     otomatik testler ve koşucu
```

## Yol haritası

- Lig ve turnuva modları, yedek oyuncu değişikliği
- Avantaj kuralı, uzatma dakikaları, geri pas kuralı
- Gerçek 3D oyuncu modelleri ve motion-capture animasyonlar
- Spiker ses kayıtları, kayıtlı seyirci sesleri
- Kafa vuruşu ve havadan top kontrolü
- Çevrimiçi/yerel çok oyunculu
