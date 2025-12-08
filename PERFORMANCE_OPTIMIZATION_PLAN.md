# Professional Performance Optimization Plan

## Problem Analysis

### Current Performance Issues

1. **Splash Screen Delay**: App takes >1 minute to load despite splash only showing 1.5s
2. **HomeScreen Initialization**: 4 async methods called simultaneously without coordination
3. **Massive Database Queries**: 
   - `_calculateRealStatistics()` loops through ALL 758 words and queries database for EACH word = 758 queries
   - `_loadRecentWords()` loads ALL words then processes SharedPreferences
   - LevelVocabularyLoader queries database for EACH word in file fallback (119 queries for level 1.1)
4. **Sequential Level Loading**: Levels loaded one by one (1.1 → 1.2 → 1.3 → 1.4 → 1.5 → 2.0)
5. **No Performance Monitoring**: No tracking of database queries, async operations, or bottlenecks
6. **No Progress Indicators**: Users see splash screen but no indication of what's loading

### Root Causes

- **N+1 Query Problem**: Multiple individual database queries instead of batch queries
- **Synchronous Blocking**: Heavy operations block UI thread
- **Redundant Data Loading**: Same data loaded multiple times
- **No Lazy Loading**: All data loaded upfront instead of on-demand
- **No Caching Strategy**: Data reloaded unnecessarily
- **No Performance Metrics**: Can't identify bottlenecks

## Solution Plan

### Phase 1: Performance Monitoring Infrastructure

#### 1.1 Create Performance Monitoring Service

**File**: `lib/service/performance_monitor.dart`

**Features**:
- Track database query count and timing
- Track async operation duration
- Track memory usage
- Track frame rendering performance
- Generate performance reports
- Log slow operations (>100ms threshold)

**Key Methods**:
```dart
class PerformanceMonitor {
  static void trackDatabaseQuery(String query, Duration duration);
  static void trackAsyncOperation(String name, Duration duration);
  static void trackMemoryUsage();
  static Map<String, dynamic> getPerformanceReport();
  static void logSlowOperation(String operation, Duration duration);
}
```

#### 1.2 Add Database Query Interceptor

**File**: `lib/repository/dictionary_words_repository.dart`

**Changes**:
- Wrap all database queries with PerformanceMonitor tracking
- Log query count and duration
- Identify slow queries (>50ms)

#### 1.3 Add Async Operation Tracking

**Files**: All service/repository files

**Changes**:
- Wrap critical async operations with performance tracking
- Track operation start/end times
- Log operations taking >100ms

### Phase 2: Optimize Data Loading Strategy

#### 2.1 Optimize HomeScreen._calculateRealStatistics()

**File**: `lib/screen/home_screen.dart`

**Current Problem**: 
- Loads ALL words (758)
- Queries database for EACH word (758 queries)
- Takes ~30-60 seconds

**Solution**:
- Use batch query to get ALL word progress in ONE query
- Use `getWordsByTopicsBatch()` to get all words for target topics
- Calculate statistics from loaded Word objects directly (use `word.reviewCount`)
- Expected: Reduce from 758 queries to 1-2 queries, <1 second

#### 2.2 Optimize HomeScreen._loadRecentWords()

**File**: `lib/screen/home_screen.dart`

**Current Problem**:
- Loads ALL words
- Processes SharedPreferences keys
- Matches words individually

**Solution**:
- Query database directly for words with `lastReviewed` field
- Use single SQL query: `SELECT * FROM words WHERE lastReviewed IS NOT NULL ORDER BY lastReviewed DESC LIMIT 3`
- Expected: Reduce from 758+ operations to 1 query, <100ms

#### 2.3 Optimize LevelVocabularyLoader File Fallback

**File**: `lib/service/level_vocabulary_loader.dart`

**Current Problem**:
- When database query fails, loads from file
- Queries database for EACH word in file (119 queries for 1.1)
- Sequential queries block execution

**Solution**:
- Batch query: Get ALL words from file list in ONE query
- Use `WHERE en IN (...)` with parameterized query
- Fallback to individual queries only for missing words
- Expected: Reduce from 119 queries to 1 query per level

#### 2.4 Parallelize Level Loading

**File**: `lib/service/level_vocabulary_loader.dart`

**Current Problem**:
- Levels loaded sequentially (1.1 → 1.2 → 1.3...)
- Total time = sum of all level load times

**Solution**:
- Load all levels in parallel using `Future.wait()`
- Use batch queries where possible
- Expected: Reduce from sequential sum to max(level load times)

### Phase 3: Implement Lazy Loading

#### 3.1 Defer Non-Critical Data Loading

**File**: `lib/screen/home_screen.dart`

**Changes**:
- Load critical data first (user name, basic stats)
- Defer non-critical data (recent words, word of the day) until after UI renders
- Show UI immediately with loading indicators for deferred data

#### 3.2 Implement Progressive Loading

**File**: `lib/screen/home_screen.dart`

**Changes**:
- Load dashboard data in stages:
  1. User preferences (instant)
  2. Basic statistics (cached or quick query)
  3. Topic list (batch query)
  4. Detailed statistics (background)
  5. Recent words (lazy)

### Phase 4: Add Progress Indicators

#### 4.1 Enhanced Splash Screen

**File**: `lib/screen/splash_screen.dart`

**Changes**:
- Add progress indicator showing loading stages
- Display current loading operation name
- Show percentage complete
- Allow user to skip to main screen after critical data loads

#### 4.2 Loading States in HomeScreen

