# VARDİYA — Aşama 4 Raporu (Bölüm 2-8 yapısı ve kararların etkisi)

Sürüm: 0.4.0 · Godot 4.7 · Compatibility renderer

## 1. Ne yapıldı

### Bölümler (hepsi oynanabilir: gri kutu mekân + keşif + kararlar)

Bölüm başına büyük karar ve QTE:

| Bölüm | Bakış açısı | Mekân | Büyük kararlar | QTE |
|---|---|---|---|---|
| 1 Son Kontrol | Kemal | soyunma odası, üretim holü | `b1_selim_uyar`, `b1_ariza_rapor` | robot kolu |
| 2 Grev | Defne → Kemal | fabrika kapısı | `b2_grev_destek`, `b2_kapi` | — |
| 3 Liman | Rıza | konteyner sahası | `b3_ogren`, `b3_teslim` (+ küçük karar: zarf) | bekçi |
| 4 Aile Evi | Defne | ev | `b4_yuzles`, `b4_sinav` | — |
| 5 Gece Vardiyası | Kemal → Rıza → Defne | gece fabrikası | yangında `b5_kurtar`, `b5_kamyon`, `b5_kanit`; yangın yoksa `b5_sabotaj`, `b5_polis`, `b5_kanit` | duman, kamyon, sürünerek kaçış / sabotajcı |
| 6 İhbar | hayatta olan (Rıza › Defne › Kemal) | emniyet görüşme odası | `b6_sir` (itiraf / ihbar / şirketi suçla), `b6_basin` | — |
| 7 Hesap | hayatta olan (Defne › Kemal › Rıza) | ev | `b7_barisma` (tek kişi kaldıysa `b7_yalniz`), `b7_plan` | — |
| 8 Son Vardiya | hayatta olan | fabrika kapısı, şafak | `b8_final`, `b8_bedel` | güvenlik |

Toplam 31 karar kimliği ve 7 QTE var. Her bölümde en az 2 büyük karar bulunuyor.

### Kararların sonraki bölümlere etkisi (örnekler)
- **Yangın kararla doğuyor.** Bölüm 1'de arıza gizlenirse (`fault_hidden`) ya da Bölüm 3'te varillerin teslimine izin verilirse (`cargo_delivered`), Bölüm 5'te yangın çıkıyor. İkisi de yoksa gece başka bir yoldan ilerliyor: sabotajcı yakalanıyor, yangın çıkmıyor.
- **Bölüm 4'teki seçim Bölüm 5'teki kurtarma seçeneklerini belirliyor.**
  - Defne sınava giderse içeride değil. Kemal'in seçenekleri: Selim'i kurtar ya da dışarı çık.
  - Defne babasının yanında kalırsa seçenekler: Defne'yi kurtar ya da Selim'i kurtar.
  - Süre dolarsa Kemal ikisi için de geri dönüyor ve ölüyor.
- **Bölüm 1'deki QTE Bölüm 5'te hayati.** Bölüm 1'de yaralanan Kemal, Bölüm 5'teki duman QTE'sinde başarısız olursa ölüyor.
- **İhbar bakış açısına bağlı.** Bölüm 6'da ihbar eden, o sahneyi oynayan karakter oluyor (`informer = pov`). Diğer ikisinin ona güveni -3 düşüyor.
- **Kanıtlar yeni seçenekler açıyor.** Rıza'nın Defne'ye gönderdiği varil fotoğrafı, Defne'nin yangın kaydı ve Kemal'in hata kaydı, Bölüm 6 ile 8'de "kanıtları aç / şirketi suçla" seçeneklerini açıyor.
- **Bölüm 7 bir hesap dökümüyle açılıyor.** Selim'in akıbeti, kapı, variller, ihbar, soruşturma, gizli tamir ve açığa çıkan sır, yalnızca gerçekten yaşandıysa birer satır olarak gösteriliyor.

### Ölümler ve "oyun devam eder"
- Üç karakter de Bölüm 5'te ölebiliyor:
  - Kemal: tereddüt edip ikisi için geri dönerse, ya da yaralıyken dumandan çıkamazsa.
  - Rıza: kamyonla duvarı yıkarken başarısız olursa.
  - Defne: sürünerek kaçış QTE'sinde başarısız olursa.
- Bölüm 8'de güvenlik QTE'si ya da "suçu üstüne al" seçimi, sahneyi oynayan karakteri `missing` (tutuklandı / kayıp) yapıyor.
- **Bakış açısı ölüye geçmiyor.** Her bölüm, hayatta olan ilk karakteri öncelik sırasıyla seçiyor. Ölen karakterin sahnesi atlanıyor ve diğerleri onun yokluğuna tepki veriyor.
- **Ölümler sonraki bölümlerde görünüyor:** Bölüm 5 sonrası satırlar, Bölüm 6-8'de ölüme özel satırlar, mekânda boş kalan yer (ölen karakter sahneye konmuyor), Bölüm 8'de kapıdaki mumlar.
- **Üçü de ölürse** Bölüm 6-8, Nevin, Selim ve anlatıcıyla kısa ara sahneler olarak sürüyor. Sonuç: Acı Hesap.
- Bölüm 8 bitince ulaşılan son, bölüm sonu ekranında yazıyor. Tam final sahneleri ve kredi Aşama 5'te.

