# 📚 **Data Generation Requirements for Vietnamese English Learning App**

## 🎯 **Project Overview**
Create a comprehensive English vocabulary dataset for Vietnamese learners aged 7+, with **10,000 words** organized by topics and difficulty levels.

## 📋 **Required Files to Generate**

### 1. **`lib/repository/dictionary.dart`** - Main vocabulary data
### 2. **Topic distribution data** - For topic organization

---

## 🏗️ **Data Structure Requirements**

### **dWord Model Structure**
```dart
dWord(
  en: 'classroom',                    // English word
  vi: 'phòng học',                   // Vietnamese translation
  pronunciation: '/ˈklɑːsruːm/',     // IPA pronunciation
  sentence: 'The students were quiet as they entered the classroom.',
  sentenceVi: 'Các học sinh im lặng khi bước vào phòng học.',
  topic: 'schools',                   // Topic identifier
  level: WordLevel.BASIC1,           // Difficulty level
  type: WordType.noun,               // Grammar type
  difficulty: 2,                     // 1-5 scale
  nextReview: DateTime.now().add(Duration(days: 1)),
  isKidFriendly: true,
  mnemonicTip: 'Class (lớp) + room (phòng) = phòng học',
  tags: ['schools', 'basic', 'education', 'learning'],
),
```

### **Required Enums**
```dart
enum WordLevel { BASIC1, BASIC2, BASIC3, ADVANCED1, ADVANCED2, ADVANCED3 }
enum WordType { noun, verb, adjective, adverb, preposition, conjunction, interjection, pronoun, determiner, phrase }
```

---

## 📊 **Word Distribution by Level**

### **BASIC1 (1,500 words)** - Ages 7-9
- **Target**: Fundamental daily vocabulary
- **Topics**: `schools`, `family`, `colors`, `shapes`, `basic_numbers`
- **Difficulty**: 1-2
- **Examples**: cat, dog, red, blue, mother, father, one, two, big, small

### **BASIC2 (1,500 words)** - Ages 9-11  
- **Target**: Expanded daily life vocabulary
- **Topics**: `body`, `food`, `animals`, `weather`, `transportation`
- **Difficulty**: 2-3
- **Examples**: elephant, sandwich, bicycle, cloudy, hospital, playground

### **BASIC3 (2,000 words)** - Ages 11-13
- **Target**: School and social vocabulary
- **Topics**: `classroom`, `examination`, `feelings`, `sports`, `hobbies`
- **Difficulty**: 2-4
- **Examples**: mathematics, friendship, competition, celebration, environment

### **ADVANCED1 (2,000 words)** - Ages 13-15
- **Target**: Academic and formal vocabulary
- **Topics**: `universities`, `school_subjects`, `science`, `technology`
- **Difficulty**: 3-5
- **Examples**: psychology, chemistry, laboratory, experiment, hypothesis

### **ADVANCED2 (1,500 words)** - Ages 15-17
- **Target**: Complex social and professional vocabulary  
- **Topics**: `relationships`, `characteristics`, `career`, `society`
- **Difficulty**: 4-5
- **Examples**: entrepreneur, sophisticated, analytical, communication, leadership

### **ADVANCED3 (1,500 words)** - Ages 17+
- **Target**: Specialized and academic vocabulary
- **Topics**: `appearance`, `psychology`, `philosophy`, `literature`, `business`
- **Difficulty**: 4-5
- **Examples**: entrepreneurship, philosophical, psychological, sophisticated, comprehensive

---

## 🏷️ **Topic Categories & Examples**

### **Education Topics**
- `schools` (BASIC1): classroom, teacher, student, homework, principal
- `examination` (BASIC2): test, quiz, grade, score, pass, fail
- `classroom` (BASIC3): whiteboard, projector, assignment, presentation
- `universities` (ADVANCED1): professor, lecture, semester, thesis, research
- `school_subjects` (ADVANCED1): mathematics, physics, chemistry, biology, literature

### **Family & Social Topics**
- `family` (BASIC1): mother, father, sister, brother, grandmother
- `relationships` (ADVANCED2): friendship, marriage, partnership, colleague
- `characteristics` (ADVANCED2): personality, behavior, attitude, character

### **Physical & Visual Topics**
- `colors` (BASIC1): red, blue, green, yellow, orange, purple
- `shapes` (BASIC1): circle, square, triangle, rectangle, oval
- `body` (BASIC2): head, hand, foot, eye, nose, mouth
- `appearance` (ADVANCED3): elegant, sophisticated, attractive, distinctive

### **Daily Life Topics**
- `food` (BASIC2): apple, banana, rice, bread, water, milk
- `animals` (BASIC2): cat, dog, bird, fish, elephant, lion
- `weather` (BASIC2): sunny, rainy, cloudy, windy, hot, cold
- `transportation` (BASIC2): car, bus, train, bicycle, airplane

### **Academic Topics**
- `science` (ADVANCED1): experiment, hypothesis, theory, research, analysis
- `technology` (ADVANCED1): computer, software, internet, digital, innovation
- `psychology` (ADVANCED3): behavior, cognitive, emotional, mental, therapy
- `business` (ADVANCED3): management, marketing, finance, strategy, profit

---

## 🎯 **Quality Requirements**

### **For Each Word Entry:**

#### ✅ **English Word (en)**
- Use common, practical vocabulary
- Prefer words used in daily life and education
- Avoid archaic or overly technical terms for basic levels

#### ✅ **Vietnamese Translation (vi)**
- Use standard Vietnamese (Northern dialect)
- Provide the most common translation
- For multiple meanings, choose the most relevant for the age group

