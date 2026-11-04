const List<String> darkVibeXSupportedLanguages = <String>[
  'English',
  'Hindi',
  'Arabic',
  'Bengali',
  'Malayalam',
  'Baluchi',
  'Chinese (Simplified)',
  'Chinese (Traditional)',
];

const Set<String> darkVibeXRtlLanguages = <String>{
  'Arabic',
  'Baluchi',
};

bool darkVibeXIsSupportedLanguage(String value) =>
    darkVibeXSupportedLanguages.contains(value.trim());

bool darkVibeXIsRtlLanguage(String value) =>
    darkVibeXRtlLanguages.contains(value.trim());

String darkVibeXText(String language, String key) {
  final normalized = language.trim().toLowerCase();
  final Map<String, String> values;
  switch (normalized) {
    case 'hindi':
      values = _hindi;
      break;
    case 'arabic':
      values = _arabic;
      break;
    case 'bengali':
      values = _bengali;
      break;
    case 'malayalam':
      values = _malayalam;
      break;
    case 'baluchi':
      values = _baluchi;
      break;
    case 'chinese (simplified)':
      values = _chineseSimplified;
      break;
    case 'chinese (traditional)':
      values = _chineseTraditional;
      break;
    default:
      values = _english;
  }
  return values[key] ?? _extended[normalized]?[key] ?? _english[key] ?? key;
}

const Map<String, String> _english = <String, String>{
  'party': 'Party',
  'discover': 'Discover',
  'message': 'Message',
  'mine': 'Mine',
  'follow': 'Follow',
  'fans': 'Fans',
  'charm': 'Charm',
  'wallet': 'Wallet',
  'wealth_level': 'Wealth level',
  'medal_of_honor': 'Medal of Honor',
  'shop': 'Shop',
  'props': 'Props',
  'task': 'Task',
  'host_data': 'Host data',
  'family': 'Family',
  'cp_nest': 'CP Nest',
  'feedback': 'Feedback',
  'setting': 'Setting',
  'message_notification': 'Message notification',
  'bind_account': 'Bind account',
  'language_settings': 'Language settings',
  'about_tinni': 'About DarkVibeX',
  'blocklist': 'Blocklist',
  'privacy_statement': 'Privacy statement',
  'sign_out': 'Sign out',
  'voice': 'Voice',
  'vibration': 'Vibration',
  'floating_room_only': 'Only receive floating screen in the room',
  'car': 'Car',
  'profile': 'Profile',
  'lucky': 'Lucky',
  'ring': 'Ring',
  'profile_background': 'Profile Background',
  'entrance': 'Entrance',
  'bubble': 'Bubble',
  'frame': 'Frame',
  'my_items': 'My items',
  'purchase': 'Purchase',
  'send': 'Send',
  'use': 'Use',
  'using': 'Using',
  'remove': 'Remove',
  'permanent': 'Permanent',
  'family_wallet': 'Family Wallet',
  'daily_check_in': 'Daily Check-in',
  'family_announcement': 'Family Announcement',
  'member_list': 'Member List',
  'family_level': 'Family Level',
  'family_members': 'Family Members',
  'join_requests': 'Join Requests',
  'members': 'Members',
  'create': 'Create',
  'open': 'Open',
  'request_to_join': 'Request to Join',
  'home': 'Home',
  'trends': 'Trends',
};

const Map<String, String> _hindi = <String, String>{
  'party': 'पार्टी',
  'discover': 'खोजें',
  'message': 'संदेश',
  'mine': 'मेरा',
  'follow': 'फॉलो',
  'fans': 'फैन्स',
  'charm': 'चार्म',
  'wallet': 'वॉलेट',
  'wealth_level': 'वेल्थ लेवल',
  'medal_of_honor': 'मेडल ऑफ ऑनर',
  'shop': 'शॉप',
  'props': 'प्रॉप्स',
  'task': 'टास्क',
  'host_data': 'होस्ट डेटा',
  'family': 'फैमिली',
  'cp_nest': 'CP नेस्ट',
  'feedback': 'फीडबैक',
  'setting': 'सेटिंग',
  'message_notification': 'मैसेज नोटिफिकेशन',
  'bind_account': 'अकाउंट लिंक करें',
  'language_settings': 'भाषा सेटिंग',
  'about_tinni': 'DarkVibeX के बारे में',
  'blocklist': 'ब्लॉकलिस्ट',
  'privacy_statement': 'प्राइवेसी स्टेटमेंट',
  'sign_out': 'साइन आउट',
  'voice': 'आवाज़',
  'vibration': 'वाइब्रेशन',
  'floating_room_only': 'फ्लोटिंग स्क्रीन केवल रूम में दिखाएँ',
  'car': 'कार',
  'profile': 'प्रोफाइल',
  'lucky': 'लकी',
  'ring': 'रिंग',
  'profile_background': 'प्रोफाइल बैकग्राउंड',
  'entrance': 'एंट्रेंस',
  'bubble': 'बबल',
  'frame': 'फ्रेम',
  'my_items': 'मेरे आइटम',
  'purchase': 'खरीदें',
  'send': 'भेजें',
  'use': 'लगाएँ',
  'using': 'लगा हुआ',
  'remove': 'हटाएँ',
  'permanent': 'परमानेंट',
  'family_wallet': 'फैमिली वॉलेट',
  'daily_check_in': 'डेली चेक-इन',
  'family_announcement': 'फैमिली घोषणा',
  'member_list': 'मेंबर लिस्ट',
  'family_level': 'फैमिली लेवल',
  'family_members': 'फैमिली मेंबर्स',
  'join_requests': 'जॉइन रिक्वेस्ट',
  'members': 'मेंबर्स',
  'create': 'बनाएँ',
  'open': 'खोलें',
  'request_to_join': 'जॉइन रिक्वेस्ट भेजें',
  'home': 'होम',
  'trends': 'ट्रेंड्स',
};