### Yeni mekânlar
`factory_gate`, `port_yard`, `family_home`, `factory_night`, `police_room`. Toplam 7 gri kutu mekân var. Yangın dekoru, yalnızca yangın çıktıysa kurulan koşullu kutularla yapıldı. Kuşbakışı planlar `docs/maps/` altında.

### Araçlar
- **`story_sim.py --game`:** tüm oyunu Bölüm 1'den 8'e oynuyor ve her bölümün sonundaki durumları bir sonrakine taşıyor. Beş sonun her biri için somut bir test yolu üretiyor (`docs/SON_TEST_YOLLARI.md`). Süre yaklaşık 26 saniye.
- **Doğrulayıcı (`validate_data.py`) artık:**
  - Ulaşılamayan sonu **hata** sayıyor. Karar artık gerçek oynanış simülasyonuna dayanıyor; bağımsız değişken örneklemesi bilgi olarak kaldı.
  - Sahneyi ölü ya da kayıp bir karaktere oynatmaya çalışan bölümü hata sayıyor.
  - "Bu bölümde ölebilen karakter sonraki hiçbir bölümde fark edilmiyor" durumunu hata sayıyor.
  - Bölüm 2-8'de hiçbir oynanışta ulaşılamayan düğüm, seçenek ve nesneleri raporluyor.

## 2. Test sonuçları (bu ortamda)
| Test | Sonuç |
|---|---|
| Doğrulayıcı, katı mod + tüm oyun simülasyonu | **0 hata**, 2 uyarı (iki seçimde seçenekler bilinçli olarak koşullu; simülasyon her yolda en az 2 seçenek olduğunu gösteriyor) |
| Tüm oyun simülasyonu | Beş sonun beşine de ulaşıldı. Bölüm 2-8'de ulaşılamayan düğüm, seçenek ya da nesne yok. |
| Python testleri | **22/22 geçti**. Yenileri: ihbar kaldırılınca İhanet sonunun ulaşılamaz bulunması, sonraki bölümlerde tepkisi olmayan ölüm, ölü karaktere sahne verme, tüm oyun simülasyonuyla 5 son. |
| GDScript `gdparse` + `gdlint` | temiz |
| Motor içi testler (32 test grubu; yenileri: 8 bölüm × 2+ büyük karar, yangının önceki kararlara bağlılığı, sınav seçiminin kurtarma seçeneklerine etkisi, bakış açısının ölüyü atlaması, herkes ölünce devam, ölümün sonraki bölümde görünmesi, ihbarın bakış açısına yazılması, Bölüm 1 → 2 bağlantısı) | **ÇALIŞTIRILAMADI** (Godot'yu çalıştırma izni hâlâ yok) |
| Kare süresi | **ÖLÇÜLEMEDİ** |

## 3. Varsayımlar
1. Bölüm uzunlukları şimdilik kısa: oynanış başına yaklaşık 5-10 dakika. Yapı, dallar ve bağlantılar tam; 4-5 saatlik süre hedefi için metin ve sahne genişletmesi Aşama 5-6'da yapılacak.
2. "Bedel ödemek" iki biçimde var: ölüm, ya da `missing` (tutuklanma veya kaybolma). İkisi de hayatta sayılmıyor, dolayısıyla Acı Hesap sonuna sayılıyor.
3. Yeni NPC'ler: Komiser (Bölüm 6) ve sevkiyatçı. Sevkiyatçı yalnızca anlatıcı satırlarında geçiyor.
4. Simülatör tam gezinme yapmıyor, bütçeli çalışıyor: bölüm başına en fazla 120 bin durum, sonraki bölüme en fazla 2500 durum taşınıyor. Taşınan durumlar önce yaşam durumu ve bayrak kombinasyonlarına göre, sonra güvenin uç değerlerine göre çeşitlendiriliyor. Bu yüzden "ulaşılamaz" uyarıları çok nadir de olsa yanlış alarm olabilir. Bulunan test yolları ise kesin.
5. Bakış açısı öncelikleri: Bölüm 6'da Rıza önde, çünkü sır onun. Bölüm 7 ve 8'de Defne önde. `pov` bayrağıyla aynı karar düğümü her karakter için kullanılabiliyor.

## 4. Sonraki aşama (5) için
- Her son için final sahnesi, son kartı ve kredi ekranı.
- Ana menüde "sonlar" galerisi: ulaşılan sonlar kaydediliyor.
- Metin genişletmesiyle süre hedefine yaklaşma.
