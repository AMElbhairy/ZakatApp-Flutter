import 'dart:convert';

import 'package:archive/archive.dart';

import '../core/utils/amount_parser.dart';
import '../models/app_state.dart';
import '../models/investment_asset.dart';
import '../models/recurring_transaction.dart';
import '../models/saving.dart';
import '../models/transaction.dart';
import 'app_state_controller.dart';
import 'backup_restore_service.dart';
import 'sync_diagnostics_service.dart';

/// Holds the parsed domain entries from a CSV or Excel file/archive.
class CsvImportResult {
  const CsvImportResult({
    this.transactions = const <Transaction>[],
    this.savings = const <Saving>[],
    this.investments = const <InvestmentAsset>[],
    this.recurringTransactions = const <RecurringTransaction>[],
    this.warnings = const <String>[],
  });

  final List<Transaction> transactions;
  final List<Saving> savings;
  final List<InvestmentAsset> investments;
  final List<RecurringTransaction> recurringTransactions;
  final List<String> warnings;

  int get totalCount =>
      transactions.length +
      savings.length +
      investments.length +
      recurringTransactions.length;

  bool get isEmpty => totalCount == 0;
  bool get isNotEmpty => totalCount > 0;

  Map<String, int> get counts => <String, int>{
        'transactions': transactions.length,
        'savings': savings.length,
        'investments': investments.length,
        'recurring': recurringTransactions.length,
      };
}

/// Service to export and import app operational entries (Transactions, Savings,
/// Investments, Recurring) to and from Excel / CSV files without touching account
/// credentials, security keys, or device preferences.
class CsvExcelDataService {
  const CsvExcelDataService();

  static const String _utf8Bom = '\uFEFF';

  // ---------------------------------------------------------------------------
  // CSV ENCODING / EXPORT
  // ---------------------------------------------------------------------------

  /// Exports all data entities to a single comprehensive Master CSV.
  static String exportMasterCsv(AppStateModel state) {
    final List<List<String>> rows = <List<String>>[
      <String>[
        'RecordType',
        'ID',
        'Date',
        'Title/Description',
        'Category',
        'Type',
        'Amount',
        'Currency',
        'Status/Extra1',
        'Extra2',
        'Extra3',
        'Extra4',
        'Extra5',
        'Extra6',
        'CreatedAt',
      ],
    ];

    // 1. Transactions
    for (final Transaction t in state.transactions) {
      rows.add(<String>[
        'TRANSACTION',
        t.id,
        t.date,
        t.description,
        t.category,
        t.type,
        t.amount.toString(),
        t.currency,
        t.rolledOver ? 'RolledOver' : 'Standard',
        t.rolledAmount?.toString() ?? '',
        t.sourceIncomeId ?? '',
        t.exchangePairId ?? '',
        t.activityType ?? '',
        t.metalQuantity?.toString() ?? '',
        t.createdAt,
      ]);
    }

    // 2. Savings
    for (final Saving s in state.savings) {
      rows.add(<String>[
        'SAVING',
        s.id,
        s.dateAcquired,
        s.description,
        s.assetType,
        s.unit,
        s.amount.toString(),
        s.purchaseCurrency,
        s.remainingAmount.toString(),
        s.purchaseAmount.toString(),
        s.linkedCashEntryId ?? '',
        s.sourceIncomeId ?? '',
        s.exchangeSourceSavingId ?? '',
        s.transferActivityId ?? '',
        s.createdAt,
      ]);
    }

    // 3. Investments
    for (final InvestmentAsset i in state.investments) {
      rows.add(<String>[
        'INVESTMENT',
        i.id,
        i.valuationDate,
        i.description,
        i.investmentType,
        i.assetSubtype,
        i.originalPrice.toString(),
        i.currency,
        i.valuationMode,
        i.totalPayable.toString(),
        i.paidAmount.toString(),
        i.remainingAmount.toString(),
        i.marketValue.toString(),
        jsonEncode(i.installmentPlan),
        i.createdAt,
      ]);
    }

    // 4. Recurring
    for (final RecurringTransaction r in state.recurringTransactions) {
      rows.add(<String>[
        'RECURRING',
        r.id,
        r.lastProcessed ?? '',
        r.name,
        r.category,
        r.type,
        r.amount.toString(),
        r.currency,
        r.frequency,
        r.dayOfMonth.toString(),
        r.enabled ? 'Enabled' : 'Disabled',
        r.skipMonth,
        r.reminderTime,
        r.description,
        r.createdAt,
      ]);
    }

    return _utf8Bom + _encodeCsvTable(rows);
  }

  /// Exports only transactions to CSV.
  static String exportTransactionsCsv(List<Transaction> transactions) {
    final List<List<String>> rows = <List<String>>[
      <String>[
        'ID',
        'Date',
        'Description',
        'Category',
        'Type',
        'Amount',
        'Currency',
        'CreatedAt',
        'RolledOver',
        'RolledAmount',
        'SourceIncomeId',
        'ExchangePairId',
        'RemainingAmount',
        'ActivityType',
        'MetalQuantity',
      ],
      ...transactions.map(
        (Transaction t) => <String>[
          t.id,
          t.date,
          t.description,
          t.category,
          t.type,
          t.amount.toString(),
          t.currency,
          t.createdAt,
          t.rolledOver ? 'true' : 'false',
          t.rolledAmount?.toString() ?? '',
          t.sourceIncomeId ?? '',
          t.exchangePairId ?? '',
          t.remainingAmount?.toString() ?? '',
          t.activityType ?? '',
          t.metalQuantity?.toString() ?? '',
        ],
      ),
    ];
    return _utf8Bom + _encodeCsvTable(rows);
  }

