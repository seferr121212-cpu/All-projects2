# Test kontrol listesi (gerçek donanım)

Oyunu aç, ~15 dakika oyna, sonra **F3 → "QA raporunu kaydet"** (ya da oyunu kapat; otomatik yazılır).
Rapor: `%APPDATA%\Godot\app_userdata\Ufuk Yolu - Horizon Road\qa_report.txt` — içeriğini bana yapıştır.
Rapor FPS yüzdeliklerini (p50/p95/p99), takılma sayısını, GPU/işlemciyi ve bölge başına süreyi içerir.

## Performans (rapordan bakarım)
- p95 kare süresi ≤ 16.7 ms (60 fps) hedef; 33 ms üstü sorun.
- Takılma (>50 ms) sayısı: bölge geçişi ve yükleme dışında 0 olmalı.

## Elle bakılacaklar
1. Sürüş: direksiyon/hız hissi, yokuşta yapışma, kameranın titremesi.
2. Araçtan in/bin, sürgülü kapı, içeri gir, uyu/kaydet/yükle.
3. Yürüyüş: ayak sesi, animasyon, duvardan geçme.
4. Her bölgede NPC'lerle konuş (6 NPC'li hikâyeler: Ayşe, Murat, Selim, Leyla). Konuşurken ses blip'i.
5. İşler: çay, ağ, çömlek, çoban, tamir, demleme; gezici kafe. Ödeme ve görev ilerlemesi doğru mu?
6. Günlük → Yol görevleri: tamamlananlar ✔, ödüller bir kez.
7. 4 harita parçası → final bildirimi.
8. Fotoğraf/çizim modu, gece/gün, hava çeşitleri.
9. Ayarlar: grafik kalitesi, ses, dil (TR/EN), ekran modu.

## Not al
Sıkıcı/zor/anlaşılmaz anlar, hatalar, takılmalar, beğenmediğin modeller. Bana yaz.
