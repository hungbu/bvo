// make topic repository
// make topic class
// make topic repository

import 'package:bvo/model/topic.dart';

class TopicRepository {
  Future<List<Topic>> getTopics() async {
    List<Topic> topics = getTopicsFromLocal();

    return topics;
  }

  List<Topic> getTopicsFromLocal() {
    List<Topic> topics = [];
    List<String> topicsString = ['schools', 'examination', 'extracurricular', 'school stationery', 'school subjects', 'classroom', 'universities',
      'body', 'appearance', 'characteristics', 'age', 'feelings', 'family', 'relationships', 'colours', 'shapes',
      'numbers', 'ordinal numbers', 'days in a week', 'talking about time', 'measurement', 'direction',
      'living room', 'bedroom', 'bathroom', 'kitchen', 'kitchenware', 'garden', 'garage', 'daily activities',
      'cooking', 'stores', 'games & sports', 'recreation places', 'restaurants', 'music', 'music instruments',
      'movies', 'entertainment', 'events', 'amusement parks', 'fashion', 'clothes', 'make-up', 'accessories',
      'pets', 'zoo animals', 'flowers', 'plants', 'insects', 'food', 'beverages', 'fruits', 'drinks', 'spices',
      'tastes', 'hotels', 'famous landmarks', 'travelling', 'transportation', 'vehicles', 'seasons', 'weather',
      'health', 'illnesses', 'medicine', 'hospital', 'parts of the house', 'furniture', 'electronics', 'cleaning',
      'chores', 'city', 'neighborhood', 'village', 'countryside', 'communication', 'technology', 'computers',
      'internet', 'social media', 'work', 'professions', 'offices', 'jobs', 'money', 'banking', 'business',
      'companies', 'shopping', 'markets', 'vacations', 'holidays', 'festivals', 'art', 'painting', 'sculpture',
      'literature', 'books', 'newspapers', 'magazines', 'science', 'inventions', 'space', 'planets', 'oceans',
      'mountains', 'rivers', 'lakes', 'forests', 'animals', 'wild animals', 'birds', 'fish', 'sea animals', 'reptiles',
      'farm animals', 'tools', 'machines', 'vehicles', 'transportation systems', 'energy', 'electricity', 'minerals',
      'metals', 'plastic', 'recycling', 'environment', 'pollution', 'climate', 'disasters', 'global warming', 'recycling',
      'construction', 'engineering', 'architecture', 'buildings', 'famous structures', 'bridges', 'roads', 'bridges',
      'cities', 'capitals', 'countries', 'cultures', 'languages', 'communication', 'greetings', 'introductions',
      'meeting people', 'asking directions', 'travel plans', 'hotel reservations', 'currency exchange', 'ordering food',
      'reading a menu', 'talking about hobbies', 'shopping for clothes', 'buying groceries', 'asking for help',
      'describing people', 'giving opinions', 'agreeing & disagreeing', 'solving problems', 'making plans', 'phone calls',
      'emails', 'letters', 'inviting people', 'talking about family', 'discussing work', 'planning vacations', 'discussing health',
      'fitness', 'yoga', 'meditation', 'diet', 'healthy eating', 'first aid', 'emergencies', 'police', 'firefighters',
      'doctors', 'dentists', 'pharmacies', 'medications', 'personal hygiene', 'safety', 'security', 'home security',
      'sharing opinions', 'television', 'news', 'advertising', 'careers', 'job interviews', 'resumes', 'work ethics',
      'teamwork', 'time management', 'goals', 'motivation', 'productivity', 'leadership', 'entrepreneurship', 'financial planning']
    ;

    for (int i = 0; i < topicsString.length; i++) {
      topics.add(Topic( topic: topicsString[i], id: i+1));
    }

    return topics;
  }
}