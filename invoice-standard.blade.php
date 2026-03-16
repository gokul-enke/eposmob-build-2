<!DOCTYPE html>
<html dir="ltr" lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>Tax Invoice</title>
    <style>
        body {
            font-family: 'DejaVu Sans', sans-serif;
            font-size: 10px;
            color: #000;
            margin: 0;
            padding: 0;
            line-height: 1.2;
        }

        .container {
            width: 100%;
            margin-top: 10px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            table-layout: fixed;
        }

        td,
        th {
            padding: 3px 5px;
            vertical-align: top;
            word-wrap: break-word;
            border: 1px solid #000;
        }

        .no-border td {
            border: none;
        }

        .text-center {
            text-align: center;
        }

        .text-right {
            text-align: right;
        }

        .text-left {
            text-align: left;
        }

        .header-section {
            margin-bottom: 10px;
        }

        .header-section td {
            border: none;
            padding: 0;
        }

        .invoice-title {
            font-size: 16px;
            font-weight: bold;
        }

        .metadata-table {
            margin-bottom: 10px;
            border-collapse: collapse;
        }

        .metadata-table td {
            border: 1px solid #000 !important;
        }

        .metadata-header {
            font-size: 9px;
            height: 25px;
            background-color: #fff;
        }

        .metadata-value {
            font-weight: bold;
            font-size: 11px;
            height: 25px;
        }

        .address-header {
            background-color: #f9f9f9;
            font-weight: bold;
            font-size: 13px;
            height: 20px;
        }

        .address-content-table td {
            border: none;
            padding: 2px 5px;
            font-size: 9px;
            white-space: nowrap;
        }

        .address-content-table td.value {
            white-space: normal;
            font-weight: bold;
        }

        .items-table thead th {
            background-color: #f9f9f9;
            font-size: 9px;
            font-weight: bold;
            text-align: center;
        }

        .items-table tbody td {
            height: 30px;
        }

        .arabic {
            direction: rtl;
        }

        .summary-table td {
            border: 1px solid #000;
        }

        .total-row {
            background-color: #f0f0f0;
            font-weight: bold;
        }
    </style>
</head>

