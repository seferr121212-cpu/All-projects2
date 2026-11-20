# VARDİYA — Aşama 7 Raporu (Cila ve optimizasyon)

Sürüm: 0.7.0 · Godot 4.7 · Compatibility renderer

## 0. Önce önemli bir düzeltme: oynama süresi
Önceki raporlarda oynama süresini "1,5-2,5 saat" diye tahmin etmiştim. **Bu yanlıştı.** Bu aşamada yazdığım ölçüm aracı (`tools/playtime.py`) oyunu baştan sona yüzlerce kez rastgele oynatıp okunan metni ve yapılan eylemleri zamanlıyor:

| Sürüm | Hızlı oyuncu | Dikkatli oyuncu |
|---|---|---|
| 0.6.0 (Aşama 6) | ~22 dk | ~27 dk |
| **0.7.0 (bu aşama)** | **~25 dk** | **~35 dk** |
| Hedef | 4-5 saat | 4-5 saat |

- **Hızlı oyuncu:** dakikada 230 kelime okuyor ve isteğe bağlı eşyaların yarısına bakıyor.
- **Dikkatli oyuncu:** dakikada 160 kelime okuyor, her şeye bakıyor ve günlüğü okuyor.

Tek bir oynanış, hedefin yaklaşık **8'de 1'i**. Beş sonun hepsini görmek için oyunu birkaç kez oynamak gerekiyor, bu da toplam süreyi 2 saat civarına çıkarıyor; ama hedef tek oynanış için. Bu açığı kapatmak için hikâye metninin şimdikinin yaklaşık 8 katına (Türkçe ~20.000 ek kelime, İngilizcesiyle birlikte) çıkması gerekiyor. Bu, cila aşamasına sığacak bir iş değil; bölüm 5'te ayrı bir aşama olarak öneriyorum.

## 1. Ne yapıldı

### Ses (tamamı kodla üretiliyor, dosya yok)
`scenes/audio/sound_synth.gd` sesleri sinüs ve gürültü tariflerinden üretiyor. Tohumlar sabit olduğu için her derlemede aynı sesler çıkıyor.

| Tür | İçerik |
|---|---|
| **Arayüz** (10 ses) | Gezinme, seçme, seçim açılışı, son 3 saniyede saat tıkırtısı, karar sesi, sessizlik sesi, QTE başarılı/başarısız, günlüğe not düşme |
| **Ortam** (8 döngü) | Fabrika uğultusu ve makine ritmi, gece fabrikası, liman (rüzgâr, rıhtıma vuran su), ev (oda sesi, saat tik-tak), floresan vızıltısı (soyunma odası, sorgu odası), grev kalabalığı uğultusu, yangın çıtırtısı, açık hava |
| **Müzik** (5 duygu) | sakin, gergin, hüzünlü, sıcak, gece. 16 saniyelik akor döngüleri ve seyrek melodi notaları. |

- Döngüler eklem yeri tıklamasız; bir motor testi bunu kontrol ediyor.
- **Atama:** her mekânın bir ortam sesi var (`ambience`). Varyantla değişebiliyor: gece fabrikası yangında çıtırtıya, Acı Hesap epilogunda kapı sesi açık havaya dönüyor. Her bölümün ve epilogun bir müziği var (`index.json` → `music`). Ana menüde sakin müzik, jenerikte sıcak müzik çalıyor.
- **Yükleme:** döngüler arka planda bir iş parçacığında (`WorkerThreadPool`) üretiliyor, ana iş parçacığı beklemiyor. Kanallar arasında 1,5 saniyelik geçiş (crossfade) var.
- **Gerçek kayıtlarla değiştirme:** `assets/audio/` altına aynı adla `.ogg` ya da `.wav` dosyası konursa o dosya kullanılıyor. Kod değişikliği gerekmiyor.

### Sunum
- **Bölüm kartı:** her bölüm "Bölüm n" ve bölüm adıyla, siyah ekran üzerinde açılıyor. Epiloglarda "Son sahne" yazıyor. Kayıttan devam edilirken kart gösterilmiyor.
- **Mekân geçişlerinde siyahtan açılma:** yeni mekân kurulurken oluşan takılmayı ve ilk kareyi gizliyor.

