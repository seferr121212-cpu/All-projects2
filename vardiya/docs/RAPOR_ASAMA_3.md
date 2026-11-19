# VARDİYA — Aşama 3 Raporu (Bölüm 1 oynanabilir)

Sürüm: 0.3.0 · Godot 4.7 · Compatibility renderer

## 1. Ne yapıldı
- **Bölüm 1 "Son Kontrol"** (`data/chapters/ch01_last_check.json`, 40 düğüm). Yeni oyun artık buradan başlıyor; Aşama 2'nin deneme bölümü `test_chapters` altına alındı (yalnız testlerde).
  - Soyunma odası keşfi: kendi dolabın (zorunlu), Selim'in dolabı, ilan panosu, atölye kapısı.
  - Üretim holü keşfi: iş emri (zorunlu), **isteğe bağlı** işten çıkarma listesi, robot hata kaydı, Selim.
  - Büyük karar 1, `b1_selim_uyar`: Selim'i uyar / ima et / şakaya vur / kolu sor / sus. "Uyar" ve "ima et" **yalnızca listeyi keşfettiysen** çıkıyor.
  - QTE `b1_kol_qte`: robot kolundan kaç. Başarısız olursan oyun bitmiyor; Kemal yaralanıyor (`kemal_injured`) ve sonraki replikler değişiyor.
  - Büyük karar 2, `b1_ariza_rapor`: resmî rapor / kanıtla rapor / imzala ama gizlice tamir et / imzala / sus. "Kanıtla rapor" yalnızca robot panelindeki hata kaydını gördüysen çıkıyor.
  - Ayrıca küçük bir karar var (Nevin'e cevap). Sonraki bölümler için bayraklar: `selim_warned`, `fault_reported`, `fault_evidence`, `fault_fixed_secretly`, `fault_hidden`, `kemal_injured`.
- **Gri kutu mekânlar** (`data/locations/*.json`): JSON'dan kodla kuruluyor. Zemin ve duvarlar, kutu propları, 1 gölgeli yönlü ışık, gölgesiz nokta ışıklar, ortam rengi ve sis var. Vertex shading, doku yok.
- **Karakter hareketi** (`scenes/world/player_controller.gd`): kameraya göre yürüme, sol çubuk / WASD.
- **Kamera** (`camera_rig.gd`):
  - Takip kamerası sağ çubuk veya sağ fare sürüklemesiyle döner; SpringArm sayesinde duvardan geçmez.
  - Diyalogda konuşan kişiyi omuz üstü çeken sinematik kameraya yumuşak geçiş yapılıyor.
- **Keşif** (`explore` düğümü + `world_view.gd` + HUD):
  - En yakın ve oyuncunun baktığı nesne seçiliyor; nesnenin üstünde "A/E + ad" istemi çıkıyor, yeni nesneler yıldızlı.
  - Kilitli nesneler bir replik oynatıyor ("Önce üstümü değiştireyim").
  - Bulunan ipucu günlüğe ekleniyor ve ekranda bildirim çıkıyor. Ekranda bir hedef metni duruyor.
- **Günlük ekranı**: SELECT / J / Tab ile açılıyor, oyunu duraklatıyor.
- **QTE sistemi** (`qte` düğümü): üç mod var: tek basış, art arda basma, basılı tutma.
  - Kolay mod: süre 1,75 katına çıkıyor, gereken basış sayısı yarıya iniyor.
  - Erişilebilirlik ayarı açıksa "art arda basma" yerine "basılı tut" geliyor.
- **Grafik akış şeması** (bölüm sonu): katmanlı karar kutuları ve seçenekler.
  - Seçilen yol turuncu çizgiyle gösteriliyor; görülüp seçilmeyen seçenekler soluk.
  - Hiç ulaşılmayan karar ve seçenekler "?" olarak çıkıyor; keşif yüzdesi gösteriliyor.
  - Çubuk / D-pad ile kaydırılıyor.
- **Kayıt**: bulunan nesneler, ziyaret edilen düğümler (akış şeması için) ve geçerli mekân artık kayda giriyor. Keşif sırasında yüklenen kayıt aynı odaya ve aynı bulunan nesnelere dönüyor.
- **Araçlar**:
  - `tools/story_sim.py`: motor mantığının Python ikizi. Bir bölümün tüm oynanış durumlarını geziyor (Bölüm 1'de 2460 farklı durum) ve her sona örnek bir test yolu yazdırıyor.
  - Doğrulayıcı yeni kontroller yapıyor:
    - Hiçbir oynanışta sunulamayan seçenek, ulaşılamayan nesne veya düğüm.
    - Bilinmeyen mekân veya başlangıç noktası, olmayan nokta veya aktör, kırık QTE dalı.
    - **Yürünebilirlik:** her başlangıç noktasından her etkileşim noktasına oyuncu kapsülüyle yürüyerek ulaşılabiliyor mu (ızgara taraması).
    - 1K'dan büyük doku.
  - `tools/render_map.py`: mekânın kuşbakışı planını çiziyor (`docs/maps/*.png`). Bu çizimle iç içe geçmiş iki etkileşim noktasını bulup düzelttim.
- **Render ayarları**:
  - Yönlü gölge çözünürlüğü 1024, yumuşak gölge filtresi kapalı.
  - `force_vertex_shading` açık; nesne başına en fazla 8 ışık.
  - MSAA ve SSAA kapalı. SDFGI, VoxelGI ve SSR, Compatibility renderer'da zaten yok.

## 2. Nasıl çalıştırılır
```bash
godot --path vardiya
```
Gamepad tuşları:

| Eylem | Gamepad | Klavye / fare |
|---|---|---|
| Yürü | Sol çubuk | WASD |
| Kamera | Sağ çubuk | Sağ fare sürükle |
| Etkileşim / devam | A | E veya Boşluk |
| Seçimler | Y / B / A / X | 1-4 veya ok tuşları |
| QTE | A | Boşluk |
| Günlük | SELECT | J |
| Duraklat | START | Esc |

## 3. Test sonuçları (bu ortamda)
| Test | Sonuç |
|---|---|
| Doğrulayıcı, gerçek veri | **0 hata**, 4 uyarı (beklenen: son bölümleri yok, 4 son henüz ulaşılamaz) |
| Python birim testleri | **19/19 geçti**. Yeni testler: nesnenin noktası yok, bilinmeyen mekân ve başlangıç noktası, QTE dalı eksik, sunulamayan seçenek, Bölüm 1'in tüm dallarına ulaşılabilirlik, keşfe bağlı seçenek, yürünemeyen başlangıç noktası ve kapı. |
| `story_sim` Bölüm 1 | Tüm düğümler, seçenekler ve nesneler en az bir oynanışta ulaşılabilir |
| GDScript `gdparse` (29 dosya) + `gdlint` | temiz |
| Motor içi testler (24 test grubu; yenileri: kilitli kapı, keşfin seçeneği açması, QTE başarı/başarısızlık, kolay mod ve basılı tut, akış şeması, keşif içinde kaydet/yükle, Bölüm 1 baştan sona, mekân kurulumu) | **ÇALIŞTIRILAMADI** |
| Kare süresi | **ÖLÇÜLEMEDİ** |

**Engel aynı:** Godot 4.7'nin resmî ikilisini indirip açtım, ama bu ortamda çalıştırma isteği izin denetiminde iki kez daha reddedildi. Motor testleri, gerçek 3D görüntü ve kare süresi hâlâ doğrulanmadı. 3D kodu (kamera, çarpışma, ışık) bu yüzden en riskli kısım. Lütfen şu iki komutu çalıştırıp çıktıyı paylaşın:

```bash
godot --headless --path vardiya res://tests/test_runner.tscn
```

```bash
godot --path vardiya --resolution 1920x1080 --fullscreen -- --benchmark
```
Benchmark artık Bölüm 1'i 3D olarak otomatik oynuyor: kamerayı döndürüyor, tüm nesneleri inceliyor ve QTE sonuçlarını sırayla değiştiriyor.

**Tahmin (ölçüm değil):** En kalabalık sahne olan üretim holünde yaklaşık 45 ağ, 1 gölgeli ışık ve 3 gölgesiz ışık var. Compatibility renderer'da bu yaklaşık 150-200 çizim çağrısı eder. Vega 6 için hafif bir yük; 1080p'de 30 FPS'nin rahatça üstünde kalmasını bekliyorum.

## 4. Varsayımlar
1. Mekânlar elle yazılmış `.tscn` yerine JSON'dan kodla kuruluyor. Böylece doğrulayıcı mekânları da denetleyebiliyor. Aşama 6'da low-poly modeller aynı nokta ve başlangıç adlarıyla bu kutuların yerine geçecek.
2. "Pişirilmiş ışık": gri kutuda henüz lightmap yok, çünkü LightmapGI pişirmesi editör gerektiriyor. Şimdilik ortam rengi + 1 gölgeli ışık + gölgesiz nokta ışıklar kullanılıyor. Pişirme Aşama 6'da yapılacak.
3. Yeni konuşmacılar NPC: Selim (bakım işçisi, Kemal'in arkadaşı) ve Nevin (vardiya amiri). Bunlar `data/characters.json` içinde. GameState yalnızca üç oynanabilir karakteri izliyor.
4. QTE kararları da karar geçmişine yazılıyor (`b1_kol_qte = success/fail`), böylece sonraki bölümler bu sonuca bakabiliyor.
5. "Gizlice tamir et" seçeneğinde Defne'nin Kemal'e güveni -1 düşüyor (Kemal o gece eve gitmiyor). "Sus" seçeneğinde Nevin kâğıdı kendisi imzalıyor ve arıza gizli kalıyor (`fault_hidden`). Bu bayrak Bölüm 5'teki yangına bağlanacak.
6. Hücre sahnesine geçerken aynı mekân yeni bir başlangıç noktasıyla yeniden kuruluyor; kısa bir kesme gibi davranıyor.
7. Bölüm 1 sonunda "sonraki bölüm" yok, oyun ana menüye dönüyor. Bölüm 2 bağlantısı Aşama 4'te gelecek.

## 5. Bilinen eksikler
- Seslendirme ve ses yok. Animasyon da yok: karakterler kapsül + kafa, yürüme animasyonu yok. Sanat Aşama 6'da.
- Kamera çarpışması ve yürüme hissi motorda denenmedi.
- Doğrulayıcının son erişilebilirliği hâlâ örneklemeye dayanıyor. Bölümler arası tam yol taraması Aşama 4-5'te gelecek; `story_sim` buna hazır.