const Map<String, String> _urdu = <String, String>{
  'party': 'پارٹی',
  'discover': 'تلاش',
  'message': 'پیغام',
  'mine': 'میرا',
  'follow': 'فالو',
  'fans': 'فینز',
  'charm': 'چارم',
  'wallet': 'والیٹ',
  'wealth_level': 'ویلتھ لیول',
  'medal_of_honor': 'میڈل آف آنر',
  'shop': 'شاپ',
  'props': 'پراپس',
  'task': 'ٹاسک',
  'host_data': 'ہوسٹ ڈیٹا',
  'family': 'فیملی',
  'cp_nest': 'CP نیسٹ',
  'feedback': 'فیڈبیک',
  'setting': 'سیٹنگ',
  'message_notification': 'میسج نوٹیفکیشن',
  'bind_account': 'اکاؤنٹ لنک کریں',
  'language_settings': 'زبان کی سیٹنگ',
  'about_tinni': 'DarkVibeX کے بارے میں',
  'blocklist': 'بلاک لسٹ',
  'privacy_statement': 'پرائیویسی اسٹیٹمنٹ',
  'sign_out': 'سائن آؤٹ',
  'voice': 'آواز',
  'vibration': 'وائبریشن',
  'floating_room_only': 'فلوٹنگ اسکرین صرف روم میں دکھائیں',
  'car': 'کار',
  'profile': 'پروفائل',
  'lucky': 'لکی',
  'ring': 'رِنگ',
  'profile_background': 'پروفائل بیک گراؤنڈ',
  'entrance': 'انٹرنس',
  'bubble': 'ببل',
  'frame': 'فریم',
  'my_items': 'میرے آئٹمز',
  'purchase': 'خریدیں',
  'send': 'بھیجیں',
  'use': 'استعمال کریں',
  'using': 'استعمال میں',
  'remove': 'ہٹائیں',
  'permanent': 'مستقل',
  'family_wallet': 'فیملی والیٹ',
  'daily_check_in': 'روزانہ چیک اِن',
  'family_announcement': 'فیملی اعلان',
  'member_list': 'ممبر لسٹ',
  'family_level': 'فیملی لیول',
  'family_members': 'فیملی ممبرز',
  'join_requests': 'جوائن درخواستیں',
  'members': 'ممبرز',
  'create': 'بنائیں',
  'open': 'کھولیں',
  'request_to_join': 'جوائن درخواست بھیجیں',
  'home': 'ہوم',
  'trends': 'ٹرینڈز',
};


const Map<String, String> _arabic = <String, String>{
  'party': 'حفلة',
  'discover': 'اكتشف',
  'message': 'الرسائل',
  'mine': 'حسابي',
  'follow': 'متابَعون',
  'fans': 'المعجبون',
  'charm': 'السحر',
  'wallet': 'المحفظة',
  'wealth_level': 'مستوى الثروة',
  'medal_of_honor': 'وسام الشرف',
  'shop': 'المتجر',
  'props': 'العناصر',
  'task': 'المهام',
  'family': 'العائلة',
  'cp_nest': 'عش CP',
  'feedback': 'الملاحظات',
  'setting': 'الإعدادات',
};

const Map<String, String> _bengali = <String, String>{
  'party': 'পার্টি',
  'discover': 'খুঁজুন',
  'message': 'বার্তা',
  'mine': 'আমার',
  'follow': 'ফলো',
  'fans': 'ফ্যান',
  'charm': 'চার্ম',
  'wallet': 'ওয়ালেট',
  'wealth_level': 'সম্পদ স্তর',
  'medal_of_honor': 'সম্মান পদক',
  'shop': 'শপ',
  'props': 'আইটেম',
  'task': 'টাস্ক',
  'family': 'পরিবার',
  'cp_nest': 'CP নেস্ট',
  'feedback': 'ফিডব্যাক',
  'setting': 'সেটিংস',
};

const Map<String, String> _malayalam = <String, String>{
  'party': 'പാർട്ടി',
  'discover': 'കണ്ടെത്തുക',
  'message': 'സന്ദേശം',
  'mine': 'എന്റെത്',
  'follow': 'ഫോളോ',
  'fans': 'ഫാൻസ്',
  'charm': 'ചാർം',
  'wallet': 'വാലറ്റ്',
  'wealth_level': 'സമ്പത്ത് നില',
  'medal_of_honor': 'ബഹുമതി മെഡൽ',
  'shop': 'ഷോപ്പ്',
  'props': 'ഐറ്റങ്ങൾ',
  'task': 'ടാസ്ക്',
  'family': 'കുടുംബം',
  'cp_nest': 'CP നെസ്റ്റ്',
  'feedback': 'ഫീഡ്ബാക്ക്',
  'setting': 'സെറ്റിംഗ്സ്',
};

