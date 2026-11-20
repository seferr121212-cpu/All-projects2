# VARDİYA — Aşama 8 Raporu (İçerik genişletme)

Sürüm: 0.8.2 · Godot 4.7 · Compatibility renderer

# 3. KISIM: B devam (en güncel durum)

| Sürüm | Hızlı oyuncu | Dikkatli oyuncu | Aşama 8'de eklenen tekil TR kelime |
|---|---|---|---|
| 0.7.0 | ~25 dk | ~35 dk | — |
| 0.8.0 | ~36 dk | ~50 dk | ~3.975 |
| 0.8.1 | ~44 dk | ~61 dk | ~5.600 |
| **0.8.2 (bu teslim)** | **~47 dk** | **~67 dk** | **~7.060** (+ ~10.600 EN) |

**Bu teslimde eklenenler:**
- **Bölüm 8:**
  - Son vardiya sabahı 05.10'da evde başlıyor. Ütü masası, Sevgi kanepede, aşağıda bekleyen Rıza; çıkmadan önce masaya not bırakma seçimi.
  - Kapıya gelenlerle konuşulabiliyor: Hüsnü Hoca, Ece, Zeynep ve Deniz, Sevgi.
- **Bölüm 7:**
  - Evde 3 yeni keşif noktası: Defne'nin masası, askılıktaki üç mont, telesekreter.
  - Yalnız kalan karakterin gecesi.
  - Üç barışma konuşmasının uzun hâlleri: baba-kız, Defne-Rıza, Kemal-Rıza.
- **Bölüm 6:** Sendika avukatı Leyla Tan (yeni yan karakter, sahnede yok); sorgu odasında 2 yeni nokta.
- **Bölüm 5:**
  - Kemal'in yangındaki ilk dakikaları: kabloları sökülmüş alarm, 112.
  - Defne Nevin'in masasında Demirtaş teslimat notlarını buluyor.
  - Cevdet Rıza'ya varilleri geri getirme karşılığı borç affı teklif ediyor.
  - Kemal gece Selim'i arıyor.
- **Bölüm 3:** Liman avlusunda 2 yeni nokta. Rıhtım babasında "R + K, 1993" yazısı.
- **Bölüm 2:** Kapının iç tarafında Kemal ile Rıza.
- **Epiloglar:** Beş epilogun hepsinde bir "Sonra:" bölümü var. Sevgi, Ece, Hüsnü Hoca, Cevdet, Rıza'nın kamyonu, Deniz ve Nevin'in akıbeti, oyuncunun yan hikâyelerde yaptığı seçimlere göre değişiyor. Aynı metin beş epilogda tekrarlandığı için **ham** kelime sayısı 8.700; tabloda **tekil** sayı var.

**Toplam (Aşama 8):**
- 536 yeni düğüm.
- 25 süresiz seçim.
- 5 keşif bölümü ve mevcut keşiflere 12 yeni nokta.
- 7 yan karakter.

**Süre neden yavaş artıyor?** Yeni sahnelerin çoğu bir dala bağlı: bakış açısına, kimin yaşadığına ya da yan hikâye seçimine. Tek oynanışta oyuncu eklenen metnin ancak yaklaşık %45'ini görüyor (ölçüm: dikkatli oyuncu Aşama 8 metninden ~3.200 kelime okuyor). Bu dalların hepsi beş sonu ve tekrar oynamayı zenginleştiriyor, ama tek oynanışın süresini sınırlı uzatıyor. B hedefine (~1,5-2 saat) ulaşmak için kalan ~13.000 TR kelimenin büyük kısmını herkesin gördüğü ana yola yazmayı öneriyorum.

**Testler:**
- Doğrulayıcı: 0 hata, 2 bilinçli uyarı.
- Tam oyun simülasyonu: 5 sonun hepsine ulaşılıyor.
- Python testleri: 37/37.
- Motor testleri ve kare süresi: çalıştırılamadı (Godot izni yok).

**Araç:** Belirli düğümlerden yapılan eklemeler artık kontrol ediliyor. Hedef düğüme gitmeyen bir ekleme, sahneyi sessizce erişilemez bırakmak yerine hata veriyor. Bu kontrol bir hatayı yakaladı ve hata düzeltildi.