<body>
    <div class="container">
        <!-- Top Header: Company Name and Contact -->
        <table style="border: none; margin-bottom: 20px;" class="no-border">
            <tr>
                <!-- Company Details -->
                <td width="50%" style="border: none; padding: 0;">
                    <div style="font-size: 16px; font-weight: bold; color: #000;">{{ $companyDetails['name'] }}</div>
                    <div style="margin-top: 5px; font-size: 12px;">{{ $companyDetails['street'] }}, {{
                        $companyDetails['district'] }}</div>
                    <div style="font-size: 12px;">{{ $companyDetails['city'] }}, {{ $companyDetails['zip'] }}</div>
                    <div style="margin-top: 5px; font-size: 12px;">Email: {{ $companyDetails['email'] }}</div>
                    <div style="font-size: 12px;">Mob: {{ $companyDetails['phone'] }}</div>
                </td>

                <!-- Invoice Title & VAT -->
                <td width="50%" class="text-right" style="border: none; padding: 0;">
                    <div class="invoice-title" style="font-size: 20px;">Tax Invoice</div>
                    <div class="invoice-title arabic" style="font-size: 20px;">فاتورة ضريبية</div>
                    <div style="margin-top: 10px;">
                        <strong style="font-size: 11px;">VAT No: {{ $companyDetails['vat_number'] }}</strong>
                        <div class="arabic" style="font-size: 11px;">الرقم الضريبي</div>
                    </div>
                </td>
            </tr>
        </table>

        <!-- QR and Metadata Wrapper -->
        <table style="border: none; margin-bottom: 10px;" class="no-border">
            <tr>
                <!-- QR Code (Left of Grid) -->


                <!-- Metadata Grid -->
                <td width="80%" style="border: none; padding: 15px 0; vertical-align: bottom;">
                    <table class="metadata-table" style="width: 100%;">
                        <tr class="metadata-header text-center">
                            <td>
                                <div>Invoice Number</div>
                                <div class="arabic">رقم الفاتورة</div>
                            </td>
                            <td>
                                <div>Invoice Date</div>
                                <div class="arabic">تاريخ الفاتورة</div>
                            </td>
                            <td>
                                <div>Invoice Type</div>
                                <div class="arabic">نوع الفاتورة</div>
                            </td>
                        </tr>
                        <tr class="metadata-value text-center">
                            <td>{{ $order->order_number }}</td>
                            <td>{{ $order->order_date }}</td>
                            <td>{{ $order->payment_status == 'paid' ? 'Credit' : 'Cash' }}</td>
                        </tr>
                    </table>
                </td>

                <td width="15%" style="border: none; padding: 0; vertical-align: top;">
                    @if($zatcaEnabled && $qrCode)
                    <img src="{{ $qrCode }}" style="width: 100px; height: 100px;" />
                    @endif
                </td>
            </tr>
        </table>

        <!-- Address Section -->
        <table style="margin-bottom: 10px;">
            <tr>
                <!-- Invoice From -->
                <td width="50%" style="padding: 0;">
                    <table class="no-border">
                        <tr class="address-header">
                            <td class="text-left">Invoice From</td>
                            <td class="text-right arabic">فاتورة من</td>
                        </tr>
                    </table>
                    <table class="address-content-table" style="width: 100%; table-layout: fixed;">
                        <tr>
                            <td width="30%">Name :</td>
                            <td width="40%" class="value">{{ $order->cart->store->name }}</td>
                            <td width="30%" class="text-right arabic">إسم :</td>
                        </tr>
                        <tr>
                            <td>Building No :</td>
                            <td class="value">{{ $companyDetails['building_no'] ?? '' }}</td>
                            <td class="text-right arabic">رقم للبناء :</td>
                        </tr>
                        <tr>
                            <td>Street name :</td>
                            <td class="value">{{ $companyDetails['address'] }}</td>
                            <td class="text-right arabic">اسم الشارع :</td>
                        </tr>
                        <tr>
                            <td>City :</td>
                            <td class="value">{{ $companyDetails['city'] ?? 'Dammam' }}</td>
                            <td class="text-right arabic">مدينة :</td>
                        </tr>
                        <tr>
                            <td>VAT No :</td>
                            <td class="value">{{ $companyDetails['vat_number'] ?? '310071014300003' }}</td>
                            <td class="text-right arabic">رقم الضريبية :</td>
                        </tr>
                        <tr>
                            <td>Account No :</td>
                            <td class="value">{{ $companyDetails['account_no'] ?? '04800000326610 (NCB)' }}</td>
                            <td class="text-right arabic">رقم الحساب :</td>
                        </tr>
                        <tr>
                            <td>IBAN :</td>
                            <td class="value">{{ $companyDetails['iban'] ?? 'SA4910000004800000326610' }}</td>
                            <td class="text-right arabic">ايبن :</td>
                        </tr>
                    </table>
                </td>
                <!-- Invoice To -->
                <td width="50%" style="padding: 0;">
                    <table class="no-border">
                        <tr class="address-header">
                            <td class="text-left">Invoice To</td>
                            <td class="text-right arabic">فاتورة إلى</td>
                        </tr>
                    </table>
                    <table class="address-content-table" style="width: 100%; table-layout: fixed;">
                        <tr>
                            <td width="30%">Name :</td>
                            <td width="40%" class="value">{{ $order->cart->customer->user->name ?? 'N/A' }}</td>
                            <td width="30%" class="text-right arabic">إسم :</td>
                        </tr>
                        @if(!empty($orderPropsArray['CUSTOMER_NAME_AR']))
                        <tr>
                            <td colspan="3" class="text-center arabic" style="font-size: 11px;">{{
                                $orderPropsArray['CUSTOMER_NAME_AR'] }}</td>
                        </tr>
                        @endif
                        <tr>
                            <td>Building No :</td>
                            <td class="value">{{ $orderPropsArray['CUSTOMER_BUILDING_NO'] ?? '' }}</td>
                            <td class="text-right arabic">رقم للبناء :</td>
                        </tr>
                        <tr>
                            <td>Address :</td>
                            <td class="value">{{ $orderPropsArray['CUSTOMER_ADDRESS'] ?? 'N/A' }}</td>
                            <td class="text-right arabic">عنوان :</td>
                        </tr>
                        <tr>
                            <td>City :</td>
                            <td class="value">{{ $orderPropsArray['CUSTOMER_CITY'] ?? 'N/A' }}</td>
                            <td class="text-right arabic">مدينة :</td>
                        </tr>
                        <tr>
                            <td>C.R No :</td>
                            <td class="value">{{ $orderPropsArray['CUSTOMER_CR_NO'] ?? 'N/A' }}</td>
                            <td class="text-right arabic">رقم السجل التجاري :</td>
                        </tr>
                        <tr>
                            <td>VAT No :</td>
                            <td class="value">{{ $orderPropsArray['CUSTOMER_VAT_NO'] ?? 'N/A' }}</td>
                            <td class="text-right arabic">رقم الضريبية :</td>
                        </tr>
                        <tr>
                            <td>Customer No :</td>
                            <td class="value">{{ $order->cart->customer_id }}</td>
                            <td class="text-right arabic">رقم العميل :</td>
                        </tr>
                    </table>
                </td>
            </tr>
        </table>

        <!-- Items Table -->
        <table class="items-table">
            <thead>
                <tr>
                    <th width="5%">S No:</th>
                    <th width="35%">
                        <div>Description</div>
                        <div class="arabic">البيان</div>
                    </th>
                    <th width="10%">
                        <div>Qty</div>
                        <div class="arabic">كمية</div>
                    </th>
                    <th width="10%">
                        <div>Rate</div>
                        <div class="arabic">مجموع</div>
                    </th>
                    <th width="10%">
                        <div>Discount</div>
                        <div class="arabic">خصم</div>
                    </th>
                    <th width="10%">
                        <div>Taxable Amt</div>
                        <div class="arabic">المباغ الخاضع</div>
                    </th>
                    <th width="10%">
                        <div>VAT (15%)</div>
                        <div class="arabic">الضريبية</div>
                    </th>
                    <th width="10%">
                        <div>Total (Inc Vat)</div>
                        <div class="arabic">الأجمالي</div>
                    </th>
                </tr>
            </thead>
            <tbody>
                @foreach ($carts['cart_items'] as $item)
                <tr>
                    <td class="text-center">{{ $loop->iteration }}</td>
                    <td>
                        <div>{{ $item['product_name'] ?? 'N/A' }}</div>
                        <div class="arabic">{{ $item['product_name_ar'] ?? '' }}</div>
                    </td>
                    <td class="text-center">{{ $item['quantity'] }}</td>
                    <td class="text-right">{{ number_format($item['unit_price'], 2) }}</td>
                    <td class="text-right">0.00</td>
                    <td class="text-right">{{ number_format($item['total_price'] - ($item['tax_amount'] ?? 0), 2) }}
                    </td>
                    <td class="text-right">{{ number_format($item['tax_amount'] ?? 0, 2) }}</td>
                    <td class="text-right">{{ number_format($item['total_price'], 2) }}</td>
                </tr>
                @endforeach
                @if(!empty($order->shipping_cost) && $order->shipping_cost > 0)
                @php
                $vatRate = 15;
                $inclusiveAmount = $order->shipping_cost;

                $vatAmount = ($inclusiveAmount * $vatRate) / (100 + $vatRate);
                $baseAmount = $inclusiveAmount - $vatAmount;
                @endphp
                <tr>
                    <td class="text-center">{{ count($carts['cart_items']) + 1 }}</td>
                    <td>
                        <div>Delivery Charge</div>
                        <div class="arabic">رسوم التسليم</div>
                    </td>
                    <td class="text-center">1</td>

                    <td class="text-right">{{ number_format($inclusiveAmount, 3) }}</td>

                    <td class="text-right">0.00</td>
                    <!-- Unit Price (Excluding VAT) -->
                    <td class="text-right">{{ number_format($baseAmount, 3) }}</td>

                    <!-- Tax Rate -->

                    <!-- Tax Amount -->
                    <td class="text-right">{{ number_format($vatAmount, 3) }}</td>

                    <!-- Total Price (Inclusive - like 65.000 in image) -->
                    <td class="text-right">{{ number_format($inclusiveAmount, 3) }}</td>

                </tr>
                @endif
            </tbody>
        </table>

        <!-- Summary and Amount in Words -->
        <table class="no-border" style="margin-top: 10px;">
            <tr>
                <td width="60%">
                    <div style="margin-bottom: 20px;">
                        <strong>Amount in Words:</strong> {{ $amountInWords }}
                    </div>
                    <div style="font-size: 9px;">
                        Delivery Time: {{ $order->created_at }}<br>
                        Payment Method: @foreach($paymentMethods as $method) {{ $method }} @endforeach
                    </div>
                </td>
                <td width="40%" style="padding: 0;">
                    <table class="summary-table">
                        <tr>
                            <td width="60%">Total (Exc VAT)</td>
                            <td width="40%" class="text-right">{{ number_format($carts['price_summary']['grand_total'] -
                                ($carts['price_summary']['tax_total'] ?? 0), 2) }}</td>
                        </tr>
                        <tr>
                            <td>Total VAT</td>
                            <td class="text-right">{{ number_format($carts['price_summary']['tax_total'] ?? 0, 2) }}
                            </td>
                        </tr>
                        @if(!empty($order->shipping_cost) && $order->shipping_cost > 0)
                        <tr>
                            <td>Delivery Charge</td>
                            <td class="text-right">{{ number_format($order->shipping_cost, 2) }}</td>
                        </tr>
                        @endif
                        <tr class="total-row">
                            <td>Total (Inc VAT)</td>
                            <td class="text-right">{{ number_format($order->grand_total, 2) }}</td>
                        </tr>
                    </table>
                </td>
        </table>

        <!-- Signature Section -->
        <table style="margin-top: 50px; border: none;" class="no-border">
            <tr>
                <td width="50%" style="border: none; padding: 0;">
                    <div style="font-weight: bold;">Receiver: ...........................................</div>
                </td>
                <td width="50%" class="text-right" style="border: none; padding: 0;">
                    <div style="font-weight: bold;">Sales Man: ...........................................</div>
                </td>
            </tr>
        </table>
    </div>
</body>

</html>