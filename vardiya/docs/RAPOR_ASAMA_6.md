# VARDİYA — Aşama 6 Raporu (Sanat geçişi)

Sürüm: 0.6.0 · Godot 4.7 · Compatibility renderer

## 1. Ne yapıldı

### Gri kutudan stilize düşük poligona
- **Çarpışma değişmedi.** Veri dosyalarındaki her kutu, çarpışma ve yürünebilirlik için olduğu gibi kullanılıyor. Görünüm, kutunun içine sığan bir prop'tan geliyor. Bu yüzden oynanış, etkileşim noktaları ve doğrulayıcının yürüme ızgarası önceki aşamayla aynı.
- **Prop kiti** (`scenes/world/prop_kit.gd`): 37 tür. Konteyner (oluklu yan yüzeyler, kapı kolları), dolap, tezgâh, bant (makaralı, ayaklı), robot kolu, kamyon (kabin, kasa, tekerler, farlar), bekçi kulübesi, vinç ayağı (kafes), korkuluk, çit, I-kiriş, boru hattı, asma lamba, sokak lambası, palet, varil, masa, çalışma masası, kanepe, raf, mutfak tezgâhı, pano (kâğıtlarla), pencere, kapı, ekran, pankart (yazı şeritleriyle), sarı-siyah tehlike şeridi, grevci kalabalığı (bir kısmı pankart tutuyor) ve diğerleri. Veri dosyasında `kind` alanıyla seçiliyor; `mat` malzemeyi değiştiriyor.
- **Birleştirilmiş mesh** (`scenes/world/mesh_batch.gd`): bir mekândaki bütün statik geometri, malzeme başına **tek mesh**te toplanıyor. Bu, mekân başına 3-10 çizim çağrısı demek. Önceden her kutu ayrı bir çizimdi.
- **Sahte ortam gölgesi (AO):** köşe renklerine pişiriliyor. Prop'ların alt kısmı koyulaşıyor, zeminde duvar diplerinde ve eşyaların çevresinde temas gölgesi oluşuyor. Zemin 0,5 m'lik ızgara, karolarda hafif ton farkı var. Büyük yüzeyler 1-1,5 m'lik parçalara bölünüyor; Compatibility'de zorunlu köşe başı ışıklandırma bu sayede duvarın ortasına da ulaşıyor.
- **Dokular** (`scenes/world/art_kit.gd`): beton, metal (fırçalanmış), boya, ahşap (damar), kumaş ve sıva. Hepsi ilk sahne yüklenirken `FastNoiseLite` ile **512 piksel** üretiliyor; dosya ya da içe aktarma adımı yok. Dünya koordinatlı triplanar örnekleme kullanılıyor, ton köşe renginden geliyor. Toplam yaklaşık 6-8 MB video belleği (mipmap dahil).

### Karakterler
- `scenes/world/character_body.gd`: baş ve gövde tek mesh, kollar ve bacaklar ayrı eklemli. Karakter başına **5 çizim çağrısı**, iskelet yok.
- Her karakterin kendi silueti var (`characters.json` → `look`):
  - **Kemal:** iş tulumu, kasket, bıyık.
  - **Defne:** at kuyruğu saç, sırt çantası.
  - **Rıza:** sakal, ceket.
  - **Selim:** kır saç, gözlük.
  - **Nevin:** topuz saç.
  - **Komiser:** uzun palto.
- **Animasyonlar:**
  - Yürürken bacaklar ve kollar sallanıyor, gövde iniyor-kalkıyor.
  - Dururken nefes alıyor ve hafifçe dönüyor; karakterlerin rölantileri birbirinden kaydırılmış.
  - Konuşan karakter, satır gelince başını sallıyor ve el hareketi yapıyor.

### Atmosfer
- **Duvar stilleri:**
  - **Fabrika:** iki tonlu metal duvar, I-kiriş kolonlar, üstte pencere şeridi, çatı makasları, boru hatları.
  - **Ev:** süpürgelik ve tavan bandı.
  - **Açık hava:** alçak beton duvar ve çit, arkasında gökyüzü.
