import 'package:flutter/material.dart';

class HomeWidget extends StatelessWidget {
  final List<Map<String, dynamic>> cartItems;
  
  const HomeWidget({super.key, required this.cartItems});


@override
Widget build(BuildContext context) {
  return Column(
    children: [
      // Fixed Top Section - Product Entry
      Material(
        elevation: 4,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: _buildProductEntrySection(),
        ),
      ),
      
      // Flexible Middle Section with Proper Scroll
      Flexible(
        child: Container(
          color: Colors.white,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCartItemsSection(),
                      // Empty space if needed
                      if (cartItems.length < 4) 
                        SizedBox(height: (4 - cartItems.length) * 80),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      
      // Fixed Bottom Section - Action Buttons
      Material(
        elevation: 8,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _buildActionButtons(),
        ),
      ),
    ],
  );
}

Widget _buildProductEntrySection() {
  return Column(
    children: [
      Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Barcode',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              keyboardType: TextInputType.text,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Price',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ],
  );
}
 Widget _buildCartItemsSection() {
  final totalAmount = cartItems.fold(0.0, (sum, item) => sum + item['total']);

  return Container(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        const Text(
          'ORDER ITEMS',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cartItems.length,
          itemBuilder: (_, index) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(
                cartItems[index]['name'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${cartItems[index]['quantity']} x ₹${cartItems[index]['price']}',
              ),
              trailing: Text(
                '₹${cartItems[index]['total']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TOTAL:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '₹$totalAmount',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'CLEAR',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.orange),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'SAVE',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'CONFIRM',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}