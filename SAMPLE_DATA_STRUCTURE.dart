// 📋 **SAMPLE DATA STRUCTURE** - For AI Reference
// This file shows the exact format and examples for data generation

import '../model/word.dart';

List<dWord> dictionary = [
  // ==========================================
  // BASIC1 LEVEL - Ages 7-9 (1,500 words)
  // ==========================================
  
  // Schools Topic (200 words) - BASIC1
  dWord(
    en: 'classroom',
    vi: 'phòng học',
    pronunciation: '/ˈklɑːsruːm/',
    sentence: 'The students were quiet as they entered the classroom.',
    sentenceVi: 'Các học sinh im lặng khi bước vào phòng học.',
    topic: 'schools',
    level: WordLevel.BASIC1,
    type: WordType.noun,
    difficulty: 2,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Class (lớp) + room (phòng) = phòng học',
    tags: ['schools', 'basic', 'education', 'learning'],
  ),
  dWord(
    en: 'teacher',
    vi: 'giáo viên',
    pronunciation: '/ˈtiːtʃər/',
    sentence: 'The teacher explained the math problem to the class.',
    sentenceVi: 'Giáo viên giải thích bài toán cho lớp.',
    topic: 'schools',
    level: WordLevel.BASIC1,
    type: WordType.noun,
    difficulty: 1,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Teacher - "ti-chơ" - người dạy học',
    tags: ['schools', 'basic', 'education', 'people'],
  ),
  dWord(
    en: 'student',
    vi: 'học sinh',
    pronunciation: '/ˈstuːdənt/',
    sentence: 'Every student in the class passed the test.',
    sentenceVi: 'Mọi học sinh trong lớp đều vượt qua bài kiểm tra.',
    topic: 'schools',
    level: WordLevel.BASIC1,
    type: WordType.noun,
    difficulty: 1,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Student - "s-tu-đen" - người học',
    tags: ['schools', 'basic', 'education', 'people'],
  ),

  // Family Topic (200 words) - BASIC1
  dWord(
    en: 'mother',
    vi: 'mẹ',
    pronunciation: '/ˈmʌðər/',
    sentence: 'My mother cooks delicious meals for the family.',
    sentenceVi: 'Mẹ tôi nấu những bữa ăn ngon cho gia đình.',
    topic: 'family',
    level: WordLevel.BASIC1,
    type: WordType.noun,
    difficulty: 1,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Mother - "mơ-đơ" - mẹ yêu thương',
    tags: ['family', 'basic', 'people', 'relationships'],
  ),
  dWord(
    en: 'father',
    vi: 'bố',
    pronunciation: '/ˈfɑːðər/',
    sentence: 'My father works hard to support our family.',
    sentenceVi: 'Bố tôi làm việc chăm chỉ để nuôi gia đình.',
    topic: 'family',
    level: WordLevel.BASIC1,
    type: WordType.noun,
    difficulty: 1,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Father - "phá-đơ" - bố yêu thương',
    tags: ['family', 'basic', 'people', 'relationships'],
  ),

  // Colors Topic (100 words) - BASIC1
  dWord(
    en: 'red',
    vi: 'màu đỏ',
    pronunciation: '/red/',
    sentence: 'The apple is red and sweet.',
    sentenceVi: 'Quả táo màu đỏ và ngọt.',
    topic: 'colors',
    level: WordLevel.BASIC1,
    type: WordType.adjective,
    difficulty: 1,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Red - màu của máu, của tình yêu',
    tags: ['colors', 'basic', 'visual', 'description'],
  ),
  dWord(
    en: 'blue',
    vi: 'màu xanh dương',
    pronunciation: '/bluː/',
    sentence: 'The sky is blue and clear today.',
    sentenceVi: 'Bầu trời xanh và trong vắt hôm nay.',
    topic: 'colors',
    level: WordLevel.BASIC1,
    type: WordType.adjective,
    difficulty: 1,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Blue - màu của bầu trời và biển cả',
    tags: ['colors', 'basic', 'visual', 'description'],
  ),

  // ==========================================
  // BASIC2 LEVEL - Ages 9-11 (1,500 words)
  // ==========================================
  
  // Body Topic (200 words) - BASIC2
  dWord(
    en: 'head',
    vi: 'đầu',
    pronunciation: '/hed/',
    sentence: 'I wear a hat on my head.',
    sentenceVi: 'Tôi đội mũ trên đầu.',
    topic: 'body',
    level: WordLevel.BASIC2,
    type: WordType.noun,
    difficulty: 1,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Head - "hét" - phần đầu của cơ thể',
    tags: ['body', 'basic', 'physical', 'health'],
  ),
  dWord(
    en: 'hand',
    vi: 'tay',
    pronunciation: '/hænd/',
    sentence: 'I write with my right hand.',
    sentenceVi: 'Tôi viết bằng tay phải.',
    topic: 'body',
    level: WordLevel.BASIC2,
    type: WordType.noun,
    difficulty: 1,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Hand - "hăn" - bàn tay để cầm nắm',
    tags: ['body', 'basic', 'physical', 'health'],
  ),

  // Food Topic (300 words) - BASIC2
  dWord(
    en: 'apple',
    vi: 'táo',
    pronunciation: '/ˈæpəl/',
    sentence: 'An apple a day keeps the doctor away.',
    sentenceVi: 'Một quả táo mỗi ngày giúp tránh xa bác sĩ.',
    topic: 'food',
    level: WordLevel.BASIC2,
    type: WordType.noun,
    difficulty: 1,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Apple - "ép-pồ" - quả táo ngon và bổ',
    tags: ['food', 'basic', 'fruit', 'healthy'],
  ),
  dWord(
    en: 'banana',
    vi: 'chuối',
    pronunciation: '/bəˈnænə/',
    sentence: 'Monkeys love to eat bananas.',
    sentenceVi: 'Khỉ thích ăn chuối.',
    topic: 'food',
    level: WordLevel.BASIC2,
    type: WordType.noun,
    difficulty: 2,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Banana - "ba-na-na" - quả chuối vàng',
    tags: ['food', 'basic', 'fruit', 'healthy'],
  ),

  // ==========================================
  // BASIC3 LEVEL - Ages 11-13 (2,000 words)
  // ==========================================
  
  // Examination Topic (200 words) - BASIC3
  dWord(
    en: 'exam',
    vi: 'bài thi',
    pronunciation: '/ɪɡˈzæm/',
    sentence: 'The final exam is scheduled for next week.',
    sentenceVi: 'Bài thi cuối kỳ được lên lịch vào tuần tới.',
    topic: 'examination',
    level: WordLevel.BASIC3,
    type: WordType.noun,
    difficulty: 2,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Exam - "ég-zăm" - bài kiểm tra',
    tags: ['examination', 'basic', 'education', 'testing'],
  ),
  dWord(
    en: 'quiz',
    vi: 'bài kiểm tra ngắn',
    pronunciation: '/kwɪz/',
    sentence: 'We have a math quiz every Friday.',
    sentenceVi: 'Chúng tôi có bài kiểm tra toán mỗi thứ Sáu.',
    topic: 'examination',
    level: WordLevel.BASIC3,
    type: WordType.noun,
    difficulty: 2,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Quiz - "quít" - bài kiểm tra nhanh',
    tags: ['examination', 'basic', 'education', 'testing'],
  ),

  // ==========================================
  // ADVANCED1 LEVEL - Ages 13-15 (2,000 words)
  // ==========================================
  
  // Universities Topic (400 words) - ADVANCED1
  dWord(
    en: 'university',
    vi: 'đại học',
    pronunciation: '/ˌjuːnɪˈvɜːrsəti/',
    sentence: 'She studies medicine at the university.',
    sentenceVi: 'Cô ấy học y khoa tại đại học.',
    topic: 'universities',
    level: WordLevel.ADVANCED1,
    type: WordType.noun,
    difficulty: 4,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'University - trường đại học cao cấp',
    tags: ['universities', 'advanced', 'education', 'higher-learning'],
  ),
  dWord(
    en: 'professor',
    vi: 'giáo sư',
    pronunciation: '/prəˈfesər/',
    sentence: 'The professor teaches advanced mathematics.',
    sentenceVi: 'Giáo sư dạy toán học nâng cao.',
    topic: 'universities',
    level: WordLevel.ADVANCED1,
    type: WordType.noun,
    difficulty: 4,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Professor - giáo viên cấp cao nhất',
    tags: ['universities', 'advanced', 'education', 'people'],
  ),

  // Science Topic (400 words) - ADVANCED1
  dWord(
    en: 'experiment',
    vi: 'thí nghiệm',
    pronunciation: '/ɪkˈsperɪmənt/',
    sentence: 'The scientist conducted an important experiment.',
    sentenceVi: 'Nhà khoa học đã tiến hành một thí nghiệm quan trọng.',
    topic: 'science',
    level: WordLevel.ADVANCED1,
    type: WordType.noun,
    difficulty: 4,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Experiment - thử nghiệm để tìm hiểu',
    tags: ['science', 'advanced', 'research', 'laboratory'],
  ),

  // ==========================================
  // ADVANCED2 LEVEL - Ages 15-17 (1,500 words)
  // ==========================================
  
  // Relationships Topic (300 words) - ADVANCED2
  dWord(
    en: 'friendship',
    vi: 'tình bạn',
    pronunciation: '/ˈfrendʃɪp/',
    sentence: 'Their friendship has lasted for many years.',
    sentenceVi: 'Tình bạn của họ đã kéo dài nhiều năm.',
    topic: 'relationships',
    level: WordLevel.ADVANCED2,
    type: WordType.noun,
    difficulty: 3,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Friendship - mối quan hệ bạn bè',
    tags: ['relationships', 'advanced', 'social', 'emotions'],
  ),

  // ==========================================
  // ADVANCED3 LEVEL - Ages 17+ (1,500 words)
  // ==========================================
  
  // Psychology Topic (300 words) - ADVANCED3
  dWord(
    en: 'psychology',
    vi: 'tâm lý học',
    pronunciation: '/saɪˈkɑːlədʒi/',
    sentence: 'Psychology helps us understand human behavior.',
    sentenceVi: 'Tâm lý học giúp chúng ta hiểu hành vi con người.',
    topic: 'psychology',
    level: WordLevel.ADVANCED3,
    type: WordType.noun,
    difficulty: 5,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Psychology - khoa học về tâm lý',
    tags: ['psychology', 'advanced', 'science', 'mind'],
  ),

  // Business Topic (300 words) - ADVANCED3
  dWord(
    en: 'entrepreneur',
    vi: 'doanh nhân',
    pronunciation: '/ˌɑːntrəprəˈnɜːr/',
    sentence: 'The young entrepreneur started her own company.',
    sentenceVi: 'Nữ doanh nhân trẻ đã thành lập công ty riêng.',
    topic: 'business',
    level: WordLevel.ADVANCED3,
    type: WordType.noun,
    difficulty: 5,
    nextReview: DateTime.now().add(Duration(days: 1)),
    isKidFriendly: true,
    mnemonicTip: 'Entrepreneur - người khởi nghiệp kinh doanh',
    tags: ['business', 'advanced', 'career', 'leadership'],
  ),

  // ==========================================
  // CONTINUE PATTERN FOR ALL 10,000 WORDS...
  // ==========================================
  
  /* 
  IMPORTANT NOTES FOR AI:
  
  1. Follow this EXACT structure for all 10,000 words
  2. Maintain consistent formatting and indentation
  3. Use proper Vietnamese diacritics (á, à, ả, ã, ạ, etc.)
  4. Verify IPA pronunciations are accurate
  5. Ensure example sentences are natural and age-appropriate
  6. Create helpful mnemonic tips for Vietnamese learners
  7. Use appropriate tags for each word
  8. Distribute WordType properly (40% nouns, 25% verbs, etc.)
  9. Progress difficulty logically within each level
  10. Group words by topic within each level
  
  WORD COUNT TARGET:
  - BASIC1: 1,500 words
  - BASIC2: 1,500 words  
  - BASIC3: 2,000 words
  - ADVANCED1: 2,000 words
  - ADVANCED2: 1,500 words
  - ADVANCED3: 1,500 words
  TOTAL: 10,000 words
  */
];