- **Gökyüzü:** liman (gece) ve fabrika kapısı (bulutlu) için prosedürel gökyüzü. İç mekânlarda düz arka plan ve sis var.
- **Işıklar:**
  - **Hale:** lambalarda toplamalı (additive) parıltı.
  - **Işık hüzmesi:** sahte hacimsel koni; fabrika, liman ve sorgu odasında.
  - **Titreme:** yorgun floresan (soyunma odası, sorgu odası) ve ateş ışığı.
- **Parçacıklar:** CPU parçacıkları, sistem başına 8-28 parçacık. Fabrikada toz, limanda sis, yangında kıvılcım ve duman.
- **Kenar karartması (vignette):** sorgu odasında daha koyu.
- **Bölüm 5 yangını:** yalnızca `fire_started` bayrağı açıksa çıkıyor. Ölçeği oynayan alev katmanları, kıvılcım, duman ve titreyen turuncu ışıktan oluşuyor.

### Epilog ışık varyantları
Mekân dosyasına koşullu `variants` eklendi. Bir epilog, mekânın ışığını, gökyüzünü ve parçacıklarını kendi tonuna çevirebiliyor:

| Son | Mekân | Ton |
|---|---|---|
| Dayanışma | Üretim holü | Gündüz, aydınlık pencereler, kooperatif pankartı, tezgâh, raf |
| Ayrılık | Ev | Şafak ışığı, taşınma kolileri |
| Acı Hesap | Fabrika kapısı | Gün batımı, yerde sis, anma mumları ve çiçekler |
| İhanet | Sorgu odası | Daha soğuk ve sert ışık, daha koyu kenarlar |
| Gizli Son | Ev | Neredeyse karanlık; masada titreyen tek mum |

### Ayarlar
**Görsel efektler: Yüksek / Düşük** ayarı eklendi (TR/EN). Düşük ayarda gerçek zamanlı gölge, parçacık, hale, ışık hüzmesi ve kenar karartması kapanıyor. Değişiklik bir sonraki sahne yüklemesinde uygulanıyor.

### Doğrulayıcı (yeni kurallar)
- Bilinmeyen prop türü, malzeme, duvar stili, parçacık türü ve titreme modu hata veriyor; renkler `#rrggbb` biçiminde olmalı.
- Odanın dışına taşan kutu hata veriyor. Ateş çarpışmalı olamaz.
- **Bütçeler** (her koşul açıkken, en kötü durum):
  - En fazla 4 omni ışık.
  - En fazla 4 parçacık sistemi (her ateş 2 sistem sayılıyor).
  - En fazla 3 ateş.
- Varyantın koşulu denetleniyor; varyant yalnızca atmosfer anahtarlarını değiştirebiliyor.
- Karakter görünümü denetleniyor: saç stili, renkler, boy ve yapı 0,8-1,2 aralığında olmalı.
- Bu kurallar gerçek bir hatayı yakaladı: yeni bir palet, fabrika kapısında Defne'nin başlangıç noktasını kapatıyordu. Gece fabrikasında da parçacık bütçesi aşılıyordu. İkisi de düzeltildi.

## 2. Nasıl çalıştırılır
```bash
godot --path vardiya
```
Ayarlar → **Görsel efektler** ile Yüksek / Düşük arasında geçiş yapılır. Oyun içinde F3 kare süresi katmanını açar.

