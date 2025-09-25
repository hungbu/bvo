# 🎨 Topic Visual Status Feature - Dimmed Display for Unlearned Topics

## ✅ **Feature Overview**

### **User Request**:
> "trong topic screen, chỉ những từ topic nào đang học và đã học thì hiển thị bình thường, những topic nào chưa học thì nên để tối hơn 1 chút"

### **Solution Implemented**:
- ✅ **Visual differentiation** between learned and unlearned topics
- ✅ **Dimmed styling** for topics with 0 words learned
- ✅ **Normal styling** for topics with any progress (≥1 word learned)
- ✅ **Consistent theming** across all card elements

---

## 🔍 **Learning Status Logic**

### **Status Determination**:
```dart
// Determine learning status
final isCompleted = progress >= 1.0;          // 100% progress
final isUnlearned = reviewedCount == 0;       // No words learned yet

// reviewedCount = words learned ≥10 times (from UserProgressRepository)
```

### **Visual States**:
```
🟢 Normal Topics    - reviewedCount > 0    (Any learning progress)
🔘 Dimmed Topics    - reviewedCount == 0   (No words learned yet)
✅ Completed Topics - progress >= 1.0      (All words mastered)
```

---

## 🎨 **Visual Changes Applied**

### **1. Card Elevation & Shadow**
```dart
// Before: Uniform elevation for all topics
elevation: 2,
shadowColor: color.withOpacity(0.2),

// After: Different elevation based on learning status
elevation: isUnlearned ? 1 : 2, // Lower elevation for unlearned
shadowColor: isUnlearned 
    ? Colors.grey.withOpacity(0.1)   // Muted shadow
    : color.withOpacity(0.2),        // Normal shadow
```

### **2. Background Gradient**
```dart
// Before: Colorful gradient for all topics
LinearGradient(
  colors: [
    color.withOpacity(0.08),  // Topic-specific color
    color.withOpacity(0.03),
  ],
)

// After: Conditional gradient
gradient: isUnlearned 
    ? LinearGradient(
        colors: [
          Colors.grey.withOpacity(0.05),  // Muted grey
          Colors.grey.withOpacity(0.02),
        ],
      )
    : LinearGradient(
        colors: [
          color.withOpacity(0.08),        // Normal color
          color.withOpacity(0.03),
        ],
      ),
```

### **3. Topic Icon**
```dart
// Before: Bright topic-specific colors
decoration: BoxDecoration(
  color: color.withOpacity(0.15),
),
child: Icon(icon, color: color, size: 16),

// After: Dimmed for unlearned topics
decoration: BoxDecoration(
  color: isUnlearned 
      ? Colors.grey.withOpacity(0.1)    // Muted background
      : color.withOpacity(0.15),        // Normal background
),
child: Icon(
  icon,
  color: isUnlearned 
      ? Colors.grey.withOpacity(0.6)    // Muted icon
      : color,                          // Normal icon
  size: 16,
),
```

### **4. Topic Title**
```dart
// Before: Default text color for all
style: const TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.bold,
  letterSpacing: 0.2,
  height: 1.1,
),

// After: Dimmed text for unlearned
style: TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.bold,
  letterSpacing: 0.2,
  height: 1.1,
  color: isUnlearned 
      ? Colors.grey.withOpacity(0.7)    // Muted text
      : null,                           // Default text color
),
```

### **5. Difficulty Stars**
```dart
// Before: Golden/grey stars for all topics
color: index < stars ? Colors.amber : Colors.grey[400],

// After: Dimmed stars for unlearned topics
color: isUnlearned 
    ? (index < stars ? Colors.grey[400] : Colors.grey[300])  // All grey
    : (index < stars ? Colors.amber : Colors.grey[400]),     // Normal
```

### **6. Time Estimation**
```dart
// Before: Same grey for all topics
Icon(Icons.access_time, size: 10, color: Colors.grey[600]),
Text(estimatedTime, style: TextStyle(fontSize: 9, color: Colors.grey[600])),

// After: Lighter grey for unlearned
Icon(
  Icons.access_time,
  size: 10,
  color: isUnlearned ? Colors.grey[400] : Colors.grey[600],
),
Text(
  estimatedTime,
  style: TextStyle(
    fontSize: 9,
    color: isUnlearned ? Colors.grey[400] : Colors.grey[600],
  ),
),
```

### **7. Progress Text & Percentage**
```dart
// Before: Same colors for all topics
Text('$reviewedCount/$totalWords từ đã thuộc', 
     style: TextStyle(color: Colors.grey[700]))
Text('$progressPercentage%', 
     style: TextStyle(color: color))

// After: Muted colors for unlearned
Text('$reviewedCount/$totalWords từ đã thuộc',
  style: TextStyle(
    color: isUnlearned ? Colors.grey[500] : Colors.grey[700],
  )
)
Text('$progressPercentage%',
  style: TextStyle(
    color: isUnlearned ? Colors.grey[500] : color,
  )
)
```