#### ✅ **IPA Pronunciation**
- Use standard American English IPA
- Include stress marks: `/ˈklɑːsruːm/`
- Verify accuracy with reliable dictionaries

#### ✅ **Example Sentences**
- **English**: Natural, age-appropriate sentences
- **Vietnamese**: Accurate, natural translations
- Use vocabulary suitable for the target age group
- Avoid complex grammar for basic levels

#### ✅ **Mnemonic Tips (mnemonicTip)**
- Help Vietnamese learners remember the word
- Use sound associations: "Cat - 'cát' - con mèo kêu meo meo"
- Use meaning connections: "Class (lớp) + room (phòng) = phòng học"
- Use visual or cultural references when helpful

#### ✅ **Tags**
- Include topic name
- Add level indicator: 'basic' or 'advanced'  
- Add category: 'education', 'family', 'visual', 'physical', etc.
- Add grammar type: 'noun', 'verb', 'adjective'

### **WordType Distribution Guidelines**
- **Nouns**: 40-50% (people, objects, places, concepts)
- **Verbs**: 25-30% (actions, states)
- **Adjectives**: 15-20% (descriptions, qualities)
- **Adverbs**: 5-8% (manner, time, place)
- **Others**: 5-10% (prepositions, conjunctions, etc.)

---

## 📝 **File Format Requirements**

### **File Header**
```dart
import '../model/word.dart';

List<dWord> dictionary = [
  // BASIC1 Level Words (1,500 words)
  // Schools Topic (150-200 words)
  dWord(
    en: 'classroom',
    vi: 'phòng học',
    // ... complete structure
  ),
  
  // Family Topic (150-200 words)
  dWord(
    en: 'mother',
    vi: 'mẹ',
    // ... complete structure
  ),
  
  // Continue for all topics and levels...
];
```

### **Organization Structure**
1. **Group by Level**: BASIC1 → BASIC2 → BASIC3 → ADVANCED1 → ADVANCED2 → ADVANCED3
2. **Group by Topic** within each level
3. **Add comments** for each section
4. **Consistent formatting** and indentation

---

## 🎯 **Topic Distribution Target**

### **BASIC1 Topics (1,500 words)**
- `schools` (200 words)
- `family` (200 words)  
- `colors` (100 words)
- `shapes` (100 words)
- `basic_numbers` (150 words)
- `basic_verbs` (250 words)
- `basic_adjectives` (250 words)
- `basic_nouns` (250 words)

### **BASIC2 Topics (1,500 words)**
- `body` (200 words)
- `food` (300 words)
- `animals` (250 words)
- `weather` (150 words)
- `transportation` (200 words)
- `clothing` (150 words)
- `house` (250 words)

### **BASIC3 Topics (2,000 words)**
- `classroom` (300 words)
- `examination` (200 words)
- `feelings` (250 words)
- `sports` (300 words)
- `hobbies` (250 words)
- `time` (200 words)
- `places` (300 words)
- `actions` (200 words)

### **ADVANCED1 Topics (2,000 words)**
- `universities` (400 words)
- `school_subjects` (400 words)
- `science` (400 words)
- `technology` (400 words)
- `health` (400 words)

### **ADVANCED2 Topics (1,500 words)**
- `relationships` (300 words)
- `characteristics` (300 words)
- `career` (300 words)
- `society` (300 words)
- `culture` (300 words)

### **ADVANCED3 Topics (1,500 words)**
- `appearance` (300 words)
- `psychology` (300 words)
- `philosophy` (300 words)
- `literature` (300 words)
- `business` (300 words)

---

## ⚠️ **Important Guidelines**

### **Age Appropriateness**
- **BASIC levels**: Use simple, concrete concepts
- **ADVANCED levels**: Include abstract concepts and specialized vocabulary
- **All levels**: Ensure content is appropriate for Vietnamese cultural context

### **Vietnamese Learner Considerations**
- Focus on words commonly used in Vietnamese English education
- Include words that appear in Vietnamese English textbooks
- Consider pronunciation difficulties for Vietnamese speakers
- Provide cultural context when needed

### **Quality Assurance**
- Verify all IPA pronunciations
- Ensure Vietnamese translations are accurate
- Check that example sentences are natural
- Validate that mnemonic tips are helpful

### **Consistency Requirements**
- Use consistent formatting throughout
- Follow the exact dWord structure
- Maintain consistent difficulty progression
- Use standardized topic names

---

## 📤 **Deliverable Format**

Please provide:
1. **Complete `dictionary.dart` file** with all 10,000 words
2. **Topic summary document** showing word count per topic
3. **Quality checklist** confirming all requirements are met

### **File Size Estimate**
- Expected file size: ~2-3MB
- Lines of code: ~80,000-100,000 lines
- Ensure proper formatting for readability

---

## 💡 **Success Criteria**

✅ **10,000 words total** distributed across all levels  
✅ **Age-appropriate vocabulary** for each level  
✅ **Complete dWord structure** for every entry  
✅ **Accurate Vietnamese translations**  
✅ **Proper IPA pronunciations**  
✅ **Natural example sentences** in both languages  
✅ **Helpful mnemonic tips** for Vietnamese learners  
✅ **Consistent formatting** and organization  
✅ **Cultural appropriateness** for Vietnamese context  
✅ **Educational value** for English learning progression

This dataset will serve as the foundation for a comprehensive English learning app for Vietnamese students, supporting their journey from basic to advanced English proficiency.