---


# 2. KISIM: B + D seçenekleri

## Durum özeti
| Sürüm | Hızlı oyuncu | Dikkatli oyuncu | Aşama 8'de eklenen TR kelime |
|---|---|---|---|
| 0.7.0 | ~25 dk | ~35 dk | — |
| 0.8.0 (1. kısım) | ~36 dk | ~50 dk | ~3.975 |
| **0.8.1 (bu teslim)** | **~44 dk** | **~61 dk** | **~5.620** (+ ~8.400 EN) |
| B hedefi | | ~1,5-2 saat | ~20.000 |

- **D (yeni 3B mekânlar, yan karakterler sahnede, daha uzun keşif): tamamlandı.**
- **B (20.000 kelime): yaklaşık %28'i tamamlandı.** Kalan ~14.400 Türkçe kelime ve İngilizcesi sonraki teslimlerde gelecek.

Bölüm bölüm dikkatli oyuncu: 1: 12,0 · 2: 8,1 · 3: 8,5 · 4: 6,5 · 5: 6,2 · 6: 5,7 · 7: 5,3 · 8: 4,4 dk · epilog 2,2 · jenerik 1,9.

## D — yapılanlar
**5 yeni 3B mekân.** Aşama 6'daki gibi tamamen veriyle kuruluyor, model ya da doku dosyası yok:

| Mekân | Bölüm | İçerik |
|---|---|---|
| `harbour_teahouse` (liman kahvesi) | 3 | Masalar, ocak, sessiz televizyon, tavla oynayan iki yaşlı; köşe masada Cevdet |
| `prep_school` (dershane / sınav salonu) | 2, 5 | Sıralar, tahta, deneme sıralaması; Hüsnü Hoca, Ece (Defne'nin onu sınava ikna ettiği yolda) |
| `hospital_corridor` (acil koridoru) | 5 | Floresan, bozuk çay makinesi, hemşire masası; yaşayanlar, Selim ve Zeynep |
| `station_steps` (karakol önü, akşam) | 6 | Merdivenler, sokak lambaları, siyah araba, muhabirler; bakış açısına göre Cevdet, ya da Sevgi ve Ece |
| `cemetery` (deniz kenarında mezarlık) | 7 | Kimin öldüğüne göre beliren yeni mezar taşları, servi ağaçları, bank; Zeynep ve Sevgi |

**Yan karakterler sahnede.** Sevgi, Cevdet, Ece, Hüsnü Hoca ve Zeynep'in görünüş tanımları vardı; artık bedenleriyle duruyorlar. Yeni karakter Hayriye Ana yalnızca telefonda konuşuyor.
- Kamera konuşan kişiye dönüyor.
- Ev ve fabrika kapısına "misafir" olarak geliyorlar: Bölüm 4'te Ece, Bölüm 7'de Selim, Zeynep ve bebek Deniz, Bölüm 8'in şafağında Hüsnü Hoca, Ece, Zeynep ve Sevgi. Misafirler yalnızca kendi sahnelerinde görünüyor; bunu `scene_guests` bayrağı denetliyor ve Bölüm 8 sonunda bayrak temizleniyor, böylece epiloglara sızmıyorlar.

**Daha uzun keşif.** Yeni mekânlarda 5 yeni keşif bölümü var: 15 isteğe bağlı nokta, 5 günlük notu.

1. kısımdaki 2B kart sahnelerinin hepsi artık 3B. Tek istisna Bölüm 5'teki hastane sahnesi: üç karakter de öldüyse sahne hâlâ kartla oynanıyor, çünkü yönetecek kimse kalmıyor.

## B — bu teslimde eklenen sahneler
| Bölüm | Yeni sahne |
|---|---|
| 1 | Öğle arası Defne'yle telefon (robotu anlatmak ya da anlatmamak) |
| 2 | Nevin'le bekçi kulübesinin arkasında: listeyi kim yazdırıyor, Selim için rica |
| 3 | Rıza'nın annesi Hayriye Ana: kamyon için bozdurulan bilezikler, Cevdet'in "selamı" |
| 4 | Balkonda Rıza'nın borç itirafı; Defne birikimini teklif edebilir |
| 5 | Sınav salonu (sınavı seçtiyse); yangına giden yolda Rıza |
| 6 | Komiser önceki kararları tek tek sayıyor: sensör, kapı, konteyner. Bakış açısındaki karakterin cevabı. |
| 7 | Sevgi akşam yemeğinde; son vardiyadan önceki gece limanda |
| 8 | Hüsnü Hoca'nın otuz yıl önceki on dört günlük grevi; Nevin'in son sözü |

Toplam (1. ve 2. kısım):
- **421 yeni düğüm**, **22 yeni süresiz seçim**, **5 keşif bölümü**.
- **~5.620 TR + ~8.400 EN kelime**.
- **6 yan karakter**.

Sonları belirleyen kurallar ve eski 40 karar değişmedi; yeni seçimler yalnızca yan hikâye bayraklarını değiştiriyor.

## Testler (bu teslim)
| Test | Sonuç |
|---|---|
| Doğrulayıcı | **0 hata**, 2 bilinçli uyarı. Yeni mekânların yürünebilirlik, ışık ve parçacık bütçesi ile aktör ve nokta erişimi kontrol edildi. |
| Tam oyun simülasyonu | 5 sonun hepsine ulaşılıyor; bakış açısı hatası yok |
| Python testleri | **37/37** |
| Kuşbakışı haritalar | `docs/maps/` altında 5 yeni mekân (yerleşimi gözle kontrol ettim) |
| Motor testleri, kare süresi | **Çalıştırılamadı** (Godot izni yok). 5 yeni mekân var; bütçeleri en fazla 3 ışık ve 1 parçacık sistemi, yani mevcut mekânlardan hafif. Yine de hedef cihazda ölçülmesi gerekiyor. |

## Varsayımlar (2. kısım)
1. **Yeni mekânlar yalnızca verilerle tanımlandı ve motorda hiç görülmedi.** Yerleşim kuşbakışı haritalarla kontrol edildi. Duvar, ışık ve kamera mesafesi ilk açılışta ayar isteyebilir.
2. **Aktörlerin bakış yönü (`rot`) tahminî.** Bazı karakterler konuşurken yanlış yöne bakıyor olabilir.
3. **Sınav salonu, dershane mekânının aynısını kullanıyor.**

## Sıradaki adım
B'nin kalanı: ~14.400 Türkçe kelime ve İngilizcesi. En kısa bölümlerden (7, 8, 6, 5) başlayarak birkaç teslimde gelecek. Her teslimden sonra süre ölçülecek.

---

# 1. KISIM (önceki teslim, tarihçe)

## 0. Özet ve süre konusunda dürüst durum
8 bölümün hepsine yeni sahneler ve üç kişisel yan hikâye eklendi. Ölçülen oynama süresi (`tools/playtime.py`, 200 rastgele oynanış):

| Sürüm | Hızlı oyuncu | Dikkatli oyuncu | Hikâye metni (TR) |
|---|---|---|---|
| 0.7.0 | ~25 dk | ~35 dk | ~5.100 kelime |
| **0.8.0 (bu teslim)** | **~36 dk** | **~50 dk** | **~9.100 kelime** |
| Hedef | 4-5 saat | 4-5 saat | |

**Aşama 7 raporundaki hesabım yine iyimserdi.** "~20.000 ek Türkçe kelime ile 4-5 saate ulaşılır" demiştim. Bu aşamada ölçtüğüm oran şu: **eklenen her 1.000 Türkçe kelime dikkatli oyuncuya ~4 dakika katıyor.** Oyuncu bir oynanışta metnin ancak bir kısmını görüyor; çünkü dallar, ölüm durumları ve bakış açısı değişiyor. Buna göre:
- 20.000 ek kelime ≈ dikkatli oyuncu için **~2 saat**, hızlı oyuncu için ~1,5 saat.
- 4-5 saat için **~55.000-65.000 ek kelime** gerekir. Bu, kısa bir romanın uzunluğu; İngilizcesiyle iki katı.

Bu yüzden Aşama 8'i burada bir **ara teslim** olarak durdurdum: süre hedefini birlikte yeniden belirlemeniz gerekiyor (bölüm 5'te seçenekler).