const Map<String, String> _filipino = <String, String>{
  'party': 'Party',
  'discover': 'Tuklasin',
  'message': 'Mensahe',
  'mine': 'Akin',
  'follow': 'Sinusundan',
  'fans': 'Mga Fan',
  'charm': 'Charm',
  'wallet': 'Wallet',
  'wealth_level': 'Antas ng Yaman',
  'medal_of_honor': 'Medalya ng Karangalan',
  'shop': 'Tindahan',
  'props': 'Mga Item',
  'task': 'Gawain',
  'family': 'Pamilya',
  'cp_nest': 'CP Nest',
  'feedback': 'Feedback',
  'setting': 'Settings',
};

const Map<String, String> _persian = <String, String>{
  'party': 'پارتی',
  'discover': 'کشف',
  'message': 'پیام',
  'mine': 'من',
  'follow': 'دنبال‌شده',
  'fans': 'طرفداران',
  'charm': 'جذابیت',
  'wallet': 'کیف پول',
  'wealth_level': 'سطح ثروت',
  'medal_of_honor': 'نشان افتخار',
  'shop': 'فروشگاه',
  'props': 'آیتم‌ها',
  'task': 'وظیفه',
  'family': 'خانواده',
  'cp_nest': 'لانه CP',
  'feedback': 'بازخورد',
  'setting': 'تنظیمات',
};

const Map<String, String> _kurdish = <String, String>{
  'party': 'پارتی',
  'discover': 'دۆزینەوە',
  'message': 'پەیام',
  'mine': 'هی من',
  'follow': 'شوێنکەوتن',
  'fans': 'هەواداران',
  'charm': 'جوانی',
  'wallet': 'جزدان',
  'wealth_level': 'ئاستی دەوڵەمەندی',
  'medal_of_honor': 'میداڵی شانازی',
  'shop': 'فرۆشگا',
  'props': 'ئایتمەکان',
  'task': 'ئەرک',
  'family': 'خێزان',
  'cp_nest': 'CP Nest',
  'feedback': 'فیدباک',
  'setting': 'ڕێکخستن',
};

const Map<String, String> _baluchi = <String, String>{
  'party': 'پارٹی',
  'discover': 'دریافت',
  'message': 'پیغام',
  'mine': 'منی',
  'follow': 'دنبال',
  'fans': 'هوادار',
  'charm': 'کشش',
  'wallet': 'والٹ',
  'wealth_level': 'دولت ءِ سطح',
  'medal_of_honor': 'عزت ءِ تمغہ',
  'shop': 'دکان',
  'props': 'آئٹم',
  'task': 'کار',
  'family': 'خاندان',
  'cp_nest': 'CP Nest',
  'feedback': 'فیڈبیک',
  'setting': 'سیٹنگ',
};

const Map<String, String> _chineseSimplified = <String, String>{
  'party': '派对',
  'discover': '发现',
  'message': '消息',
  'mine': '我的',
  'follow': '关注',
  'fans': '粉丝',
  'charm': '魅力',
  'wallet': '钱包',
  'wealth_level': '财富等级',
  'medal_of_honor': '荣誉勋章',
  'shop': '商店',
  'props': '道具',
  'task': '任务',
  'family': '家族',
  'cp_nest': 'CP 小窝',
  'feedback': '反馈',
  'setting': '设置',
};

const Map<String, String> _chineseTraditional = <String, String>{
  'party': '派對',
  'discover': '探索',
  'message': '訊息',
  'mine': '我的',
  'follow': '關注',
  'fans': '粉絲',
  'charm': '魅力',
  'wallet': '錢包',
  'wealth_level': '財富等級',
  'medal_of_honor': '榮譽勳章',
  'shop': '商店',
  'props': '道具',
  'task': '任務',
  'family': '家族',
  'cp_nest': 'CP 小窩',
  'feedback': '意見回饋',
  'setting': '設定',
};

const Map<String, String> _korean = <String, String>{
  'party': '파티',
  'discover': '탐색',
  'message': '메시지',
  'mine': '내 정보',
  'follow': '팔로우',
  'fans': '팬',
  'charm': '매력',
  'wallet': '지갑',
  'wealth_level': '부 레벨',
  'medal_of_honor': '명예 훈장',
  'shop': '상점',
  'props': '아이템',
  'task': '미션',
  'family': '패밀리',
  'cp_nest': 'CP 네스트',
  'feedback': '피드백',
  'setting': '설정',
};


