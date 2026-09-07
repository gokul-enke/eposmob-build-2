import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({Key? key}) : super(key: key);

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
        title: Text(
          'legal.terms_and_condition.page_title'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _buildBody(size),
    );
  }

  Widget _buildBody(Size size) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: BuildBoxShadowContainer(
        circleRadius: 13,
        color: Colors.white,
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'legal.terms_and_condition.heading'.tr,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'legal.terms_and_condition.label_last_updated'.tr,
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Text(
              'legal.terms_and_condition.section_introduction'.tr,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your privacy is important to us. This privacy policy explains how we collect, use, disclose, and safeguard your information when you use our application.',
            ),
            const Divider(),
            Text(
              'legal.terms_and_condition.section_info_collect'.tr,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We collect the following types of information:',
            ),
            const Text(
              '- Personal Data (e.g., name, email address)',
            ),
            const Text(
              '- Usage Data (e.g., interaction with the app)',
            ),
            const Divider(),
            Text(
              'legal.terms_and_condition.section_how_use'.tr,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We use the information we collect in the following ways:',
            ),
            const Text(
              '- To provide and maintain our Service',
            ),
            const Text(
              '- To notify you about changes to our Service',
            ),
            const Text(
              '- To provide customer support',
            ),
            const Divider(),
            Text(
              'legal.terms_and_condition.section_disclosure'.tr,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We may share your information with third parties only in the following circumstances:',
            ),
            const Text(
              '- With service providers for business purposes',
            ),
            const Text(
              '- With law enforcement if required by law',
            ),
            const Divider(),
            Text(
              'legal.terms_and_condition.section_security'.tr,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We implement reasonable security measures to protect your information from unauthorized access or disclosure.',
            ),
            const Divider(),
            Text(
              'legal.terms_and_condition.section_rights'.tr,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have the right to request access to the personal information we have about you, to correct any inaccuracies, and to request the deletion of your personal data.',
            ),
            const Divider(),
            Text(
              'legal.terms_and_condition.section_changes'.tr,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We may update our privacy policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page.',
            ),
            const Divider(),
            Text(
              'legal.terms_and_condition.section_contact'.tr,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'If you have any questions about this Privacy Policy, please contact us via email at support@example.com.',
            ),
          ],
        ),
      ),
    );
  }
}
