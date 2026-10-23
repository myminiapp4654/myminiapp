const List<Map<String, dynamic>> kWordPuzzles = [
  // 1 — Shahar & taom
  {
    'words': [
      {'word': 'TOSHKENT', 'hint': 'Poytaxtimiz', 'emoji': '🏙️'},
      {'word': 'PALOV', 'hint': 'Milliy taom', 'emoji': '🍚'},
      {'word': 'ARZON', 'hint': 'Narxi past', 'emoji': '💰'},
    ],
  },
  // 2 — Fasl & kitob
  {
    'words': [
      {'word': 'BAHOR', 'hint': 'Yil fasli', 'emoji': '🌸'},
      {'word': 'YOMGIR', 'hint': "Bahorda yog'adi", 'emoji': '🌧️'},
      {'word': 'KITOB', 'hint': "O'qiladigan narsa", 'emoji': '📚'},
    ],
  },
  // 3 — Tuyg'u & san'at
  {
    'words': [
      {'word': 'SEVGI', 'hint': "Qalbdagi tuyg'u", 'emoji': '❤️'},
      {'word': 'MUZIKA', 'hint': 'Quloqqa yoqimli', 'emoji': '🎵'},
      {'word': 'DOSTON', 'hint': 'Epik asar', 'emoji': '📜'},
    ],
  },
  // 4 — Mevalar
  {
    'words': [
      {'word': 'UZUM', 'hint': 'Tok mevasi', 'emoji': '🍇'},
      {'word': 'OLMA', 'hint': 'Qizil meva', 'emoji': '🍎'},
      {'word': 'LIMON', 'hint': 'Nordon meva', 'emoji': '🍋'},
    ],
  },
  // 5 — Yovvoyi hayvonlar
  {
    'words': [
      {'word': 'ARSLON', 'hint': "Cho'l podshosi", 'emoji': '🦁'},
      {'word': 'TULKI', 'hint': 'Ayyor hayvon', 'emoji': '🦊'},
      {'word': 'BURGUT', 'hint': 'Ulkan qush', 'emoji': '🦅'},
    ],
  },
  // 6 — Maktab
  {
    'words': [
      {'word': 'MAKTAB', 'hint': "Ta'lim joyi", 'emoji': '🏫'},
      {'word': 'DAFTAR', 'hint': 'Yoziladigan narsa', 'emoji': '📓'},
      {'word': 'RUCHKA', 'hint': 'Yozish asbobi', 'emoji': '✏️'},
    ],
  },
  // 7 — Tabiat
  {
    'words': [
      {'word': 'DENGIZ', 'hint': 'Katta suv havzasi', 'emoji': '🌊'},
      {'word': 'BULUT', 'hint': "Osmon bo'lagi", 'emoji': '☁️'},
      {'word': 'SHAMOL', 'hint': 'Esadi', 'emoji': '💨'},
    ],
  },
  // 8 — Hayot
  {
    'words': [
      {'word': 'HAMROH', 'hint': "Yo'ldosh", 'emoji': '🤝'},
      {'word': 'SABR', 'hint': 'Kuch manbai', 'emoji': '⏳'},
      {'word': 'UMID', 'hint': 'Kelajakka ishonch', 'emoji': '✨'},
    ],
  },
  // 9 — Kasblar
  {
    'words': [
      {'word': 'OSHPAZ', 'hint': 'Taom pishiradi', 'emoji': '👨‍🍳'},
      {'word': 'TABIB', 'hint': 'Davolaydi', 'emoji': '👨‍⚕️'},
      {'word': 'PILOT', 'hint': 'Samolyot boshqaradi', 'emoji': '✈️'},
    ],
  },
  // 10 — Sport
  {
    'words': [
      {'word': 'FUTBOL', 'hint': "To'p o'yini", 'emoji': '⚽'},
      {'word': 'TENNIS', 'hint': 'Raketka bilan', 'emoji': '🎾'},
      {'word': 'KURASH', 'hint': "Milliy sport o'yini", 'emoji': '🤼'},
    ],
  },
  // 11 — Ranglar
  {
    'words': [
      {'word': 'SARIQ', 'hint': 'Quyosh rangi', 'emoji': '💛'},
      {'word': 'YASHIL', 'hint': "O't rangi", 'emoji': '💚'},
      {'word': 'MOVIY', 'hint': 'Osmon rangi', 'emoji': '💙'},
    ],
  },
  // 12 — Joylar
  {
    'words': [
      {'word': 'BOZOR', 'hint': 'Savdo joyi', 'emoji': '🛒'},
      {'word': 'SHIFOXONA', 'hint': 'Davolanish joyi', 'emoji': '🏥'},
      {'word': 'KUTUBXONA', 'hint': 'Kitoblar joyi', 'emoji': '📖'},
    ],
  },
  // 13 — Salomlashish
  {
    'words': [
      {'word': 'SALOM', 'hint': 'Uchrashuvdagi birinchi so\'z', 'emoji': '👋'},
      {'word': 'RAHMAT', 'hint': 'Minnatdorlik bildiriladi', 'emoji': '🙏'},
      {'word': 'XAYR', 'hint': 'Xayrlashuvda aytiladi', 'emoji': '👋'},
    ],
  },
  // 14 — Sabzavotlar
  {
    'words': [
      {'word': 'TARVUZ', 'hint': "Yozgi meva-sabzavot", 'emoji': '🍉'},
      {'word': 'BODRING', 'hint': 'Yashil sabzavot', 'emoji': '🥒'},
      {'word': 'SABZI', 'hint': 'Plavda kerak', 'emoji': '🥕'},
    ],
  },
  // 15 — Osmon
  {
    'words': [
      {'word': 'YULDUZ', 'hint': 'Kechasi porlaydi', 'emoji': '⭐'},
      {'word': 'HILOL', 'hint': 'Yarim oy', 'emoji': '🌙'},
      {'word': 'QUYOSH', 'hint': 'Kunduz porlaydi', 'emoji': '☀️'},
    ],
  },
  // 16 — Uy hayvonlari
  {
    'words': [
      {'word': 'MUSHUK', 'hint': 'Miyovlaydi', 'emoji': '🐱'},
      {'word': 'KUCHUK', 'hint': "Vovullaydi, sodiq do'st", 'emoji': '🐶'},
      {'word': 'TOVUQ', 'hint': 'Tuxum beradi', 'emoji': '🐔'},
    ],
  },
  // 17 — O'zbekiston shaharlari
  {
    'words': [
      {'word': 'SAMARQAND', 'hint': "Ipak yo'li shahri", 'emoji': '🕌'},
      {'word': 'BUXORO', 'hint': 'Tarixiy shahar', 'emoji': '🏛️'},
      {'word': 'NAMANGAN', 'hint': "Farg'ona vodiysi", 'emoji': '🏙️'},
    ],
  },
  // 18 — Tabiat II
  {
    'words': [
      {'word': 'TOGLAR', 'hint': 'Baland yer', 'emoji': '⛰️'},
      {'word': 'DARYO', 'hint': 'Oqadi', 'emoji': '🌊'},
      {'word': 'SAHRO', 'hint': "Qum va issiq", 'emoji': '🏜️'},
    ],
  },
  // 19 — Uy-joy buyumlari
  {
    'words': [
      {'word': 'STOL', 'hint': 'Ustiga qoyiladi', 'emoji': '🪑'},
      {'word': 'KROVAT', 'hint': 'Uxlanadi', 'emoji': '🛏️'},
      {'word': 'KURSI', 'hint': "O'tiriladi", 'emoji': '🪑'},
    ],
  },
  // 20 — Texnologiya
  {
    'words': [
      {'word': 'TELEFON', 'hint': 'Gaplashiladi', 'emoji': '📱'},
      {'word': 'KOMPYUTER', 'hint': 'Ishlash asbobi', 'emoji': '💻'},
      {'word': 'INTERNET', 'hint': 'Global tarmoq', 'emoji': '🌐'},
    ],
  },
  // 21 — Taomlar
  {
    'words': [
      {'word': 'SHASHLIQ', 'hint': "O'tda pishadi", 'emoji': '🍢'},
      {'word': 'SOMSA', 'hint': "Tandirda pishgan", 'emoji': '🥟'},
      {'word': 'LAGMON', 'hint': "Tortilgan qiyma", 'emoji': '🍜'},
    ],
  },
  // 22 — Hissiyotlar
  {
    'words': [
      {'word': 'BAXT', 'hint': 'Yaxshi hayot', 'emoji': '😊'},
      {'word': 'QUVONCH', 'hint': "Xursandchilik hissi", 'emoji': '😄'},
      {'word': 'XURSAND', 'hint': "Ko'ngli to'q", 'emoji': '🥰'},
    ],
  },
  // 23 — Qahramonlik
  {
    'words': [
      {'word': 'QAHRAMON', 'hint': 'Xalq himoyachisi', 'emoji': '🦸'},
      {'word': 'BOTIR', 'hint': 'Jasur inson', 'emoji': '⚔️'},
      {'word': 'JASUR', 'hint': "Qo'rqmaydigan", 'emoji': '💪'},
    ],
  },
  // 24 — San'at
  {
    'words': [
      {'word': 'RASM', 'hint': "Chizilgan tasvirlar", 'emoji': '🎨'},
      {'word': 'RAQS', 'hint': "Musiqa bilan harakat", 'emoji': '💃'},
      {'word': 'HAYKAL', 'hint': "Ko'chada turadigan asar", 'emoji': '🗿'},
    ],
  },
  // 25 — Ta'lim
  {
    'words': [
      {'word': 'SABOQ', 'hint': "O'rganiladi", 'emoji': '📝'},
      {'word': 'IMTIHON', 'hint': 'Bilim sinovi', 'emoji': '📊'},
      {'word': 'DIPLOM', 'hint': 'Tamomlash hujjati', 'emoji': '🎓'},
    ],
  },
  // 26 — Fasllar
  {
    'words': [
      {'word': 'YOZGI', 'hint': 'Issiq fasl sifati', 'emoji': '☀️'},
      {'word': 'QISHKI', 'hint': 'Sovuq fasl sifati', 'emoji': '❄️'},
      {'word': 'KUZGI', 'hint': "Barglar to'kiladi", 'emoji': '🍂'},
    ],
  },
  // 27 — Suvli joylar
  {
    'words': [
      {'word': 'HOVUZ', 'hint': "Ko'l emas, sun'iy", 'emoji': '🏊'},
      {'word': 'SHARSHAR', 'hint': "Balanddan tushuvchi suv", 'emoji': '💧'},
      {'word': 'BULOQ', 'hint': 'Tabiiy suv manbai', 'emoji': '🌊'},
    ],
  },
  // 28 — Qushlar
  {
    'words': [
      {'word': 'BULBUL', 'hint': "Xushsado qush", 'emoji': '🐦'},
      {'word': 'TUSTOVUQ', 'hint': "Rang-barang qush", 'emoji': '🦚'},
      {'word': 'LAYLAK', 'hint': "Bahor xabarchisi", 'emoji': '🦢'},
    ],
  },
  // 29 — Musiqa
  {
    'words': [
      {'word': 'DUTOR', 'hint': "Ikki torli musiqa asbobi", 'emoji': '🎸'},
      {'word': 'DOIRA', 'hint': 'Zarb asbobi', 'emoji': '🥁'},
      {'word': 'RUBOB', 'hint': "O'zbek milliy asbobi", 'emoji': '🪕'},
    ],
  },
  // 30 — Tabiat III
  {
    'words': [
      {'word': 'GULZOR', 'hint': "Gullar bog'i", 'emoji': '🌺'},
      {'word': 'DARAXT', 'hint': 'Tanasi bor o\'simlik', 'emoji': '🌳'},
      {'word': 'BARGLAR', 'hint': "Daraxt bezagi", 'emoji': '🍃'},
    ],
  },
];
