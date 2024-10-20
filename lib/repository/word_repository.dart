// word repository class
import 'package:bvo/model/word.dart';

class WordRepository {
  // get word
  Future<List<Word>> getWordsOfTopic(String topic) async {
    return await getDictionary(topic);
  }

  Future<List<Word>> getDictionary(String topic) async {
    List<dynamic> dictionary = await loadDictionary(topic);
    List<Word> words = dictionary.map((e) => Word.fromJson(e)).toList();
    return words;
  }

  Future<List<dynamic>> loadDictionary(String topic) async {
    dynamic dictionary = [
      {
        'en': 'classroom',
        'vi': 'phòng học',
        'pronunciation': '/ˈklɑːsruːm/',
        'sentence': 'The students were quiet as they entered the classroom.',
        'topic': 'schools'
      },
      {
        'en': 'teacher',
        'vi': 'giáo viên',
        'pronunciation': '/ˈtiːtʃər/',
        'sentence': 'The teacher explained the math problem to the class.',
        'topic': 'schools'
      },
      {
        'en': 'homework',
        'vi': 'bài tập về nhà',
        'pronunciation': '/ˈhoʊmwɜːrk/',
        'sentence': 'I need to finish my homework before dinner.',
        'topic': 'schools'
      },
      {
        'en': 'student',
        'vi': 'học sinh',
        'pronunciation': '/ˈstuːdənt/',
        'sentence': 'Every student in the class passed the test.',
        'topic': 'schools'
      },
      {
        'en': 'principal',
        'vi': 'hiệu trưởng',
        'pronunciation': '/ˈprɪnsəpəl/',
        'sentence': 'The principal gave a speech during the school assembly.',
        'topic': 'schools'
      },
      {
        'en': 'exam',
        'vi': 'bài thi',
        'pronunciation': '/ɪɡˈzæm/',
        'sentence': 'The final exam is scheduled for next week.',
        'topic': 'schools'
      },
      {
        'en': 'subject',
        'vi': 'môn học',
        'pronunciation': '/ˈsʌbdʒɪkt/',
        'sentence': 'My favorite subject is history.',
        'topic': 'schools'
      },
      {
        'en': 'recess',
        'vi': 'giờ ra chơi',
        'pronunciation': '/ˈriːses/',
        'sentence': 'The children ran to the playground during recess.',
        'topic': 'schools'
      },
      {
        'en': 'desk',
        'vi': 'bàn học',
        'pronunciation': '/desk/',
        'sentence': 'I always sit at the front desk in the classroom.',
        'topic': 'schools'
      },
      {
        'en': 'textbook',
        'vi': 'sách giáo khoa',
        'pronunciation': '/ˈtɛkstbʊk/',
        'sentence': 'Please bring your math textbook to class tomorrow.',
        'topic': 'schools'
      },
      {
        'en': 'uniform',
        'vi': 'đồng phục',
        'pronunciation': '/ˈjuːnɪfɔːrm/',
        'sentence': 'All students must wear their school uniform.',
        'topic': 'schools'
      },
      {
        'en': 'library',
        'vi': 'thư viện',
        'pronunciation': '/ˈlaɪbreri/',
        'sentence': 'The school library is open until 5 PM.',
        'topic': 'schools'
      },
      {
        'en': 'chalkboard',
        'vi': 'bảng phấn',
        'pronunciation': '/ˈtʃɔːkbɔːrd/',
        'sentence': 'The teacher wrote the lesson on the chalkboard.',
        'topic': 'schools'
      },
      {
        'en': 'lesson',
        'vi': 'bài học',
        'pronunciation': '/ˈlesn/',
        'sentence': 'Today’s lesson is about the solar system.',
        'topic': 'schools'
      },
      {
        'en': 'grade',
        'vi': 'điểm số',
        'pronunciation': '/ɡreɪd/',
        'sentence': 'I got a good grade on my science project.',
        'topic': 'schools'
      },
      {
        'en': 'notebook',
        'vi': 'vở',
        'pronunciation': '/ˈnoʊtbʊk/',
        'sentence': 'Don’t forget to write the notes in your notebook.',
        'topic': 'schools'
      },
      {
        'en': 'backpack',
        'vi': 'ba lô',
        'pronunciation': '/ˈbækˌpæk/',
        'sentence':
            'He put all his books into his backpack before leaving school.',
        'topic': 'schools'
      },
      {
        'en': 'quiz',
        'vi': 'bài kiểm tra',
        'pronunciation': '/kwɪz/',
        'sentence': 'We have a quiz on vocabulary tomorrow.',
        'topic': 'schools'
      },
      {
        'en': 'schedule',
        'vi': 'thời khóa biểu',
        'pronunciation': '/ˈskɛdʒuːl/',
        'sentence': 'My schedule is very busy this semester.',
        'topic': 'schools'
      },
      {
        'en': 'graduation',
        'vi': 'lễ tốt nghiệp',
        'pronunciation': '/ˌɡrædʒuˈeɪʃn/',
        'sentence': 'We will celebrate our graduation in June.',
        'topic': 'schools'
      }
    ];

    // filter dictionary by topic
    final result = dictionary.where((e) => e['topic'] == topic).toList();

    return result;
  }
}
