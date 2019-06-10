import 'dart:async';

import 'package:briefing/model/article.dart';
import 'package:briefing/model/channel.dart';
import 'package:rxdart/rxdart.dart';

import 'package:http/http.dart' as http;
import 'package:webfeed/webfeed.dart';

import 'package:briefing/database/database.dart';

class ArticleListBloc {
  final _articleListSubject = PublishSubject<List<Article>>();
  List<Article> _articleList = <Article>[];

  Map<String, List<Article>> _cached;

  ArticleListBloc() {
    _cached = Map();
    print("++++++ArticleListBloc");
    _articleListSubject.add(_articleList);
    _fetchDB();
  }

  Stream<List<Article>> get rssItemList => _articleListSubject.stream;

  dispose() {
    _articleListSubject.close();
  }

  void _fetchDB() async {
    print("++++++BLOC ARTICLE ***_fetchDB***");
    var local = await DBProvider.db.getAllArticle().then((list) {
      return list.where((e) => e.isNew()).toList();
    });
    if (local.isNotEmpty) {
      _articleList.addAll(local);
      _articleListSubject.add(_articleList);
    } else {
      _fetchNetwork();
    }
  }

  Future<void> refresh() {
    _fetchNetwork();
    return null;
  }

  _fetchNetwork() async {
    print("++++++BLOC ARTICLE ***_updateRssItemList***");
    List<Channel> channels = await DBProvider.db.getAllStarredChannel();
    channels.forEach((channel) async {
      print("Channel ${channel.toString()}");
      var tmp = await _fetchRssFeed(channel);
      if (tmp.isNotEmpty) {
        _articleList.clear();
        _articleList.addAll(tmp);
        _articleListSubject.add(_articleList);

        tmp.forEach((article) async {
          print('Channel id: ${article.channel.id}');
          int id = await DBProvider.db.insertArticleMap(article);
          print('Article $id inserted');
        });
      }
    });
  }

  Future<List<Article>> _fetchRssFeed(Channel channel) async {
    print("+++++BLOC_ARTICLE _fetchRssItem ${channel.linkRss}");
    if (!_cached.containsKey(channel.linkRss)) {
      final response = await http.get(channel.linkRss);
      if (response.statusCode == 200) {
        var rssFeed = RssFeed.parse(response.body);

        List<RssItem> items = rssFeed.items;
        List<Article> articles = [];

        items.forEach((rssItem) {
          articles.add(Article.fromRssItem(rssItem, channel));
        });
        print('channel.title==: ${rssFeed.title.toString()}');
        _cached[channel.linkRss] = articles;
      } else {
        print('Http Error ${response.statusCode} $channel.linkRss');
      }
      print("not cached ${channel.linkRss}");
    }
    return _cached[channel.linkRss];
  }

  Future<List<Article>> _fetchArticleList() async {
    var channelListStarred =
        channelList.values.where((channel) => channel.starred);
    var allFutureArticleList =
        channelListStarred.map((ag) => _fetchRssFeed(ag));
    final allArticleList = await Future.wait(allFutureArticleList);
    print('Future.wait length: ${allArticleList.length}');
    List<Article> articleList = <Article>[];
    allArticleList.forEach((list) {
      print('list.isEmpty ${list.isEmpty}');
      articleList.addAll(list.where((item) => item.isNew()));
    });
    print('articleRssList length: ${articleList.length}');
    return articleList;
  }

//  List<ArticleRss> prepareItems(String responseBody) {
//    var channel = RssFeed.parse(responseBody);
//    List<RssItem> items = channel.items;
//    List<ArticleRss> articles = [];
//
//    items.forEach((f) {
//      articles.add(ArticleRss.fromParent(f, channel));
//    });
//    return articles;
//  }
}