**File**: `lib/screen/home_screen.dart`

**Changes**:
- Show skeleton loaders for different sections
- Display loading indicators for async operations
- Progressive reveal as data loads

### Phase 5: Database Optimization

#### 5.1 Add Database Indexes

**File**: `lib/repository/dictionary_words_repository.dart`

**Changes**:
- Add index on `topic` column (for `getWordsByTopic`)
- Add index on `en` column (for `getWord`)
- Add index on `lastReviewed` column (for recent words query)
- Add composite index on `(topic, en)` for faster lookups

#### 5.2 Optimize Query Strategies

**File**: `lib/repository/dictionary_words_repository.dart`

**Changes**:
- Use batch queries instead of individual queries
- Implement query result caching
- Use prepared statements for repeated queries

### Phase 6: Caching Strategy

#### 6.1 Implement Smart Caching

**Files**: All service/repository files

**Changes**:
- Cache frequently accessed data (topics, word lists)
- Implement cache invalidation strategy
- Use memory-efficient caching (limit cache size)
- Cache statistics calculations

#### 6.2 Preload Critical Data

**File**: `lib/main.dart`

**Changes**:
- Preload critical data during splash screen
- Cache database connection
- Preload topic list
- Preload user preferences

## Implementation Steps

### Step 1: Create Performance Monitor (Priority: HIGH)
1. Create `PerformanceMonitor` service
2. Add tracking to database repository
3. Add tracking to critical async operations
4. Generate initial performance report

### Step 2: Fix Critical Bottlenecks (Priority: CRITICAL)
1. Optimize `_calculateRealStatistics()` - use batch queries
2. Optimize `_loadRecentWords()` - use direct database query
3. Optimize LevelVocabularyLoader file fallback - batch queries
4. Parallelize level loading

### Step 3: Add Progress Indicators (Priority: HIGH)
1. Enhance splash screen with progress
2. Add loading states to HomeScreen
3. Show operation names during loading

### Step 4: Database Optimization (Priority: MEDIUM)
1. Add database indexes
2. Optimize query strategies
3. Implement query caching

### Step 5: Lazy Loading (Priority: MEDIUM)
1. Defer non-critical data loading
2. Implement progressive loading
3. Add skeleton loaders

### Step 6: Caching Strategy (Priority: LOW)
1. Implement smart caching
2. Preload critical data
3. Cache invalidation strategy

## Expected Results

### Performance Metrics

**Before Optimization**:
- Splash screen: >60 seconds
- Database queries: 1000+ queries on startup
- HomeScreen load: 30-60 seconds
- Level loading: Sequential, ~5-10 seconds total

**After Optimization**:
- Splash screen: <3 seconds (critical data only)
- Database queries: <10 queries on startup
- HomeScreen load: <2 seconds (critical data), progressive loading for rest
- Level loading: Parallel, <2 seconds total

### User Experience

- **Immediate UI**: Users see main screen within 3 seconds
- **Progressive Loading**: Data loads progressively with indicators
- **No Blocking**: UI remains responsive during data loading
- **Clear Feedback**: Users know what's loading and progress

## Monitoring & Maintenance

### Performance Metrics to Track

1. **Startup Time**: Time from app launch to usable UI
2. **Database Query Count**: Total queries per operation
3. **Database Query Duration**: Average and max query times
4. **Memory Usage**: Peak memory during startup
5. **Frame Rate**: UI rendering performance
6. **Slow Operations**: Operations taking >100ms

### Performance Budgets

- **Startup Time**: <3 seconds for critical data
- **Database Queries**: <10 queries on startup
- **Query Duration**: <50ms per query (average)
- **Memory Usage**: <100MB during startup
- **Frame Rate**: >55 FPS during loading

### Continuous Monitoring

- Log performance metrics to file
- Generate performance reports weekly
- Alert on performance regressions
- Track performance trends over time

## Testing Strategy

### Performance Testing

1. **Cold Start Test**: Measure startup time from app launch
2. **Warm Start Test**: Measure startup time after app restart
3. **Database Query Test**: Count and time all database queries
4. **Memory Test**: Monitor memory usage during startup
5. **Frame Rate Test**: Monitor UI rendering performance

### Load Testing

1. Test with large database (139k+ words)
2. Test with slow device (low-end Android)
3. Test with limited memory
4. Test with slow storage (emulated)

### Regression Testing

1. Ensure functionality unchanged after optimization
2. Verify data accuracy after batch queries
3. Test cache invalidation scenarios
4. Test error handling and fallbacks

## Success Criteria

1. ✅ Splash screen shows for <3 seconds
2. ✅ Database queries reduced from 1000+ to <10 on startup
3. ✅ HomeScreen shows UI within 3 seconds
4. ✅ All data loads progressively without blocking UI
5. ✅ Performance monitoring shows all operations <100ms
6. ✅ User can interact with app immediately after splash
7. ✅ No functionality regressions
8. ✅ Memory usage stays within budget

## Risk Mitigation

### Risks

1. **Data Accuracy**: Batch queries might miss edge cases
2. **Cache Staleness**: Cached data might become outdated
3. **Memory Usage**: Caching might increase memory usage
4. **Complexity**: Performance monitoring adds complexity

### Mitigation Strategies

1. **Thorough Testing**: Test all edge cases with batch queries
2. **Cache Invalidation**: Implement proper cache invalidation
3. **Memory Limits**: Set limits on cache size
4. **Documentation**: Document all performance optimizations
5. **Rollback Plan**: Keep old code commented for rollback if needed