### **8. Progress Bar**
```dart
// Before: Colorful progress bar for all
LinearProgressIndicator(
  backgroundColor: Colors.grey[300],
  valueColor: AlwaysStoppedAnimation<Color>(color),
)

// After: Dimmed for unlearned topics
LinearProgressIndicator(
  backgroundColor: isUnlearned ? Colors.grey[200] : Colors.grey[300],
  valueColor: AlwaysStoppedAnimation<Color>(
    isUnlearned ? Colors.grey[400]! : color
  ),
)
```

---

## 🎯 **Visual Comparison**

### **Before (All topics same brightness)**:
```
┌─────────────────────────────────────┐
│ 🟦 BUSINESS                         │  ← Same brightness
│ ⭐⭐⭐ • 5 min                       │
│ 0/20 từ đã thuộc            0%     │
│ ▒▒▒▒▒▒▒▒▒▒                        │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ 🟦 SCHOOL                           │  ← Same brightness
│ ⭐⭐⭐ • 3 min                       │
│ 8/15 từ đã thuộc           53%     │
│ ████████▒▒                         │
└─────────────────────────────────────┘
```

### **After (Unlearned topics dimmed)**:
```
┌─────────────────────────────────────┐
│ 🔘 BUSINESS                         │  ← Dimmed (0 progress)
│ ☆☆☆ • 5 min                        │
│ 0/20 từ đã thuộc            0%     │
│ ▁▁▁▁▁▁▁▁▁▁                        │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ 🟦 SCHOOL                           │  ← Normal (has progress)
│ ⭐⭐⭐ • 3 min                       │
│ 8/15 từ đã thuộc           53%     │
│ ████████▒▒                         │
└─────────────────────────────────────┘
```

---

## 🔧 **Code Changes Summary**

### **Files Modified**:
- **`lib/screen/topic_screen.dart`**

### **Key Methods Updated**:
- ✅ **`_buildTopicCard()`** - Added `isUnlearned` status logic
- ✅ **`_buildDifficultyStars()`** - Added `isUnlearned` parameter for dimmed stars
- ✅ **Card styling** - Conditional elevation, shadow, gradient
- ✅ **All text elements** - Conditional color based on learning status
- ✅ **Progress indicators** - Dimmed colors for unlearned topics

### **Status Logic**:
```dart
final isCompleted = progress >= 1.0;          // 100% complete
final isUnlearned = reviewedCount == 0;       // No learning yet
// reviewedCount comes from UserProgressRepository (words learned ≥10 times)
```

### **Lint Fixes Applied**:
- ✅ Removed unused `isStarted` variable
- ✅ Removed unused `_getTopicData()` method
- ✅ Removed unreachable `default:` case in switch
- ✅ Removed unused import `topic_configs_repository.dart`

---

## 🎯 **User Experience Impact**

### **Clear Visual Hierarchy**:
1. **✅ Completed Topics** - Bright colors + checkmark icon
2. **🟢 In-Progress Topics** - Normal bright colors + progress bar
3. **🔘 Unlearned Topics** - Dimmed grey tones (subtle but accessible)

### **Benefits**:
- ✅ **Instant recognition** of learning status
- ✅ **Motivation to start** unlearned topics (they look "inactive")
- ✅ **Progress celebration** - completed topics stand out
- ✅ **Clean visual design** - not overwhelming, just subtle dimming
- ✅ **Accessibility maintained** - still readable, just less prominent

### **User Psychology**:
- **Dimmed topics** feel "waiting to be activated" 
- **Normal topics** show active learning progress
- **Bright completed topics** provide sense of achievement

---

## ✅ **Testing Results**

### **Scenarios to Test**:
1. **Topic with 0 words learned** → Should appear dimmed (grey tones)
2. **Topic with 1+ words learned** → Should appear normal (bright colors)
3. **Topic with 100% completion** → Should appear normal + green checkmark
4. **Mixed topic list** → Clear visual distinction between states

### **Expected Behavior**:
```
Topics Display:
🔘 business (0/20)      ← Dimmed grey
🟦 school (8/15)        ← Normal blue  
🟢 family (12/12) ✅    ← Normal green + completed
🔘 travel (0/18)        ← Dimmed grey
🟠 work (3/10)          ← Normal orange
```

---

## 🚀 **Result**

**Perfect visual differentiation implemented!** 

- ✅ **Unlearned topics** are subtly dimmed with grey tones
- ✅ **Active/completed topics** maintain bright, engaging colors  
- ✅ **Consistent theming** across all card elements
- ✅ **Clean code** with proper status logic
- ✅ **User-friendly** design that encourages learning progress

**The topic screen now provides immediate visual feedback about learning progress while maintaining accessibility and aesthetic appeal!** 🎨
