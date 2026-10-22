#!/usr/bin/env python3
"""시뮬레이터에서 찍은 실제 화면(capture_simulator.sh)에 헤드라인을 얹어 App Store 스크린샷을 만든다.

실행: python3 scripts/screens/compose_simulator.py   (레포 최상단에서, Pillow 필요)
입력: scripts/screens/build/sim/{ko,en}_<화면>.png
출력: docs/screenshots/marketing/{ko,en}/<화면>.png  (1242x2688, iPhone 6.5")
"""
import os, pathlib
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
raw = str(ROOT / "scripts" / "screens" / "build" / "sim")
out = str(ROOT / "docs" / "screenshots" / "marketing")
W, H = 1242, 2688   # App Store Connect 제출 규격 (iPhone 6.5")
FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"

# (출력 파일, 원본 캡처, 헤드라인, 부제) — 번호 순서가 스토어 순서다. 1·2장은 현수막 단체사진.
CAPTIONS = {
 "ko": [
  ("01-banner", "banner", "현수막 든 단체사진, 현수막 없이", "바닥을 탭하면 모두의 앞에 현수막이 놓여요"),
  ("02-banner-design", "bannerDesign", "테마 고르고 문구만 적으면 끝", "야유회 · 동창회 · 졸업 · 생일 등 테마 13가지"),
  ("03-remote", "02-remote", "친구 iPhone이 설치 없이 리모컨", "QR 한 번이면 미리보기 보며 셔터"),
  ("04-countdown", "04-countdown", "손바닥 하나로 셔터", "손바닥 · 박수 · 미소로 찍고, 음성과 불빛으로 카운트다운"),
  ("05-bestshot", "01-main", "눈 감은 사진은 이제 그만", "연사 중 모두 눈 뜬 베스트샷을 골라 두고, 잘리는 사람도 알려 줘요"),
  ("06-reviews", "03-reviews", "찍은 사진은 리모컨 폰으로 바로", "앱 없는 친구도 사진을 저장하고 공유해요"),
  ("07-gallery", "05-gallery", "베스트샷만 모아 보기", "연사 중 다른 장으로 바꾸고 AirDrop으로 나눠요"),
  ("08-pairing", "07-pairing", "QR만 보여 주면 준비 끝", "계정도, 페어링도, 추가 장비도 필요 없어요"),
  ("09-simple", "06-simple", "누구나 쉬운 큰 버튼 모드", "어르신도 버튼 하나로 단체사진 완성"),
 ],
 "en": [
  ("01-banner", "banner", "The banner group photo, no printing", "Tap the ground and a banner appears in front of everyone"),
  ("02-banner-design", "bannerDesign", "Pick a theme, add your words", "13 themes for reunions, parties, graduations and more"),
  ("03-remote", "02-remote", "Any iPhone becomes the remote", "Scan one QR code, nothing to install"),
  ("04-countdown", "04-countdown", "Raise your palm to shoot", "Palm, clap or smile shutter with voice and light countdown"),
  ("05-bestshot", "01-main", "No more closed eyes", "Bursts keep the shot where everyone's eyes are open"),
  ("06-reviews", "03-reviews", "Photos land on the remote", "Friends without the app can save and share them"),
  ("07-gallery", "05-gallery", "Best shots, all in one place", "Swap in another frame and share with AirDrop"),
  ("08-pairing", "07-pairing", "Show the QR and you're ready", "No account, no pairing, no extra hardware"),
  ("09-simple", "06-simple", "Big buttons for everyone", "One large shutter anyone can press"),
 ],
 "ja": [
  ("01-banner", "banner", "横断幕なしで横断幕の集合写真", "床をタップすると、みんなの前に横断幕が置かれます"),
  ("02-banner-design", "bannerDesign", "テーマを選んで文字を入れるだけ", "同窓会、パーティー、卒業など13種類のテーマ"),
  ("03-remote", "02-remote", "どのiPhoneもリモコンに", "QRコードを読み取るだけ。インストール不要"),
  ("04-countdown", "04-countdown", "手のひらをかざして撮影", "手のひら、拍手、笑顔で撮影。音声と光のカウントダウン付き"),
  ("05-bestshot", "01-main", "目を閉じた写真とさよなら", "連写から、全員が目を開けている1枚を選びます"),
  ("06-reviews", "03-reviews", "撮った写真はリモコンにも届く", "アプリのないお友だちも保存・共有できます"),
  ("07-gallery", "05-gallery", "ベストショットをまとめて見る", "別のコマに差し替えて、AirDropで共有"),
  ("08-pairing", "07-pairing", "QRを見せれば準備完了", "アカウントもペアリング設定も追加の機器も不要です"),
  ("09-simple", "06-simple", "だれでも押せる大きなボタン", "大きなシャッターボタンがひとつだけ"),
 ],
 "zh-Hans": [
 ("01-banner", "banner", "不用印横幅，也能拍横幅合影", "点一下地面，横幅就出现在大家面前"),
 ("02-banner-design", "bannerDesign", "选个主题，写上文字就好", "同学聚会、派对、毕业等 13 种主题"),
 ("03-remote", "02-remote", "朋友的 iPhone 就是遥控器", "扫一下二维码，无需安装"),
 ("04-countdown", "04-countdown", "举起手掌就能拍", "手掌、拍手、微笑都能触发，还有语音和灯光倒计时"),
 ("05-bestshot", "01-main", "告别闭眼的照片", "从连拍中选出所有人都睁眼的一张"),
 ("06-reviews", "03-reviews", "拍好的照片直接发到遥控器", "没有装 App 的朋友也能保存和分享"),
 ("07-gallery", "05-gallery", "集中查看最佳照片", "换成连拍中的另一张，再用隔空投送分享"),
 ("08-pairing", "07-pairing", "亮出二维码就能开拍", "无需账号，无需配对设置，无需额外设备"),
 ("09-simple", "06-simple", "人人都会按的大按钮", "只有一个大快门，谁都能按"),
 ],
 "zh-Hant": [
 ("01-banner", "banner", "不用印布條，也能拍布條團體照", "點一下地面，布條就出現在大家面前"),
 ("02-banner-design", "bannerDesign", "選個主題，寫上文字就好", "同學會、派對、畢業等 13 種主題"),
 ("03-remote", "02-remote", "朋友的 iPhone 就是遙控器", "掃一下 QR code，不需安裝"),
 ("04-countdown", "04-countdown", "舉起手掌就能拍", "手掌、拍手、微笑都能觸發，還有語音和燈光倒數"),
 ("05-bestshot", "01-main", "告別閉眼的照片", "從連拍中挑出所有人都睜眼的一張"),
 ("06-reviews", "03-reviews", "拍好的照片直接傳到遙控器", "沒有安裝 App 的朋友也能儲存和分享"),
 ("07-gallery", "05-gallery", "集中查看最佳照片", "換成連拍中的另一張，再用 AirDrop 分享"),
 ("08-pairing", "07-pairing", "亮出 QR code 就能開拍", "不需帳號，不需配對設定，不需額外設備"),
 ("09-simple", "06-simple", "人人都會按的大按鈕", "只有一個大快門，誰都能按"),
 ],
 "ru": [
 ("01-banner", "banner", "Фото с баннером без печати", "Коснитесь пола — и баннер появится перед всеми"),
 ("02-banner-design", "bannerDesign", "Тема и пара слов — и всё готово", "13 тем для встреч, вечеринок, выпускных и не только"),
 ("03-remote", "02-remote", "Чужой iPhone — как пульт", "Отсканируйте QR-код, ничего не устанавливая"),
 ("04-countdown", "04-countdown", "Снимайте одной ладонью", "Ладонь, хлопок или улыбка, голосовой и световой отсчёт"),
 ("05-bestshot", "01-main", "Больше никаких закрытых глаз", "Из серии выбирается кадр, где у всех открыты глаза"),
 ("06-reviews", "03-reviews", "Фото сразу на пульте", "Друзья без приложения тоже сохранят и отправят снимок"),
 ("07-gallery", "05-gallery", "Лучшие кадры в одном месте", "Замените кадр другим из серии и отправьте по AirDrop"),
 ("08-pairing", "07-pairing", "Покажите QR — и готово", "Ни аккаунтов, ни настройки подключения, ни доп. устройств"),
 ("09-simple", "06-simple", "Крупная кнопка для всех", "Один большой затвор, который нажмёт любой"),
 ],
 "es": [
 ("01-banner", "banner", "Foto con pancarta, sin imprimir", "Toca el suelo y la pancarta aparece delante de todos"),
 ("02-banner-design", "bannerDesign", "Elige un tema y escribe tu texto", "13 temas para reencuentros, fiestas, graduaciones y más"),
 ("03-remote", "02-remote", "Otro iPhone es tu control", "Escanea el QR, sin instalar nada"),
 ("04-countdown", "04-countdown", "Dispara con la palma de la mano", "Palma, palmada o sonrisa, con cuenta atrás por voz y luz"),
 ("05-bestshot", "01-main", "Se acabaron los ojos cerrados", "Elige la toma en la que todos tienen los ojos abiertos"),
 ("06-reviews", "03-reviews", "Las fotos llegan al control", "Los amigos sin la app también pueden guardarlas y compartirlas"),
 ("07-gallery", "05-gallery", "Todas las mejores tomas", "Cambia por otra de la ráfaga y compártela con AirDrop"),
 ("08-pairing", "07-pairing", "Enseña el QR y listo", "Sin cuentas, sin ajustes de emparejamiento, sin accesorios"),
 ("09-simple", "06-simple", "Botón grande para todos", "Un único obturador grande que cualquiera puede pulsar"),
 ],
 "de": [
 ("01-banner", "banner", "Gruppenfoto mit Banner, ohne Druck", "Tippe auf den Boden und das Banner steht vor allen"),
 ("02-banner-design", "bannerDesign", "Motiv wählen, Text eintippen", "13 Motive für Klassentreffen, Partys, Abschlussfeiern und mehr"),
 ("03-remote", "02-remote", "Jedes iPhone wird zur Fernbedienung", "QR-Code scannen, nichts installieren"),
 ("04-countdown", "04-countdown", "Mit der Handfläche auslösen", "Handfläche, Klatschen oder Lächeln, mit Countdown per Stimme und Licht"),
 ("05-bestshot", "01-main", "Schluss mit geschlossenen Augen", "Aus der Serie das Foto mit allen offenen Augen wählen"),
 ("06-reviews", "03-reviews", "Fotos landen direkt auf der Fernbedienung", "Auch Freunde ohne App können sie sichern und teilen"),
 ("07-gallery", "05-gallery", "Alle besten Fotos im Überblick", "Gegen ein anderes aus der Serie tauschen und per AirDrop teilen"),
 ("08-pairing", "07-pairing", "QR-Code zeigen und loslegen", "Kein Konto, keine Kopplung, kein Zubehör"),
 ("09-simple", "06-simple", "Große Taste für alle", "Ein großer Auslöser, den jeder drücken kann"),
 ],
 "fr": [
 ("01-banner", "banner", "Photo de groupe avec banderole, sans imprimer", "Touchez le sol et la banderole apparaît devant tout le monde"),
 ("02-banner-design", "bannerDesign", "Un thème, quelques mots, et c’est prêt", "13 thèmes pour retrouvailles, fêtes, remises de diplômes et plus"),
 ("03-remote", "02-remote", "Un autre iPhone devient télécommande", "Scannez le QR code, rien à installer"),
 ("04-countdown", "04-countdown", "Déclenchez d’un geste de la paume", "Paume, applaudissement ou sourire, avec compte à rebours vocal et lumineux"),
 ("05-bestshot", "01-main", "Fini les yeux fermés", "Choisit la photo où tout le monde a les yeux ouverts"),
 ("06-reviews", "03-reviews", "Les photos arrivent sur la télécommande", "Même sans l’app, vos amis peuvent les enregistrer et les partager"),
 ("07-gallery", "05-gallery", "Toutes les meilleures photos", "Remplacez-en une par une autre de la rafale et partagez par AirDrop"),
 ("08-pairing", "07-pairing", "Montrez le QR code, c’est prêt", "Ni compte, ni association à configurer, ni accessoire"),
 ("09-simple", "06-simple", "Un gros bouton pour tous", "Un seul grand déclencheur que chacun peut presser"),
 ],
 "it": [
 ("01-banner", "banner", "Foto con striscione, senza stampare", "Tocca il pavimento e lo striscione appare davanti a tutti"),
 ("02-banner-design", "bannerDesign", "Scegli un tema e scrivi il testo", "13 temi per rimpatriate, feste, lauree e altro"),
 ("03-remote", "02-remote", "Un altro iPhone diventa telecomando", "Scansiona il QR, senza installare nulla"),
 ("04-countdown", "04-countdown", "Scatta con il palmo della mano", "Palmo, applauso o sorriso, con conto alla rovescia a voce e luce"),
 ("05-bestshot", "01-main", "Basta occhi chiusi", "Sceglie lo scatto in cui tutti hanno gli occhi aperti"),
 ("06-reviews", "03-reviews", "Le foto arrivano sul telecomando", "Anche gli amici senza app possono salvarle e condividerle"),
 ("07-gallery", "05-gallery", "Tutti gli scatti migliori", "Cambia con un altro della sequenza e condividi con AirDrop"),
 ("08-pairing", "07-pairing", "Mostra il QR e sei pronto", "Niente account, niente associazioni, niente accessori"),
 ("09-simple", "06-simple", "Un grande pulsante per tutti", "Un solo grande pulsante di scatto che chiunque può premere"),
 ],
 "pt-BR": [
 ("01-banner", "banner", "Foto em grupo com faixa, sem imprimir", "Toque no chão e a faixa aparece na frente de todos"),
 ("02-banner-design", "bannerDesign", "Escolha um tema e escreva o texto", "13 temas para reencontros, festas, formaturas e mais"),
 ("03-remote", "02-remote", "Outro iPhone vira o controle", "Leia o QR code, sem instalar nada"),
 ("04-countdown", "04-countdown", "Dispare com a palma da mão", "Palma, palmas ou sorriso, com contagem por voz e luz"),
 ("05-bestshot", "01-main", "Chega de olhos fechados", "Escolhe a foto em que todos estão de olhos abertos"),
 ("06-reviews", "03-reviews", "As fotos chegam ao controle", "Amigos sem o app também salvam e compartilham"),
 ("07-gallery", "05-gallery", "Todas as melhores fotos", "Troque por outra da rajada e compartilhe por AirDrop"),
 ("08-pairing", "07-pairing", "Mostre o QR code e pronto", "Sem conta, sem pareamento, sem acessórios"),
 ("09-simple", "06-simple", "Botão grande para todos", "Um único obturador grande que qualquer um aperta"),
 ],
 "th": [
 ("01-banner", "banner", "ภาพหมู่ถือแบนเนอร์ ไม่ต้องสั่งพิมพ์", "แตะที่พื้น แบนเนอร์ก็ปรากฏตรงหน้าทุกคน"),
 ("02-banner-design", "bannerDesign", "เลือกธีม พิมพ์ข้อความ ก็เสร็จ", "13 ธีมสำหรับงานเลี้ยงรุ่น ปาร์ตี้ รับปริญญา และอื่น ๆ"),
 ("03-remote", "02-remote", "iPhone เครื่องไหนก็เป็นรีโมตได้", "สแกน QR code ไม่ต้องติดตั้งอะไร"),
 ("04-countdown", "04-countdown", "ถ่ายด้วยฝ่ามือเดียว", "ฝ่ามือ ปรบมือ หรือยิ้ม พร้อมนับถอยหลังด้วยเสียงและแสง"),
 ("05-bestshot", "01-main", "ลาก่อนภาพที่มีคนหลับตา", "เลือกภาพที่ทุกคนลืมตาจากการถ่ายต่อเนื่อง"),
 ("06-reviews", "03-reviews", "ภาพส่งไปที่รีโมตทันที", "เพื่อนที่ไม่มีแอปก็บันทึกและแชร์ได้"),
 ("07-gallery", "05-gallery", "ดูภาพที่ดีที่สุดรวมกัน", "สลับเป็นภาพอื่นในชุดแล้วแชร์ด้วย AirDrop"),
 ("08-pairing", "07-pairing", "โชว์ QR code ก็พร้อมถ่าย", "ไม่ต้องมีบัญชี ไม่ต้องตั้งค่าจับคู่ ไม่ต้องใช้อุปกรณ์เสริม"),
 ("09-simple", "06-simple", "ปุ่มใหญ่ที่ใครก็กดได้", "ปุ่มชัตเตอร์ใหญ่ปุ่มเดียว ใครก็กดได้"),
 ],
 "vi": [
 ("01-banner", "banner", "Ảnh nhóm có băng rôn, không cần in", "Chạm vào sàn, băng rôn hiện ngay trước mặt mọi người"),
 ("02-banner-design", "bannerDesign", "Chọn chủ đề, viết lời là xong", "13 chủ đề cho họp lớp, tiệc, tốt nghiệp và hơn thế nữa"),
 ("03-remote", "02-remote", "iPhone nào cũng thành điều khiển", "Quét mã QR, không cần cài đặt"),
 ("04-countdown", "04-countdown", "Chụp chỉ bằng lòng bàn tay", "Lòng bàn tay, vỗ tay hay nụ cười, kèm đếm ngược bằng giọng nói và ánh sáng"),
 ("05-bestshot", "01-main", "Không còn ảnh nhắm mắt", "Chọn ảnh mà mọi người đều mở mắt"),
 ("06-reviews", "03-reviews", "Ảnh gửi ngay đến điều khiển", "Bạn bè không có ứng dụng cũng lưu và chia sẻ được"),
 ("07-gallery", "05-gallery", "Xem gọn các ảnh đẹp nhất", "Đổi sang ảnh khác trong loạt và chia sẻ qua AirDrop"),
 ("08-pairing", "07-pairing", "Chỉ cần đưa mã QR là xong", "Không tài khoản, không cài đặt ghép nối, không thiết bị thêm"),
 ("09-simple", "06-simple", "Nút lớn cho mọi người", "Một nút chụp lớn mà ai cũng bấm được"),
 ],
 "cs": [
 ("01-banner", "banner", "Fotka s bannerem bez tisku", "Klepněte na podlahu a banner se objeví před všemi"),
 ("02-banner-design", "bannerDesign", "Vyberte motiv a napište text", "13 motivů na srazy, oslavy, promoce a další"),
 ("03-remote", "02-remote", "Druhý iPhone je ovladač", "Naskenujte QR kód, nic neinstalujte"),
 ("04-countdown", "04-countdown", "Fotte dlaní", "Dlaň, tlesknutí nebo úsměv s hlasovým a světelným odpočtem"),
 ("05-bestshot", "01-main", "Konec zavřených očí", "Vybere snímek, na kterém mají všichni otevřené oči"),
 ("06-reviews", "03-reviews", "Fotky rovnou na ovladači", "Kamarádi bez aplikace je také uloží a sdílejí"),
 ("07-gallery", "05-gallery", "Všechny nejlepší snímky", "Vyměňte za jiný ze série a sdílejte přes AirDrop"),
 ("08-pairing", "07-pairing", "Ukažte QR kód a hotovo", "Bez účtu, bez párování, bez příslušenství"),
 ("09-simple", "06-simple", "Velké tlačítko pro každého", "Jediná velká spoušť, kterou zmáčkne kdokoli"),
 ],
 "da": [
 ("01-banner", "banner", "Gruppebillede med banner, uden print", "Tryk på gulvet, og banneret dukker op foran alle"),
 ("02-banner-design", "bannerDesign", "Vælg et tema, skriv din tekst", "13 temaer til rejsegilde, fester, eksamen og mere"),
 ("03-remote", "02-remote", "En anden iPhone bliver fjernbetjening", "Scan QR-koden, installér intet"),
 ("04-countdown", "04-countdown", "Tag billeder med håndfladen", "Håndflade, klap eller smil med nedtælling i stemme og lys"),
 ("05-bestshot", "01-main", "Slut med lukkede øjne", "Vælger billedet, hvor alle har øjnene åbne"),
 ("06-reviews", "03-reviews", "Billeder direkte til fjernbetjeningen", "Også venner uden appen kan gemme og dele dem"),
 ("07-gallery", "05-gallery", "Alle de bedste billeder samlet", "Byt til et andet fra serien og del via AirDrop"),
 ("08-pairing", "07-pairing", "Vis QR-koden, så er du klar", "Ingen konto, ingen parringsopsætning, intet ekstra udstyr"),
 ("09-simple", "06-simple", "Stor knap til alle", "Én stor udløser, som alle kan trykke på"),
 ],
 "el": [
 ("01-banner", "banner", "Ομαδική φωτογραφία με πανό, χωρίς εκτύπωση", "Πατήστε στο δάπεδο και το πανό εμφανίζεται μπροστά σε όλους"),
 ("02-banner-design", "bannerDesign", "Διαλέξτε θέμα, γράψτε το κείμενό σας", "13 θέματα για συναντήσεις, πάρτι, αποφοιτήσεις και άλλα"),
 ("03-remote", "02-remote", "Άλλο iPhone γίνεται τηλεχειριστήριο", "Σαρώστε το QR, χωρίς εγκατάσταση"),
 ("04-countdown", "04-countdown", "Λήψη με μια παλάμη", "Παλάμη, χειροκρότημα ή χαμόγελο, με αντίστροφη μέτρηση φωνής και φωτός"),
 ("05-bestshot", "01-main", "Τέλος τα κλειστά μάτια", "Επιλέγει τη λήψη όπου όλοι έχουν τα μάτια ανοιχτά"),
 ("06-reviews", "03-reviews", "Οι φωτογραφίες πάνε στο τηλεχειριστήριο", "Και οι φίλοι χωρίς την εφαρμογή τις αποθηκεύουν και τις μοιράζονται"),
 ("07-gallery", "05-gallery", "Όλες οι καλύτερες λήψεις μαζί", "Αλλάξτε με άλλη από τη ριπή και μοιραστείτε με AirDrop"),
 ("08-pairing", "07-pairing", "Δείξτε το QR και είστε έτοιμοι", "Χωρίς λογαριασμό, χωρίς ρυθμίσεις αντιστοίχισης, χωρίς πρόσθετο εξοπλισμό"),
 ("09-simple", "06-simple", "Μεγάλο κουμπί για όλους", "Ένα μεγάλο κουμπί κλείστρου που μπορεί να πατήσει ο καθένας"),
 ],
 "fi": [
 ("01-banner", "banner", "Ryhmäkuva bannerilla, ei painatusta", "Napauta lattiaa, niin banneri ilmestyy kaikkien eteen"),
 ("02-banner-design", "bannerDesign", "Valitse teema ja kirjoita teksti", "13 teemaa luokkakokouksiin, juhliin, valmistujaisiin ja muuhun"),
 ("03-remote", "02-remote", "Toisesta iPhonesta kaukosäädin", "Skannaa QR-koodi, ei asennusta"),
 ("04-countdown", "04-countdown", "Kuvaa kämmenellä", "Kämmen, taputus tai hymy, ääni- ja valolähtölaskennalla"),
 ("05-bestshot", "01-main", "Ei enää suljettuja silmiä", "Valitsee kuvan, jossa kaikilla silmät auki"),
 ("06-reviews", "03-reviews", "Kuvat suoraan kaukosäätimelle", "Ilman sovellusta olevatkin ystävät voivat tallentaa ja jakaa"),
 ("07-gallery", "05-gallery", "Kaikki parhaat kuvat yhdessä", "Vaihda sarjasta toiseen kuvaan ja jaa AirDropilla"),
 ("08-pairing", "07-pairing", "Näytä QR-koodi ja olet valmis", "Ei tiliä, ei paritusasetuksia, ei lisälaitteita"),
 ("09-simple", "06-simple", "Iso painike kaikille", "Yksi iso laukaisin, jota kuka tahansa voi painaa"),
 ],
 "id": [
 ("01-banner", "banner", "Foto grup dengan spanduk, tanpa cetak", "Ketuk lantai dan spanduk muncul di depan semua orang"),
 ("02-banner-design", "bannerDesign", "Pilih tema, tulis teksnya", "13 tema untuk reuni, pesta, wisuda, dan lainnya"),
 ("03-remote", "02-remote", "iPhone lain jadi remote", "Pindai QR, tanpa memasang apa pun"),
 ("04-countdown", "04-countdown", "Potret dengan telapak tangan", "Telapak tangan, tepuk tangan, atau senyum, dengan hitung mundur suara dan cahaya"),
 ("05-bestshot", "01-main", "Selamat tinggal mata terpejam", "Memilih foto yang matanya terbuka semua"),
 ("06-reviews", "03-reviews", "Foto langsung ke remote", "Teman tanpa app pun bisa menyimpan dan membagikannya"),
 ("07-gallery", "05-gallery", "Semua foto terbaik di satu tempat", "Ganti dengan foto lain dari rangkaian dan bagikan lewat AirDrop"),
 ("08-pairing", "07-pairing", "Tunjukkan QR, langsung siap", "Tanpa akun, tanpa pengaturan pemasangan, tanpa perangkat tambahan"),
 ("09-simple", "06-simple", "Tombol besar untuk semua", "Satu tombol rana besar yang bisa ditekan siapa saja"),
 ],
 "nb": [
 ("01-banner", "banner", "Gruppebilde med banner, uten utskrift", "Trykk på gulvet, så dukker banneret opp foran alle"),
 ("02-banner-design", "bannerDesign", "Velg tema, skriv teksten din", "13 temaer for gjensyn, fester, eksamen og mer"),
 ("03-remote", "02-remote", "En annen iPhone blir fjernkontroll", "Skann QR-koden, ingenting å installere"),
 ("04-countdown", "04-countdown", "Ta bilder med håndflaten", "Håndflate, klapp eller smil med nedtelling i stemme og lys"),
 ("05-bestshot", "01-main", "Slutt på lukkede øyne", "Velger bildet der alle har øynene åpne"),
 ("06-reviews", "03-reviews", "Bildene havner på fjernkontrollen", "Også venner uten appen kan lagre og dele dem"),
 ("07-gallery", "05-gallery", "Alle de beste bildene samlet", "Bytt til et annet fra serien og del via AirDrop"),
 ("08-pairing", "07-pairing", "Vis QR-koden, så er du klar", "Ingen konto, ingen paringsoppsett, ikke noe ekstrautstyr"),
 ("09-simple", "06-simple", "Stor knapp for alle", "Én stor utløser som alle kan trykke på"),
 ],
 "nl": [
 ("01-banner", "banner", "Groepsfoto met spandoek, zonder printen", "Tik op de vloer en het spandoek staat voor iedereen"),
 ("02-banner-design", "bannerDesign", "Kies een thema, schrijf je tekst", "13 thema’s voor reünies, feesten, diploma-uitreikingen en meer"),
 ("03-remote", "02-remote", "Een andere iPhone wordt afstandsbediening", "Scan de QR-code, niets installeren"),
 ("04-countdown", "04-countdown", "Fotografeer met je handpalm", "Handpalm, klap of lach, met aftellen via stem en licht"),
 ("05-bestshot", "01-main", "Geen dichte ogen meer", "Kiest de foto waarop iedereen de ogen open heeft"),
 ("06-reviews", "03-reviews", "Foto’s direct op de afstandsbediening", "Ook vrienden zonder de app bewaren en delen ze"),
 ("07-gallery", "05-gallery", "Alle beste foto’s bij elkaar", "Wissel met een andere uit de serie en deel via AirDrop"),
 ("08-pairing", "07-pairing", "Toon de QR-code en je bent klaar", "Geen account, geen koppelinstellingen, geen extra apparatuur"),
 ("09-simple", "06-simple", "Grote knop voor iedereen", "Eén grote ontspanner die iedereen kan indrukken"),
 ],
}

