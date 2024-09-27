import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/get_faq.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:provider/provider.dart';

class FaqPage extends StatefulWidget {
  const FaqPage({Key? key}) : super(key: key);

  @override
  FaqPageState createState() => FaqPageState();
}

class FaqPageState extends State<FaqPage> {
  List<FaqData>? faqList; // Store the fetched FAQs
  bool isLoading = true; // Loading state

  @override
  void initState() {
    super.initState();
    fetchFaqData(); // Fetch FAQs
  }

  Future<void> fetchFaqData() async {
    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint("accessToken From AuthModel $accessToken");
      final response = await http.get(Uri.parse(APPUrl.listFaqs), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        FaqModel faqModel = FaqModel.fromJson(jsonResponse);

        setState(() {
          faqList = faqModel.data;
          isLoading = false; // Data fetched, set loading to false
        });
      } else {
        setState(() {
          isLoading = false; // Set loading to false if an error occurs
        });
      }
    } catch (error) {
      debugPrint('Error fetching FAQs: $error');
      setState(() {
        isLoading = false; // Set loading to false on error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Frequently Asked Questions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _buildBody(size),
    );
  }

  Widget _buildBody(Size size) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (faqList == null || faqList!.isEmpty) {
      return const Center(child: Text('No FAQs available.'));
    }

    return BuildBoxShadowContainer(
      circleRadius: 13,
      color: Colors.white,
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        itemCount: faqList?.length ?? 0,
        itemBuilder: (context, index) {
          final faq = faqList![index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ExpansionTile(
              title: Text(faq.question ?? 'No Question'),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(faq.answer,
                          style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
