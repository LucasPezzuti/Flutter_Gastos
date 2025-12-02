import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/category.dart';

/// Servicio para exportar datos de gastos a diferentes formatos
class ExportService {
  
  /// Exporta gastos a formato CSV
  static String exportToCSV(List<Expense> expenses, Map<int, Category> categories) {
    final List<List<String>> rows = [];
    
    // Headers
    rows.add([
      'Fecha',
      'Descripción', 
      'Monto',
      'Categoría',
      'Es Tarjeta de Crédito',
      'Cuota Actual',
      'Total Cuotas',
      'Está Pagada'
    ]);
    
    // Data rows
    for (final expense in expenses) {
      final category = categories[expense.categoryId];
      rows.add([
        DateFormat('dd/MM/yyyy').format(expense.date),
        expense.description,
        expense.amount.toString(),
        category?.name ?? 'Sin categoría',
        expense.isCreditCard ? 'Sí' : 'No',
        expense.currentInstallment?.toString() ?? '',
        expense.totalInstallments?.toString() ?? '',
        expense.isPaid ? 'Sí' : 'No',
      ]);
    }
    
    return const ListToCsvConverter().convert(rows);
  }
  
  /// Genera un reporte PDF de gastos
  static Future<Uint8List> generatePDFReport({
    required List<Expense> expenses,
    required Map<int, Category> categories,
    required String title,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();
    
    // Calcular estadísticas
    final totalAmount = expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
    final regularExpenses = expenses.where((e) => !e.isCreditCard).toList();
    final creditCardExpenses = expenses.where((e) => e.isCreditCard).toList();
    final paidCreditExpenses = creditCardExpenses.where((e) => e.isPaid).toList();
    
    // Estadísticas por categoría
    final Map<String, double> categoryTotals = {};
    final Map<String, int> categoryCount = {};
    
    for (final expense in expenses) {
      final categoryName = categories[expense.categoryId]?.name ?? 'Sin categoría';
      categoryTotals[categoryName] = (categoryTotals[categoryName] ?? 0) + expense.amount;
      categoryCount[categoryName] = (categoryCount[categoryName] ?? 0) + 1;
    }
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Título
            pw.Header(
              level: 0,
              child: pw.Text(
                title,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Período (si se especifica)
            if (startDate != null && endDate != null)
              pw.Text(
                'Período: ${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
                style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic),
              ),
            
            pw.SizedBox(height: 20),
            
            // Resumen ejecutivo
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Resumen Ejecutivo',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text('Total de gastos: ${expenses.length}'),
                  pw.Text('Monto total: \$${NumberFormat('#,##0.00').format(totalAmount)}'),
                  pw.Text('Gastos regulares: ${regularExpenses.length}'),
                  pw.Text('Cuotas de tarjeta: ${creditCardExpenses.length}'),
                  pw.Text('Cuotas pagadas: ${paidCreditExpenses.length}'),
                  pw.Text('Promedio por gasto: \$${NumberFormat('#,##0.00').format(totalAmount / expenses.length)}'),
                ],
              ),
            ),
            
            pw.SizedBox(height: 30),
            
            // Resumen por categorías
            pw.Text(
              'Resumen por Categorías',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            
            pw.SizedBox(height: 10),
            
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Categoría', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Cantidad', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Porcentaje', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...categoryTotals.entries.map((entry) {
                  final percentage = (entry.value / totalAmount * 100);
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(entry.key),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${categoryCount[entry.key] ?? 0}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('\$${NumberFormat('#,##0.00').format(entry.value)}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${percentage.toStringAsFixed(1)}%'),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
            
            pw.SizedBox(height: 30),
            
            // Detalle de gastos
            pw.Text(
              'Detalle de Gastos',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            
            pw.SizedBox(height: 10),
            
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Fecha', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Descripción', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Monto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Categoría', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Estado', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                  ],
                ),
                ...expenses.map((expense) {
                  final category = categories[expense.categoryId];
                  String status = '';
                  if (expense.isCreditCard) {
                    status = 'Cuota ${expense.currentInstallment}/${expense.totalInstallments}';
                    if (expense.isPaid) status += ' (Pagada)';
                  } else {
                    status = 'Regular';
                  }
                  
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(DateFormat('dd/MM/yy').format(expense.date), style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(expense.description.length > 30 ? '${expense.description.substring(0, 30)}...' : expense.description, style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('\$${NumberFormat('#,##0').format(expense.amount)}', style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(category?.name ?? 'Sin categoría', style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(status, style: const pw.TextStyle(fontSize: 8)),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ];
        },
      ),
    );
    
    return pdf.save();
  }
  
  /// Descarga un archivo en web o guarda en móvil
  static Future<bool> downloadFile({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
  }) async {
    try {
      if (kIsWeb) {
        // En web usar printing para abrir el archivo
        if (fileName.endsWith('.pdf')) {
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => bytes,
            name: fileName,
          );
        } else {
          // Para CSV u otros archivos en web, usamos download del navegador
          await Printing.sharePdf(
            bytes: bytes,
            filename: fileName,
          );
        }
      } else {
        // En móvil usar printing para compartir/guardar
        await Printing.sharePdf(
          bytes: bytes,
          filename: fileName,
        );
      }
      
      return true;
    } catch (e) {
      print('Error descargando archivo: $e');
      return false;
    }
  }
}