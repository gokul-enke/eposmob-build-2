import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_render/pdf_render_widgets.dart';
import 'package:provider/provider.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({Key? key}) : super(key: key);

  @override
  _InvoiceScreenState createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  File? _pdfFile;
  String _status = 'Fetching order details...';
  OrderDetailsModel? _orderDetails;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetailsAndGeneratePDF();
  }

  Future<void> _fetchOrderDetailsAndGeneratePDF() async {
    try {
      await _fetchOrderDetails();
      if (_orderDetails != null) {
        await _generatePDF();
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      debugPrint('Error: $e');
    }
  }

  Future<void> _fetchOrderDetails() async {
    setState(() {
      _status = 'Fetching order details...';
    });

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      String ordersId =
          Provider.of<SalesProvider>(context, listen: false).getOrderId;
      debugPrint(ordersId);
      final response = await SalesProvider().listOrderDetails(
        context,
        ordersId,
        accessToken ?? "",
      );

      if (response["status"] == "success") {
        setState(() {
          _orderDetails = OrderDetailsModel.fromJson(response);
          _status = 'Order details fetched successfully';
        });
      } else {
        setState(() {
          _status = 'Failed to fetch order details';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error fetching order details: $e';
      });
      debugPrint('Error fetching order details: $e');
    }
  }

  Future<void> _generatePDF() async {
    try {
      setState(() {
        _status = 'Generating PDF...';
      });

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  pw.SizedBox(height: 20),
                  _buildAddressSection(),
                  pw.SizedBox(height: 20),
                  _buildInvoiceDetails(),
                  pw.SizedBox(height: 20),
                  _buildItemsTable(),
                  pw.SizedBox(height: 20),
                  _buildTotal(),
                  pw.SizedBox(height: 20),
                  _buildFooter(),
                ],
              ),
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File(
          "${output.path}/order_details_${_orderDetails?.data?.orderNumber ?? 'unknown'}.pdf");
      await file.writeAsBytes(await pdf.save());

      setState(() {
        _pdfFile = file;
        _status = 'PDF generated successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Error generating PDF: $e';
      });
      debugPrint('Error generating PDF: $e');
    }
  }

  pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Order Details',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.Text('(Original for Recipient)',
            style: const pw.TextStyle(fontSize: 14)),
      ],
    );
  }

  pw.Widget _buildAddressSection() {
    final customerDetails = _orderDetails?.data?.customerDetails;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Sold By:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Your Company Name'),
              pw.Text('Your Company Address'),
              pw.Text('Phone: Your Phone'),
              pw.Text('Email: Your Email'),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Customer Details:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Name: ${customerDetails?.name ?? 'N/A'}'),
              pw.Text('Email: ${customerDetails?.email ?? 'N/A'}'),
              pw.Text('Phone: ${customerDetails?.phone ?? 'N/A'}'),
              pw.Text('Customer ID: ${customerDetails?.customerId ?? 'N/A'}'),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildInvoiceDetails() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('PAN NO: Your PAN'),
            pw.Text('GST Registration No: Your GST'),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
                'Order Number: ${_orderDetails?.data?.orderNumber ?? 'N/A'}'),
            pw.Text('Order Date: ${_orderDetails?.data?.orderDate ?? 'N/A'}'),
            pw.Text(
                'Order Status: ${_orderDetails?.data?.orderStatus ?? 'N/A'}'),
            pw.Text('Store ID: ${_orderDetails?.data?.storeId ?? 'N/A'}'),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildItemsTable() {
    final cartItems = _orderDetails?.data?.cart?.cartItems;

    return pw.Table.fromTextArray(
      border: pw.TableBorder.all(),
      cellAlignment: pw.Alignment.centerLeft,
      headerHeight: 25,
      cellHeight: 40,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
      },
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: const pw.TextStyle(),
      headers: ['Item Name', 'Unit Price', 'Quantity', 'Total Price'],
      data: cartItems!
          .map((item) => [
                item.productName ?? 'N/A',
                '${item.unitPrice ?? 0}',
                '${item.quantity ?? 0}',
                item.totalPrice ?? 'N/A',
              ])
          .toList(),
    );
  }

  pw.Widget _buildTotal() {
    final priceSummary = _orderDetails?.data?.priceSummary;
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _buildTotalRow('Subtotal', priceSummary?.subTotal),
          _buildTotalRow('Tax', priceSummary?.totalTax),
          _buildTotalRow('Discount', priceSummary?.discount),
          _buildTotalRow('Net Total', priceSummary?.netTotal, isBold: true),
        ],
      ),
    );
  }

  pw.Widget _buildTotalRow(String label, int? amount, {bool isBold = false}) {
    final style = isBold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null;
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text('${amount ?? 0}', style: style),
      ],
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
            'Payment Status: ${_orderDetails?.data?.paymentStatus ?? 'N/A'}'),
        pw.Text(
            'Delivery Status: ${_orderDetails?.data?.deliveryStatus ?? 'N/A'}'),
        pw.Text('Thank you for your order!'),
      ],
    );
  }

  Future<void> _sharePDF() async {
    if (_pdfFile != null) {
      await Share.shareFiles([_pdfFile!.path],
          text: 'Here is your order details PDF');
    } else {
      debugPrint('PDF file is null, cannot share');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Details PDF')),
      body: Column(
        children: [
          Expanded(
            child: _pdfFile == null
                ? Center(child: Text(_status))
                : PdfViewer.openFile(_pdfFile!.path),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(_status),
                ElevatedButton(
                  onPressed: _pdfFile != null ? _sharePDF : null,
                  child: const Text('Share PDF'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
