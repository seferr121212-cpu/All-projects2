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

## Aşama 0 — Kurulum ve belgeler ✅ (bu oturum)
- Proje iskeleti, `project.godot`, klasör yapısı, GDD.md, PLAN.md.
- **Bitti:** belgeler onaylandı, Godot 4.7 sürümü doğrulandı.

## Aşama 1 — İskelet + karavan + Karadeniz yaylası (boş ama güzel)
- Autoload'lar: GameState, TimeManager, WeatherManager, SaveManager (stub),
  Localization, AudioManager.
- InputMap (KB+M + gamepad): sür, fren, dön, kamera, in/bin, fotoğraf, günlük.
- Araç kontrolcüsü (onaylanan yaklaşım), takip + kokpit kamerası, yüzey çekişi.
- Bölge 1: arazi (yer tutucu mesh/heightmap), yol, çay terasları, MultiMesh ağaçlar,
  WorldEnvironment, gün döngüsü ışık eğrileri, sis, yağmur/sis/açık hava, ortam sesi.
- Debug paneli: saati hızlandır, havayı değiştir, FPS.
- **Bitti:** oyuncu karavanla bölgeyi gezebiliyor, gün döngüsü ve en az 3 hava
  durumu görsel+işitsel olarak değişiyor; konsolda hata yok; 60 FPS hedefinde.

## Aşama 2 — Fotoğraf modu + günlük albümü
- Vizör UI, ızgara, DOF, pozlama, filtreler; PNG kaydı; hedef tespiti ve puanlama.
- Günlük ekranı: Albüm sekmesi.
- **Bitti:** çekilen fotoğraf `user://photos/` altında PNG olarak oluşuyor, puanı ve
  hedefleri ile albümde görünüyor; yeniden başlatınca kayıtlı.

## Aşama 3 — İlk esnaf + diyalog + mini aktivite + para
- JSON diyalog sistemi (TR/EN), ilişki seviyesi, isimle hitap.
- Çay üreticisi NPC + çay hasadı mini aktivitesi.
- Para (GameState), economy_config, HUD'da para göstergesi, fotoğraf satışı.
- **Bitti:** oyuncu NPC ile konuşup aktiviteyi bitiriyor, para kazanıyor, ilişki
  seviyesi artıyor; diyaloglar her iki dilde çalışıyor.

## Aşama 4 — Yükseltmeler + karavan içi + kayıt
- Yükseltme verisi + mağaza UI (tamirci), yakıt.
- Karavan iç mekanı: yatak (uyku), harita masası, günlük defteri.
- SaveManager tam: otomatik + elle kayıt/yükleme.
- **Bitti:** yükseltme satın alınıp etkisi hissediliyor; uyku zamanı ilerletiyor;
  kaydet-çık-yükle döngüsü tüm durumu koruyor (headless testle doğrulanmış).

## Aşama 5 — Çizim modu
- 2D tuval, fırça/renk, silik referans, PNG kaydı, günlükte Çizimler sekmesi, satış.
- **Bitti:** çizim kaydedilip günlükte görünüyor ve satılabiliyor.

## Aşama 6 — Ege bölgesi + hava/mevsim çeşitliliği + geçiş
- Ege balıkçı köyü sahnesi, balıkçı NPC + ağ toplama aktivitesi.
- Bölge geçişi (yol + yükleme perdesi), bölge başına palet/mevsim profili, fırtına ve kar.
- **Bitti:** iki bölge arasında kayıpsız geçiş; her bölgenin kendi atmosferi var.

## Aşama 7 — Ses, müzik, menüler, ayarlar, yerelleştirme, cila, build
- Ana menü, duraklat, ayarlar (grafik/ses/dil/tuş/gün uzunluğu), müzik katmanları.
- Tüm metinler CSV'de; eksik anahtar taraması.
- Windows export (export templates gerekir).
- **Bitti:** Windows .exe başlıyor, ana menüden oyun tamamen oynanabiliyor.

---

## Açık kararlar
1. Araç fiziği: `CharacterBody3D` arcade kontrolcü (öneri) vs `VehicleBody3D`.
2. Godot çalıştırılabilir dosyasının bu ortamda nasıl sağlanacağı (bkz. rapor).

## Notlar / varsayımlar
- Proje mevcut `All-projects2` git deposunun içinde `horizon-road/` alt klasöründe;
  ayrı iç içe depo açmak yerine bu depo kullanıldı.
