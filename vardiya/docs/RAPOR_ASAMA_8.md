# VARDİYA — Aşama 8 Raporu (İçerik genişletme, 1. kısım)

Sürüm: 0.8.0 · Godot 4.7 · Compatibility renderer

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