const Map<String, Map<String, String>> _extended = <String, Map<String, String>>{
  'english': {
    'private_chat_alerts':'Private chat and inbox alerts','room_notifications':'Room notifications','room_activity':'Room activity and invitations','notification_sound':'Notification sound','floating_room':'Only receive floating screen in the room','darkvibex_id':'DarkVibeX ID','google_linked':'Google account linked','guest_account':'Guest account','bind_google':'Bind Google account','google_linked_short':'Google linked','google_bind_success':'Google account linked to ID {id}','google_bind_failed':'Google account could not be linked','binding_note':'Binding Google keeps this same DarkVibeX ID and profile.','language_saved':'Language preference saved: {value}','language_save_failed':'Language preference could not be saved','language_note':'This language is saved to your DarkVibeX account. Create ID and Settings use the same language list. User names, room text, chat and numeric IDs are not auto-translated.','about_description':'Social voice rooms, live room controls, messaging, Family, CP, gifts, games, VIP, wallet and profile features.','modules_note':'BD, Agency, Host, Guardian and country-specific modules are intentionally not part of DarkVibeX.','no_blocked_users':'No blocked users','unblock':'Unblock','user':'User','no_props':'No owned props yet','using':'Using','use':'Use','google_bind_title':'Bind account','language_title':'Language settings','about_title':'About DarkVibeX','blocklist_title':'Blocklist','props_title':'Props','shop_title':'Shop','message_title':'Message notification'
  },
  'hindi': {
    'private_chat_alerts':'प्राइवेट चैट और इनबॉक्स अलर्ट','room_notifications':'रूम नोटिफिकेशन','room_activity':'रूम गतिविधि और निमंत्रण','notification_sound':'नोटिफिकेशन की आवाज़','floating_room':'फ्लोटिंग स्क्रीन केवल रूम में दिखाएँ','darkvibex_id':'DarkVibeX ID','google_linked':'Google अकाउंट लिंक है','guest_account':'गेस्ट अकाउंट','bind_google':'Google अकाउंट लिंक करें','google_linked_short':'Google लिंक है','google_bind_success':'Google अकाउंट ID {id} से लिंक हो गया','google_bind_failed':'Google अकाउंट लिंक नहीं हो सका','binding_note':'Google लिंक करने पर यही DarkVibeX ID और प्रोफाइल बनी रहेगी।','language_saved':'भाषा सेटिंग सेव हुई: {value}','language_save_failed':'भाषा सेटिंग सेव नहीं हो सकी','language_note':'यह भाषा आपके DarkVibeX अकाउंट में सेव होती है। यूज़र नाम, रूम टेक्स्ट, चैट और नंबर अपने आप अनुवादित नहीं होते।','about_description':'सोशल वॉइस रूम, लाइव रूम कंट्रोल, मैसेजिंग, फैमिली, CP, गिफ्ट, गेम, VIP, वॉलेट और प्रोफाइल सुविधाएँ।','modules_note':'BD, Agency, Host, Guardian और देश-विशेष मॉड्यूल DarkVibeX का हिस्सा नहीं हैं।','no_blocked_users':'कोई ब्लॉक किया हुआ यूज़र नहीं','unblock':'अनब्लॉक करें','user':'यूज़र','no_props':'अभी कोई प्रॉप्स नहीं हैं','using':'इस्तेमाल में','use':'इस्तेमाल करें','google_bind_title':'अकाउंट लिंक करें','language_title':'भाषा सेटिंग','about_title':'DarkVibeX के बारे में','blocklist_title':'ब्लॉकलिस्ट','props_title':'प्रॉप्स','shop_title':'शॉप','message_title':'मैसेज नोटिफिकेशन'
  },
  'urdu': {
    'private_chat_alerts':'پرائیویٹ چیٹ اور اِن باکس الرٹس','room_notifications':'روم نوٹیفکیشن','room_activity':'روم کی سرگرمیاں اور دعوتیں','notification_sound':'نوٹیفکیشن کی آواز','floating_room':'فلوٹنگ اسکرین صرف روم میں دکھائیں','darkvibex_id':'DarkVibeX ID','google_linked':'Google اکاؤنٹ منسلک ہے','guest_account':'گیسٹ اکاؤنٹ','bind_google':'Google اکاؤنٹ منسلک کریں','google_linked_short':'Google منسلک ہے','google_bind_success':'Google اکاؤنٹ ID {id} سے منسلک ہوگیا','google_bind_failed':'Google اکاؤنٹ منسلک نہیں ہوسکا','binding_note':'Google منسلک کرنے سے یہی DarkVibeX ID اور پروفائل برقرار رہے گی۔','language_saved':'زبان محفوظ ہوگئی: {value}','language_save_failed':'زبان محفوظ نہیں ہوسکی','language_note':'یہ زبان آپ کے DarkVibeX اکاؤنٹ میں محفوظ ہوتی ہے۔ نام، روم متن، چیٹ اور عددی IDs خودکار ترجمہ نہیں ہوتے۔','about_description':'سوشل وائس رومز، لائیو کنٹرول، پیغامات، فیملی، CP، گفٹس، گیمز، VIP، والیٹ اور پروفائل۔','modules_note':'BD، Agency، Host، Guardian اور ملک کے مخصوص ماڈیولز DarkVibeX میں شامل نہیں۔','no_blocked_users':'کوئی بلاک صارف نہیں','unblock':'ان بلاک کریں','user':'صارف','no_props':'ابھی کوئی آئٹم نہیں','using':'استعمال میں','use':'استعمال کریں','google_bind_title':'اکاؤنٹ منسلک کریں','language_title':'زبان کی سیٹنگ','about_title':'DarkVibeX کے بارے میں','blocklist_title':'بلاک لسٹ','props_title':'آئٹمز','shop_title':'شاپ','message_title':'میسج نوٹیفکیشن'
  },
  'arabic': {
    'private_chat_alerts':'تنبيهات المحادثات الخاصة والبريد الوارد','room_notifications':'إشعارات الغرف','room_activity':'نشاط الغرفة والدعوات','notification_sound':'صوت الإشعار','floating_room':'عرض الشاشة العائمة داخل الغرفة فقط','darkvibex_id':'معرّف DarkVibeX','google_linked':'حساب Google مرتبط','guest_account':'حساب ضيف','bind_google':'ربط حساب Google','google_linked_short':'Google مرتبط','google_bind_success':'تم ربط Google بالمعرّف {id}','google_bind_failed':'تعذر ربط حساب Google','binding_note':'ربط Google يحافظ على معرّف DarkVibeX والملف الشخصي نفسيهما.','language_saved':'تم حفظ اللغة: {value}','language_save_failed':'تعذر حفظ اللغة','language_note':'تُحفظ اللغة في حساب DarkVibeX. لا تتم ترجمة الأسماء ونصوص الغرف والمحادثات والمعرّفات تلقائياً.','about_description':'غرف صوتية اجتماعية، تحكم مباشر، رسائل، عائلة، CP، هدايا، ألعاب، VIP، محفظة وملف شخصي.','modules_note':'وحدات BD وAgency وHost وGuardian والوحدات الخاصة بالدول غير متوفرة في DarkVibeX.','no_blocked_users':'لا يوجد مستخدمون محظورون','unblock':'إلغاء الحظر','user':'مستخدم','no_props':'لا توجد عناصر مملوكة','using':'قيد الاستخدام','use':'استخدم','google_bind_title':'ربط الحساب','language_title':'إعدادات اللغة','about_title':'حول DarkVibeX','blocklist_title':'قائمة الحظر','props_title':'العناصر','shop_title':'المتجر','message_title':'إشعارات الرسائل'
  },
  'bengali': {
    'private_chat_alerts':'ব্যক্তিগত চ্যাট ও ইনবক্স সতর্কতা','room_notifications':'রুম নোটিফিকেশন','room_activity':'রুমের কার্যকলাপ ও আমন্ত্রণ','notification_sound':'নোটিফিকেশন শব্দ','floating_room':'শুধু রুমে ফ্লোটিং স্ক্রিন দেখান','darkvibex_id':'DarkVibeX আইডি','google_linked':'Google অ্যাকাউন্ট সংযুক্ত','guest_account':'গেস্ট অ্যাকাউন্ট','bind_google':'Google অ্যাকাউন্ট সংযুক্ত করুন','google_linked_short':'Google সংযুক্ত','google_bind_success':'Google অ্যাকাউন্ট {id} আইডির সঙ্গে যুক্ত হয়েছে','google_bind_failed':'Google অ্যাকাউন্ট যুক্ত করা যায়নি','binding_note':'Google যুক্ত করলে একই DarkVibeX আইডি ও প্রোফাইল থাকবে।','language_saved':'ভাষা সংরক্ষিত: {value}','language_save_failed':'ভাষা সংরক্ষণ করা যায়নি','language_note':'এই ভাষা আপনার DarkVibeX অ্যাকাউন্টে সংরক্ষিত হয়। নাম, রুমের লেখা, চ্যাট ও নম্বর স্বয়ংক্রিয়ভাবে অনুবাদ হয় না।','about_description':'সামাজিক ভয়েস রুম, লাইভ নিয়ন্ত্রণ, মেসেজিং, পরিবার, CP, উপহার, গেম, VIP, ওয়ালেট ও প্রোফাইল।','modules_note':'BD, Agency, Host, Guardian এবং দেশভিত্তিক মডিউল DarkVibeX-এর অংশ নয়।','no_blocked_users':'কোনো ব্লক করা ব্যবহারকারী নেই','unblock':'আনব্লক','user':'ব্যবহারকারী','no_props':'কোনো মালিকানাধীন আইটেম নেই','using':'ব্যবহৃত হচ্ছে','use':'ব্যবহার করুন','google_bind_title':'অ্যাকাউন্ট সংযুক্ত করুন','language_title':'ভাষা সেটিংস','about_title':'DarkVibeX সম্পর্কে','blocklist_title':'ব্লক তালিকা','props_title':'আইটেম','shop_title':'দোকান','message_title':'মেসেজ নোটিফিকেশন'
  },
  'malayalam': {
    'private_chat_alerts':'സ്വകാര്യ ചാറ്റ്, ഇൻബോക്സ് അറിയിപ്പുകൾ','room_notifications':'റൂം അറിയിപ്പുകൾ','room_activity':'റൂം പ്രവർത്തനങ്ങളും ക്ഷണങ്ങളും','notification_sound':'അറിയിപ്പ് ശബ്ദം','floating_room':'റൂമിൽ മാത്രം ഫ്ലോട്ടിംഗ് സ്ക്രീൻ കാണിക്കുക','darkvibex_id':'DarkVibeX ഐഡി','google_linked':'Google അക്കൗണ്ട് ബന്ധിപ്പിച്ചു','guest_account':'ഗസ്റ്റ് അക്കൗണ്ട്','bind_google':'Google അക്കൗണ്ട് ബന്ധിപ്പിക്കുക','google_linked_short':'Google ബന്ധിപ്പിച്ചു','google_bind_success':'Google അക്കൗണ്ട് {id} ഐഡിയുമായി ബന്ധിപ്പിച്ചു','google_bind_failed':'Google അക്കൗണ്ട് ബന്ധിപ്പിക്കാനായില്ല','binding_note':'Google ബന്ധിപ്പിച്ചാലും ഇതേ DarkVibeX ഐഡിയും പ്രൊഫൈലും തുടരും.','language_saved':'ഭാഷ സേവ് ചെയ്തു: {value}','language_save_failed':'ഭാഷ സേവ് ചെയ്യാനായില്ല','language_note':'ഈ ഭാഷ നിങ്ങളുടെ DarkVibeX അക്കൗണ്ടിൽ സേവ് ചെയ്യും. പേരുകൾ, റൂം ടെക്സ്റ്റ്, ചാറ്റ്, നമ്പർ ഐഡികൾ സ്വയം വിവർത്തനം ചെയ്യില്ല.','about_description':'സോഷ്യൽ വോയ്സ് റൂമുകൾ, ലൈവ് നിയന്ത്രണം, സന്ദേശങ്ങൾ, കുടുംബം, CP, സമ്മാനങ്ങൾ, ഗെയിമുകൾ, VIP, വാലറ്റ്, പ്രൊഫൈൽ.','modules_note':'BD, Agency, Host, Guardian, രാജ്യ-നിർദ്ദിഷ്ട മൊഡ്യൂളുകൾ DarkVibeX-ൽ ഉൾപ്പെടുന്നില്ല.','no_blocked_users':'ബ്ലോക്ക് ചെയ്ത ഉപയോക്താക്കളില്ല','unblock':'അൺബ്ലോക്ക്','user':'ഉപയോക്താവ്','no_props':'ഉടമസ്ഥതയിലുള്ള ഇനങ്ങളില്ല','using':'ഉപയോഗിക്കുന്നു','use':'ഉപയോഗിക്കുക','google_bind_title':'അക്കൗണ്ട് ബന്ധിപ്പിക്കുക','language_title':'ഭാഷാ ക്രമീകരണം','about_title':'DarkVibeX കുറിച്ച്','blocklist_title':'ബ്ലോക്ക് ലിസ്റ്റ്','props_title':'ഇനങ്ങൾ','shop_title':'ഷോപ്പ്','message_title':'സന്ദേശ അറിയിപ്പുകൾ'
  },
  'filipino (tagalog)': {
    'private_chat_alerts':'Mga alerto sa pribadong chat at inbox','room_notifications':'Mga notification sa room','room_activity':'Aktibidad at mga imbitasyon sa room','notification_sound':'Tunog ng notification','floating_room':'Ipakita lang ang floating screen sa room','darkvibex_id':'DarkVibeX ID','google_linked':'Naka-link ang Google account','guest_account':'Guest account','bind_google':'I-link ang Google account','google_linked_short':'Naka-link ang Google','google_bind_success':'Naka-link ang Google sa ID {id}','google_bind_failed':'Hindi ma-link ang Google account','binding_note':'Mananatili ang parehong DarkVibeX ID at profile kapag ini-link ang Google.','language_saved':'Na-save ang wika: {value}','language_save_failed':'Hindi na-save ang wika','language_note':'Nase-save ang wikang ito sa iyong DarkVibeX account. Hindi awtomatikong isinasalin ang mga pangalan, room text, chat at numeric ID.','about_description':'Mga social voice room, live controls, messaging, Family, CP, gifts, games, VIP, wallet at profile.','modules_note':'Hindi kasama sa DarkVibeX ang BD, Agency, Host, Guardian at mga module na partikular sa bansa.','no_blocked_users':'Walang naka-block na user','unblock':'I-unblock','user':'User','no_props':'Wala pang pag-aari na props','using':'Ginagamit','use':'Gamitin','google_bind_title':'I-link ang account','language_title':'Mga setting ng wika','about_title':'Tungkol sa DarkVibeX','blocklist_title':'Blocklist','props_title':'Props','shop_title':'Tindahan','message_title':'Mga notification sa mensahe'
  },
  'persian (farsi)': {
    'private_chat_alerts':'هشدارهای گفتگوی خصوصی و صندوق ورودی','room_notifications':'اعلان‌های اتاق','room_activity':'فعالیت‌ها و دعوت‌های اتاق','notification_sound':'صدای اعلان','floating_room':'نمایش صفحه شناور فقط در اتاق','darkvibex_id':'شناسه DarkVibeX','google_linked':'حساب Google متصل است','guest_account':'حساب مهمان','bind_google':'اتصال حساب Google','google_linked_short':'Google متصل است','google_bind_success':'حساب Google به شناسه {id} متصل شد','google_bind_failed':'اتصال حساب Google ناموفق بود','binding_note':'با اتصال Google همین شناسه و نمایه DarkVibeX حفظ می‌شود.','language_saved':'زبان ذخیره شد: {value}','language_save_failed':'ذخیره زبان انجام نشد','language_note':'این زبان در حساب DarkVibeX ذخیره می‌شود. نام‌ها، متن اتاق، گفتگو و شناسه‌های عددی خودکار ترجمه نمی‌شوند.','about_description':'اتاق‌های صوتی اجتماعی، کنترل زنده، پیام‌رسانی، خانواده، CP، هدایا، بازی‌ها، VIP، کیف پول و نمایه.','modules_note':'ماژول‌های BD، Agency، Host، Guardian و ویژه کشورها بخشی از DarkVibeX نیستند.','no_blocked_users':'کاربر مسدودشده‌ای نیست','unblock':'رفع مسدودی','user':'کاربر','no_props':'هنوز آیتمی ندارید','using':'در حال استفاده','use':'استفاده','google_bind_title':'اتصال حساب','language_title':'تنظیمات زبان','about_title':'درباره DarkVibeX','blocklist_title':'فهرست مسدودها','props_title':'آیتم‌ها','shop_title':'فروشگاه','message_title':'اعلان پیام‌ها'
  },
  'kurdish': {
    'private_chat_alerts':'ئاگادارکردنەوەی چاتی تایبەت و سندوقی پەیام','room_notifications':'ئاگادارکردنەوەی ژوور','room_activity':'چالاکی و بانگهێشتەکانی ژوور','notification_sound':'دەنگی ئاگادارکردنەوە','floating_room':'تەنها لە ژووردا شاشەی هەڵواسراو پیشان بدە','darkvibex_id':'ناسنامەی DarkVibeX','google_linked':'هەژماری Google بەستراوەتەوە','guest_account':'هەژماری میوان','bind_google':'هەژماری Google ببەستەوە','google_linked_short':'Google بەستراوە','google_bind_success':'Google بە ناسنامەی {id} بەستراوە','google_bind_failed':'نەتوانرا هەژماری Google ببەسترێتەوە','binding_note':'بە بەستنەوەی Google هەمان ناسنامە و پرۆفایلی DarkVibeX دەمێنێتەوە.','language_saved':'زمان پاشەکەوت کرا: {value}','language_save_failed':'زمان پاشەکەوت نەکرا','language_note':'ئەم زمانە لە هەژماری DarkVibeX پاشەکەوت دەکرێت. ناو، دەقی ژوور، چات و ناسنامە ژمارەییەکان خۆکارانە وەرناگێڕدرێن.','about_description':'ژووری دەنگی کۆمەڵایەتی، کۆنترۆڵی ڕاستەوخۆ، پەیام، خێزان، CP، دیاری، یاری، VIP، جزدان و پرۆفایل.','modules_note':'BD، Agency، Host، Guardian و مۆدیولی تایبەتی وڵاتان بەشی DarkVibeX نین.','no_blocked_users':'هیچ بەکارهێنەرێکی بلۆککراو نییە','unblock':'بلۆک لاببە','user':'بەکارهێنەر','no_props':'هێشتا هیچ ئایتمێکت نییە','using':'بەکاردێت','use':'بەکاربهێنە','google_bind_title':'بەستنەوەی هەژمار','language_title':'ڕێکخستنی زمان','about_title':'دەربارەی DarkVibeX','blocklist_title':'لیستی بلۆک','props_title':'ئایتمەکان','shop_title':'فرۆشگا','message_title':'ئاگادارکردنەوەی پەیام'
  },
  'baluchi': {
    'private_chat_alerts':'نجی چیٹ ءُ اِن باکس ءِ خبر','room_notifications':'روم ءِ نوٹیفکیشن','room_activity':'روم ءِ کار و دعوت','notification_sound':'نوٹیفکیشن ءِ آواز','floating_room':'فلوٹنگ سکرین فقط روم ءَ نشان بدے','darkvibex_id':'DarkVibeX آئی ڈی','google_linked':'Google اکاؤنٹ بندگ بوتگ','guest_account':'مہمان اکاؤنٹ','bind_google':'Google اکاؤنٹ بند کن','google_linked_short':'Google بندگ','google_bind_success':'Google اکاؤنٹ آئی ڈی {id} ءَ بند بوت','google_bind_failed':'Google اکاؤنٹ بند نہ بوت','binding_note':'Google ءَ بند کنیں ہمے DarkVibeX آئی ڈی ءُ پروفائل برقرار بنت۔','language_saved':'زبان محفوظ بوت: {value}','language_save_failed':'زبان محفوظ نہ بوت','language_note':'اے زبان شما ءِ DarkVibeX اکاؤنٹ ءَ محفوظ بیت۔ نام، روم متن، چیٹ ءُ عددی آئی ڈی خودکار ترجمہ نہ بنت۔','about_description':'سماجی وائس روم، لائیو کنٹرول، پیغام، خاندان، CP، گفٹ، گیم، VIP، والٹ ءُ پروفائل۔','modules_note':'BD، Agency، Host، Guardian ءُ ملک مخصوص ماڈیول DarkVibeX ءِ حصہ نہ انت۔','no_blocked_users':'بلاک بوتگیں کاربر نیست','unblock':'بلاک باز کن','user':'کاربر','no_props':'ہنوز ملکیتیں آئٹم نیست','using':'کارمرزگ ءَ انت','use':'کارمرز کن','google_bind_title':'اکاؤنٹ بند کن','language_title':'زبان ءِ سیٹنگ','about_title':'DarkVibeX ءِ باروا','blocklist_title':'بلاک لسٹ','props_title':'آئٹم','shop_title':'دکان','message_title':'پیغام ءِ نوٹیفکیشن'
  },
  'chinese (simplified)': {
    'private_chat_alerts':'私聊和收件箱提醒','room_notifications':'房间通知','room_activity':'房间动态和邀请','notification_sound':'通知声音','floating_room':'仅在房间内接收悬浮屏幕','darkvibex_id':'DarkVibeX ID','google_linked':'Google 账号已关联','guest_account':'访客账号','bind_google':'关联 Google 账号','google_linked_short':'Google 已关联','google_bind_success':'Google 账号已关联到 ID {id}','google_bind_failed':'无法关联 Google 账号','binding_note':'关联 Google 后，当前 DarkVibeX ID 和个人资料保持不变。','language_saved':'语言偏好已保存：{value}','language_save_failed':'无法保存语言偏好','language_note':'此语言会保存到你的 DarkVibeX 账号。用户名、房间文字、聊天和数字 ID 不会自动翻译。','about_description':'社交语音房、实时房间控制、消息、家族、CP、礼物、游戏、VIP、钱包和个人资料。','modules_note':'BD、Agency、Host、Guardian 和国家专属模块不属于 DarkVibeX。','no_blocked_users':'没有已屏蔽用户','unblock':'取消屏蔽','user':'用户','no_props':'暂无拥有的道具','using':'使用中','use':'使用','google_bind_title':'关联账号','language_title':'语言设置','about_title':'关于 DarkVibeX','blocklist_title':'屏蔽名单','props_title':'道具','shop_title':'商店','message_title':'消息通知'
  },
  'chinese (traditional)': {
    'private_chat_alerts':'私人聊天與收件匣提醒','room_notifications':'房間通知','room_activity':'房間動態與邀請','notification_sound':'通知音效','floating_room':'僅在房間內接收浮動畫面','darkvibex_id':'DarkVibeX ID','google_linked':'Google 帳戶已連結','guest_account':'訪客帳戶','bind_google':'連結 Google 帳戶','google_linked_short':'Google 已連結','google_bind_success':'Google 帳戶已連結至 ID {id}','google_bind_failed':'無法連結 Google 帳戶','binding_note':'連結 Google 後，原有 DarkVibeX ID 與個人資料會保持不變。','language_saved':'語言偏好已儲存：{value}','language_save_failed':'無法儲存語言偏好','language_note':'此語言會儲存至你的 DarkVibeX 帳戶。使用者名稱、房間文字、聊天及數字 ID 不會自動翻譯。','about_description':'社交語音房、即時房間控制、訊息、家族、CP、禮物、遊戲、VIP、錢包及個人資料。','modules_note':'BD、Agency、Host、Guardian 及國家專屬模組不屬於 DarkVibeX。','no_blocked_users':'沒有封鎖的使用者','unblock':'解除封鎖','user':'使用者','no_props':'尚無擁有的道具','using':'使用中','use':'使用','google_bind_title':'連結帳戶','language_title':'語言設定','about_title':'關於 DarkVibeX','blocklist_title':'封鎖清單','props_title':'道具','shop_title':'商店','message_title':'訊息通知'
  },
  'korean': {
    'private_chat_alerts':'비공개 채팅 및 받은 편지함 알림','room_notifications':'룸 알림','room_activity':'룸 활동 및 초대','notification_sound':'알림 소리','floating_room':'룸 안에서만 플로팅 화면 받기','darkvibex_id':'DarkVibeX ID','google_linked':'Google 계정 연결됨','guest_account':'게스트 계정','bind_google':'Google 계정 연결','google_linked_short':'Google 연결됨','google_bind_success':'Google 계정이 ID {id}에 연결되었습니다','google_bind_failed':'Google 계정을 연결할 수 없습니다','binding_note':'Google을 연결해도 기존 DarkVibeX ID와 프로필은 유지됩니다.','language_saved':'언어 설정 저장됨: {value}','language_save_failed':'언어 설정을 저장할 수 없습니다','language_note':'이 언어는 DarkVibeX 계정에 저장됩니다. 사용자 이름, 룸 텍스트, 채팅 및 숫자 ID는 자동 번역되지 않습니다.','about_description':'소셜 음성 룸, 실시간 룸 제어, 메시지, 패밀리, CP, 선물, 게임, VIP, 지갑 및 프로필 기능.','modules_note':'BD, Agency, Host, Guardian 및 국가별 모듈은 DarkVibeX에 포함되지 않습니다.','no_blocked_users':'차단된 사용자가 없습니다','unblock':'차단 해제','user':'사용자','no_props':'보유한 아이템이 없습니다','using':'사용 중','use':'사용','google_bind_title':'계정 연결','language_title':'언어 설정','about_title':'DarkVibeX 정보','blocklist_title':'차단 목록','props_title':'아이템','shop_title':'상점','message_title':'메시지 알림'
  },
};
