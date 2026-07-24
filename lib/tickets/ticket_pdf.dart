import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<List<int>> buildTicketPdf(Map<String, dynamic> ticket) async {
  final pdf = pw.Document();
  final seats = (ticket['seat_numbers'] as List).join(', ');
  final qrData = {
    'booking_ref': ticket['booking_ref'],
    'schedule_id': ticket['schedule_id'],
    'seats': ticket['seat_numbers'],
    'contact_person': ticket['contact_person'],
    'payment_status': ticket['payment_status'],
  }.toString();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(28),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.indigo900, width: 2),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CaWil',
                        style: pw.TextStyle(
                          fontSize: 30,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo900,
                        ),
                      ),
                      pw.Text(
                        'Bus Ticket',
                        style: const pw.TextStyle(
                          fontSize: 15,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.green600,
                    ),
                    child: pw.Text(
                      ticket['payment_status'].toString().toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _field('Booking Ref', ticket['booking_ref']),
                          _field('Contact Person', ticket['contact_person']),
                          _field('Phone', ticket['phone']),
                          _field('Route',
                              '${ticket['origin']} to ${ticket['destination']}'),
                          _field('Bus', ticket['bus_number']),
                          _field('Departure', ticket['departure_time']),
                          _field('Report Time', ticket['report_time']),
                          _field('Seats', seats),
                          _field('Total Paid',
                              '${ticket['currency']} ${ticket['total_price']}'),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 24),
                    pw.Container(
                      width: 145,
                      height: 145,
                      padding: const pw.EdgeInsets.all(8),
                      color: PdfColors.white,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrData,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey500),
              pw.Text(
                'Show this ticket before boarding. The QR code contains the booking reference and seat details.',
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          ),
        );
      },
    ),
  );

  return pdf.save();
}

pw.Widget _field(String label, Object? value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value?.toString() ?? 'N/A',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
}
