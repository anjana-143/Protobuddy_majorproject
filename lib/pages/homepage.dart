import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:protobuddy/buttonnavbar/CustomBottomNavigationBar.dart';
import 'package:protobuddy/components/profile.dart';
import 'package:protobuddy/database/firebase.dart';
import 'package:protobuddy/models/usermodel.dart';
import 'package:protobuddy/pages/portfolio/portfolio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Debouncer {
  final int milliseconds;
  VoidCallback? action;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  run(VoidCallback action) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  UserModel currentUser = UserModel(
    uid: 'user_uid_here',
    email: 'user_email@example.com',
    fullname: 'User Fullname',
    avatar: 'avatar_url_here',
    user: 'User Preferences',
  );
  List<QueryDocumentSnapshot<Map<String, dynamic>>> portfolioData = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> allPortfolioData = [];
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  final Debouncer _debouncer = Debouncer(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    fetchPortfolios();
  }

  Future<void> fetchPortfolios() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
          .collection("protobuddy/data/portfolio")
          .orderBy('name')
          .get();
      setState(() {
        portfolioData = snapshot.docs;
        allPortfolioData = List.from(portfolioData);
        bubbleSort(portfolioData);
      });
    } catch (error) {
      print("Error fetching portfolios: $error");
    }
  }

  void bubbleSort(List<QueryDocumentSnapshot<Map<String, dynamic>>> arr) {
    int n = arr.length;
    for (int i = 0; i < n - 1; i++) {
      for (int j = 0; j < n - i - 1; j++) {
        String name1 = arr[j]['name'];
        String name2 = arr[j + 1]['name'];
        if (name1.compareTo(name2) > 0) {
          QueryDocumentSnapshot<Map<String, dynamic>> temp = arr[j];
          arr[j] = arr[j + 1];
          arr[j + 1] = temp;
        }
      }
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> recommendPortfolioItems(
      UserModel user, List<QueryDocumentSnapshot<Map<String, dynamic>>> portfolioData) {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> recommendedItems = [];

    for (var item in portfolioData) {
      double similarity = calculateSimilarity(item, user);
      if (similarity > 0.7) {
        recommendedItems.add(item);
      }
    }

    return recommendedItems;
  }

  double calculateSimilarity(QueryDocumentSnapshot<Map<String, dynamic>> item, UserModel user) {
    double addressSimilarity = 0.0;
    double specialitySimilarity = 0.0;
    double titleSimilarity = 0.0;

    String? preferredAddress = user.user;
    String? preferredSpeciality = user.user;
    String? preferredTitle = user.user;

    if (item['address'] == preferredAddress) {
      addressSimilarity = 1.0;
    }

    if (item['speciality'] == preferredSpeciality) {
      specialitySimilarity = 1.0;
    }

    if (item['title'] == preferredTitle) {
      titleSimilarity = 1.0;
    }

    double overallSimilarity = (addressSimilarity + specialitySimilarity + titleSimilarity) / 3.0;
    return overallSimilarity;
  }

  void handleSearch(String query) {
    setState(() {
      searchQuery = query;
    });

    _debouncer.run(() {
      List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredData = [];
      if (query.isNotEmpty) {
        filteredData = allPortfolioData.where((item) {
          String name = item['name'].toLowerCase();
          String title = item['title'].toLowerCase();
          String address = item['address'].toLowerCase();
          // Split the query into individual words
          final queryWords = query.toLowerCase().split(' ');
          // Check if any word in the query matches the name, title, or address
          bool nameMatch = queryWords.any((word) => name.contains(word));
          bool titleMatch = queryWords.any((word) => title.contains(word));
          bool addressMatch = queryWords.any((word) => address.contains(word));
          // Calculate Jaccard similarity for each field
          final nameSimilarity = jaccardSimilarity(name, queryWords);
          final titleSimilarity = jaccardSimilarity(title, queryWords);
          final addressSimilarity = jaccardSimilarity(address, queryWords);
          // Print Jaccard similarity for debugging
          print('Jaccard similarity for ${item['name']} - Name: $nameSimilarity, Title: $titleSimilarity, Address: $addressSimilarity');
          // Return true if any of the fields match any word in the query or have similarity above a threshold
          return nameMatch || titleMatch || addressMatch ||
              nameSimilarity > 0.7 || titleSimilarity > 0.7 || addressSimilarity > 0.7;
        }).toList();
      } else {
        // If the query is empty, show all portfolio items
        filteredData = List.from(allPortfolioData);
      }

      setState(() {
        portfolioData = filteredData;
      });
    });
  }

  double jaccardSimilarity(String text, List<String> queryWords) {
    final textSet = Set.from(text.split(' '));
    final querySet = Set.from(queryWords);
    final intersection = textSet.intersection(querySet).length;
    final union = textSet.union(querySet).length;
    return intersection / union;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: UserProfile(),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
        toolbarHeight: 100,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              "Portfolio's",
              style: TextStyle(
                color: Colors.black,
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: searchController,
                onChanged: handleSearch,
                decoration: InputDecoration(
                  hintText: 'Search by name, title, or address',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: () {
                      searchController.clear();
                      handleSearch('');
                    },
                    icon: Icon(Icons.clear),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Container(
            margin: EdgeInsets.fromLTRB(20, 20, 20, 50),
            child: Column(
              children: [
                if (portfolioData.isEmpty && searchQuery.isNotEmpty)
                  Text(
                    'No Results Found',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: portfolioData.length,
                    itemBuilder: (BuildContext context, index) {
                      QueryDocumentSnapshot<Map<String, dynamic>> data = portfolioData[index];
                      return GestureDetector(
                        onTap: () {
                          Get.to(() => PortfolioDetail(
                            avatar: data['avatar'],
                            description: data['description'],
                            education: data['education'],
                            email: data['email'],
                            experience: data['experience'],
                            name: data['name'],
                            speciality: data['speciality'],
                            work: data['work'],
                            address: data['address'],
                            title: data['title'],
                          ));
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 18.0, bottom: 18),
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(226, 232, 240, 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.5),
                                  spreadRadius: 3,
                                  blurRadius: 2,
                                  offset: const Offset(7, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 20.0),
                              child: Row(
                                children: [
                                  Image.network(
                                    '${data['avatar']}',
                                    fit: BoxFit.cover,
                                    height: 80,
                                    width: 80,
                                  ),
                                  SizedBox(width: 20),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${capitalizeFirstLetter(data['name'])}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        '${capitalizeFirstLetter(data['title'])}',
                                        style: TextStyle(fontSize: 15, letterSpacing: 1.2),
                                      ),
                                      SizedBox(height: 10),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          '${capitalizeFirstLetter(data['address']).length > 15 ? capitalizeFirstLetter(data['address']).substring(0, 15) + '...' : capitalizeFirstLetter(data['address'])}',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            child: CustomBottomNavigationBar(initialIndex: 0),
            bottom: 0,
            left: 0,
            right: 0,
          ),
        ],
      ),
    );
  }

  String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
