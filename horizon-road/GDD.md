# Ufuk Yolu / Horizon Road — Game Design Document (v0.1)

## 1. Özet
Tek kişilik, rahatlatıcı, stilize low-poly 3D keşif oyunu. Oyuncu karavanıyla
Türkiye coğrafyasını gezer; manzara izler, fotoğraf çeker, resim çizer, yerel esnafa
yardım ederek para kazanır ve karavanını geliştirir.

- **Motor:** Godot 4.7, GDScript (statik tipli), Forward+ renderer
- **Platform:** Windows (PC), klavye+fare ve gamepad
- **Dil:** TR + EN (translation CSV)
- **Savaş, ölüm, zaman baskısı, "game over" yok.**
- **Hedef duygu:** huzur, merak, özgürlük, sıcak insan ilişkileri.
- **Ruh referansları (kopya değil):** Eastshade, Sable, Alba, Firewatch, A Short Hike.

## 2. Tasarım sütunları
1. **Atmosfer önce gelir:** ışık, hava, mevsim, gün döngüsü, ses, müzik.
2. **Özgürlük:** istediğin yöne git; zorunlu görev sırası yok.
3. **Sıcak ilişkiler:** esnaf seni hatırlar, adınla hitap eder.
4. **Yaratıcılık:** fotoğraf ve çizim gerçek mekanik.
5. **Küçük ama cilalı:** yarım 10 özellik yerine tam 3 özellik.

## 3. Görsel stil
- Stilize low-poly. Kalite; ışık, palet, gökyüzü, sis, gölge ve havadan gelir.
- WorldEnvironment + DirectionalLight3D + volumetrik sis + prosedürel gökyüzü,
  glow, ACES/AgX tonemapping, renk düzeltme.
- Gün evreleri: şafak → öğle → altın saat → alacakaranlık → gece; yumuşak geçişler
  (Gradient/Curve tabanlı renk eğrileri).
- Bölge paletleri:
  | Bölge | Palet |
  |---|---|
  | Karadeniz yaylası | koyu/çay yeşili, gri sis, ıslak kahve |
  | Ege köyü | turkuaz, kireç beyazı, kiremit turuncusu |
  | Kapadokya | kayısı, pembe tüf, soluk mavi sabah |
  | Doğu Anadolu kışı | mavi, beyaz, gri |
- Varlıklar: Kenney, Quaternius (CC0). Erişilemezse primitive yer tutucu + elle
  indirme listesi.
- Performans: orta PC'de 60 FPS. MultiMesh (ağaç/çimen/taş), görünürlük aralığı (HLOD),
  gölge mesafesi ayarı.

## 4. Ana döngü
Keşfet → esnafa yardım et → para kazan → karavanı geliştir → yeni bölge →
fotoğraf/çizim koleksiyonu → tekrar.

**Günlük (Journal):** fotoğraflar, çizimler, tanışılan insanlar, keşfedilen yerler.

## 5. Sistemler

### 5.1 Araç (karavan/jeep)
- 3. şahıs takip kamerası + kokpit kamerası.
- Arcade/yarı-simülasyon. **Önerilen yaklaşım:** `CharacterBody3D` tabanlı kendi
  araç kontrolcüsü (hız/dönüş eğrileri, zemin normaline hizalama, yüzeye göre çekiş).
  Gerekçe: `VehicleBody3D` düşük hızda titreme, takla ve süspansiyon ayarı zorluğu
  yaşatır; rahat bir oyunda öngörülebilirlik gerçekçilikten değerli. (Onay bekliyor.)
- Yüzeyler: yol / çimen / çamur / kar → çekiş ve maksimum hız çarpanı.
- E ile in/bin; yürüyerek keşif (`CharacterBody3D` oyuncu).
- Yakıt + basit bakım: cezasız para sinki (yakıt bitince yavaş "ekonomi modu").
- Karavan içi: yatak (uyku = zaman atlama), mutfak, harita masası, günlük defteri.

### 5.2 Zaman, hava, mevsim
- `TimeManager`: ayarlanabilir gün uzunluğu (varsayılan 14 gerçek dk), sinyaller:
  `hour_changed`, `phase_changed`, `day_changed`.