def font(size, bold):
    return ImageFont.truetype(FONT, size, index=6 if bold else 2)  # Bold / Regular faces in the collection

def wrap(draw, text, f, maxw):
    words, lines, cur = text.split(" "), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=f) <= maxw: cur = t
        else: lines.append(cur); cur = w
    lines.append(cur)
    return lines

for lang, caps in CAPTIONS.items():
    os.makedirs(os.path.join(out, lang), exist_ok=True)
    for name, source, title, sub in caps:
        src = os.path.join(raw, f"{lang}_{source}.png")
        if not os.path.exists(src): print("missing", src); continue
        canvas = Image.new("RGB", (W, H), (16, 16, 18))
        d = ImageDraw.Draw(canvas)
        d.rectangle([0, 0, W, 16], fill=(255, 214, 10))
        tf, sf = font(86, True), font(48, False)
        y = 150
        for line in wrap(d, title, tf, W - 160):
            d.text((W / 2, y), line, font=tf, fill=(255, 214, 10), anchor="mt"); y += 104
        y += 14
        for line in wrap(d, sub, sf, W - 180):
            d.text((W / 2, y), line, font=sf, fill=(225, 225, 230), anchor="mt"); y += 62
        top = y + 50
        shot = Image.open(src).convert("RGB")
        maxh = H - top - 70
        scale = min((W - 200) / shot.width, maxh / shot.height)
        sw, sh = int(shot.width * scale), int(shot.height * scale)
        shot = shot.resize((sw, sh), Image.LANCZOS)
        mask = Image.new("L", (sw, sh), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw, sh], radius=70, fill=255)
        x = (W - sw) // 2
        d.rounded_rectangle([x - 12, top - 12, x + sw + 12, top + sh + 12], radius=82, fill=(60, 60, 66))
        canvas.paste(shot, (x, top), mask)
        canvas.save(os.path.join(out, lang, f"{name}.png"))
print("done →", out)
