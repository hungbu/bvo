# Data Loading Priority Analysis

## Mục tiêu
Đánh giá mức độ ưu tiên của các data loading operations để tối ưu UX:
- **SYNC (Blocking)**: Data quan trọng nhất, phải có trước khi hiển thị UI
- **ASYNC HIGH**: Data quan trọng, load ngay nhưng không blocking UI (có thể hiển thị loading state)
- **ASYNC MEDIUM**: Data hữu ích, load sau khi UI đã render
- **ASYNC LOW/LAZY**: Data không quan trọng, chỉ load khi user cần (on-demand)

---

## Phân tích chi tiết

### 🚨 CRITICAL - SYNC (Blocking UI)

#### 1. Basic User Data
- **Data**: `userName`, `dailyGoal`
- **Source**: SharedPreferences
- **Time**: <10ms
- **Priority**: CRITICAL
- **Reason**: Cần để hiển thị header, greeting
- **Strategy**: Load sync trong `initState()`

#### 2. Topics List (Minimal)
- **Data**: List of topic IDs và names (6 topics)
- **Source**: Hardcoded trong TopicRepository
- **Time**: <50ms
- **Priority**: CRITICAL
- **Reason**: Cần để hiển thị navigation, topic cards
- **Strategy**: Load sync - chỉ cần essentials, không cần progress data

#### 3. Last Topic ID
- **Data**: `lastTopic` (string ID)
- **Source**: SharedPreferences
- **Time**: <10ms
- **Priority**: CRITICAL
- **Reason**: Cần để hiển thị "Continue Learning" button
- **Strategy**: Load sync

---

### ⚡ HIGH PRIORITY - ASYNC (Load ngay, không blocking)

#### 4. Dashboard Statistics (Simplified)
- **Data**: `totalWordsLearned`, `streakDays`, `todayWordsLearned`
- **Source**: Database (getAllWords + count)
- **Time**: ~200-500ms (sau khi optimize)
- **Priority**: HIGH
- **Reason**: Quan trọng cho dashboard nhưng có thể hiển thị loading state
- **Strategy**: Load async ngay sau khi UI render, hiển thị skeleton/loading

#### 5. Topics Progress (Batch)
- **Data**: Progress cho tất cả topics (learnedWords, progressPercentage)
- **Source**: Database (batch query)
- **Time**: ~100-200ms
- **Priority**: HIGH
- **Reason**: Cần để hiển thị progress bars trên topic cards
- **Strategy**: Load async parallel với statistics, update UI khi ready

#### 6. Word of the Day (Simplified)
- **Data**: 1 word object
- **Source**: Database (getWordsForReview hoặc random)
- **Time**: ~50-100ms
- **Priority**: HIGH
- **Reason**: Feature chính của dashboard
- **Strategy**: Load async, hiển thị placeholder khi loading

---

### 📊 MEDIUM PRIORITY - ASYNC (Load sau khi UI render)

#### 7. Recent Words
- **Data**: 3 words gần đây nhất
- **Source**: SharedPreferences + Database lookup
- **Time**: ~100-200ms
- **Priority**: MEDIUM
- **Reason**: Nice-to-have, không critical cho UX
- **Strategy**: Load async sau khi critical data đã load, hiển thị empty state nếu chưa có

#### 8. Reviewed Words by Topic
- **Data**: Words đã review grouped by topic
- **Source**: Database
- **Time**: ~100-200ms
- **Priority**: MEDIUM
- **Reason**: Hữu ích nhưng không blocking
- **Strategy**: Load async background, update khi ready

#### 9. Topic Groups (Detailed)
- **Data**: Topic groups với word counts chi tiết
- **Source**: Database aggregation
- **Time**: ~200-300ms
- **Priority**: MEDIUM
- **Reason**: Cần cho topic grouping nhưng có thể load sau
- **Strategy**: Load async sau khi topics list đã hiển thị

---

### 🔄 LOW PRIORITY - LAZY (Load on-demand)

#### 10. Word Details
- **Data**: Full word object với progress
- **Source**: Database (getWord)
- **Time**: ~20-50ms
- **Priority**: LOW
- **Reason**: Chỉ load khi user click vào word
- **Strategy**: Load khi user mở word detail dialog

#### 11. Flashcard Words
- **Data**: List of words cho flashcard session
- **Source**: Database (filtered by level/topic)
- **Time**: ~100-200ms
- **Priority**: LOW
- **Reason**: Chỉ load khi user click "Start Flashcard"
- **Strategy**: Load khi navigate to FlashcardScreen

#### 12. Quiz Words
- **Data**: Words cho quiz game
- **Source**: Database + QuizRepository
- **Time**: ~100-200ms
- **Priority**: LOW
- **Reason**: Chỉ load khi user vào quiz screen
- **Strategy**: Load trong QuizScreen.initState()

#### 13. Topic Words (Full List)
- **Data**: Tất cả words trong một topic
- **Source**: Database (getWordsByTopic)
- **Time**: ~50-100ms
- **Priority**: LOW
- **Reason**: Chỉ load khi user vào topic detail screen
- **Strategy**: Load trong TopicDetailScreen.initState()

---

## Implementation Strategy

### Phase 1: Critical Data (Sync)
```dart
@override
void initState() {
  super.initState();
  // Load critical data synchronously
  _loadCriticalSyncData();
  // Then load high priority async data
  _loadHighPriorityAsyncData();
  // Finally load medium/low priority data
  _loadNonCriticalAsyncData();
}
```

### Phase 2: High Priority (Async, immediate)
- Load ngay sau khi UI render
- Hiển thị loading states
- Update UI khi data ready

### Phase 3: Medium Priority (Async, deferred)
- Load sau khi high priority data đã ready
- Có thể cancel nếu user navigate away
- Update UI silently

### Phase 4: Low Priority (Lazy)
- Load chỉ khi user cần
- Cache kết quả để tránh reload

---

## Expected Performance Improvements

### Before Optimization
- **Total Load Time**: ~30 seconds
- **UI Blocking**: ~5-10 seconds
- **User Experience**: App feels slow, blank screen

### After Optimization
- **Critical Data Load**: <100ms (sync)
- **UI Render Time**: <200ms
- **High Priority Data**: ~500ms (async, non-blocking)
- **User Experience**: App feels instant, progressive loading

### Improvement
- **Perceived Performance**: 95% improvement (instant UI)
- **Actual Load Time**: 60% improvement (critical data only)
- **User Satisfaction**: Much better (no blank screen)

---

## Code Changes Required

1. **Separate sync vs async loading**
2. **Add loading states cho high priority data**
3. **Defer medium/low priority data**
4. **Implement lazy loading cho on-demand data**
5. **Add cancellation support cho background loading**