  /// Exports only savings & accounts to CSV.
  static String exportSavingsCsv(List<Saving> savings) {
    final List<List<String>> rows = <List<String>>[
      <String>[
        'ID',
        'DateAcquired',
        'Description',
        'AssetType',
        'Amount',
        'Unit',
        'RemainingAmount',
        'PurchaseCurrency',
        'PurchaseAmount',
        'CreatedAt',
        'LinkedCashEntryId',
        'SourceIncomeId',
        'ExchangeSourceSavingId',
        'TransferActivityId',
      ],
      ...savings.map(
        (Saving s) => <String>[
          s.id,
          s.dateAcquired,
          s.description,
          s.assetType,
          s.amount.toString(),
          s.unit,
          s.remainingAmount.toString(),
          s.purchaseCurrency,
          s.purchaseAmount.toString(),
          s.createdAt,
          s.linkedCashEntryId ?? '',
          s.sourceIncomeId ?? '',
          s.exchangeSourceSavingId ?? '',
          s.transferActivityId ?? '',
        ],
      ),
    ];
    return _utf8Bom + _encodeCsvTable(rows);
  }

  /// Exports only investments & property assets to CSV.
  static String exportInvestmentsCsv(List<InvestmentAsset> investments) {
    final List<List<String>> rows = <List<String>>[
      <String>[
        'ID',
        'ValuationDate',
        'Description',
        'InvestmentType',
        'AssetSubtype',
        'ValuationMode',
        'Currency',
        'OriginalPrice',
        'TotalInterest',
        'TotalPayable',
        'PaidAmount',
        'RemainingAmount',
        'MarketValue',
        'MarketValueDate',
        'OwnershipSharePct',
        'Country',
        'Location',
        'NoZakat',
        'CreatedAt',
        'YearlyGrowthRate',
        'InstallmentPlan',
      ],
      ...investments.map(
        (InvestmentAsset i) => <String>[
          i.id,
          i.valuationDate,
          i.description,
          i.investmentType,
          i.assetSubtype,
          i.valuationMode,
          i.currency,
          i.originalPrice.toString(),
          i.totalInterest.toString(),
          i.totalPayable.toString(),
          i.paidAmount.toString(),
          i.remainingAmount.toString(),
          i.marketValue.toString(),
          i.marketValueDate,
          i.ownershipSharePct.toString(),
          i.country,
          i.location,
          i.noZakat ? 'true' : 'false',
          i.createdAt,
          i.yearlyGrowthRate.toString(),
          jsonEncode(i.installmentPlan),
        ],
      ),
    ];
    return _utf8Bom + _encodeCsvTable(rows);
  }

  /// Exports only recurring transactions to CSV.
  static String exportRecurringCsv(List<RecurringTransaction> recurring) {
    final List<List<String>> rows = <List<String>>[
      <String>[
        'ID',
        'Name',
        'Category',
        'Type',
        'Amount',
        'Currency',
        'Frequency',
        'DayOfMonth',
        'Enabled',
        'AutoAdd',
        'SkipMonth',
        'ReminderEnabled',
        'ReminderTime',
        'LastProcessed',
        'CreatedAt',
        'Description',
      ],
      ...recurring.map(
        (RecurringTransaction r) => <String>[
          r.id,
          r.name,
          r.category,
          r.type,
          r.amount.toString(),
          r.currency,
          r.frequency,
          r.dayOfMonth.toString(),
          r.enabled ? 'true' : 'false',
          r.autoAdd ? 'true' : 'false',
          r.skipMonth,
          r.reminderEnabled ? 'true' : 'false',
          r.reminderTime,
          r.lastProcessed ?? '',
          r.createdAt,
          r.description,
        ],
      ),
    ];
    return _utf8Bom + _encodeCsvTable(rows);
  }

  /// Creates a ZIP archive containing individual CSV files.
  static List<int> exportCsvZip(AppStateModel state) {
    final Archive archive = Archive();

    final List<int> txBytes = utf8.encode(exportTransactionsCsv(state.transactions));
    archive.addFile(ArchiveFile('transactions.csv', txBytes.length, txBytes));

    final List<int> savBytes = utf8.encode(exportSavingsCsv(state.savings));
    archive.addFile(ArchiveFile('savings.csv', savBytes.length, savBytes));

    final List<int> invBytes = utf8.encode(exportInvestmentsCsv(state.investments));
    archive.addFile(ArchiveFile('investments.csv', invBytes.length, invBytes));

    final List<int> recBytes = utf8.encode(exportRecurringCsv(state.recurringTransactions));
    archive.addFile(ArchiveFile('recurring.csv', recBytes.length, recBytes));

    final List<int> masterBytes = utf8.encode(exportMasterCsv(state));
    archive.addFile(ArchiveFile('all_entries_master.csv', masterBytes.length, masterBytes));

    return ZipEncoder().encode(archive);
  }

  // ---------------------------------------------------------------------------
  // CSV / EXCEL PARSING & IMPORT
  // ---------------------------------------------------------------------------

