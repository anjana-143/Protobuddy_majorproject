import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:protobuddy/buttonnavbar/CustomBottomNavigationBar.dart';
import 'package:protobuddy/pages/buyandsale/viewwork.dart';
import 'package:protobuddy/utils/constants.dart';

class BuyList extends StatefulWidget {
  const BuyList({Key? key}) : super(key: key);

  @override
  State<BuyList> createState() => _BuyListState();
}

class _BuyListState extends State<BuyList> {
  String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String searchQuery = '';
  List<QueryDocumentSnapshot<Map<String, dynamic>>> recommendedPortfolios = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.arrow_back_ios,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          " Sale",
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              width: 150,
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              searchAndRecommend(searchQuery);
            },
            icon: Icon(Icons.refresh),
            color: Colors.black,
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height,
            margin: EdgeInsets.fromLTRB(20, 20, 20, 50),
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection("protobuddy/data/forSell").snapshots(),
              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
                if (snapshot.hasError) {
                  return Text("Something went wrong");
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.black,
                    ),
                  );
                }

                List<QueryDocumentSnapshot> filteredData = snapshot.data!.docs.where((data) =>
                  data['category'].toLowerCase().contains(searchQuery.toLowerCase()) ||
                  data['description'].toLowerCase().contains(searchQuery.toLowerCase())
                ).toList();


                return ListView.builder(
                  itemCount: filteredData.length,
                  shrinkWrap: true,
                  itemBuilder: (BuildContext context, int index) {
                    QueryDocumentSnapshot data = filteredData[index];

                    return GestureDetector(
                      onTap: () {
                        Get.to(() => ViewWork(
                          work: '${data['work']}',
                          email: '${data['email']}',
                        ));
                        
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 18.0, bottom: 18),
                        child: Material(
                          elevation: 8,
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(226, 232, 240, 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 20.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Image.network(
                                      '${data['work']}',
                                      fit: BoxFit.cover,
                                      height: 100,
                                      width: 100,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 20,
                                  ),
                                  Flexible(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          height: 10,
                                        ),
                                        Text(
                                          '${capitalizeFirstLetter(data['title'])}',
                                          style: TextStyle(
                                            fontSize: 15,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        SizedBox(
                                          height: 10,
                                        ),
                                        Text(
                                          '${capitalizeFirstLetter(data['description'])}',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 1.2,
                                          ),
                                        )
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
            ),
          ),
          Positioned(
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: () {
                Get.toNamed('/sell');
              },
              child: Icon(
                Icons.add,
                color: Colors.black,
              ),
            ),
            bottom: 80,
            right: 10,
          ),
          Positioned(
            child: CustomBottomNavigationBar(
              initialIndex: 2,
            ),
            bottom: 0,
            left: 0,
            right: 0,
          )
        ],
      ),
    );
  }
   
  Future<void> searchAndRecommend(String searchTerm) async {
    try {
      QuerySnapshot portfoliosSnapshot = await FirebaseFirestore.instance.collection("protobuddy/data/forSell").get();

      List<QueryDocumentSnapshot<Map<String, dynamic>>> allPortfolios = portfoliosSnapshot.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();

      if (allPortfolios.isNotEmpty) {
        List<Map<String, dynamic>> similarityScores = allPortfolios.map((otherPortfolio) {
          Map<String, dynamic> portfolioData = otherPortfolio.data() ?? {};
          double similarity = calculateJaccardSimilarity(
            Set<String>.from(portfolioData['description'].toString().split(" ")),
            Set<String>.from(searchTerm.split(" ")),
          );
          return {'portfolio': otherPortfolio, 'similarity': similarity};
        }).toList();

        similarityScores.sort((a, b) => b['similarity'].compareTo(a['similarity']));

        // Recommended portfolios based on content similarity
        recommendedPortfolios = similarityScores
            .map((item) => item['portfolio'] as QueryDocumentSnapshot<Map<String, dynamic>>)
            .toList();

        setState(() {}); // Update the UI after getting recommendations
      } else {
        print("No portfolios available");
      }
    } catch (error) {
      // Handle error
      print("Error occurred: $error");
    }
  }

  double calculateJaccardSimilarity(Set<String> portfolio1, Set<String> portfolio2) {
    final intersectionSize = portfolio1.intersection(portfolio2).length;
    final unionSize = portfolio1.union(portfolio2).length;

    return unionSize == 0 ? 0 : intersectionSize / unionSize;
  }
}
