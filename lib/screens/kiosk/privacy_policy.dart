import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({Key? key}) : super(key: key);

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
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _buildBody(size),
    );
  }

  Widget _buildBody(Size size) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: BuildBoxShadowContainer(
        circleRadius: 13,
        color: Colors.white,
        margin: EdgeInsets.all(4),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Last updated:',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 16),
            Text(
              'Introduction',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Your privacy is important to us. This privacy policy explains how we collect, use, disclose, and safeguard your information when you use our application.',
            ),
            Divider(),
            Text(
              'Information We Collect',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'We collect the following types of information:',
            ),
            Text(
              '- Personal Data (e.g., name, email address)',
            ),
            Text(
              '- Usage Data (e.g., interaction with the app)',
            ),
            Divider(),
            Text(
              'How We Use Your Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'We use the information we collect in the following ways:',
            ),
            Text(
              '- To provide and maintain our Service',
            ),
            Text(
              '- To notify you about changes to our Service',
            ),
            Text(
              '- To provide customer support',
            ),
            Divider(),
            Text(
              'Disclosure of Your Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'We may share your information with third parties only in the following circumstances:',
            ),
            Text(
              '- With service providers for business purposes',
            ),
            Text(
              '- With law enforcement if required by law',
            ),
            Divider(),
            Text(
              'Security of Your Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'We implement reasonable security measures to protect your information from unauthorized access or disclosure.',
            ),
            Divider(),
            Text(
              'Your Rights',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'You have the right to request access to the personal information we have about you, to correct any inaccuracies, and to request the deletion of your personal data.',
            ),
            Divider(),
            Text(
              'Changes to This Privacy Policy',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'We may update our privacy policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page.',
            ),
            Divider(),
            Text(
              'Contact Us',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'If you have any questions about this Privacy Policy, please contact us via email at support@example.com.',
            ),
          ],
        ),
      ),
    );
  }
}