## 3. Test sonuçları (bu ortamda)
| Test | Sonuç |
|---|---|
| Doğrulayıcı (tüm oyun + epiloglar + yeni sanat kuralları) | **0 hata**, 2 uyarı. Uyarılar önceki aşamayla aynı: bilinçli olarak koşullu seçenekler. |
| Python testleri | **32/32 geçti**. 5 yeni test: bilinmeyen tür ve malzeme, ışık ve parçacık bütçesi, varyant koşulu ve anahtarları, çarpışmalı ateş ve oda dışı kutu, karakter görünümü. |
| Hikâye simülasyonu (`story_sim.py --game`) | Değişiklik yok: 5 sonun hepsine ulaşılıyor, epiloglar oynanıyor. |
| GDScript `gdparse` + `gdlint` | Temiz. |
| Motor içi testler (46 grup) | **ÇALIŞTIRILAMADI.** Godot'yu çalıştırma izni hâlâ yok. 6 grup yeni: 7 mekânın mesh, köşe, ışık ve çizim bütçesi; 512 piksel doku ve önbellek; epilog varyantları; 6 karakterin gövdesi ve yürüme animasyonu; düşük kalitede gölge, parçacık ve vignette kapalı; yangın propları. |
| Kare süresi | **ÖLÇÜLEMEDİ.** Ayrıntılı tahmin aşağıda. |
| Haritalar (`docs/maps/*.png`) | Yeniden üretildi. Yeni süs eşyaları çarpışmasız, yürünebilirlik değişmedi. |

**Kare süresi tahmini (ölçüm değil):**
- **Çizim çağrıları:** mekân başına 3-10 birleştirilmiş mesh, en fazla 4 hale, 4 hüzme ve 3 ateş, karakter başına 5 parça, en fazla 4 parçacık sistemi ve gölge geçişi. Toplam kabaca 60-90 çizim çağrısı; bu, önceki gri kutu sürümüyle aynı düzeyde ya da daha az.
- **Ek maliyet piksel tarafında:**
  - Triplanar doku, piksel başına 3 örnekleme demek.
  - Toplamalı hale ve hüzmeler üst üste çizim (overdraw) ekliyor.
- Vega 6'da 1080p 30 FPS sınırda kalırsa ilk adım **Görsel efektler: Düşük**. Ölçüm için:
```bash
godot --path vardiya --resolution 1920x1080 --fullscreen -- --benchmark
```
Motor testleri için:
```bash
godot --headless --path vardiya res://tests/test_runner.tscn
```

## 4. Varsayımlar
1. **Model dosyası yerine kodla üretilen geometri.** Bu ortamda Godot çalıştırılamadığı için `.glb` içe aktarma ve görsel kontrol yapılamıyor. Kodla üretilen geometri telif riskini sıfırlıyor ve kurulum boyutunu artırmıyor. İleride elle modellenmiş varlıklar aynı `kind` adlarıyla değiştirilebilir.
2. **Dokular dosya değil, çalışma anında üretiliyor.** İlk sahne yüklemesinde 6 doku için tahminen 100-300 ms ek süre gerekiyor; sonra önbellekten geliyor. Yükleme ekranı bunu gizliyor.
3. **Glow ve renk düzeltme (adjustment) kullanılmadı.** Compatibility'de ek bir tam ekran geçiş gerektiriyorlar. Parlama hissini ışıksız (unshaded) malzeme ve haleler veriyor.
4. **Duvar yüzeyinde ışıklandırma köşe başına.** Proje ayarında `force_vertex_shading` açık kalıyor, ışık köşe noktalarında hesaplanıyor. Büyük yüzeyler bu yüzden parçalara bölündü.
5. **Yüzler kaba.** Yüz yalnızca göz, burun, bıyık ya da sakal parçalarından oluşuyor; mimik yok. Stilize düşük poligon tarzına uygun.
6. **Görsel sonuç henüz hiç görülmedi.** Çalıştırınca renk, ölçek ya da yön sorunu görürseniz ekran görüntüsüyle bildirmeniz, Aşama 7'de hızla düzeltilmesini sağlar.

## 5. Sonraki aşama (7: cila ve optimizasyon) için öneriler
- Hedef cihazda benchmark. Gerekirse varsayılan kaliteyi cihaza göre seçme, hüzme ve hale sayısını azaltma.
- Kendi üretimimiz ortam sesleri ve müzik (şu an ses yok).
- Kamera geçişleri, bölüm başı kartları ve menü arka planında canlı sahne.
- Metin genişletme: oynama süresi hâlâ tahminen 1,5-2,5 saat, hedef 4-5 saat.