- `WeatherManager`: açık, parçalı bulutlu, sis, yağmur, fırtına, kar.
  Durumlar `WeatherProfile` resource'ları; geçişler yumuşak interpolasyon.
  Etkiledikleri: ışık, sis yoğunluğu, gökyüzü, parçacıklar, ortam sesi, ıslaklık.
- Mevsim: ilk sürümde bölge başına sabit; `Season` enum + bölge verisiyle
  ileride takvime bağlanabilir.

### 5.3 Fotoğraf modu
- Vizör UI: kadraj, üçte bir ızgarası, odak, diyafram/DOF, pozlama, filtreler.
- PNG `user://photos/` altına kaydedilir, albüme eklenir.
- Hedefler (`PhotoSubject` grubu): manzara, hayvan, insan, yapı, özel an.
- Puan: içerik (hedef görünürlüğü, kadraj içi oranı) + kompozisyon (üçte bir
  noktalarına yakınlık) + nadirlik (özel an). Ödül odaklı, ceza yok.
- Satış / esnafa gösterme; lens yükseltmeleri.

### 5.4 Çizim modu (Aşama 5)
- 2D tuval, fırça boyutu, renk paleti, silik referans görüntü.
- PNG `user://drawings/`, günlüğe girer, satılabilir.

### 5.5 Esnaf / NPC
- Veri: `data/npcs/*.json` (ad, meslek, kişilik, diyalog ağacı, aktiviteler).
- Metinler translation key ile; TR/EN CSV'de.
- İlişki: Tanışma → Tanıdık → Dost → Yakın Dost. İpucu, indirim, yeni iş açar.
- Mini aktiviteler (1-3 dk, başarısızlık cezası yok): balık ağı toplama, çay hasadı,
  odun taşıma, parça değiştirme, hamur şekillendirme.
- İlk esnaf (Karadeniz): çay üreticisi — **çay hasadı** aktivitesi.

### 5.6 Ekonomi
- Gelir: esnaf işleri, fotoğraf, çizim satışı.
- Gider: yükseltmeler (depo, konfor, ışık, motor, lastik, lens, çizim malzemesi),
  yakıt, yiyecek.
- Tüm sayılar `data/economy_config.tres` içinde.
- İleride: gezici kafe/atölye (altyapı düşünülür, ilk sürümde yok).

### 5.7 Dünya
- El yapımı bölgeler, her biri ayrı sahne; geçiş yol/tünel + yükleme perdesi.
- Sınırlı rastgelelik (bitki dağılımı, hava, NPC rotaları). Prosedürel dünya yok.
- Bölgeler: 1) Karadeniz yaylası (ilk) 2) Ege balıkçı köyü 3) Kapadokya 4) Doğu Anadolu kışı.

### 5.8 Ses ve müzik
- `AudioManager`: katmanlı ortam (rüzgar, dalga, kuş, yağmur) bölge/saat/havaya göre.
- Seyrek, sakin müzik; sürüş ve manzara katmanları.
- CC0 / yer tutucu.

### 5.9 UI, kayıt, ayarlar
- Minimal şeffaf HUD; Günlük, Harita, Envanter, Ayarlar.
- `SaveManager`: JSON, otomatik + elle; bölge, saat, para, yükseltmeler, albüm, NPC'ler.
- Ayarlar: grafik, ses, dil, tuş atama, gün uzunluğu. InputMap ile KB+M ve gamepad.

## 6. Teknik mimari
```
horizon-road/
  autoload/   GameState, TimeManager, WeatherManager, SaveManager, Localization, AudioManager
  scenes/     player/, vehicle/, camera/, interiors/
  scripts/    sistem dışı yardımcı sınıflar (class_name)
  regions/    blacksea_highland/, aegean_village/ ...
  ui/         hud, journal, photo_mode, dialogue, menus
  data/       economy_config, upgrades, npcs/*.json, weather profiles
  localization/ strings.csv (keys,en,tr)
  assets/     models/, audio/, textures/
```
- Sinyal tabanlı gevşek bağlılık; sistemler birbirini autoload sinyalleri üzerinden dinler.
- Veri/mantık ayrımı; statik tipleme; yalnızca "neden" yorumları.
- Her aşama sonunda commit.