  /// Parses file contents from bytes and file name (.csv, .xlsx, .zip).
  static CsvImportResult parseFileContent({
    required List<int> bytes,
    required String fileName,
  }) {
    final String lowerName = fileName.toLowerCase();

    // 1. ZIP file containing CSVs or Excel
    if (lowerName.endsWith('.zip')) {
      return _parseZipArchive(bytes);
    }

    // 2. XLSX file
    if (lowerName.endsWith('.xlsx')) {
      return _parseXlsxFile(bytes);
    }

    // 3. Plain CSV
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      text = latin1.decode(bytes);
    }
    return parseCsvText(text, defaultFileName: fileName);
  }

  /// Parses a raw CSV string into domain items.
  static CsvImportResult parseCsvText(
    String rawCsv, {
    String? defaultFileName,
  }) {
    String cleanText = rawCsv;
    if (cleanText.startsWith(_utf8Bom)) {
      cleanText = cleanText.substring(_utf8Bom.length);
    }

    final List<List<String>> table = decodeCsv(cleanText);
    if (table.isEmpty) {
      return const CsvImportResult(warnings: <String>['File contains no rows.']);
    }

    final List<String> header = table.first.map((String c) => c.trim().toLowerCase()).toList();
    final List<List<String>> dataRows = table.skip(1).toList();

    // Detect format
    final bool isMaster = header.contains('recordtype');
    final bool isTransactionFile = header.contains('rolledover') ||
        header.contains('metalquantity') ||
        (header.contains('amount') &&
            header.contains('currency') &&
            header.contains('description') &&
            !header.contains('assettype') &&
            !header.contains('investmenttype') &&
            !header.contains('frequency'));

    final bool isSavingFile = header.contains('assettype') ||
        header.contains('purchasecurrency') ||
        header.contains('dateacquired');

    final bool isInvestmentFile = header.contains('investmenttype') ||
        header.contains('valuationdate') ||
        header.contains('installmentplan') ||
        header.contains('totalpayable');

    final bool isRecurringFile = header.contains('frequency') ||
        header.contains('dayofmonth') ||
        header.contains('skipmonth');

    final List<Transaction> transactions = <Transaction>[];
    final List<Saving> savings = <Saving>[];
    final List<InvestmentAsset> investments = <InvestmentAsset>[];
    final List<RecurringTransaction> recurring = <RecurringTransaction>[];
    final List<String> warnings = <String>[];

    if (isMaster) {
      final int typeIdx = header.indexOf('recordtype');
      for (final List<String> row in dataRows) {
        if (row.isEmpty) continue;
        final String recordType = (typeIdx < row.length ? row[typeIdx] : '')
            .trim()
            .toUpperCase();
        try {
          if (recordType == 'TRANSACTION') {
            final Transaction? item = _parseMasterTransaction(row);
            if (item != null) transactions.add(item);
          } else if (recordType == 'SAVING') {
            final Saving? item = _parseMasterSaving(row);
            if (item != null) savings.add(item);
          } else if (recordType == 'INVESTMENT') {
            final InvestmentAsset? item = _parseMasterInvestment(row);
            if (item != null) investments.add(item);
          } else if (recordType == 'RECURRING') {
            final RecurringTransaction? item = _parseMasterRecurring(row);
            if (item != null) recurring.add(item);
          }
        } catch (e) {
          warnings.add('Skipped row due to error: $e');
        }
      }
    } else if (isSavingFile) {
      for (final List<String> row in dataRows) {
        final Saving? item = _parseSavingRow(header, row);
        if (item != null) savings.add(item);
      }
    } else if (isInvestmentFile) {
      for (final List<String> row in dataRows) {
        final InvestmentAsset? item = _parseInvestmentRow(header, row);
        if (item != null) investments.add(item);
      }
    } else if (isRecurringFile) {
      for (final List<String> row in dataRows) {
        final RecurringTransaction? item = _parseRecurringRow(header, row);
        if (item != null) recurring.add(item);
      }
    } else if (isTransactionFile || (defaultFileName?.toLowerCase().contains('transaction') ?? false)) {
      for (final List<String> row in dataRows) {
        final Transaction? item = _parseTransactionRow(header, row);
        if (item != null) transactions.add(item);
      }
    } else {
      // Fallback: try parsing each row as a transaction if amount & currency are present
      for (final List<String> row in dataRows) {
        final Transaction? item = _parseTransactionRow(header, row);
        if (item != null) transactions.add(item);
      }
    }

    return CsvImportResult(
      transactions: transactions,
      savings: savings,
      investments: investments,
      recurringTransactions: recurring,
      warnings: warnings,
    );
  }

  // ---------------------------------------------------------------------------
  // APPLICATION & DATABASE MERGE
  // ---------------------------------------------------------------------------

  /// Applies the parsed CSV / Excel items to the application database.
  /// If [replace] is true, replaces only the entity tables with the imported items.
  /// If [replace] is false, merges by ID with existing records.
  static Future<RestoreResult> applyImport({
    required AppStateController controller,
    required CsvImportResult data,
    required bool replace,
  }) async {
    final Map<String, dynamic> current = controller.state.toJson();

    final List<Map<String, dynamic>> incomingTx =
        data.transactions.map((Transaction e) => e.toJson()).toList();
    final List<Map<String, dynamic>> incomingSav =
        data.savings.map((Saving e) => e.toJson()).toList();
    final List<Map<String, dynamic>> incomingInv =
        data.investments.map((InvestmentAsset e) => e.toJson()).toList();
    final List<Map<String, dynamic>> incomingRec =
        data.recurringTransactions.map((RecurringTransaction e) => e.toJson()).toList();

    final Map<String, dynamic> nextStateJson = Map<String, dynamic>.from(current);

    if (replace) {
      if (data.transactions.isNotEmpty) nextStateJson['transactions'] = incomingTx;
      if (data.savings.isNotEmpty) nextStateJson['savings'] = incomingSav;
      if (data.investments.isNotEmpty) nextStateJson['investments'] = incomingInv;
      if (data.recurringTransactions.isNotEmpty) {
        nextStateJson['recurringTransactions'] = incomingRec;
      }
    } else {
      nextStateJson['transactions'] = _mergeMapListsById(
        (current['transactions'] as List?) ?? const <dynamic>[],
        incomingTx,
      );
      nextStateJson['savings'] = _mergeMapListsById(
        (current['savings'] as List?) ?? const <dynamic>[],
        incomingSav,
      );
      nextStateJson['investments'] = _mergeMapListsById(
        (current['investments'] as List?) ?? const <dynamic>[],
        incomingInv,
      );
      nextStateJson['recurringTransactions'] = _mergeMapListsById(
        (current['recurringTransactions'] as List?) ?? const <dynamic>[],
        incomingRec,
      );
    }

    // Retain active user ID, email, profile and settings intact
    if (controller.state.userId != null) {
      nextStateJson['userId'] = controller.state.userId;
    }
    if (controller.state.userEmail != null) {
      nextStateJson['email'] = controller.state.userEmail;
      nextStateJson['userEmail'] = controller.state.userEmail;
    }
    if (controller.state.userDisplayName != null) {
      nextStateJson['displayName'] = controller.state.userDisplayName;
      nextStateJson['userDisplayName'] = controller.state.userDisplayName;
    }
    if (controller.state.userProvider != null) {
      nextStateJson['provider'] = controller.state.userProvider;
      nextStateJson['userProvider'] = controller.state.userProvider;
    }

    final AppStateModel next = AppStateModel.fromJson(nextStateJson);
    await controller.updateState(next);

    await SyncDiagnosticsService.record(
      level: 'info',
      subsystem: 'csv_import',
      message: 'CSV/Excel import completed',
      metadata: <String, dynamic>{
        'replace': replace,
        'counts': data.counts,
      },
    );

    return RestoreResult(
      mode: replace ? 'replace' : 'merge',
      counts: data.counts,
      warnings: data.warnings,
    );
  }

  // ---------------------------------------------------------------------------
  // CSV HELPERS (RFC 4180 COMPLIANT)
  // ---------------------------------------------------------------------------

  static String _encodeCsvTable(List<List<String>> rows) {
    return rows.map(_encodeCsvRow).join('\r\n');
  }

  static String _encodeCsvRow(List<String> cells) {
    return cells.map(_escapeCsvCell).join(',');
  }

  static String _escapeCsvCell(String cell) {
    if (cell.contains(',') ||
        cell.contains('"') ||
        cell.contains('\n') ||
        cell.contains('\r')) {
      return '"${cell.replaceAll('"', '""')}"';
    }
    return cell;
  }

  /// RFC 4180 compliant CSV parser with support for quotes, escaped quotes,
  /// multiple lines within cells, and automatic delimiter detection (, ; \t).
  static List<List<String>> decodeCsv(String text) {
    if (text.trim().isEmpty) return const <List<String>>[];

    // Auto-detect delimiter from first line
    final String firstLine = text.split(RegExp(r'\r\n|\r|\n')).first;
    String delimiter = ',';
    final int commas = firstLine.split(',').length - 1;
    final int semicolons = firstLine.split(';').length - 1;
    final int tabs = firstLine.split('\t').length - 1;
    if (semicolons > commas && semicolons >= tabs) {
      delimiter = ';';
    } else if (tabs > commas && tabs > semicolons) {
      delimiter = '\t';
    }

    final List<List<String>> rows = <List<String>>[];
    List<String> currentRow = <String>[];
    final StringBuffer currentCell = StringBuffer();
    bool insideQuotes = false;

    final int len = text.length;
    for (int i = 0; i < len; i++) {
      final String char = text[i];

      if (char == '"') {
        if (insideQuotes && i + 1 < len && text[i + 1] == '"') {
          // Escaped quote: ""
          currentCell.write('"');
          i++; // Skip next quote
        } else {
          insideQuotes = !insideQuotes;
        }
      } else if (char == delimiter && !insideQuotes) {
        currentRow.add(currentCell.toString().trim());
        currentCell.clear();
      } else if ((char == '\n' || char == '\r') && !insideQuotes) {
        if (char == '\r' && i + 1 < len && text[i + 1] == '\n') {
          i++; // Skip \n in \r\n
        }
        currentRow.add(currentCell.toString().trim());
        currentCell.clear();
        if (currentRow.isNotEmpty && currentRow.any((String c) => c.isNotEmpty)) {
          rows.add(currentRow);
        }
        currentRow = <String>[];
      } else {
        currentCell.write(char);
      }
    }

    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString().trim());
      if (currentRow.any((String c) => c.isNotEmpty)) {
        rows.add(currentRow);
      }
    }

    return rows;
  }

  // ---------------------------------------------------------------------------
  // ZIP ARCHIVE PARSING
  // ---------------------------------------------------------------------------

  static CsvImportResult _parseZipArchive(List<int> bytes) {
    try {
      final Archive archive = ZipDecoder().decodeBytes(bytes);
      final List<Transaction> transactions = <Transaction>[];
      final List<Saving> savings = <Saving>[];
      final List<InvestmentAsset> investments = <InvestmentAsset>[];
      final List<RecurringTransaction> recurring = <RecurringTransaction>[];
      final List<String> warnings = <String>[];

      for (final ArchiveFile file in archive) {
        if (!file.isFile) continue;
        final String name = file.name.toLowerCase();
        if (name.startsWith('__macosx') || name.startsWith('.')) continue;

        if (name.endsWith('.csv')) {
          final List<int> content = file.content as List<int>;
          final CsvImportResult parsed = parseFileContent(
            bytes: content,
            fileName: file.name,
          );
          transactions.addAll(parsed.transactions);
          savings.addAll(parsed.savings);
          investments.addAll(parsed.investments);
          recurring.addAll(parsed.recurringTransactions);
          warnings.addAll(parsed.warnings);
        } else if (name.endsWith('.xlsx')) {
          final List<int> content = file.content as List<int>;
          final CsvImportResult parsed = _parseXlsxFile(content);
          transactions.addAll(parsed.transactions);
          savings.addAll(parsed.savings);
          investments.addAll(parsed.investments);
          recurring.addAll(parsed.recurringTransactions);
          warnings.addAll(parsed.warnings);
        }
      }

      return CsvImportResult(
        transactions: transactions,
        savings: savings,
        investments: investments,
        recurringTransactions: recurring,
        warnings: warnings,
      );
    } catch (e) {
      return CsvImportResult(warnings: <String>['Failed to unzip archive: $e']);
    }
  }

  // ---------------------------------------------------------------------------
  // XLSX (EXCEL) ARCHIVE PARSING
  // ---------------------------------------------------------------------------

  static CsvImportResult _parseXlsxFile(List<int> bytes) {
    try {
      final Archive archive = ZipDecoder().decodeBytes(bytes);

      // 1. Extract shared strings
      final List<String> sharedStrings = <String>[];
      final ArchiveFile? sstFile = archive.findFile('xl/sharedStrings.xml');
      if (sstFile != null) {
        final String sstXml = utf8.decode(sstFile.content as List<int>, allowMalformed: true);
        final RegExp strRegex = RegExp(r'<si>([\s\S]*?)<\/si>');
        final RegExp tRegex = RegExp(r'<t[^>]*>([\s\S]*?)<\/t>');
        for (final Match match in strRegex.allMatches(sstXml)) {
          final String siContent = match.group(1) ?? '';
          final StringBuffer sb = StringBuffer();
          for (final Match tMatch in tRegex.allMatches(siContent)) {
            sb.write(_unescapeXml(tMatch.group(1) ?? ''));
          }
          sharedStrings.add(sb.toString());
        }
      }

      final List<Transaction> transactions = <Transaction>[];
      final List<Saving> savings = <Saving>[];
      final List<InvestmentAsset> investments = <InvestmentAsset>[];
      final List<RecurringTransaction> recurring = <RecurringTransaction>[];
      final List<String> warnings = <String>[];

      // 2. Parse all sheet*.xml
      for (final ArchiveFile file in archive) {
        if (!file.isFile) continue;
        if (file.name.startsWith('xl/worksheets/sheet') && file.name.endsWith('.xml')) {
          final String sheetXml = utf8.decode(file.content as List<int>, allowMalformed: true);
          final List<List<String>> rows = _parseWorksheetXml(sheetXml, sharedStrings);
          if (rows.isNotEmpty) {
            final String csvContent = _encodeCsvTable(rows);
            final CsvImportResult parsed = parseCsvText(csvContent);
            transactions.addAll(parsed.transactions);
            savings.addAll(parsed.savings);
            investments.addAll(parsed.investments);
            recurring.addAll(parsed.recurringTransactions);
            warnings.addAll(parsed.warnings);
          }
        }
      }

      return CsvImportResult(
        transactions: transactions,
        savings: savings,
        investments: investments,
        recurringTransactions: recurring,
        warnings: warnings,
      );
    } catch (e) {
      return CsvImportResult(warnings: <String>['Failed to parse Excel file: $e']);
    }
  }

  static List<List<String>> _parseWorksheetXml(
    String sheetXml,
    List<String> sharedStrings,
  ) {
    final List<List<String>> rows = <List<String>>[];
    final RegExp rowRegex = RegExp(r'<row[^>]*>([\s\S]*?)<\/row>');
    final RegExp cellRegex = RegExp(r'<c\s+([^>]*?)>(?:<v>([\s\S]*?)<\/v>|<is><t>([\s\S]*?)<\/t><\/is>)?<\/c>');
    final RegExp tAttrRegex = RegExp(r't="([^"]*)"');

    for (final Match rowMatch in rowRegex.allMatches(sheetXml)) {
      final String rowContent = rowMatch.group(1) ?? '';
      final List<String> rowCells = <String>[];

      for (final Match cellMatch in cellRegex.allMatches(rowContent)) {
        final String attrs = cellMatch.group(1) ?? '';
        final String? val = cellMatch.group(2);
        final String? inlineStr = cellMatch.group(3);

        String cellValue = '';
        final Match? tMatch = tAttrRegex.firstMatch(attrs);
        final String cellType = tMatch?.group(1) ?? '';

        if (inlineStr != null) {
          cellValue = _unescapeXml(inlineStr);
        } else if (cellType == 's' && val != null) {
          final int? idx = int.tryParse(val.trim());
          if (idx != null && idx >= 0 && idx < sharedStrings.length) {
            cellValue = sharedStrings[idx];
          }
        } else if (val != null) {
          cellValue = _unescapeXml(val.trim());
        }

        rowCells.add(cellValue);
      }

      if (rowCells.any((String c) => c.isNotEmpty)) {
        rows.add(rowCells);
      }
    }
    return rows;
  }

  static String _unescapeXml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  // ---------------------------------------------------------------------------
  // ROW CONVERTERS
  // ---------------------------------------------------------------------------

  static Transaction? _parseTransactionRow(List<String> header, List<String> row) {
    final String amountStr = _valByCol(header, row, <String>['amount']);
    final double? amount = tryParseAmount(amountStr);
    if (amount == null || amount <= 0) return null;

    final String id = _valByCol(header, row, <String>['id'], fallback: 'tx_${DateTime.now().microsecondsSinceEpoch}');
    final String date = normalizeDateText(_valByCol(header, row, <String>['date', 'transactiondate']));
    final String description = _valByCol(header, row, <String>['description', 'title', 'note']);
    final String category = _valByCol(header, row, <String>['category'], fallback: 'General');
    final String type = _valByCol(header, row, <String>['type', 'transactiontype'], fallback: 'expense').toLowerCase();
    final String currency = _valByCol(header, row, <String>['currency'], fallback: 'USD').toUpperCase();
    final String createdAt = normalizeTimestampText(_valByCol(header, row, <String>['createdat']));
    final bool rolledOver = _valByCol(header, row, <String>['rolledover']).toLowerCase() == 'true';
    final double? rolledAmount = tryParseAmount(_valByCol(header, row, <String>['rolledamount']));
    final String? sourceIncomeId = _nullIfEmpty(_valByCol(header, row, <String>['sourceincomeid']));
    final String? exchangePairId = _nullIfEmpty(_valByCol(header, row, <String>['exchangepairid']));
    final double? remainingAmount = tryParseAmount(_valByCol(header, row, <String>['remainingamount']));
    final String? activityType = _nullIfEmpty(_valByCol(header, row, <String>['activitytype']));
    final double? metalQuantity = tryParseAmount(_valByCol(header, row, <String>['metalquantity']));

    return Transaction(
      id: id,
      type: type,
      date: date,
      amount: amount,
      currency: currency,
      category: category,
      description: description,
      createdAt: createdAt,
      rolledOver: rolledOver,
      rolledAmount: rolledAmount,
      sourceIncomeId: sourceIncomeId,
      exchangePairId: exchangePairId,
      remainingAmount: remainingAmount,
      activityType: activityType,
      metalQuantity: metalQuantity,
    );
  }

  static Saving? _parseSavingRow(List<String> header, List<String> row) {
    final String amountStr = _valByCol(header, row, <String>['amount']);
    final double? amount = tryParseAmount(amountStr);
    if (amount == null || amount <= 0) return null;

    final String id = _valByCol(header, row, <String>['id'], fallback: 'sav_${DateTime.now().microsecondsSinceEpoch}');
    final String dateAcquired = normalizeDateText(_valByCol(header, row, <String>['dateacquired', 'date']));
    final String description = _valByCol(header, row, <String>['description', 'name', 'title']);
    final String assetType = _valByCol(header, row, <String>['assettype'], fallback: 'cash');
    final String unit = _valByCol(header, row, <String>['unit', 'currency'], fallback: 'USD').toUpperCase();
    final double remainingAmount = tryParseAmount(_valByCol(header, row, <String>['remainingamount'])) ?? amount;
    final String purchaseCurrency = _valByCol(header, row, <String>['purchasecurrency', 'currency'], fallback: unit).toUpperCase();
    final double purchaseAmount = tryParseAmount(_valByCol(header, row, <String>['purchaseamount'])) ?? amount;
    final String createdAt = normalizeTimestampText(_valByCol(header, row, <String>['createdat']));
    final String? linkedCashEntryId = _nullIfEmpty(_valByCol(header, row, <String>['linkedcashentryid']));
    final String? sourceIncomeId = _nullIfEmpty(_valByCol(header, row, <String>['sourceincomeid']));
    final String? exchangeSourceSavingId = _nullIfEmpty(_valByCol(header, row, <String>['exchangesourcesavingid']));
    final String? transferActivityId = _nullIfEmpty(_valByCol(header, row, <String>['transferactivityid']));

    return Saving(
      id: id,
      assetType: assetType,
      dateAcquired: dateAcquired,
      amount: amount,
      remainingAmount: remainingAmount,
      unit: unit,
      description: description,
      purchaseCurrency: purchaseCurrency,
      purchaseAmount: purchaseAmount,
      createdAt: createdAt,
      linkedCashEntryId: linkedCashEntryId,
      sourceIncomeId: sourceIncomeId,
      exchangeSourceSavingId: exchangeSourceSavingId,
      transferActivityId: transferActivityId,
    );
  }

  static InvestmentAsset? _parseInvestmentRow(List<String> header, List<String> row) {
    final String originalPriceStr = _valByCol(header, row, <String>['originalprice', 'value', 'amount']);
    final double? originalPrice = tryParseAmount(originalPriceStr);
    if (originalPrice == null || originalPrice <= 0) return null;

    final String id = _valByCol(header, row, <String>['id'], fallback: 'inv_${DateTime.now().microsecondsSinceEpoch}');
    final String valuationDate = normalizeDateText(_valByCol(header, row, <String>['valuationdate', 'date']));
    final String description = _valByCol(header, row, <String>['description', 'name']);
    final String investmentType = _valByCol(header, row, <String>['investmenttype', 'category'], fallback: 'property');
    final String assetSubtype = _valByCol(header, row, <String>['assetsubtype'], fallback: 'Real Estate');
    final String valuationMode = _valByCol(header, row, <String>['valuationmode'], fallback: 'manual');
    final String currency = _valByCol(header, row, <String>['currency'], fallback: 'USD').toUpperCase();
    final double totalInterest = tryParseAmount(_valByCol(header, row, <String>['totalinterest'])) ?? 0.0;
    final double totalPayable = tryParseAmount(_valByCol(header, row, <String>['totalpayable'])) ?? originalPrice;
    final double paidAmount = tryParseAmount(_valByCol(header, row, <String>['paidamount'])) ?? 0.0;
    final double remainingAmount = tryParseAmount(_valByCol(header, row, <String>['remainingamount'])) ?? (totalPayable - paidAmount);
    final double marketValue = tryParseAmount(_valByCol(header, row, <String>['marketvalue'])) ?? originalPrice;
    final String marketValueDate = normalizeDateText(_valByCol(header, row, <String>['marketvaluedate', 'valuationdate']));
    final double ownershipSharePct = tryParseAmount(_valByCol(header, row, <String>['ownershipsharepct'])) ?? 100.0;
    final String country = _valByCol(header, row, <String>['country']);
    final String location = _valByCol(header, row, <String>['location']);
    final bool noZakat = _valByCol(header, row, <String>['nozakat']).toLowerCase() != 'false';
    final String createdAt = normalizeTimestampText(_valByCol(header, row, <String>['createdat']));
    final double yearlyGrowthRate = tryParseAmount(_valByCol(header, row, <String>['yearlygrowthrate'])) ?? 0.0;

    final String planRaw = _valByCol(header, row, <String>['installmentplan']);
    List<Map<String, dynamic>> plan = const <Map<String, dynamic>>[];
    if (planRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(planRaw);
        plan = InvestmentAsset.normalizeInstallmentPlan(decoded);
      } catch (_) {}
    }

    return InvestmentAsset(
      id: id,
      investmentType: investmentType,
      assetSubtype: assetSubtype,
      ownershipType: 'Sole',
      valuationMode: valuationMode,
      currency: currency,
      originalPrice: originalPrice,
      totalInterest: totalInterest,
      totalPayable: totalPayable,
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
      installmentPlan: plan,
      valuationDate: valuationDate,
      marketValue: marketValue,
      marketValueDate: marketValueDate,
      valuationSource: 'CSV Import',
      loanBalance: 0.0,
      loanAsOfDate: valuationDate,
      paidAmountToDate: paidAmount,
      ownershipSharePct: ownershipSharePct,
      country: country,
      location: location,
      inflationRateAnnual: 0.0,
      estimatedCurrentValue: marketValue,
      description: description,
      noZakat: noZakat,
      createdAt: createdAt,
      yearlyGrowthRate: yearlyGrowthRate,
    );
  }

  static RecurringTransaction? _parseRecurringRow(List<String> header, List<String> row) {
    final String amountStr = _valByCol(header, row, <String>['amount']);
    final double? amount = tryParseAmount(amountStr);
    if (amount == null || amount <= 0) return null;

    final String id = _valByCol(header, row, <String>['id'], fallback: 'rec_${DateTime.now().microsecondsSinceEpoch}');
    final String name = _valByCol(header, row, <String>['name', 'title'], fallback: 'Recurring Item');
    final String category = _valByCol(header, row, <String>['category'], fallback: 'General');
    final String type = _valByCol(header, row, <String>['type'], fallback: 'expense').toLowerCase();
    final String currency = _valByCol(header, row, <String>['currency'], fallback: 'USD').toUpperCase();
    final String frequency = _valByCol(header, row, <String>['frequency'], fallback: 'monthly').toLowerCase();
    final int dayOfMonth = int.tryParse(_valByCol(header, row, <String>['dayofmonth'])) ?? 1;
    final bool enabled = _valByCol(header, row, <String>['enabled']).toLowerCase() != 'false';
    final bool autoAdd = _valByCol(header, row, <String>['autoadd']).toLowerCase() != 'false';
    final String skipMonth = _valByCol(header, row, <String>['skipmonth']);
    final bool reminderEnabled = _valByCol(header, row, <String>['reminderenabled']).toLowerCase() == 'true';
    final String reminderTime = _valByCol(header, row, <String>['remindertime'], fallback: '09:00');
    final String? lastProcessed = _nullIfEmpty(_valByCol(header, row, <String>['lastprocessed']));
    final String createdAt = normalizeTimestampText(_valByCol(header, row, <String>['createdat']));
    final String description = _valByCol(header, row, <String>['description']);

    return RecurringTransaction(
      id: id,
      name: name,
      type: type,
      amount: amount,
      currency: currency,
      category: category,
      description: description,
      dayOfMonth: dayOfMonth,
      frequency: frequency,
      lastProcessed: lastProcessed,
      enabled: enabled,
      skipMonth: skipMonth,
      createdAt: createdAt,
      autoAdd: autoAdd,
      reminderEnabled: reminderEnabled,
      reminderTime: reminderTime,
    );
  }

  // Master row parsers
  static Transaction? _parseMasterTransaction(List<String> row) {
    if (row.length < 8) return null;
    final double? amount = tryParseAmount(row[6]);
    if (amount == null || amount <= 0) return null;

    return Transaction(
      id: row[1].isNotEmpty ? row[1] : 'tx_${DateTime.now().microsecondsSinceEpoch}',
      date: normalizeDateText(row[2]),
      description: row[3],
      category: row[4].isNotEmpty ? row[4] : 'General',
      type: row[5].toLowerCase(),
      amount: amount,
      currency: row[7].toUpperCase(),
      createdAt: row.length > 14 ? normalizeTimestampText(row[14]) : '',
      rolledOver: row.length > 8 && row[8].toLowerCase() == 'rolledover',
      rolledAmount: row.length > 9 ? tryParseAmount(row[9]) : null,
      sourceIncomeId: row.length > 10 ? _nullIfEmpty(row[10]) : null,
      exchangePairId: row.length > 11 ? _nullIfEmpty(row[11]) : null,
      activityType: row.length > 12 ? _nullIfEmpty(row[12]) : null,
      metalQuantity: row.length > 13 ? tryParseAmount(row[13]) : null,
    );
  }

  static Saving? _parseMasterSaving(List<String> row) {
    if (row.length < 8) return null;
    final double? amount = tryParseAmount(row[6]);
    if (amount == null || amount <= 0) return null;

    return Saving(
      id: row[1].isNotEmpty ? row[1] : 'sav_${DateTime.now().microsecondsSinceEpoch}',
      dateAcquired: normalizeDateText(row[2]),
      description: row[3],
      assetType: row[4].isNotEmpty ? row[4] : 'cash',
      unit: row[5].toUpperCase(),
      amount: amount,
      purchaseCurrency: row[7].toUpperCase(),
      remainingAmount: row.length > 8 ? (tryParseAmount(row[8]) ?? amount) : amount,
      purchaseAmount: row.length > 9 ? (tryParseAmount(row[9]) ?? amount) : amount,
      linkedCashEntryId: row.length > 10 ? _nullIfEmpty(row[10]) : null,
      sourceIncomeId: row.length > 11 ? _nullIfEmpty(row[11]) : null,
      exchangeSourceSavingId: row.length > 12 ? _nullIfEmpty(row[12]) : null,
      transferActivityId: row.length > 13 ? _nullIfEmpty(row[13]) : null,
      createdAt: row.length > 14 ? normalizeTimestampText(row[14]) : '',
    );
  }

  static InvestmentAsset? _parseMasterInvestment(List<String> row) {
    if (row.length < 8) return null;
    final double? amount = tryParseAmount(row[6]);
    if (amount == null || amount <= 0) return null;

    List<Map<String, dynamic>> plan = const <Map<String, dynamic>>[];
    if (row.length > 13 && row[13].isNotEmpty) {
      try {
        final decoded = jsonDecode(row[13]);
        plan = InvestmentAsset.normalizeInstallmentPlan(decoded);
      } catch (_) {}
    }

    return InvestmentAsset(
      id: row[1].isNotEmpty ? row[1] : 'inv_${DateTime.now().microsecondsSinceEpoch}',
      valuationDate: normalizeDateText(row[2]),
      description: row[3],
      investmentType: row[4].isNotEmpty ? row[4] : 'property',
      assetSubtype: row[5].isNotEmpty ? row[5] : 'Real Estate',
      originalPrice: amount,
      currency: row[7].toUpperCase(),
      valuationMode: row.length > 8 && row[8].isNotEmpty ? row[8] : 'manual',
      totalInterest: 0.0,
      totalPayable: row.length > 9 ? (tryParseAmount(row[9]) ?? amount) : amount,
      paidAmount: row.length > 10 ? (tryParseAmount(row[10]) ?? 0.0) : 0.0,
      remainingAmount: row.length > 11 ? (tryParseAmount(row[11]) ?? amount) : amount,
      marketValue: row.length > 12 ? (tryParseAmount(row[12]) ?? amount) : amount,
      marketValueDate: normalizeDateText(row[2]),
      ownershipType: 'Sole',
      valuationSource: 'CSV Master Import',
      loanBalance: 0.0,
      loanAsOfDate: normalizeDateText(row[2]),
      paidAmountToDate: row.length > 10 ? (tryParseAmount(row[10]) ?? 0.0) : 0.0,
      ownershipSharePct: 100.0,
      country: '',
      location: '',
      inflationRateAnnual: 0.0,
      estimatedCurrentValue: row.length > 12 ? (tryParseAmount(row[12]) ?? amount) : amount,
      noZakat: true,
      installmentPlan: plan,
      createdAt: row.length > 14 ? normalizeTimestampText(row[14]) : '',
    );
  }

  static RecurringTransaction? _parseMasterRecurring(List<String> row) {
    if (row.length < 8) return null;
    final double? amount = tryParseAmount(row[6]);
    if (amount == null || amount <= 0) return null;

    return RecurringTransaction(
      id: row[1].isNotEmpty ? row[1] : 'rec_${DateTime.now().microsecondsSinceEpoch}',
      lastProcessed: _nullIfEmpty(row[2]),
      name: row[3],
      category: row[4].isNotEmpty ? row[4] : 'General',
      type: row[5].toLowerCase(),
      amount: amount,
      currency: row[7].toUpperCase(),
      frequency: row.length > 8 && row[8].isNotEmpty ? row[8].toLowerCase() : 'monthly',
      dayOfMonth: row.length > 9 ? (int.tryParse(row[9]) ?? 1) : 1,
      enabled: row.length > 10 ? row[10].toLowerCase() != 'disabled' : true,
      skipMonth: row.length > 11 ? row[11] : '',
      reminderTime: row.length > 12 && row[12].isNotEmpty ? row[12] : '09:00',
      description: row.length > 13 ? row[13] : '',
      createdAt: row.length > 14 ? normalizeTimestampText(row[14]) : '',
    );
  }

  // ---------------------------------------------------------------------------
  // UTILITIES
  // ---------------------------------------------------------------------------

  static String _valByCol(
    List<String> header,
    List<String> row,
    List<String> candidates, {
    String fallback = '',
  }) {
    for (final String colName in candidates) {
      final int idx = header.indexOf(colName);
      if (idx >= 0 && idx < row.length && row[idx].trim().isNotEmpty) {
        return row[idx].trim();
      }
    }
    return fallback;
  }

  static String? _nullIfEmpty(String val) => val.trim().isEmpty ? null : val.trim();

  static List<Map<String, dynamic>> _mergeMapListsById(
    List<dynamic> current,
    List<Map<String, dynamic>> incoming,
  ) {
    final Map<String, Map<String, dynamic>> byId = <String, Map<String, dynamic>>{};
    for (final dynamic item in current) {
      if (item is Map) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(item);
        final String id = (map['id'] ?? '').toString();
        if (id.isNotEmpty) byId[id] = map;
      }
    }
    for (final Map<String, dynamic> item in incoming) {
      final String id = (item['id'] ?? '').toString();
      if (id.isNotEmpty) {
        byId[id] = item;
      } else {
        byId['auto_${DateTime.now().microsecondsSinceEpoch}'] = item;
      }
    }
    return byId.values.toList(growable: false);
  }
}