### Performans
- **Otomatik performans koruması** (Ayarlar'dan kapatılabilir):
  - Oynanış 5 saniye boyunca ortalama 38 ms'den yavaş kare üretirse (~26 FPS) kalite bir basamak düşüyor.
  - Basamaklar sırayla: görsel efektler kapanıyor (açık sahnede de hemen), sonra 3B çözünürlük %85'e, sonra %70'e iniyor.
  - Kalite kendiliğinden geri yükselmiyor. Her düşüşte oyuncuya kısa bir bildirim gösteriliyor.
  - Mekân yüklemesinden sonraki ilk 4 saniye sayılmıyor. Benchmark modunda koruma kapalı.
- **3B çözünürlük ayarı:** %100, %85 ya da %70. Arayüz her zaman tam çözünürlükte kalıyor; Vega 6'da en etkili kurtarma bu olur.
- **Kare süresi raporu:** artık 3B çözünürlüğü, görsel kaliteyi ve korumanın kaç kez devreye girdiğini de yazıyor.

### İçerik
- 7 bölüme **26 isteğe bağlı keşif sahnesi** eklendi (TR + EN, yaklaşık 830 Türkçe kelime). Bölüm 5'e eklenmedi; o bölümün temposu yangın ve kaçış üzerine.
- Bazı sahneler önceki kararlara göre değişiyor: Selim yaşıyor mu, Kemal ya da Rıza öldü mü? Bölüm 7'deki kaset sahnesi, Bölüm 4'te rafta görülen kasetin sonunda dinlenmesi.
- Yeni etkileşim noktaları mekânlara eklendi; yürünebilirlik doğrulayıcıdan geçiyor.

### Araçlar
- **`tools/playtime.py`:** tüm oyunu Monte Carlo yöntemiyle oynatıp iki oyuncu profili için bölüm bölüm süre tahmini çıkarıyor.
- **Doğrulayıcı:** bilinmeyen ortam sesi ya da müzik kimliğini hata olarak yakalıyor. Aynı adla bir ses dosyası varsa onu geçerli sayıyor.

## 2. Nasıl çalıştırılır
```bash
godot --path vardiya
```
Ayarlar'daki yeni satırlar: **Görsel efektler**, **3B çözünürlük**, **Otomatik performans koruması**.

## 3. Test sonuçları (bu ortamda)
| Test | Sonuç |
|---|---|
| Doğrulayıcı (tüm oyun + epiloglar) | **0 hata**, 2 uyarı (önceki aşamalarla aynı, bilinçli) |
| Hikâye simülasyonu | 5 sonun hepsine ulaşılıyor, epiloglar oynanıyor |
| Python testleri | **35/35 geçti**. 3 yeni test: bilinmeyen ses kimliği, ses dosyasının geçerli sayılması, süre tahmininin tüm bölümleri kapsaması. |
| GDScript `gdparse` + `gdlint` | Temiz |
| Motor içi testler (51 grup, 5'i yeni) | **ÇALIŞTIRILAMADI.** Godot'yu çalıştırma izni yok. Yeni gruplar: 10 arayüz sesinin üretimi, döngü uzunluğu ve eklem yeri, verideki her ses kimliğinin üretilebilirliği, koruma basamakları ve çözünürlüğün uygulanması, bölüm kartı metinleri. |
| Kare süresi | **ÖLÇÜLEMEDİ.** Ses üretimi arka planda çalışıyor; arayüz sesleri kısa ve ilk kullanımda üretiliyor. Yeni grafik yükü yok. |
| Ses | **Dinlenemedi.** Sesler kodla üretildi; kulakla kontrol edilmedi. |

Motor testleri ve ölçüm için:
```bash
godot --headless --path vardiya res://tests/test_runner.tscn
```
```bash
godot --path vardiya --resolution 1920x1080 --fullscreen -- --benchmark
```

## 4. Varsayımlar
1. **Sesler gerçek kayıt değil, sentetik yer tutucu.** Telif riski sıfır. Kalite "sade ve atmosferik" düzeyinde; son sürümde ses tasarımcısının kayıtlarıyla aynı adlar üzerinden değiştirilebilir.
2. **3B çözünürlük ölçeği Compatibility renderer'da çift doğrusal (bilinear) ölçeklemeyle çalışıyor.** Bunu Godot 4.7 için varsayıyorum; motor testi bunu doğruluyor ama çalıştırılamadı.
3. **Koruma eşiği 38 ms.** Hedef 30 FPS; anlık takılmalar yerine 5 saniyelik ortalama kullanılıyor.
4. **Süre tahmini bir modele dayanıyor, ölçüm değil.** Okuma hızı ve eylem süreleri `tools/playtime.py` başında yazıyor. Gerçek oyuncular durur, düşünür, geri okur; gerçek süre biraz daha uzun olabilir, ama 4-5 saate yaklaşmaz.

## 5. Öneri: Aşama 8, içerik genişletme
4-5 saat hedefine ulaşmak için:
- Her bölüme 2-3 yeni ana sahne: işyeri, ev, sendika toplantısı, hastane, liman gece vardiyası gibi. Hedef, bölüm başına 25-35 dakika.
- Karakter başına kişisel yan hikâyeler:
  - **Kemal:** Defne'nin annesi.
  - **Defne:** sınav ve arkadaşları.
  - **Rıza:** borç ve kamyon.
- Yeni seçimler eklenecek; ama ana kararlar (son belirleyicileri) korunacak, doğrulayıcı ve simülatör her adımda denetleyecek.
- Yaklaşık 20.000 Türkçe kelime ve İngilizce çevirisi. Bölüm bölüm teslim edilebilir; her bölümden sonra `playtime.py` ile süre raporlanır.

Onay verirseniz Aşama 8'e bu planla başlarım. İsterseniz süre hedefini (ör. 2-3 saat) birlikte yeniden belirleyebiliriz.