## 1. Ne yapıldı
### Yan hikâyeler (TR + EN)
| Karakter | Yan hikâye | Bölümler |
|---|---|---|
| **Kemal** | Defne'nin annesi **Sevgi**, dokuz yıl sonra arıyor. Kemal'in dolabın üst rafında sakladığı, hiç açılmamış mektuplarla dolu ayakkabı kutusu. | 1, 4, 5, 6, 7, 8 |
| **Defne** | Sınav ve dershane arkadaşı **Ece** (çağrı merkezinde gece vardiyası mı, sınav mı?). Hüsnü Hoca. Annesiyle ilk mesaj ve karakol önündeki ilk karşılaşma. İzmir'de hemşirelik sonucu. | 2, 4, 5, 6, 7, 8 |
| **Rıza** | Kamyon taksitleri için tefeci **Cevdet**'e borç. Kırk yedi numaralı konteynerin neden kabul edildiği. Kamyonun anahtarı ve kapıya gelen çekici. | 1, 2, 3, 5, 6, 7, 8 |

### Bölüm bölüm yeni sahneler
| Bölüm | Yeni sahneler |
|---|---|
| 1 Son Kontrol | Soyunma odasında Sevgi'nin telefonu · çay molası, Selim'in bebeğinin adı ve Rıza'nın borç telefonu · akşam: evde yemek **ya da** (sensörü gizlice değiştirdiyse) gece fabrikada tek başına |
| 2 Grev | Grev alanında Ece · Defne'nin akşamı: dershanede Hüsnü Hoca **ya da** grev ateşinin başında Selim ve annesinden gelen mesaj · kapıda Cevdet'in arabası |
| 3 Liman | Liman kahvesinde Cevdet'in defteri · kabinde babasının fotoğrafı ve Defne'nin "sınava götürür müsün" mesajı · sabaha karşı eve dönüş |
| 4 Aile Evi | Ece ile son tekrar · ayakkabı kutusu (Kemal verir **ya da** Defne bulur) · sınav gecesi **ya da** fabrikaya çıkış |
| 5 Gece Vardiyası | Vardiyadan önce evde (Rıza, Sevgi'nin mesajı) · şafakta hastane koridoru: kimin konuştuğu kimin yaşadığına bağlı |
| 6 İhbar | Sorguda beş dakikalık ara (bakış açısına göre Cevdet / annesi ve Ece / Zeynep) · karakol önünde akşam (Cevdet ve anahtar / Sevgi ile ilk karşılaşma / Kemal ve Sevgi) |
| 7 Hesap | Mezarlık (biri öldüyse) **ya da** Selim bebeği Deniz'le geliyor · Cevdet'in çekicisi · Defne'nin yerleştirme sonucu: İzmir |
| 8 Son Vardiya | Şafakta kapıya gelenler: Hüsnü Hoca, Ece, Zeynep ve Deniz, Selim, Rıza'nın kamyonu, Sevgi · kurul sonrası kısa kapanış |

### Sayılar
- **310 yeni düğüm**, **17 yeni seçim**, 392 yeni metin anahtarı.
- **~3.975 Türkçe kelime** + **~5.930 İngilizce kelime**.
- **5 yeni yan karakter** (konuşan, sahnede bedeni olmayan): Sevgi, Cevdet, Ece, Hüsnü Hoca, Zeynep. Görünüş tanımları `characters.json`'da, ileride sahneye konabilir.
- **18 yeni hikâye bayrağı.** Bunlar yalnızca yeni sahnelerdeki replikleri, varyantları ve dalları seçiyor.

### Sonların korunması
- **Yeni seçimlerin hiçbiri güveni, ölüm durumunu, sessizlik sayacını ya da sonları belirleyen bayrakları değiştirmiyor.** Son kuralları (`endings.json`) ve eski 40 karar aynı.
- **Yeni seçimler süresiz.** Konuşma seçimi olarak tasarlandı. Süreli olsalardı, her zaman aşımı "sessizlik" sayacını artırır ve Sır sonunu kolaylaştırırdı. 8 saniyelik süreli kararlar eskisi gibi duruyor.
- Ölüler konuşmasın diye her yeni replik ve sahne yaşam durumuna bağlandı. Bakış açısı kimdeyse sahne ona göre dallanıyor.

### Araç düzeltmeleri
- **`story_sim.py`, ilk bölüm:** Simülatör ilk bölümü yalnızca o bölümün koşullarının gördüğü değişkenlerle ayırt ediyor. Bu kesin bir yöntem. Bu düzeltme olmadan yeni seçimler durum sayısını 2,2 milyona, doğrulayıcının süresini 112 saniyeye çıkarmıştı; şimdi süre yine ~28 saniye.
- **`story_sim.py`, örnekleme:** Bölümden bölüme taşınan durumlar önce yaşam durumuna göre örnekleniyor. Yeni bayraklar örneklemi sulandırınca "herkes öldü" yolu kayboluyordu; doğrulayıcı bunu uyarıyla yakaladı.
- **`playtime.py`:** Koşulu tutmayan replikler artık sayılmıyor; motor da onları atlıyor.
- **2 yeni Python testi**, toplam 37.

## 2. Nasıl çalıştırılır
```bash
godot --path vardiya
```
Yeni sahneler yeni oyunda kendiliğinden geliyor. Eski kayıtlar da açılır: eklemeler yeni düğümler, eski düğüm kimlikleri değişmedi.

## 3. Test sonuçları (bu ortamda)
| Test | Sonuç |
|---|---|
| Doğrulayıcı | **0 hata**, 2 uyarı (önceki aşamalarla aynı, bilinçli) |
| Hikâye simülasyonu | 5 sonun hepsine ulaşılıyor, epiloglar oynanıyor |
| Python testleri | **37/37 geçti** (2'si yeni) |
| GDScript | Bu aşamada GDScript değişmedi |
| Motor içi testler | **ÇALIŞTIRILAMADI.** Godot'yu çalıştırma izni yok. |
| Kare süresi | **ÖLÇÜLEMEDİ.** Yeni 3B mekân yok; mevcut mekânlar yeniden kullanılıyor. Yükte değişiklik beklemiyorum. |
| Okuma / dil kontrolü | Metinler tarafımdan yazıldı ve gözden geçirildi; **bir editör ya da anadili İngilizce olan biri okumadı.** |

```bash
godot --headless --path vardiya res://tests/test_runner.tscn
```
```bash
godot --path vardiya --resolution 1920x1080 --fullscreen -- --benchmark
```

## 4. Varsayımlar
1. **Mekân dışı sahneler 2B kartla oynanıyor.** Liman kahvesi, dershane, hastane, karakol önü ve mezarlık için 3B mekân yapmadım; siyah arka plan, mekân adı ve altyazı var. Kart sonrası oyun ilgili 3B mekâna geri dönüyor. Yeni 3B mekânlar ayrı bir iş.
2. **Yan karakterlerin sahnede bedeni yok.** Telefonda ya da kart sahnelerinde konuşuyorlar. Ev ve fabrika sahnelerinde kamera konuşan kişiye dönmüyor.
3. **Süreler model tahmini.** Okuma hızları `tools/playtime.py` başında yazıyor.
4. **Yeni seçimlerin süresiz olması** spesifikasyondaki "süreli seçim" kuralına bir istisna. Sonları belirleyen kararların hepsi hâlâ süreli.

## 5. Karar gerekiyor: süre hedefi
| Seçenek | Ek iş | Beklenen süre (dikkatli oyuncu) |
|---|---|---|
| **A.** Bu sürümde dur, cila ve hata ayıklamaya geç | — | ~50 dk |
| **B.** Planlanan ~20.000 kelimeyi tamamla: bölüm başına 2-3 sahne daha | ~16.000 TR kelime + EN, birkaç teslimde | **~1,5-2 saat** |
| **C.** 4-5 saat hedefi | ~55.000+ TR kelime + EN | 4-5 saat; çok sayıda teslim, editör desteği önerilir |
| **D.** B'ye ek olarak oynanış süresi: yeni 3B mekânlar (hastane, liman kahvesi, dershane), yan karakterlerin sahneye konması, daha uzun keşif bölümleri | B + sanat işi | ~2-2,5 saat |

**Önerim B ya da D.** Bu türdeki oyunlar tek oynanış için genellikle 2-3 saat hedefler ve birden fazla son tekrar oynamayı teşvik eder. Beş sonu görmek, toplam oynama süresini yaklaşık 2,5 katına çıkarır.
