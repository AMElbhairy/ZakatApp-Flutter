// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountTextMeta = const VerificationMeta(
    'amountText',
  );
  @override
  late final GeneratedColumn<String> amountText = GeneratedColumn<String>(
    'amount_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rolledOverMeta = const VerificationMeta(
    'rolledOver',
  );
  @override
  late final GeneratedColumn<bool> rolledOver = GeneratedColumn<bool>(
    'rolled_over',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("rolled_over" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _rolledAmountTextMeta = const VerificationMeta(
    'rolledAmountText',
  );
  @override
  late final GeneratedColumn<String> rolledAmountText = GeneratedColumn<String>(
    'rolled_amount_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceIncomeIdMeta = const VerificationMeta(
    'sourceIncomeId',
  );
  @override
  late final GeneratedColumn<String> sourceIncomeId = GeneratedColumn<String>(
    'source_income_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exchangePairIdMeta = const VerificationMeta(
    'exchangePairId',
  );
  @override
  late final GeneratedColumn<String> exchangePairId = GeneratedColumn<String>(
    'exchange_pair_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exchangeSourceIncomeIdMeta =
      const VerificationMeta('exchangeSourceIncomeId');
  @override
  late final GeneratedColumn<String> exchangeSourceIncomeId =
      GeneratedColumn<String>(
        'exchange_source_income_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _remainingAmountTextMeta =
      const VerificationMeta('remainingAmountText');
  @override
  late final GeneratedColumn<String> remainingAmountText =
      GeneratedColumn<String>(
        'remaining_amount_text',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _activityTypeMeta = const VerificationMeta(
    'activityType',
  );
  @override
  late final GeneratedColumn<String> activityType = GeneratedColumn<String>(
    'activity_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _costBasisTextMeta = const VerificationMeta(
    'costBasisText',
  );
  @override
  late final GeneratedColumn<String> costBasisText = GeneratedColumn<String>(
    'cost_basis_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _saleValueTextMeta = const VerificationMeta(
    'saleValueText',
  );
  @override
  late final GeneratedColumn<String> saleValueText = GeneratedColumn<String>(
    'sale_value_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _realizedGainTextMeta = const VerificationMeta(
    'realizedGainText',
  );
  @override
  late final GeneratedColumn<String> realizedGainText = GeneratedColumn<String>(
    'realized_gain_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _realizedGainLossCurrencyMeta =
      const VerificationMeta('realizedGainLossCurrency');
  @override
  late final GeneratedColumn<String> realizedGainLossCurrency =
      GeneratedColumn<String>(
        'realized_gain_loss_currency',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _metalQuantityTextMeta = const VerificationMeta(
    'metalQuantityText',
  );
  @override
  late final GeneratedColumn<String> metalQuantityText =
      GeneratedColumn<String>(
        'metal_quantity_text',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    date,
    amountText,
    currency,
    category,
    description,
    createdAt,
    rolledOver,
    rolledAmountText,
    sourceIncomeId,
    exchangePairId,
    exchangeSourceIncomeId,
    remainingAmountText,
    activityType,
    costBasisText,
    saleValueText,
    realizedGainText,
    realizedGainLossCurrency,
    metalQuantityText,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('amount_text')) {
      context.handle(
        _amountTextMeta,
        amountText.isAcceptableOrUnknown(data['amount_text']!, _amountTextMeta),
      );
    } else if (isInserting) {
      context.missing(_amountTextMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('rolled_over')) {
      context.handle(
        _rolledOverMeta,
        rolledOver.isAcceptableOrUnknown(data['rolled_over']!, _rolledOverMeta),
      );
    }
    if (data.containsKey('rolled_amount_text')) {
      context.handle(
        _rolledAmountTextMeta,
        rolledAmountText.isAcceptableOrUnknown(
          data['rolled_amount_text']!,
          _rolledAmountTextMeta,
        ),
      );
    }
    if (data.containsKey('source_income_id')) {
      context.handle(
        _sourceIncomeIdMeta,
        sourceIncomeId.isAcceptableOrUnknown(
          data['source_income_id']!,
          _sourceIncomeIdMeta,
        ),
      );
    }
    if (data.containsKey('exchange_pair_id')) {
      context.handle(
        _exchangePairIdMeta,
        exchangePairId.isAcceptableOrUnknown(
          data['exchange_pair_id']!,
          _exchangePairIdMeta,
        ),
      );
    }
    if (data.containsKey('exchange_source_income_id')) {
      context.handle(
        _exchangeSourceIncomeIdMeta,
        exchangeSourceIncomeId.isAcceptableOrUnknown(
          data['exchange_source_income_id']!,
          _exchangeSourceIncomeIdMeta,
        ),
      );
    }
    if (data.containsKey('remaining_amount_text')) {
      context.handle(
        _remainingAmountTextMeta,
        remainingAmountText.isAcceptableOrUnknown(
          data['remaining_amount_text']!,
          _remainingAmountTextMeta,
        ),
      );
    }
    if (data.containsKey('activity_type')) {
      context.handle(
        _activityTypeMeta,
        activityType.isAcceptableOrUnknown(
          data['activity_type']!,
          _activityTypeMeta,
        ),
      );
    }
    if (data.containsKey('cost_basis_text')) {
      context.handle(
        _costBasisTextMeta,
        costBasisText.isAcceptableOrUnknown(
          data['cost_basis_text']!,
          _costBasisTextMeta,
        ),
      );
    }
    if (data.containsKey('sale_value_text')) {
      context.handle(
        _saleValueTextMeta,
        saleValueText.isAcceptableOrUnknown(
          data['sale_value_text']!,
          _saleValueTextMeta,
        ),
      );
    }
    if (data.containsKey('realized_gain_text')) {
      context.handle(
        _realizedGainTextMeta,
        realizedGainText.isAcceptableOrUnknown(
          data['realized_gain_text']!,
          _realizedGainTextMeta,
        ),
      );
    }
    if (data.containsKey('realized_gain_loss_currency')) {
      context.handle(
        _realizedGainLossCurrencyMeta,
        realizedGainLossCurrency.isAcceptableOrUnknown(
          data['realized_gain_loss_currency']!,
          _realizedGainLossCurrencyMeta,
        ),
      );
    }
    if (data.containsKey('metal_quantity_text')) {
      context.handle(
        _metalQuantityTextMeta,
        metalQuantityText.isAcceptableOrUnknown(
          data['metal_quantity_text']!,
          _metalQuantityTextMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      amountText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount_text'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      rolledOver: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}rolled_over'],
      )!,
      rolledAmountText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rolled_amount_text'],
      ),
      sourceIncomeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_income_id'],
      ),
      exchangePairId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exchange_pair_id'],
      ),
      exchangeSourceIncomeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exchange_source_income_id'],
      ),
      remainingAmountText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remaining_amount_text'],
      ),
      activityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_type'],
      ),
      costBasisText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cost_basis_text'],
      ),
      saleValueText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_value_text'],
      ),
      realizedGainText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}realized_gain_text'],
      ),
      realizedGainLossCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}realized_gain_loss_currency'],
      ),
      metalQuantityText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metal_quantity_text'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final String id;
  final String type;
  final String date;
  final String amountText;
  final String currency;
  final String category;
  final String description;
  final String createdAt;
  final bool rolledOver;
  final String? rolledAmountText;
  final String? sourceIncomeId;
  final String? exchangePairId;
  final String? exchangeSourceIncomeId;
  final String? remainingAmountText;
  final String? activityType;
  final String? costBasisText;
  final String? saleValueText;
  final String? realizedGainText;
  final String? realizedGainLossCurrency;
  final String? metalQuantityText;
  final String updatedAt;
  final String? deletedAt;
  const Transaction({
    required this.id,
    required this.type,
    required this.date,
    required this.amountText,
    required this.currency,
    required this.category,
    required this.description,
    required this.createdAt,
    required this.rolledOver,
    this.rolledAmountText,
    this.sourceIncomeId,
    this.exchangePairId,
    this.exchangeSourceIncomeId,
    this.remainingAmountText,
    this.activityType,
    this.costBasisText,
    this.saleValueText,
    this.realizedGainText,
    this.realizedGainLossCurrency,
    this.metalQuantityText,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['date'] = Variable<String>(date);
    map['amount_text'] = Variable<String>(amountText);
    map['currency'] = Variable<String>(currency);
    map['category'] = Variable<String>(category);
    map['description'] = Variable<String>(description);
    map['created_at'] = Variable<String>(createdAt);
    map['rolled_over'] = Variable<bool>(rolledOver);
    if (!nullToAbsent || rolledAmountText != null) {
      map['rolled_amount_text'] = Variable<String>(rolledAmountText);
    }
    if (!nullToAbsent || sourceIncomeId != null) {
      map['source_income_id'] = Variable<String>(sourceIncomeId);
    }
    if (!nullToAbsent || exchangePairId != null) {
      map['exchange_pair_id'] = Variable<String>(exchangePairId);
    }
    if (!nullToAbsent || exchangeSourceIncomeId != null) {
      map['exchange_source_income_id'] = Variable<String>(
        exchangeSourceIncomeId,
      );
    }
    if (!nullToAbsent || remainingAmountText != null) {
      map['remaining_amount_text'] = Variable<String>(remainingAmountText);
    }
    if (!nullToAbsent || activityType != null) {
      map['activity_type'] = Variable<String>(activityType);
    }
    if (!nullToAbsent || costBasisText != null) {
      map['cost_basis_text'] = Variable<String>(costBasisText);
    }
    if (!nullToAbsent || saleValueText != null) {
      map['sale_value_text'] = Variable<String>(saleValueText);
    }
    if (!nullToAbsent || realizedGainText != null) {
      map['realized_gain_text'] = Variable<String>(realizedGainText);
    }
    if (!nullToAbsent || realizedGainLossCurrency != null) {
      map['realized_gain_loss_currency'] = Variable<String>(
        realizedGainLossCurrency,
      );
    }
    if (!nullToAbsent || metalQuantityText != null) {
      map['metal_quantity_text'] = Variable<String>(metalQuantityText);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      type: Value(type),
      date: Value(date),
      amountText: Value(amountText),
      currency: Value(currency),
      category: Value(category),
      description: Value(description),
      createdAt: Value(createdAt),
      rolledOver: Value(rolledOver),
      rolledAmountText: rolledAmountText == null && nullToAbsent
          ? const Value.absent()
          : Value(rolledAmountText),
      sourceIncomeId: sourceIncomeId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceIncomeId),
      exchangePairId: exchangePairId == null && nullToAbsent
          ? const Value.absent()
          : Value(exchangePairId),
      exchangeSourceIncomeId: exchangeSourceIncomeId == null && nullToAbsent
          ? const Value.absent()
          : Value(exchangeSourceIncomeId),
      remainingAmountText: remainingAmountText == null && nullToAbsent
          ? const Value.absent()
          : Value(remainingAmountText),
      activityType: activityType == null && nullToAbsent
          ? const Value.absent()
          : Value(activityType),
      costBasisText: costBasisText == null && nullToAbsent
          ? const Value.absent()
          : Value(costBasisText),
      saleValueText: saleValueText == null && nullToAbsent
          ? const Value.absent()
          : Value(saleValueText),
      realizedGainText: realizedGainText == null && nullToAbsent
          ? const Value.absent()
          : Value(realizedGainText),
      realizedGainLossCurrency: realizedGainLossCurrency == null && nullToAbsent
          ? const Value.absent()
          : Value(realizedGainLossCurrency),
      metalQuantityText: metalQuantityText == null && nullToAbsent
          ? const Value.absent()
          : Value(metalQuantityText),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      date: serializer.fromJson<String>(json['date']),
      amountText: serializer.fromJson<String>(json['amountText']),
      currency: serializer.fromJson<String>(json['currency']),
      category: serializer.fromJson<String>(json['category']),
      description: serializer.fromJson<String>(json['description']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      rolledOver: serializer.fromJson<bool>(json['rolledOver']),
      rolledAmountText: serializer.fromJson<String?>(json['rolledAmountText']),
      sourceIncomeId: serializer.fromJson<String?>(json['sourceIncomeId']),
      exchangePairId: serializer.fromJson<String?>(json['exchangePairId']),
      exchangeSourceIncomeId: serializer.fromJson<String?>(
        json['exchangeSourceIncomeId'],
      ),
      remainingAmountText: serializer.fromJson<String?>(
        json['remainingAmountText'],
      ),
      activityType: serializer.fromJson<String?>(json['activityType']),
      costBasisText: serializer.fromJson<String?>(json['costBasisText']),
      saleValueText: serializer.fromJson<String?>(json['saleValueText']),
      realizedGainText: serializer.fromJson<String?>(json['realizedGainText']),
      realizedGainLossCurrency: serializer.fromJson<String?>(
        json['realizedGainLossCurrency'],
      ),
      metalQuantityText: serializer.fromJson<String?>(
        json['metalQuantityText'],
      ),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'date': serializer.toJson<String>(date),
      'amountText': serializer.toJson<String>(amountText),
      'currency': serializer.toJson<String>(currency),
      'category': serializer.toJson<String>(category),
      'description': serializer.toJson<String>(description),
      'createdAt': serializer.toJson<String>(createdAt),
      'rolledOver': serializer.toJson<bool>(rolledOver),
      'rolledAmountText': serializer.toJson<String?>(rolledAmountText),
      'sourceIncomeId': serializer.toJson<String?>(sourceIncomeId),
      'exchangePairId': serializer.toJson<String?>(exchangePairId),
      'exchangeSourceIncomeId': serializer.toJson<String?>(
        exchangeSourceIncomeId,
      ),
      'remainingAmountText': serializer.toJson<String?>(remainingAmountText),
      'activityType': serializer.toJson<String?>(activityType),
      'costBasisText': serializer.toJson<String?>(costBasisText),
      'saleValueText': serializer.toJson<String?>(saleValueText),
      'realizedGainText': serializer.toJson<String?>(realizedGainText),
      'realizedGainLossCurrency': serializer.toJson<String?>(
        realizedGainLossCurrency,
      ),
      'metalQuantityText': serializer.toJson<String?>(metalQuantityText),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Transaction copyWith({
    String? id,
    String? type,
    String? date,
    String? amountText,
    String? currency,
    String? category,
    String? description,
    String? createdAt,
    bool? rolledOver,
    Value<String?> rolledAmountText = const Value.absent(),
    Value<String?> sourceIncomeId = const Value.absent(),
    Value<String?> exchangePairId = const Value.absent(),
    Value<String?> exchangeSourceIncomeId = const Value.absent(),
    Value<String?> remainingAmountText = const Value.absent(),
    Value<String?> activityType = const Value.absent(),
    Value<String?> costBasisText = const Value.absent(),
    Value<String?> saleValueText = const Value.absent(),
    Value<String?> realizedGainText = const Value.absent(),
    Value<String?> realizedGainLossCurrency = const Value.absent(),
    Value<String?> metalQuantityText = const Value.absent(),
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
  }) => Transaction(
    id: id ?? this.id,
    type: type ?? this.type,
    date: date ?? this.date,
    amountText: amountText ?? this.amountText,
    currency: currency ?? this.currency,
    category: category ?? this.category,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
    rolledOver: rolledOver ?? this.rolledOver,
    rolledAmountText: rolledAmountText.present
        ? rolledAmountText.value
        : this.rolledAmountText,
    sourceIncomeId: sourceIncomeId.present
        ? sourceIncomeId.value
        : this.sourceIncomeId,
    exchangePairId: exchangePairId.present
        ? exchangePairId.value
        : this.exchangePairId,
    exchangeSourceIncomeId: exchangeSourceIncomeId.present
        ? exchangeSourceIncomeId.value
        : this.exchangeSourceIncomeId,
    remainingAmountText: remainingAmountText.present
        ? remainingAmountText.value
        : this.remainingAmountText,
    activityType: activityType.present ? activityType.value : this.activityType,
    costBasisText: costBasisText.present
        ? costBasisText.value
        : this.costBasisText,
    saleValueText: saleValueText.present
        ? saleValueText.value
        : this.saleValueText,
    realizedGainText: realizedGainText.present
        ? realizedGainText.value
        : this.realizedGainText,
    realizedGainLossCurrency: realizedGainLossCurrency.present
        ? realizedGainLossCurrency.value
        : this.realizedGainLossCurrency,
    metalQuantityText: metalQuantityText.present
        ? metalQuantityText.value
        : this.metalQuantityText,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      date: data.date.present ? data.date.value : this.date,
      amountText: data.amountText.present
          ? data.amountText.value
          : this.amountText,
      currency: data.currency.present ? data.currency.value : this.currency,
      category: data.category.present ? data.category.value : this.category,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      rolledOver: data.rolledOver.present
          ? data.rolledOver.value
          : this.rolledOver,
      rolledAmountText: data.rolledAmountText.present
          ? data.rolledAmountText.value
          : this.rolledAmountText,
      sourceIncomeId: data.sourceIncomeId.present
          ? data.sourceIncomeId.value
          : this.sourceIncomeId,
      exchangePairId: data.exchangePairId.present
          ? data.exchangePairId.value
          : this.exchangePairId,
      exchangeSourceIncomeId: data.exchangeSourceIncomeId.present
          ? data.exchangeSourceIncomeId.value
          : this.exchangeSourceIncomeId,
      remainingAmountText: data.remainingAmountText.present
          ? data.remainingAmountText.value
          : this.remainingAmountText,
      activityType: data.activityType.present
          ? data.activityType.value
          : this.activityType,
      costBasisText: data.costBasisText.present
          ? data.costBasisText.value
          : this.costBasisText,
      saleValueText: data.saleValueText.present
          ? data.saleValueText.value
          : this.saleValueText,
      realizedGainText: data.realizedGainText.present
          ? data.realizedGainText.value
          : this.realizedGainText,
      realizedGainLossCurrency: data.realizedGainLossCurrency.present
          ? data.realizedGainLossCurrency.value
          : this.realizedGainLossCurrency,
      metalQuantityText: data.metalQuantityText.present
          ? data.metalQuantityText.value
          : this.metalQuantityText,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('date: $date, ')
          ..write('amountText: $amountText, ')
          ..write('currency: $currency, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('rolledOver: $rolledOver, ')
          ..write('rolledAmountText: $rolledAmountText, ')
          ..write('sourceIncomeId: $sourceIncomeId, ')
          ..write('exchangePairId: $exchangePairId, ')
          ..write('exchangeSourceIncomeId: $exchangeSourceIncomeId, ')
          ..write('remainingAmountText: $remainingAmountText, ')
          ..write('activityType: $activityType, ')
          ..write('costBasisText: $costBasisText, ')
          ..write('saleValueText: $saleValueText, ')
          ..write('realizedGainText: $realizedGainText, ')
          ..write('realizedGainLossCurrency: $realizedGainLossCurrency, ')
          ..write('metalQuantityText: $metalQuantityText, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    type,
    date,
    amountText,
    currency,
    category,
    description,
    createdAt,
    rolledOver,
    rolledAmountText,
    sourceIncomeId,
    exchangePairId,
    exchangeSourceIncomeId,
    remainingAmountText,
    activityType,
    costBasisText,
    saleValueText,
    realizedGainText,
    realizedGainLossCurrency,
    metalQuantityText,
    updatedAt,
    deletedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.type == this.type &&
          other.date == this.date &&
          other.amountText == this.amountText &&
          other.currency == this.currency &&
          other.category == this.category &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.rolledOver == this.rolledOver &&
          other.rolledAmountText == this.rolledAmountText &&
          other.sourceIncomeId == this.sourceIncomeId &&
          other.exchangePairId == this.exchangePairId &&
          other.exchangeSourceIncomeId == this.exchangeSourceIncomeId &&
          other.remainingAmountText == this.remainingAmountText &&
          other.activityType == this.activityType &&
          other.costBasisText == this.costBasisText &&
          other.saleValueText == this.saleValueText &&
          other.realizedGainText == this.realizedGainText &&
          other.realizedGainLossCurrency == this.realizedGainLossCurrency &&
          other.metalQuantityText == this.metalQuantityText &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> date;
  final Value<String> amountText;
  final Value<String> currency;
  final Value<String> category;
  final Value<String> description;
  final Value<String> createdAt;
  final Value<bool> rolledOver;
  final Value<String?> rolledAmountText;
  final Value<String?> sourceIncomeId;
  final Value<String?> exchangePairId;
  final Value<String?> exchangeSourceIncomeId;
  final Value<String?> remainingAmountText;
  final Value<String?> activityType;
  final Value<String?> costBasisText;
  final Value<String?> saleValueText;
  final Value<String?> realizedGainText;
  final Value<String?> realizedGainLossCurrency;
  final Value<String?> metalQuantityText;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.date = const Value.absent(),
    this.amountText = const Value.absent(),
    this.currency = const Value.absent(),
    this.category = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rolledOver = const Value.absent(),
    this.rolledAmountText = const Value.absent(),
    this.sourceIncomeId = const Value.absent(),
    this.exchangePairId = const Value.absent(),
    this.exchangeSourceIncomeId = const Value.absent(),
    this.remainingAmountText = const Value.absent(),
    this.activityType = const Value.absent(),
    this.costBasisText = const Value.absent(),
    this.saleValueText = const Value.absent(),
    this.realizedGainText = const Value.absent(),
    this.realizedGainLossCurrency = const Value.absent(),
    this.metalQuantityText = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    required String type,
    required String date,
    required String amountText,
    required String currency,
    required String category,
    required String description,
    required String createdAt,
    this.rolledOver = const Value.absent(),
    this.rolledAmountText = const Value.absent(),
    this.sourceIncomeId = const Value.absent(),
    this.exchangePairId = const Value.absent(),
    this.exchangeSourceIncomeId = const Value.absent(),
    this.remainingAmountText = const Value.absent(),
    this.activityType = const Value.absent(),
    this.costBasisText = const Value.absent(),
    this.saleValueText = const Value.absent(),
    this.realizedGainText = const Value.absent(),
    this.realizedGainLossCurrency = const Value.absent(),
    this.metalQuantityText = const Value.absent(),
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       date = Value(date),
       amountText = Value(amountText),
       currency = Value(currency),
       category = Value(category),
       description = Value(description),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Transaction> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? date,
    Expression<String>? amountText,
    Expression<String>? currency,
    Expression<String>? category,
    Expression<String>? description,
    Expression<String>? createdAt,
    Expression<bool>? rolledOver,
    Expression<String>? rolledAmountText,
    Expression<String>? sourceIncomeId,
    Expression<String>? exchangePairId,
    Expression<String>? exchangeSourceIncomeId,
    Expression<String>? remainingAmountText,
    Expression<String>? activityType,
    Expression<String>? costBasisText,
    Expression<String>? saleValueText,
    Expression<String>? realizedGainText,
    Expression<String>? realizedGainLossCurrency,
    Expression<String>? metalQuantityText,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (date != null) 'date': date,
      if (amountText != null) 'amount_text': amountText,
      if (currency != null) 'currency': currency,
      if (category != null) 'category': category,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (rolledOver != null) 'rolled_over': rolledOver,
      if (rolledAmountText != null) 'rolled_amount_text': rolledAmountText,
      if (sourceIncomeId != null) 'source_income_id': sourceIncomeId,
      if (exchangePairId != null) 'exchange_pair_id': exchangePairId,
      if (exchangeSourceIncomeId != null)
        'exchange_source_income_id': exchangeSourceIncomeId,
      if (remainingAmountText != null)
        'remaining_amount_text': remainingAmountText,
      if (activityType != null) 'activity_type': activityType,
      if (costBasisText != null) 'cost_basis_text': costBasisText,
      if (saleValueText != null) 'sale_value_text': saleValueText,
      if (realizedGainText != null) 'realized_gain_text': realizedGainText,
      if (realizedGainLossCurrency != null)
        'realized_gain_loss_currency': realizedGainLossCurrency,
      if (metalQuantityText != null) 'metal_quantity_text': metalQuantityText,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? date,
    Value<String>? amountText,
    Value<String>? currency,
    Value<String>? category,
    Value<String>? description,
    Value<String>? createdAt,
    Value<bool>? rolledOver,
    Value<String?>? rolledAmountText,
    Value<String?>? sourceIncomeId,
    Value<String?>? exchangePairId,
    Value<String?>? exchangeSourceIncomeId,
    Value<String?>? remainingAmountText,
    Value<String?>? activityType,
    Value<String?>? costBasisText,
    Value<String?>? saleValueText,
    Value<String?>? realizedGainText,
    Value<String?>? realizedGainLossCurrency,
    Value<String?>? metalQuantityText,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      amountText: amountText ?? this.amountText,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      rolledOver: rolledOver ?? this.rolledOver,
      rolledAmountText: rolledAmountText ?? this.rolledAmountText,
      sourceIncomeId: sourceIncomeId ?? this.sourceIncomeId,
      exchangePairId: exchangePairId ?? this.exchangePairId,
      exchangeSourceIncomeId:
          exchangeSourceIncomeId ?? this.exchangeSourceIncomeId,
      remainingAmountText: remainingAmountText ?? this.remainingAmountText,
      activityType: activityType ?? this.activityType,
      costBasisText: costBasisText ?? this.costBasisText,
      saleValueText: saleValueText ?? this.saleValueText,
      realizedGainText: realizedGainText ?? this.realizedGainText,
      realizedGainLossCurrency:
          realizedGainLossCurrency ?? this.realizedGainLossCurrency,
      metalQuantityText: metalQuantityText ?? this.metalQuantityText,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (amountText.present) {
      map['amount_text'] = Variable<String>(amountText.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rolledOver.present) {
      map['rolled_over'] = Variable<bool>(rolledOver.value);
    }
    if (rolledAmountText.present) {
      map['rolled_amount_text'] = Variable<String>(rolledAmountText.value);
    }
    if (sourceIncomeId.present) {
      map['source_income_id'] = Variable<String>(sourceIncomeId.value);
    }
    if (exchangePairId.present) {
      map['exchange_pair_id'] = Variable<String>(exchangePairId.value);
    }
    if (exchangeSourceIncomeId.present) {
      map['exchange_source_income_id'] = Variable<String>(
        exchangeSourceIncomeId.value,
      );
    }
    if (remainingAmountText.present) {
      map['remaining_amount_text'] = Variable<String>(
        remainingAmountText.value,
      );
    }
    if (activityType.present) {
      map['activity_type'] = Variable<String>(activityType.value);
    }
    if (costBasisText.present) {
      map['cost_basis_text'] = Variable<String>(costBasisText.value);
    }
    if (saleValueText.present) {
      map['sale_value_text'] = Variable<String>(saleValueText.value);
    }
    if (realizedGainText.present) {
      map['realized_gain_text'] = Variable<String>(realizedGainText.value);
    }
    if (realizedGainLossCurrency.present) {
      map['realized_gain_loss_currency'] = Variable<String>(
        realizedGainLossCurrency.value,
      );
    }
    if (metalQuantityText.present) {
      map['metal_quantity_text'] = Variable<String>(metalQuantityText.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('date: $date, ')
          ..write('amountText: $amountText, ')
          ..write('currency: $currency, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('rolledOver: $rolledOver, ')
          ..write('rolledAmountText: $rolledAmountText, ')
          ..write('sourceIncomeId: $sourceIncomeId, ')
          ..write('exchangePairId: $exchangePairId, ')
          ..write('exchangeSourceIncomeId: $exchangeSourceIncomeId, ')
          ..write('remainingAmountText: $remainingAmountText, ')
          ..write('activityType: $activityType, ')
          ..write('costBasisText: $costBasisText, ')
          ..write('saleValueText: $saleValueText, ')
          ..write('realizedGainText: $realizedGainText, ')
          ..write('realizedGainLossCurrency: $realizedGainLossCurrency, ')
          ..write('metalQuantityText: $metalQuantityText, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavingsTable extends Savings with TableInfo<$SavingsTable, Saving> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetTypeMeta = const VerificationMeta(
    'assetType',
  );
  @override
  late final GeneratedColumn<String> assetType = GeneratedColumn<String>(
    'asset_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateAcquiredMeta = const VerificationMeta(
    'dateAcquired',
  );
  @override
  late final GeneratedColumn<String> dateAcquired = GeneratedColumn<String>(
    'date_acquired',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountTextMeta = const VerificationMeta(
    'amountText',
  );
  @override
  late final GeneratedColumn<String> amountText = GeneratedColumn<String>(
    'amount_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remainingAmountTextMeta =
      const VerificationMeta('remainingAmountText');
  @override
  late final GeneratedColumn<String> remainingAmountText =
      GeneratedColumn<String>(
        'remaining_amount_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _linkedCashEntryIdMeta = const VerificationMeta(
    'linkedCashEntryId',
  );
  @override
  late final GeneratedColumn<String> linkedCashEntryId =
      GeneratedColumn<String>(
        'linked_cash_entry_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _purchaseCurrencyMeta = const VerificationMeta(
    'purchaseCurrency',
  );
  @override
  late final GeneratedColumn<String> purchaseCurrency = GeneratedColumn<String>(
    'purchase_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purchaseAmountTextMeta =
      const VerificationMeta('purchaseAmountText');
  @override
  late final GeneratedColumn<String> purchaseAmountText =
      GeneratedColumn<String>(
        'purchase_amount_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIncomeIdMeta = const VerificationMeta(
    'sourceIncomeId',
  );
  @override
  late final GeneratedColumn<String> sourceIncomeId = GeneratedColumn<String>(
    'source_income_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exchangeSourceSavingIdMeta =
      const VerificationMeta('exchangeSourceSavingId');
  @override
  late final GeneratedColumn<String> exchangeSourceSavingId =
      GeneratedColumn<String>(
        'exchange_source_saving_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _exchangeSourceIncomeIdMeta =
      const VerificationMeta('exchangeSourceIncomeId');
  @override
  late final GeneratedColumn<String> exchangeSourceIncomeId =
      GeneratedColumn<String>(
        'exchange_source_income_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _internalTransferMeta = const VerificationMeta(
    'internalTransfer',
  );
  @override
  late final GeneratedColumn<bool> internalTransfer = GeneratedColumn<bool>(
    'internal_transfer',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("internal_transfer" IN (0, 1))',
    ),
  );
  static const VerificationMeta _internalTransferTypeMeta =
      const VerificationMeta('internalTransferType');
  @override
  late final GeneratedColumn<String> internalTransferType =
      GeneratedColumn<String>(
        'internal_transfer_type',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _fundingAllocationsJsonMeta =
      const VerificationMeta('fundingAllocationsJson');
  @override
  late final GeneratedColumn<String> fundingAllocationsJson =
      GeneratedColumn<String>(
        'funding_allocations_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _transferActivityIdMeta =
      const VerificationMeta('transferActivityId');
  @override
  late final GeneratedColumn<String> transferActivityId =
      GeneratedColumn<String>(
        'transfer_activity_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    assetType,
    dateAcquired,
    amountText,
    remainingAmountText,
    unit,
    description,
    linkedCashEntryId,
    purchaseCurrency,
    purchaseAmountText,
    createdAt,
    sourceIncomeId,
    exchangeSourceSavingId,
    exchangeSourceIncomeId,
    internalTransfer,
    internalTransferType,
    fundingAllocationsJson,
    transferActivityId,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'savings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Saving> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('asset_type')) {
      context.handle(
        _assetTypeMeta,
        assetType.isAcceptableOrUnknown(data['asset_type']!, _assetTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_assetTypeMeta);
    }
    if (data.containsKey('date_acquired')) {
      context.handle(
        _dateAcquiredMeta,
        dateAcquired.isAcceptableOrUnknown(
          data['date_acquired']!,
          _dateAcquiredMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dateAcquiredMeta);
    }
    if (data.containsKey('amount_text')) {
      context.handle(
        _amountTextMeta,
        amountText.isAcceptableOrUnknown(data['amount_text']!, _amountTextMeta),
      );
    } else if (isInserting) {
      context.missing(_amountTextMeta);
    }
    if (data.containsKey('remaining_amount_text')) {
      context.handle(
        _remainingAmountTextMeta,
        remainingAmountText.isAcceptableOrUnknown(
          data['remaining_amount_text']!,
          _remainingAmountTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remainingAmountTextMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('linked_cash_entry_id')) {
      context.handle(
        _linkedCashEntryIdMeta,
        linkedCashEntryId.isAcceptableOrUnknown(
          data['linked_cash_entry_id']!,
          _linkedCashEntryIdMeta,
        ),
      );
    }
    if (data.containsKey('purchase_currency')) {
      context.handle(
        _purchaseCurrencyMeta,
        purchaseCurrency.isAcceptableOrUnknown(
          data['purchase_currency']!,
          _purchaseCurrencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_purchaseCurrencyMeta);
    }
    if (data.containsKey('purchase_amount_text')) {
      context.handle(
        _purchaseAmountTextMeta,
        purchaseAmountText.isAcceptableOrUnknown(
          data['purchase_amount_text']!,
          _purchaseAmountTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_purchaseAmountTextMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('source_income_id')) {
      context.handle(
        _sourceIncomeIdMeta,
        sourceIncomeId.isAcceptableOrUnknown(
          data['source_income_id']!,
          _sourceIncomeIdMeta,
        ),
      );
    }
    if (data.containsKey('exchange_source_saving_id')) {
      context.handle(
        _exchangeSourceSavingIdMeta,
        exchangeSourceSavingId.isAcceptableOrUnknown(
          data['exchange_source_saving_id']!,
          _exchangeSourceSavingIdMeta,
        ),
      );
    }
    if (data.containsKey('exchange_source_income_id')) {
      context.handle(
        _exchangeSourceIncomeIdMeta,
        exchangeSourceIncomeId.isAcceptableOrUnknown(
          data['exchange_source_income_id']!,
          _exchangeSourceIncomeIdMeta,
        ),
      );
    }
    if (data.containsKey('internal_transfer')) {
      context.handle(
        _internalTransferMeta,
        internalTransfer.isAcceptableOrUnknown(
          data['internal_transfer']!,
          _internalTransferMeta,
        ),
      );
    }
    if (data.containsKey('internal_transfer_type')) {
      context.handle(
        _internalTransferTypeMeta,
        internalTransferType.isAcceptableOrUnknown(
          data['internal_transfer_type']!,
          _internalTransferTypeMeta,
        ),
      );
    }
    if (data.containsKey('funding_allocations_json')) {
      context.handle(
        _fundingAllocationsJsonMeta,
        fundingAllocationsJson.isAcceptableOrUnknown(
          data['funding_allocations_json']!,
          _fundingAllocationsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fundingAllocationsJsonMeta);
    }
    if (data.containsKey('transfer_activity_id')) {
      context.handle(
        _transferActivityIdMeta,
        transferActivityId.isAcceptableOrUnknown(
          data['transfer_activity_id']!,
          _transferActivityIdMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Saving map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Saving(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      assetType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_type'],
      )!,
      dateAcquired: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_acquired'],
      )!,
      amountText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount_text'],
      )!,
      remainingAmountText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remaining_amount_text'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      linkedCashEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_cash_entry_id'],
      ),
      purchaseCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purchase_currency'],
      )!,
      purchaseAmountText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purchase_amount_text'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      sourceIncomeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_income_id'],
      ),
      exchangeSourceSavingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exchange_source_saving_id'],
      ),
      exchangeSourceIncomeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exchange_source_income_id'],
      ),
      internalTransfer: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}internal_transfer'],
      ),
      internalTransferType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}internal_transfer_type'],
      ),
      fundingAllocationsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}funding_allocations_json'],
      )!,
      transferActivityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfer_activity_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $SavingsTable createAlias(String alias) {
    return $SavingsTable(attachedDatabase, alias);
  }
}

class Saving extends DataClass implements Insertable<Saving> {
  final String id;
  final String assetType;
  final String dateAcquired;
  final String amountText;
  final String remainingAmountText;
  final String unit;
  final String description;
  final String? linkedCashEntryId;
  final String purchaseCurrency;
  final String purchaseAmountText;
  final String createdAt;
  final String? sourceIncomeId;
  final String? exchangeSourceSavingId;
  final String? exchangeSourceIncomeId;
  final bool? internalTransfer;
  final String? internalTransferType;
  final String fundingAllocationsJson;
  final String? transferActivityId;
  final String updatedAt;
  final String? deletedAt;
  const Saving({
    required this.id,
    required this.assetType,
    required this.dateAcquired,
    required this.amountText,
    required this.remainingAmountText,
    required this.unit,
    required this.description,
    this.linkedCashEntryId,
    required this.purchaseCurrency,
    required this.purchaseAmountText,
    required this.createdAt,
    this.sourceIncomeId,
    this.exchangeSourceSavingId,
    this.exchangeSourceIncomeId,
    this.internalTransfer,
    this.internalTransferType,
    required this.fundingAllocationsJson,
    this.transferActivityId,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['asset_type'] = Variable<String>(assetType);
    map['date_acquired'] = Variable<String>(dateAcquired);
    map['amount_text'] = Variable<String>(amountText);
    map['remaining_amount_text'] = Variable<String>(remainingAmountText);
    map['unit'] = Variable<String>(unit);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || linkedCashEntryId != null) {
      map['linked_cash_entry_id'] = Variable<String>(linkedCashEntryId);
    }
    map['purchase_currency'] = Variable<String>(purchaseCurrency);
    map['purchase_amount_text'] = Variable<String>(purchaseAmountText);
    map['created_at'] = Variable<String>(createdAt);
    if (!nullToAbsent || sourceIncomeId != null) {
      map['source_income_id'] = Variable<String>(sourceIncomeId);
    }
    if (!nullToAbsent || exchangeSourceSavingId != null) {
      map['exchange_source_saving_id'] = Variable<String>(
        exchangeSourceSavingId,
      );
    }
    if (!nullToAbsent || exchangeSourceIncomeId != null) {
      map['exchange_source_income_id'] = Variable<String>(
        exchangeSourceIncomeId,
      );
    }
    if (!nullToAbsent || internalTransfer != null) {
      map['internal_transfer'] = Variable<bool>(internalTransfer);
    }
    if (!nullToAbsent || internalTransferType != null) {
      map['internal_transfer_type'] = Variable<String>(internalTransferType);
    }
    map['funding_allocations_json'] = Variable<String>(fundingAllocationsJson);
    if (!nullToAbsent || transferActivityId != null) {
      map['transfer_activity_id'] = Variable<String>(transferActivityId);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  SavingsCompanion toCompanion(bool nullToAbsent) {
    return SavingsCompanion(
      id: Value(id),
      assetType: Value(assetType),
      dateAcquired: Value(dateAcquired),
      amountText: Value(amountText),
      remainingAmountText: Value(remainingAmountText),
      unit: Value(unit),
      description: Value(description),
      linkedCashEntryId: linkedCashEntryId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedCashEntryId),
      purchaseCurrency: Value(purchaseCurrency),
      purchaseAmountText: Value(purchaseAmountText),
      createdAt: Value(createdAt),
      sourceIncomeId: sourceIncomeId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceIncomeId),
      exchangeSourceSavingId: exchangeSourceSavingId == null && nullToAbsent
          ? const Value.absent()
          : Value(exchangeSourceSavingId),
      exchangeSourceIncomeId: exchangeSourceIncomeId == null && nullToAbsent
          ? const Value.absent()
          : Value(exchangeSourceIncomeId),
      internalTransfer: internalTransfer == null && nullToAbsent
          ? const Value.absent()
          : Value(internalTransfer),
      internalTransferType: internalTransferType == null && nullToAbsent
          ? const Value.absent()
          : Value(internalTransferType),
      fundingAllocationsJson: Value(fundingAllocationsJson),
      transferActivityId: transferActivityId == null && nullToAbsent
          ? const Value.absent()
          : Value(transferActivityId),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Saving.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Saving(
      id: serializer.fromJson<String>(json['id']),
      assetType: serializer.fromJson<String>(json['assetType']),
      dateAcquired: serializer.fromJson<String>(json['dateAcquired']),
      amountText: serializer.fromJson<String>(json['amountText']),
      remainingAmountText: serializer.fromJson<String>(
        json['remainingAmountText'],
      ),
      unit: serializer.fromJson<String>(json['unit']),
      description: serializer.fromJson<String>(json['description']),
      linkedCashEntryId: serializer.fromJson<String?>(
        json['linkedCashEntryId'],
      ),
      purchaseCurrency: serializer.fromJson<String>(json['purchaseCurrency']),
      purchaseAmountText: serializer.fromJson<String>(
        json['purchaseAmountText'],
      ),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      sourceIncomeId: serializer.fromJson<String?>(json['sourceIncomeId']),
      exchangeSourceSavingId: serializer.fromJson<String?>(
        json['exchangeSourceSavingId'],
      ),
      exchangeSourceIncomeId: serializer.fromJson<String?>(
        json['exchangeSourceIncomeId'],
      ),
      internalTransfer: serializer.fromJson<bool?>(json['internalTransfer']),
      internalTransferType: serializer.fromJson<String?>(
        json['internalTransferType'],
      ),
      fundingAllocationsJson: serializer.fromJson<String>(
        json['fundingAllocationsJson'],
      ),
      transferActivityId: serializer.fromJson<String?>(
        json['transferActivityId'],
      ),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'assetType': serializer.toJson<String>(assetType),
      'dateAcquired': serializer.toJson<String>(dateAcquired),
      'amountText': serializer.toJson<String>(amountText),
      'remainingAmountText': serializer.toJson<String>(remainingAmountText),
      'unit': serializer.toJson<String>(unit),
      'description': serializer.toJson<String>(description),
      'linkedCashEntryId': serializer.toJson<String?>(linkedCashEntryId),
      'purchaseCurrency': serializer.toJson<String>(purchaseCurrency),
      'purchaseAmountText': serializer.toJson<String>(purchaseAmountText),
      'createdAt': serializer.toJson<String>(createdAt),
      'sourceIncomeId': serializer.toJson<String?>(sourceIncomeId),
      'exchangeSourceSavingId': serializer.toJson<String?>(
        exchangeSourceSavingId,
      ),
      'exchangeSourceIncomeId': serializer.toJson<String?>(
        exchangeSourceIncomeId,
      ),
      'internalTransfer': serializer.toJson<bool?>(internalTransfer),
      'internalTransferType': serializer.toJson<String?>(internalTransferType),
      'fundingAllocationsJson': serializer.toJson<String>(
        fundingAllocationsJson,
      ),
      'transferActivityId': serializer.toJson<String?>(transferActivityId),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Saving copyWith({
    String? id,
    String? assetType,
    String? dateAcquired,
    String? amountText,
    String? remainingAmountText,
    String? unit,
    String? description,
    Value<String?> linkedCashEntryId = const Value.absent(),
    String? purchaseCurrency,
    String? purchaseAmountText,
    String? createdAt,
    Value<String?> sourceIncomeId = const Value.absent(),
    Value<String?> exchangeSourceSavingId = const Value.absent(),
    Value<String?> exchangeSourceIncomeId = const Value.absent(),
    Value<bool?> internalTransfer = const Value.absent(),
    Value<String?> internalTransferType = const Value.absent(),
    String? fundingAllocationsJson,
    Value<String?> transferActivityId = const Value.absent(),
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
  }) => Saving(
    id: id ?? this.id,
    assetType: assetType ?? this.assetType,
    dateAcquired: dateAcquired ?? this.dateAcquired,
    amountText: amountText ?? this.amountText,
    remainingAmountText: remainingAmountText ?? this.remainingAmountText,
    unit: unit ?? this.unit,
    description: description ?? this.description,
    linkedCashEntryId: linkedCashEntryId.present
        ? linkedCashEntryId.value
        : this.linkedCashEntryId,
    purchaseCurrency: purchaseCurrency ?? this.purchaseCurrency,
    purchaseAmountText: purchaseAmountText ?? this.purchaseAmountText,
    createdAt: createdAt ?? this.createdAt,
    sourceIncomeId: sourceIncomeId.present
        ? sourceIncomeId.value
        : this.sourceIncomeId,
    exchangeSourceSavingId: exchangeSourceSavingId.present
        ? exchangeSourceSavingId.value
        : this.exchangeSourceSavingId,
    exchangeSourceIncomeId: exchangeSourceIncomeId.present
        ? exchangeSourceIncomeId.value
        : this.exchangeSourceIncomeId,
    internalTransfer: internalTransfer.present
        ? internalTransfer.value
        : this.internalTransfer,
    internalTransferType: internalTransferType.present
        ? internalTransferType.value
        : this.internalTransferType,
    fundingAllocationsJson:
        fundingAllocationsJson ?? this.fundingAllocationsJson,
    transferActivityId: transferActivityId.present
        ? transferActivityId.value
        : this.transferActivityId,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Saving copyWithCompanion(SavingsCompanion data) {
    return Saving(
      id: data.id.present ? data.id.value : this.id,
      assetType: data.assetType.present ? data.assetType.value : this.assetType,
      dateAcquired: data.dateAcquired.present
          ? data.dateAcquired.value
          : this.dateAcquired,
      amountText: data.amountText.present
          ? data.amountText.value
          : this.amountText,
      remainingAmountText: data.remainingAmountText.present
          ? data.remainingAmountText.value
          : this.remainingAmountText,
      unit: data.unit.present ? data.unit.value : this.unit,
      description: data.description.present
          ? data.description.value
          : this.description,
      linkedCashEntryId: data.linkedCashEntryId.present
          ? data.linkedCashEntryId.value
          : this.linkedCashEntryId,
      purchaseCurrency: data.purchaseCurrency.present
          ? data.purchaseCurrency.value
          : this.purchaseCurrency,
      purchaseAmountText: data.purchaseAmountText.present
          ? data.purchaseAmountText.value
          : this.purchaseAmountText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sourceIncomeId: data.sourceIncomeId.present
          ? data.sourceIncomeId.value
          : this.sourceIncomeId,
      exchangeSourceSavingId: data.exchangeSourceSavingId.present
          ? data.exchangeSourceSavingId.value
          : this.exchangeSourceSavingId,
      exchangeSourceIncomeId: data.exchangeSourceIncomeId.present
          ? data.exchangeSourceIncomeId.value
          : this.exchangeSourceIncomeId,
      internalTransfer: data.internalTransfer.present
          ? data.internalTransfer.value
          : this.internalTransfer,
      internalTransferType: data.internalTransferType.present
          ? data.internalTransferType.value
          : this.internalTransferType,
      fundingAllocationsJson: data.fundingAllocationsJson.present
          ? data.fundingAllocationsJson.value
          : this.fundingAllocationsJson,
      transferActivityId: data.transferActivityId.present
          ? data.transferActivityId.value
          : this.transferActivityId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Saving(')
          ..write('id: $id, ')
          ..write('assetType: $assetType, ')
          ..write('dateAcquired: $dateAcquired, ')
          ..write('amountText: $amountText, ')
          ..write('remainingAmountText: $remainingAmountText, ')
          ..write('unit: $unit, ')
          ..write('description: $description, ')
          ..write('linkedCashEntryId: $linkedCashEntryId, ')
          ..write('purchaseCurrency: $purchaseCurrency, ')
          ..write('purchaseAmountText: $purchaseAmountText, ')
          ..write('createdAt: $createdAt, ')
          ..write('sourceIncomeId: $sourceIncomeId, ')
          ..write('exchangeSourceSavingId: $exchangeSourceSavingId, ')
          ..write('exchangeSourceIncomeId: $exchangeSourceIncomeId, ')
          ..write('internalTransfer: $internalTransfer, ')
          ..write('internalTransferType: $internalTransferType, ')
          ..write('fundingAllocationsJson: $fundingAllocationsJson, ')
          ..write('transferActivityId: $transferActivityId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    assetType,
    dateAcquired,
    amountText,
    remainingAmountText,
    unit,
    description,
    linkedCashEntryId,
    purchaseCurrency,
    purchaseAmountText,
    createdAt,
    sourceIncomeId,
    exchangeSourceSavingId,
    exchangeSourceIncomeId,
    internalTransfer,
    internalTransferType,
    fundingAllocationsJson,
    transferActivityId,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Saving &&
          other.id == this.id &&
          other.assetType == this.assetType &&
          other.dateAcquired == this.dateAcquired &&
          other.amountText == this.amountText &&
          other.remainingAmountText == this.remainingAmountText &&
          other.unit == this.unit &&
          other.description == this.description &&
          other.linkedCashEntryId == this.linkedCashEntryId &&
          other.purchaseCurrency == this.purchaseCurrency &&
          other.purchaseAmountText == this.purchaseAmountText &&
          other.createdAt == this.createdAt &&
          other.sourceIncomeId == this.sourceIncomeId &&
          other.exchangeSourceSavingId == this.exchangeSourceSavingId &&
          other.exchangeSourceIncomeId == this.exchangeSourceIncomeId &&
          other.internalTransfer == this.internalTransfer &&
          other.internalTransferType == this.internalTransferType &&
          other.fundingAllocationsJson == this.fundingAllocationsJson &&
          other.transferActivityId == this.transferActivityId &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class SavingsCompanion extends UpdateCompanion<Saving> {
  final Value<String> id;
  final Value<String> assetType;
  final Value<String> dateAcquired;
  final Value<String> amountText;
  final Value<String> remainingAmountText;
  final Value<String> unit;
  final Value<String> description;
  final Value<String?> linkedCashEntryId;
  final Value<String> purchaseCurrency;
  final Value<String> purchaseAmountText;
  final Value<String> createdAt;
  final Value<String?> sourceIncomeId;
  final Value<String?> exchangeSourceSavingId;
  final Value<String?> exchangeSourceIncomeId;
  final Value<bool?> internalTransfer;
  final Value<String?> internalTransferType;
  final Value<String> fundingAllocationsJson;
  final Value<String?> transferActivityId;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const SavingsCompanion({
    this.id = const Value.absent(),
    this.assetType = const Value.absent(),
    this.dateAcquired = const Value.absent(),
    this.amountText = const Value.absent(),
    this.remainingAmountText = const Value.absent(),
    this.unit = const Value.absent(),
    this.description = const Value.absent(),
    this.linkedCashEntryId = const Value.absent(),
    this.purchaseCurrency = const Value.absent(),
    this.purchaseAmountText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sourceIncomeId = const Value.absent(),
    this.exchangeSourceSavingId = const Value.absent(),
    this.exchangeSourceIncomeId = const Value.absent(),
    this.internalTransfer = const Value.absent(),
    this.internalTransferType = const Value.absent(),
    this.fundingAllocationsJson = const Value.absent(),
    this.transferActivityId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavingsCompanion.insert({
    required String id,
    required String assetType,
    required String dateAcquired,
    required String amountText,
    required String remainingAmountText,
    required String unit,
    required String description,
    this.linkedCashEntryId = const Value.absent(),
    required String purchaseCurrency,
    required String purchaseAmountText,
    required String createdAt,
    this.sourceIncomeId = const Value.absent(),
    this.exchangeSourceSavingId = const Value.absent(),
    this.exchangeSourceIncomeId = const Value.absent(),
    this.internalTransfer = const Value.absent(),
    this.internalTransferType = const Value.absent(),
    required String fundingAllocationsJson,
    this.transferActivityId = const Value.absent(),
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       assetType = Value(assetType),
       dateAcquired = Value(dateAcquired),
       amountText = Value(amountText),
       remainingAmountText = Value(remainingAmountText),
       unit = Value(unit),
       description = Value(description),
       purchaseCurrency = Value(purchaseCurrency),
       purchaseAmountText = Value(purchaseAmountText),
       createdAt = Value(createdAt),
       fundingAllocationsJson = Value(fundingAllocationsJson),
       updatedAt = Value(updatedAt);
  static Insertable<Saving> custom({
    Expression<String>? id,
    Expression<String>? assetType,
    Expression<String>? dateAcquired,
    Expression<String>? amountText,
    Expression<String>? remainingAmountText,
    Expression<String>? unit,
    Expression<String>? description,
    Expression<String>? linkedCashEntryId,
    Expression<String>? purchaseCurrency,
    Expression<String>? purchaseAmountText,
    Expression<String>? createdAt,
    Expression<String>? sourceIncomeId,
    Expression<String>? exchangeSourceSavingId,
    Expression<String>? exchangeSourceIncomeId,
    Expression<bool>? internalTransfer,
    Expression<String>? internalTransferType,
    Expression<String>? fundingAllocationsJson,
    Expression<String>? transferActivityId,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assetType != null) 'asset_type': assetType,
      if (dateAcquired != null) 'date_acquired': dateAcquired,
      if (amountText != null) 'amount_text': amountText,
      if (remainingAmountText != null)
        'remaining_amount_text': remainingAmountText,
      if (unit != null) 'unit': unit,
      if (description != null) 'description': description,
      if (linkedCashEntryId != null) 'linked_cash_entry_id': linkedCashEntryId,
      if (purchaseCurrency != null) 'purchase_currency': purchaseCurrency,
      if (purchaseAmountText != null)
        'purchase_amount_text': purchaseAmountText,
      if (createdAt != null) 'created_at': createdAt,
      if (sourceIncomeId != null) 'source_income_id': sourceIncomeId,
      if (exchangeSourceSavingId != null)
        'exchange_source_saving_id': exchangeSourceSavingId,
      if (exchangeSourceIncomeId != null)
        'exchange_source_income_id': exchangeSourceIncomeId,
      if (internalTransfer != null) 'internal_transfer': internalTransfer,
      if (internalTransferType != null)
        'internal_transfer_type': internalTransferType,
      if (fundingAllocationsJson != null)
        'funding_allocations_json': fundingAllocationsJson,
      if (transferActivityId != null)
        'transfer_activity_id': transferActivityId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavingsCompanion copyWith({
    Value<String>? id,
    Value<String>? assetType,
    Value<String>? dateAcquired,
    Value<String>? amountText,
    Value<String>? remainingAmountText,
    Value<String>? unit,
    Value<String>? description,
    Value<String?>? linkedCashEntryId,
    Value<String>? purchaseCurrency,
    Value<String>? purchaseAmountText,
    Value<String>? createdAt,
    Value<String?>? sourceIncomeId,
    Value<String?>? exchangeSourceSavingId,
    Value<String?>? exchangeSourceIncomeId,
    Value<bool?>? internalTransfer,
    Value<String?>? internalTransferType,
    Value<String>? fundingAllocationsJson,
    Value<String?>? transferActivityId,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return SavingsCompanion(
      id: id ?? this.id,
      assetType: assetType ?? this.assetType,
      dateAcquired: dateAcquired ?? this.dateAcquired,
      amountText: amountText ?? this.amountText,
      remainingAmountText: remainingAmountText ?? this.remainingAmountText,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      linkedCashEntryId: linkedCashEntryId ?? this.linkedCashEntryId,
      purchaseCurrency: purchaseCurrency ?? this.purchaseCurrency,
      purchaseAmountText: purchaseAmountText ?? this.purchaseAmountText,
      createdAt: createdAt ?? this.createdAt,
      sourceIncomeId: sourceIncomeId ?? this.sourceIncomeId,
      exchangeSourceSavingId:
          exchangeSourceSavingId ?? this.exchangeSourceSavingId,
      exchangeSourceIncomeId:
          exchangeSourceIncomeId ?? this.exchangeSourceIncomeId,
      internalTransfer: internalTransfer ?? this.internalTransfer,
      internalTransferType: internalTransferType ?? this.internalTransferType,
      fundingAllocationsJson:
          fundingAllocationsJson ?? this.fundingAllocationsJson,
      transferActivityId: transferActivityId ?? this.transferActivityId,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (assetType.present) {
      map['asset_type'] = Variable<String>(assetType.value);
    }
    if (dateAcquired.present) {
      map['date_acquired'] = Variable<String>(dateAcquired.value);
    }
    if (amountText.present) {
      map['amount_text'] = Variable<String>(amountText.value);
    }
    if (remainingAmountText.present) {
      map['remaining_amount_text'] = Variable<String>(
        remainingAmountText.value,
      );
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (linkedCashEntryId.present) {
      map['linked_cash_entry_id'] = Variable<String>(linkedCashEntryId.value);
    }
    if (purchaseCurrency.present) {
      map['purchase_currency'] = Variable<String>(purchaseCurrency.value);
    }
    if (purchaseAmountText.present) {
      map['purchase_amount_text'] = Variable<String>(purchaseAmountText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (sourceIncomeId.present) {
      map['source_income_id'] = Variable<String>(sourceIncomeId.value);
    }
    if (exchangeSourceSavingId.present) {
      map['exchange_source_saving_id'] = Variable<String>(
        exchangeSourceSavingId.value,
      );
    }
    if (exchangeSourceIncomeId.present) {
      map['exchange_source_income_id'] = Variable<String>(
        exchangeSourceIncomeId.value,
      );
    }
    if (internalTransfer.present) {
      map['internal_transfer'] = Variable<bool>(internalTransfer.value);
    }
    if (internalTransferType.present) {
      map['internal_transfer_type'] = Variable<String>(
        internalTransferType.value,
      );
    }
    if (fundingAllocationsJson.present) {
      map['funding_allocations_json'] = Variable<String>(
        fundingAllocationsJson.value,
      );
    }
    if (transferActivityId.present) {
      map['transfer_activity_id'] = Variable<String>(transferActivityId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavingsCompanion(')
          ..write('id: $id, ')
          ..write('assetType: $assetType, ')
          ..write('dateAcquired: $dateAcquired, ')
          ..write('amountText: $amountText, ')
          ..write('remainingAmountText: $remainingAmountText, ')
          ..write('unit: $unit, ')
          ..write('description: $description, ')
          ..write('linkedCashEntryId: $linkedCashEntryId, ')
          ..write('purchaseCurrency: $purchaseCurrency, ')
          ..write('purchaseAmountText: $purchaseAmountText, ')
          ..write('createdAt: $createdAt, ')
          ..write('sourceIncomeId: $sourceIncomeId, ')
          ..write('exchangeSourceSavingId: $exchangeSourceSavingId, ')
          ..write('exchangeSourceIncomeId: $exchangeSourceIncomeId, ')
          ..write('internalTransfer: $internalTransfer, ')
          ..write('internalTransferType: $internalTransferType, ')
          ..write('fundingAllocationsJson: $fundingAllocationsJson, ')
          ..write('transferActivityId: $transferActivityId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InvestmentsTable extends Investments
    with TableInfo<$InvestmentsTable, Investment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvestmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _investmentTypeMeta = const VerificationMeta(
    'investmentType',
  );
  @override
  late final GeneratedColumn<String> investmentType = GeneratedColumn<String>(
    'investment_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetSubtypeMeta = const VerificationMeta(
    'assetSubtype',
  );
  @override
  late final GeneratedColumn<String> assetSubtype = GeneratedColumn<String>(
    'asset_subtype',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownershipTypeMeta = const VerificationMeta(
    'ownershipType',
  );
  @override
  late final GeneratedColumn<String> ownershipType = GeneratedColumn<String>(
    'ownership_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valuationModeMeta = const VerificationMeta(
    'valuationMode',
  );
  @override
  late final GeneratedColumn<String> valuationMode = GeneratedColumn<String>(
    'valuation_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalPriceTextMeta = const VerificationMeta(
    'originalPriceText',
  );
  @override
  late final GeneratedColumn<String> originalPriceText =
      GeneratedColumn<String>(
        'original_price_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _totalInterestTextMeta = const VerificationMeta(
    'totalInterestText',
  );
  @override
  late final GeneratedColumn<String> totalInterestText =
      GeneratedColumn<String>(
        'total_interest_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _totalPayableTextMeta = const VerificationMeta(
    'totalPayableText',
  );
  @override
  late final GeneratedColumn<String> totalPayableText = GeneratedColumn<String>(
    'total_payable_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paidAmountTextMeta = const VerificationMeta(
    'paidAmountText',
  );
  @override
  late final GeneratedColumn<String> paidAmountText = GeneratedColumn<String>(
    'paid_amount_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remainingAmountTextMeta =
      const VerificationMeta('remainingAmountText');
  @override
  late final GeneratedColumn<String> remainingAmountText =
      GeneratedColumn<String>(
        'remaining_amount_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _installmentPlanJsonMeta =
      const VerificationMeta('installmentPlanJson');
  @override
  late final GeneratedColumn<String> installmentPlanJson =
      GeneratedColumn<String>(
        'installment_plan_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _valuationDateMeta = const VerificationMeta(
    'valuationDate',
  );
  @override
  late final GeneratedColumn<String> valuationDate = GeneratedColumn<String>(
    'valuation_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _marketValueTextMeta = const VerificationMeta(
    'marketValueText',
  );
  @override
  late final GeneratedColumn<String> marketValueText = GeneratedColumn<String>(
    'market_value_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _marketValueDateMeta = const VerificationMeta(
    'marketValueDate',
  );
  @override
  late final GeneratedColumn<String> marketValueDate = GeneratedColumn<String>(
    'market_value_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valuationSourceMeta = const VerificationMeta(
    'valuationSource',
  );
  @override
  late final GeneratedColumn<String> valuationSource = GeneratedColumn<String>(
    'valuation_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loanBalanceTextMeta = const VerificationMeta(
    'loanBalanceText',
  );
  @override
  late final GeneratedColumn<String> loanBalanceText = GeneratedColumn<String>(
    'loan_balance_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loanAsOfDateMeta = const VerificationMeta(
    'loanAsOfDate',
  );
  @override
  late final GeneratedColumn<String> loanAsOfDate = GeneratedColumn<String>(
    'loan_as_of_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paidAmountToDateTextMeta =
      const VerificationMeta('paidAmountToDateText');
  @override
  late final GeneratedColumn<String> paidAmountToDateText =
      GeneratedColumn<String>(
        'paid_amount_to_date_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _ownershipSharePctTextMeta =
      const VerificationMeta('ownershipSharePctText');
  @override
  late final GeneratedColumn<String> ownershipSharePctText =
      GeneratedColumn<String>(
        'ownership_share_pct_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _countryMeta = const VerificationMeta(
    'country',
  );
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inflationRateTextMeta = const VerificationMeta(
    'inflationRateText',
  );
  @override
  late final GeneratedColumn<String> inflationRateText =
      GeneratedColumn<String>(
        'inflation_rate_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _estimatedCurrentValueTextMeta =
      const VerificationMeta('estimatedCurrentValueText');
  @override
  late final GeneratedColumn<String> estimatedCurrentValueText =
      GeneratedColumn<String>(
        'estimated_current_value_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noZakatMeta = const VerificationMeta(
    'noZakat',
  );
  @override
  late final GeneratedColumn<bool> noZakat = GeneratedColumn<bool>(
    'no_zakat',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("no_zakat" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _yearlyGrowthRateTextMeta =
      const VerificationMeta('yearlyGrowthRateText');
  @override
  late final GeneratedColumn<String> yearlyGrowthRateText =
      GeneratedColumn<String>(
        'yearly_growth_rate_text',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    investmentType,
    assetSubtype,
    ownershipType,
    valuationMode,
    currency,
    originalPriceText,
    totalInterestText,
    totalPayableText,
    paidAmountText,
    remainingAmountText,
    installmentPlanJson,
    valuationDate,
    marketValueText,
    marketValueDate,
    valuationSource,
    loanBalanceText,
    loanAsOfDate,
    paidAmountToDateText,
    ownershipSharePctText,
    country,
    location,
    inflationRateText,
    estimatedCurrentValueText,
    description,
    noZakat,
    yearlyGrowthRateText,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'investments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Investment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('investment_type')) {
      context.handle(
        _investmentTypeMeta,
        investmentType.isAcceptableOrUnknown(
          data['investment_type']!,
          _investmentTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_investmentTypeMeta);
    }
    if (data.containsKey('asset_subtype')) {
      context.handle(
        _assetSubtypeMeta,
        assetSubtype.isAcceptableOrUnknown(
          data['asset_subtype']!,
          _assetSubtypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assetSubtypeMeta);
    }
    if (data.containsKey('ownership_type')) {
      context.handle(
        _ownershipTypeMeta,
        ownershipType.isAcceptableOrUnknown(
          data['ownership_type']!,
          _ownershipTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownershipTypeMeta);
    }
    if (data.containsKey('valuation_mode')) {
      context.handle(
        _valuationModeMeta,
        valuationMode.isAcceptableOrUnknown(
          data['valuation_mode']!,
          _valuationModeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_valuationModeMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('original_price_text')) {
      context.handle(
        _originalPriceTextMeta,
        originalPriceText.isAcceptableOrUnknown(
          data['original_price_text']!,
          _originalPriceTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalPriceTextMeta);
    }
    if (data.containsKey('total_interest_text')) {
      context.handle(
        _totalInterestTextMeta,
        totalInterestText.isAcceptableOrUnknown(
          data['total_interest_text']!,
          _totalInterestTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalInterestTextMeta);
    }
    if (data.containsKey('total_payable_text')) {
      context.handle(
        _totalPayableTextMeta,
        totalPayableText.isAcceptableOrUnknown(
          data['total_payable_text']!,
          _totalPayableTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalPayableTextMeta);
    }
    if (data.containsKey('paid_amount_text')) {
      context.handle(
        _paidAmountTextMeta,
        paidAmountText.isAcceptableOrUnknown(
          data['paid_amount_text']!,
          _paidAmountTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paidAmountTextMeta);
    }
    if (data.containsKey('remaining_amount_text')) {
      context.handle(
        _remainingAmountTextMeta,
        remainingAmountText.isAcceptableOrUnknown(
          data['remaining_amount_text']!,
          _remainingAmountTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remainingAmountTextMeta);
    }
    if (data.containsKey('installment_plan_json')) {
      context.handle(
        _installmentPlanJsonMeta,
        installmentPlanJson.isAcceptableOrUnknown(
          data['installment_plan_json']!,
          _installmentPlanJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_installmentPlanJsonMeta);
    }
    if (data.containsKey('valuation_date')) {
      context.handle(
        _valuationDateMeta,
        valuationDate.isAcceptableOrUnknown(
          data['valuation_date']!,
          _valuationDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_valuationDateMeta);
    }
    if (data.containsKey('market_value_text')) {
      context.handle(
        _marketValueTextMeta,
        marketValueText.isAcceptableOrUnknown(
          data['market_value_text']!,
          _marketValueTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_marketValueTextMeta);
    }
    if (data.containsKey('market_value_date')) {
      context.handle(
        _marketValueDateMeta,
        marketValueDate.isAcceptableOrUnknown(
          data['market_value_date']!,
          _marketValueDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_marketValueDateMeta);
    }
    if (data.containsKey('valuation_source')) {
      context.handle(
        _valuationSourceMeta,
        valuationSource.isAcceptableOrUnknown(
          data['valuation_source']!,
          _valuationSourceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_valuationSourceMeta);
    }
    if (data.containsKey('loan_balance_text')) {
      context.handle(
        _loanBalanceTextMeta,
        loanBalanceText.isAcceptableOrUnknown(
          data['loan_balance_text']!,
          _loanBalanceTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_loanBalanceTextMeta);
    }
    if (data.containsKey('loan_as_of_date')) {
      context.handle(
        _loanAsOfDateMeta,
        loanAsOfDate.isAcceptableOrUnknown(
          data['loan_as_of_date']!,
          _loanAsOfDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_loanAsOfDateMeta);
    }
    if (data.containsKey('paid_amount_to_date_text')) {
      context.handle(
        _paidAmountToDateTextMeta,
        paidAmountToDateText.isAcceptableOrUnknown(
          data['paid_amount_to_date_text']!,
          _paidAmountToDateTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paidAmountToDateTextMeta);
    }
    if (data.containsKey('ownership_share_pct_text')) {
      context.handle(
        _ownershipSharePctTextMeta,
        ownershipSharePctText.isAcceptableOrUnknown(
          data['ownership_share_pct_text']!,
          _ownershipSharePctTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownershipSharePctTextMeta);
    }
    if (data.containsKey('country')) {
      context.handle(
        _countryMeta,
        country.isAcceptableOrUnknown(data['country']!, _countryMeta),
      );
    } else if (isInserting) {
      context.missing(_countryMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    } else if (isInserting) {
      context.missing(_locationMeta);
    }
    if (data.containsKey('inflation_rate_text')) {
      context.handle(
        _inflationRateTextMeta,
        inflationRateText.isAcceptableOrUnknown(
          data['inflation_rate_text']!,
          _inflationRateTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_inflationRateTextMeta);
    }
    if (data.containsKey('estimated_current_value_text')) {
      context.handle(
        _estimatedCurrentValueTextMeta,
        estimatedCurrentValueText.isAcceptableOrUnknown(
          data['estimated_current_value_text']!,
          _estimatedCurrentValueTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_estimatedCurrentValueTextMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('no_zakat')) {
      context.handle(
        _noZakatMeta,
        noZakat.isAcceptableOrUnknown(data['no_zakat']!, _noZakatMeta),
      );
    }
    if (data.containsKey('yearly_growth_rate_text')) {
      context.handle(
        _yearlyGrowthRateTextMeta,
        yearlyGrowthRateText.isAcceptableOrUnknown(
          data['yearly_growth_rate_text']!,
          _yearlyGrowthRateTextMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Investment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Investment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      investmentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}investment_type'],
      )!,
      assetSubtype: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_subtype'],
      )!,
      ownershipType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ownership_type'],
      )!,
      valuationMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valuation_mode'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      originalPriceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_price_text'],
      )!,
      totalInterestText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}total_interest_text'],
      )!,
      totalPayableText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}total_payable_text'],
      )!,
      paidAmountText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paid_amount_text'],
      )!,
      remainingAmountText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remaining_amount_text'],
      )!,
      installmentPlanJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}installment_plan_json'],
      )!,
      valuationDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valuation_date'],
      )!,
      marketValueText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}market_value_text'],
      )!,
      marketValueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}market_value_date'],
      )!,
      valuationSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valuation_source'],
      )!,
      loanBalanceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loan_balance_text'],
      )!,
      loanAsOfDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loan_as_of_date'],
      )!,
      paidAmountToDateText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paid_amount_to_date_text'],
      )!,
      ownershipSharePctText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ownership_share_pct_text'],
      )!,
      country: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      inflationRateText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}inflation_rate_text'],
      )!,
      estimatedCurrentValueText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estimated_current_value_text'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      noZakat: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}no_zakat'],
      )!,
      yearlyGrowthRateText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}yearly_growth_rate_text'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $InvestmentsTable createAlias(String alias) {
    return $InvestmentsTable(attachedDatabase, alias);
  }
}

class Investment extends DataClass implements Insertable<Investment> {
  final String id;
  final String investmentType;
  final String assetSubtype;
  final String ownershipType;
  final String valuationMode;
  final String currency;
  final String originalPriceText;
  final String totalInterestText;
  final String totalPayableText;
  final String paidAmountText;
  final String remainingAmountText;
  final String installmentPlanJson;
  final String valuationDate;
  final String marketValueText;
  final String marketValueDate;
  final String valuationSource;
  final String loanBalanceText;
  final String loanAsOfDate;
  final String paidAmountToDateText;
  final String ownershipSharePctText;
  final String country;
  final String location;
  final String inflationRateText;
  final String estimatedCurrentValueText;
  final String description;
  final bool noZakat;
  final String? yearlyGrowthRateText;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  const Investment({
    required this.id,
    required this.investmentType,
    required this.assetSubtype,
    required this.ownershipType,
    required this.valuationMode,
    required this.currency,
    required this.originalPriceText,
    required this.totalInterestText,
    required this.totalPayableText,
    required this.paidAmountText,
    required this.remainingAmountText,
    required this.installmentPlanJson,
    required this.valuationDate,
    required this.marketValueText,
    required this.marketValueDate,
    required this.valuationSource,
    required this.loanBalanceText,
    required this.loanAsOfDate,
    required this.paidAmountToDateText,
    required this.ownershipSharePctText,
    required this.country,
    required this.location,
    required this.inflationRateText,
    required this.estimatedCurrentValueText,
    required this.description,
    required this.noZakat,
    this.yearlyGrowthRateText,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['investment_type'] = Variable<String>(investmentType);
    map['asset_subtype'] = Variable<String>(assetSubtype);
    map['ownership_type'] = Variable<String>(ownershipType);
    map['valuation_mode'] = Variable<String>(valuationMode);
    map['currency'] = Variable<String>(currency);
    map['original_price_text'] = Variable<String>(originalPriceText);
    map['total_interest_text'] = Variable<String>(totalInterestText);
    map['total_payable_text'] = Variable<String>(totalPayableText);
    map['paid_amount_text'] = Variable<String>(paidAmountText);
    map['remaining_amount_text'] = Variable<String>(remainingAmountText);
    map['installment_plan_json'] = Variable<String>(installmentPlanJson);
    map['valuation_date'] = Variable<String>(valuationDate);
    map['market_value_text'] = Variable<String>(marketValueText);
    map['market_value_date'] = Variable<String>(marketValueDate);
    map['valuation_source'] = Variable<String>(valuationSource);
    map['loan_balance_text'] = Variable<String>(loanBalanceText);
    map['loan_as_of_date'] = Variable<String>(loanAsOfDate);
    map['paid_amount_to_date_text'] = Variable<String>(paidAmountToDateText);
    map['ownership_share_pct_text'] = Variable<String>(ownershipSharePctText);
    map['country'] = Variable<String>(country);
    map['location'] = Variable<String>(location);
    map['inflation_rate_text'] = Variable<String>(inflationRateText);
    map['estimated_current_value_text'] = Variable<String>(
      estimatedCurrentValueText,
    );
    map['description'] = Variable<String>(description);
    map['no_zakat'] = Variable<bool>(noZakat);
    if (!nullToAbsent || yearlyGrowthRateText != null) {
      map['yearly_growth_rate_text'] = Variable<String>(yearlyGrowthRateText);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  InvestmentsCompanion toCompanion(bool nullToAbsent) {
    return InvestmentsCompanion(
      id: Value(id),
      investmentType: Value(investmentType),
      assetSubtype: Value(assetSubtype),
      ownershipType: Value(ownershipType),
      valuationMode: Value(valuationMode),
      currency: Value(currency),
      originalPriceText: Value(originalPriceText),
      totalInterestText: Value(totalInterestText),
      totalPayableText: Value(totalPayableText),
      paidAmountText: Value(paidAmountText),
      remainingAmountText: Value(remainingAmountText),
      installmentPlanJson: Value(installmentPlanJson),
      valuationDate: Value(valuationDate),
      marketValueText: Value(marketValueText),
      marketValueDate: Value(marketValueDate),
      valuationSource: Value(valuationSource),
      loanBalanceText: Value(loanBalanceText),
      loanAsOfDate: Value(loanAsOfDate),
      paidAmountToDateText: Value(paidAmountToDateText),
      ownershipSharePctText: Value(ownershipSharePctText),
      country: Value(country),
      location: Value(location),
      inflationRateText: Value(inflationRateText),
      estimatedCurrentValueText: Value(estimatedCurrentValueText),
      description: Value(description),
      noZakat: Value(noZakat),
      yearlyGrowthRateText: yearlyGrowthRateText == null && nullToAbsent
          ? const Value.absent()
          : Value(yearlyGrowthRateText),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Investment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Investment(
      id: serializer.fromJson<String>(json['id']),
      investmentType: serializer.fromJson<String>(json['investmentType']),
      assetSubtype: serializer.fromJson<String>(json['assetSubtype']),
      ownershipType: serializer.fromJson<String>(json['ownershipType']),
      valuationMode: serializer.fromJson<String>(json['valuationMode']),
      currency: serializer.fromJson<String>(json['currency']),
      originalPriceText: serializer.fromJson<String>(json['originalPriceText']),
      totalInterestText: serializer.fromJson<String>(json['totalInterestText']),
      totalPayableText: serializer.fromJson<String>(json['totalPayableText']),
      paidAmountText: serializer.fromJson<String>(json['paidAmountText']),
      remainingAmountText: serializer.fromJson<String>(
        json['remainingAmountText'],
      ),
      installmentPlanJson: serializer.fromJson<String>(
        json['installmentPlanJson'],
      ),
      valuationDate: serializer.fromJson<String>(json['valuationDate']),
      marketValueText: serializer.fromJson<String>(json['marketValueText']),
      marketValueDate: serializer.fromJson<String>(json['marketValueDate']),
      valuationSource: serializer.fromJson<String>(json['valuationSource']),
      loanBalanceText: serializer.fromJson<String>(json['loanBalanceText']),
      loanAsOfDate: serializer.fromJson<String>(json['loanAsOfDate']),
      paidAmountToDateText: serializer.fromJson<String>(
        json['paidAmountToDateText'],
      ),
      ownershipSharePctText: serializer.fromJson<String>(
        json['ownershipSharePctText'],
      ),
      country: serializer.fromJson<String>(json['country']),
      location: serializer.fromJson<String>(json['location']),
      inflationRateText: serializer.fromJson<String>(json['inflationRateText']),
      estimatedCurrentValueText: serializer.fromJson<String>(
        json['estimatedCurrentValueText'],
      ),
      description: serializer.fromJson<String>(json['description']),
      noZakat: serializer.fromJson<bool>(json['noZakat']),
      yearlyGrowthRateText: serializer.fromJson<String?>(
        json['yearlyGrowthRateText'],
      ),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'investmentType': serializer.toJson<String>(investmentType),
      'assetSubtype': serializer.toJson<String>(assetSubtype),
      'ownershipType': serializer.toJson<String>(ownershipType),
      'valuationMode': serializer.toJson<String>(valuationMode),
      'currency': serializer.toJson<String>(currency),
      'originalPriceText': serializer.toJson<String>(originalPriceText),
      'totalInterestText': serializer.toJson<String>(totalInterestText),
      'totalPayableText': serializer.toJson<String>(totalPayableText),
      'paidAmountText': serializer.toJson<String>(paidAmountText),
      'remainingAmountText': serializer.toJson<String>(remainingAmountText),
      'installmentPlanJson': serializer.toJson<String>(installmentPlanJson),
      'valuationDate': serializer.toJson<String>(valuationDate),
      'marketValueText': serializer.toJson<String>(marketValueText),
      'marketValueDate': serializer.toJson<String>(marketValueDate),
      'valuationSource': serializer.toJson<String>(valuationSource),
      'loanBalanceText': serializer.toJson<String>(loanBalanceText),
      'loanAsOfDate': serializer.toJson<String>(loanAsOfDate),
      'paidAmountToDateText': serializer.toJson<String>(paidAmountToDateText),
      'ownershipSharePctText': serializer.toJson<String>(ownershipSharePctText),
      'country': serializer.toJson<String>(country),
      'location': serializer.toJson<String>(location),
      'inflationRateText': serializer.toJson<String>(inflationRateText),
      'estimatedCurrentValueText': serializer.toJson<String>(
        estimatedCurrentValueText,
      ),
      'description': serializer.toJson<String>(description),
      'noZakat': serializer.toJson<bool>(noZakat),
      'yearlyGrowthRateText': serializer.toJson<String?>(yearlyGrowthRateText),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Investment copyWith({
    String? id,
    String? investmentType,
    String? assetSubtype,
    String? ownershipType,
    String? valuationMode,
    String? currency,
    String? originalPriceText,
    String? totalInterestText,
    String? totalPayableText,
    String? paidAmountText,
    String? remainingAmountText,
    String? installmentPlanJson,
    String? valuationDate,
    String? marketValueText,
    String? marketValueDate,
    String? valuationSource,
    String? loanBalanceText,
    String? loanAsOfDate,
    String? paidAmountToDateText,
    String? ownershipSharePctText,
    String? country,
    String? location,
    String? inflationRateText,
    String? estimatedCurrentValueText,
    String? description,
    bool? noZakat,
    Value<String?> yearlyGrowthRateText = const Value.absent(),
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
  }) => Investment(
    id: id ?? this.id,
    investmentType: investmentType ?? this.investmentType,
    assetSubtype: assetSubtype ?? this.assetSubtype,
    ownershipType: ownershipType ?? this.ownershipType,
    valuationMode: valuationMode ?? this.valuationMode,
    currency: currency ?? this.currency,
    originalPriceText: originalPriceText ?? this.originalPriceText,
    totalInterestText: totalInterestText ?? this.totalInterestText,
    totalPayableText: totalPayableText ?? this.totalPayableText,
    paidAmountText: paidAmountText ?? this.paidAmountText,
    remainingAmountText: remainingAmountText ?? this.remainingAmountText,
    installmentPlanJson: installmentPlanJson ?? this.installmentPlanJson,
    valuationDate: valuationDate ?? this.valuationDate,
    marketValueText: marketValueText ?? this.marketValueText,
    marketValueDate: marketValueDate ?? this.marketValueDate,
    valuationSource: valuationSource ?? this.valuationSource,
    loanBalanceText: loanBalanceText ?? this.loanBalanceText,
    loanAsOfDate: loanAsOfDate ?? this.loanAsOfDate,
    paidAmountToDateText: paidAmountToDateText ?? this.paidAmountToDateText,
    ownershipSharePctText: ownershipSharePctText ?? this.ownershipSharePctText,
    country: country ?? this.country,
    location: location ?? this.location,
    inflationRateText: inflationRateText ?? this.inflationRateText,
    estimatedCurrentValueText:
        estimatedCurrentValueText ?? this.estimatedCurrentValueText,
    description: description ?? this.description,
    noZakat: noZakat ?? this.noZakat,
    yearlyGrowthRateText: yearlyGrowthRateText.present
        ? yearlyGrowthRateText.value
        : this.yearlyGrowthRateText,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Investment copyWithCompanion(InvestmentsCompanion data) {
    return Investment(
      id: data.id.present ? data.id.value : this.id,
      investmentType: data.investmentType.present
          ? data.investmentType.value
          : this.investmentType,
      assetSubtype: data.assetSubtype.present
          ? data.assetSubtype.value
          : this.assetSubtype,
      ownershipType: data.ownershipType.present
          ? data.ownershipType.value
          : this.ownershipType,
      valuationMode: data.valuationMode.present
          ? data.valuationMode.value
          : this.valuationMode,
      currency: data.currency.present ? data.currency.value : this.currency,
      originalPriceText: data.originalPriceText.present
          ? data.originalPriceText.value
          : this.originalPriceText,
      totalInterestText: data.totalInterestText.present
          ? data.totalInterestText.value
          : this.totalInterestText,
      totalPayableText: data.totalPayableText.present
          ? data.totalPayableText.value
          : this.totalPayableText,
      paidAmountText: data.paidAmountText.present
          ? data.paidAmountText.value
          : this.paidAmountText,
      remainingAmountText: data.remainingAmountText.present
          ? data.remainingAmountText.value
          : this.remainingAmountText,
      installmentPlanJson: data.installmentPlanJson.present
          ? data.installmentPlanJson.value
          : this.installmentPlanJson,
      valuationDate: data.valuationDate.present
          ? data.valuationDate.value
          : this.valuationDate,
      marketValueText: data.marketValueText.present
          ? data.marketValueText.value
          : this.marketValueText,
      marketValueDate: data.marketValueDate.present
          ? data.marketValueDate.value
          : this.marketValueDate,
      valuationSource: data.valuationSource.present
          ? data.valuationSource.value
          : this.valuationSource,
      loanBalanceText: data.loanBalanceText.present
          ? data.loanBalanceText.value
          : this.loanBalanceText,
      loanAsOfDate: data.loanAsOfDate.present
          ? data.loanAsOfDate.value
          : this.loanAsOfDate,
      paidAmountToDateText: data.paidAmountToDateText.present
          ? data.paidAmountToDateText.value
          : this.paidAmountToDateText,
      ownershipSharePctText: data.ownershipSharePctText.present
          ? data.ownershipSharePctText.value
          : this.ownershipSharePctText,
      country: data.country.present ? data.country.value : this.country,
      location: data.location.present ? data.location.value : this.location,
      inflationRateText: data.inflationRateText.present
          ? data.inflationRateText.value
          : this.inflationRateText,
      estimatedCurrentValueText: data.estimatedCurrentValueText.present
          ? data.estimatedCurrentValueText.value
          : this.estimatedCurrentValueText,
      description: data.description.present
          ? data.description.value
          : this.description,
      noZakat: data.noZakat.present ? data.noZakat.value : this.noZakat,
      yearlyGrowthRateText: data.yearlyGrowthRateText.present
          ? data.yearlyGrowthRateText.value
          : this.yearlyGrowthRateText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Investment(')
          ..write('id: $id, ')
          ..write('investmentType: $investmentType, ')
          ..write('assetSubtype: $assetSubtype, ')
          ..write('ownershipType: $ownershipType, ')
          ..write('valuationMode: $valuationMode, ')
          ..write('currency: $currency, ')
          ..write('originalPriceText: $originalPriceText, ')
          ..write('totalInterestText: $totalInterestText, ')
          ..write('totalPayableText: $totalPayableText, ')
          ..write('paidAmountText: $paidAmountText, ')
          ..write('remainingAmountText: $remainingAmountText, ')
          ..write('installmentPlanJson: $installmentPlanJson, ')
          ..write('valuationDate: $valuationDate, ')
          ..write('marketValueText: $marketValueText, ')
          ..write('marketValueDate: $marketValueDate, ')
          ..write('valuationSource: $valuationSource, ')
          ..write('loanBalanceText: $loanBalanceText, ')
          ..write('loanAsOfDate: $loanAsOfDate, ')
          ..write('paidAmountToDateText: $paidAmountToDateText, ')
          ..write('ownershipSharePctText: $ownershipSharePctText, ')
          ..write('country: $country, ')
          ..write('location: $location, ')
          ..write('inflationRateText: $inflationRateText, ')
          ..write('estimatedCurrentValueText: $estimatedCurrentValueText, ')
          ..write('description: $description, ')
          ..write('noZakat: $noZakat, ')
          ..write('yearlyGrowthRateText: $yearlyGrowthRateText, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    investmentType,
    assetSubtype,
    ownershipType,
    valuationMode,
    currency,
    originalPriceText,
    totalInterestText,
    totalPayableText,
    paidAmountText,
    remainingAmountText,
    installmentPlanJson,
    valuationDate,
    marketValueText,
    marketValueDate,
    valuationSource,
    loanBalanceText,
    loanAsOfDate,
    paidAmountToDateText,
    ownershipSharePctText,
    country,
    location,
    inflationRateText,
    estimatedCurrentValueText,
    description,
    noZakat,
    yearlyGrowthRateText,
    createdAt,
    updatedAt,
    deletedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Investment &&
          other.id == this.id &&
          other.investmentType == this.investmentType &&
          other.assetSubtype == this.assetSubtype &&
          other.ownershipType == this.ownershipType &&
          other.valuationMode == this.valuationMode &&
          other.currency == this.currency &&
          other.originalPriceText == this.originalPriceText &&
          other.totalInterestText == this.totalInterestText &&
          other.totalPayableText == this.totalPayableText &&
          other.paidAmountText == this.paidAmountText &&
          other.remainingAmountText == this.remainingAmountText &&
          other.installmentPlanJson == this.installmentPlanJson &&
          other.valuationDate == this.valuationDate &&
          other.marketValueText == this.marketValueText &&
          other.marketValueDate == this.marketValueDate &&
          other.valuationSource == this.valuationSource &&
          other.loanBalanceText == this.loanBalanceText &&
          other.loanAsOfDate == this.loanAsOfDate &&
          other.paidAmountToDateText == this.paidAmountToDateText &&
          other.ownershipSharePctText == this.ownershipSharePctText &&
          other.country == this.country &&
          other.location == this.location &&
          other.inflationRateText == this.inflationRateText &&
          other.estimatedCurrentValueText == this.estimatedCurrentValueText &&
          other.description == this.description &&
          other.noZakat == this.noZakat &&
          other.yearlyGrowthRateText == this.yearlyGrowthRateText &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class InvestmentsCompanion extends UpdateCompanion<Investment> {
  final Value<String> id;
  final Value<String> investmentType;
  final Value<String> assetSubtype;
  final Value<String> ownershipType;
  final Value<String> valuationMode;
  final Value<String> currency;
  final Value<String> originalPriceText;
  final Value<String> totalInterestText;
  final Value<String> totalPayableText;
  final Value<String> paidAmountText;
  final Value<String> remainingAmountText;
  final Value<String> installmentPlanJson;
  final Value<String> valuationDate;
  final Value<String> marketValueText;
  final Value<String> marketValueDate;
  final Value<String> valuationSource;
  final Value<String> loanBalanceText;
  final Value<String> loanAsOfDate;
  final Value<String> paidAmountToDateText;
  final Value<String> ownershipSharePctText;
  final Value<String> country;
  final Value<String> location;
  final Value<String> inflationRateText;
  final Value<String> estimatedCurrentValueText;
  final Value<String> description;
  final Value<bool> noZakat;
  final Value<String?> yearlyGrowthRateText;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const InvestmentsCompanion({
    this.id = const Value.absent(),
    this.investmentType = const Value.absent(),
    this.assetSubtype = const Value.absent(),
    this.ownershipType = const Value.absent(),
    this.valuationMode = const Value.absent(),
    this.currency = const Value.absent(),
    this.originalPriceText = const Value.absent(),
    this.totalInterestText = const Value.absent(),
    this.totalPayableText = const Value.absent(),
    this.paidAmountText = const Value.absent(),
    this.remainingAmountText = const Value.absent(),
    this.installmentPlanJson = const Value.absent(),
    this.valuationDate = const Value.absent(),
    this.marketValueText = const Value.absent(),
    this.marketValueDate = const Value.absent(),
    this.valuationSource = const Value.absent(),
    this.loanBalanceText = const Value.absent(),
    this.loanAsOfDate = const Value.absent(),
    this.paidAmountToDateText = const Value.absent(),
    this.ownershipSharePctText = const Value.absent(),
    this.country = const Value.absent(),
    this.location = const Value.absent(),
    this.inflationRateText = const Value.absent(),
    this.estimatedCurrentValueText = const Value.absent(),
    this.description = const Value.absent(),
    this.noZakat = const Value.absent(),
    this.yearlyGrowthRateText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InvestmentsCompanion.insert({
    required String id,
    required String investmentType,
    required String assetSubtype,
    required String ownershipType,
    required String valuationMode,
    required String currency,
    required String originalPriceText,
    required String totalInterestText,
    required String totalPayableText,
    required String paidAmountText,
    required String remainingAmountText,
    required String installmentPlanJson,
    required String valuationDate,
    required String marketValueText,
    required String marketValueDate,
    required String valuationSource,
    required String loanBalanceText,
    required String loanAsOfDate,
    required String paidAmountToDateText,
    required String ownershipSharePctText,
    required String country,
    required String location,
    required String inflationRateText,
    required String estimatedCurrentValueText,
    required String description,
    this.noZakat = const Value.absent(),
    this.yearlyGrowthRateText = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       investmentType = Value(investmentType),
       assetSubtype = Value(assetSubtype),
       ownershipType = Value(ownershipType),
       valuationMode = Value(valuationMode),
       currency = Value(currency),
       originalPriceText = Value(originalPriceText),
       totalInterestText = Value(totalInterestText),
       totalPayableText = Value(totalPayableText),
       paidAmountText = Value(paidAmountText),
       remainingAmountText = Value(remainingAmountText),
       installmentPlanJson = Value(installmentPlanJson),
       valuationDate = Value(valuationDate),
       marketValueText = Value(marketValueText),
       marketValueDate = Value(marketValueDate),
       valuationSource = Value(valuationSource),
       loanBalanceText = Value(loanBalanceText),
       loanAsOfDate = Value(loanAsOfDate),
       paidAmountToDateText = Value(paidAmountToDateText),
       ownershipSharePctText = Value(ownershipSharePctText),
       country = Value(country),
       location = Value(location),
       inflationRateText = Value(inflationRateText),
       estimatedCurrentValueText = Value(estimatedCurrentValueText),
       description = Value(description),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Investment> custom({
    Expression<String>? id,
    Expression<String>? investmentType,
    Expression<String>? assetSubtype,
    Expression<String>? ownershipType,
    Expression<String>? valuationMode,
    Expression<String>? currency,
    Expression<String>? originalPriceText,
    Expression<String>? totalInterestText,
    Expression<String>? totalPayableText,
    Expression<String>? paidAmountText,
    Expression<String>? remainingAmountText,
    Expression<String>? installmentPlanJson,
    Expression<String>? valuationDate,
    Expression<String>? marketValueText,
    Expression<String>? marketValueDate,
    Expression<String>? valuationSource,
    Expression<String>? loanBalanceText,
    Expression<String>? loanAsOfDate,
    Expression<String>? paidAmountToDateText,
    Expression<String>? ownershipSharePctText,
    Expression<String>? country,
    Expression<String>? location,
    Expression<String>? inflationRateText,
    Expression<String>? estimatedCurrentValueText,
    Expression<String>? description,
    Expression<bool>? noZakat,
    Expression<String>? yearlyGrowthRateText,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (investmentType != null) 'investment_type': investmentType,
      if (assetSubtype != null) 'asset_subtype': assetSubtype,
      if (ownershipType != null) 'ownership_type': ownershipType,
      if (valuationMode != null) 'valuation_mode': valuationMode,
      if (currency != null) 'currency': currency,
      if (originalPriceText != null) 'original_price_text': originalPriceText,
      if (totalInterestText != null) 'total_interest_text': totalInterestText,
      if (totalPayableText != null) 'total_payable_text': totalPayableText,
      if (paidAmountText != null) 'paid_amount_text': paidAmountText,
      if (remainingAmountText != null)
        'remaining_amount_text': remainingAmountText,
      if (installmentPlanJson != null)
        'installment_plan_json': installmentPlanJson,
      if (valuationDate != null) 'valuation_date': valuationDate,
      if (marketValueText != null) 'market_value_text': marketValueText,
      if (marketValueDate != null) 'market_value_date': marketValueDate,
      if (valuationSource != null) 'valuation_source': valuationSource,
      if (loanBalanceText != null) 'loan_balance_text': loanBalanceText,
      if (loanAsOfDate != null) 'loan_as_of_date': loanAsOfDate,
      if (paidAmountToDateText != null)
        'paid_amount_to_date_text': paidAmountToDateText,
      if (ownershipSharePctText != null)
        'ownership_share_pct_text': ownershipSharePctText,
      if (country != null) 'country': country,
      if (location != null) 'location': location,
      if (inflationRateText != null) 'inflation_rate_text': inflationRateText,
      if (estimatedCurrentValueText != null)
        'estimated_current_value_text': estimatedCurrentValueText,
      if (description != null) 'description': description,
      if (noZakat != null) 'no_zakat': noZakat,
      if (yearlyGrowthRateText != null)
        'yearly_growth_rate_text': yearlyGrowthRateText,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InvestmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? investmentType,
    Value<String>? assetSubtype,
    Value<String>? ownershipType,
    Value<String>? valuationMode,
    Value<String>? currency,
    Value<String>? originalPriceText,
    Value<String>? totalInterestText,
    Value<String>? totalPayableText,
    Value<String>? paidAmountText,
    Value<String>? remainingAmountText,
    Value<String>? installmentPlanJson,
    Value<String>? valuationDate,
    Value<String>? marketValueText,
    Value<String>? marketValueDate,
    Value<String>? valuationSource,
    Value<String>? loanBalanceText,
    Value<String>? loanAsOfDate,
    Value<String>? paidAmountToDateText,
    Value<String>? ownershipSharePctText,
    Value<String>? country,
    Value<String>? location,
    Value<String>? inflationRateText,
    Value<String>? estimatedCurrentValueText,
    Value<String>? description,
    Value<bool>? noZakat,
    Value<String?>? yearlyGrowthRateText,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return InvestmentsCompanion(
      id: id ?? this.id,
      investmentType: investmentType ?? this.investmentType,
      assetSubtype: assetSubtype ?? this.assetSubtype,
      ownershipType: ownershipType ?? this.ownershipType,
      valuationMode: valuationMode ?? this.valuationMode,
      currency: currency ?? this.currency,
      originalPriceText: originalPriceText ?? this.originalPriceText,
      totalInterestText: totalInterestText ?? this.totalInterestText,
      totalPayableText: totalPayableText ?? this.totalPayableText,
      paidAmountText: paidAmountText ?? this.paidAmountText,
      remainingAmountText: remainingAmountText ?? this.remainingAmountText,
      installmentPlanJson: installmentPlanJson ?? this.installmentPlanJson,
      valuationDate: valuationDate ?? this.valuationDate,
      marketValueText: marketValueText ?? this.marketValueText,
      marketValueDate: marketValueDate ?? this.marketValueDate,
      valuationSource: valuationSource ?? this.valuationSource,
      loanBalanceText: loanBalanceText ?? this.loanBalanceText,
      loanAsOfDate: loanAsOfDate ?? this.loanAsOfDate,
      paidAmountToDateText: paidAmountToDateText ?? this.paidAmountToDateText,
      ownershipSharePctText:
          ownershipSharePctText ?? this.ownershipSharePctText,
      country: country ?? this.country,
      location: location ?? this.location,
      inflationRateText: inflationRateText ?? this.inflationRateText,
      estimatedCurrentValueText:
          estimatedCurrentValueText ?? this.estimatedCurrentValueText,
      description: description ?? this.description,
      noZakat: noZakat ?? this.noZakat,
      yearlyGrowthRateText: yearlyGrowthRateText ?? this.yearlyGrowthRateText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (investmentType.present) {
      map['investment_type'] = Variable<String>(investmentType.value);
    }
    if (assetSubtype.present) {
      map['asset_subtype'] = Variable<String>(assetSubtype.value);
    }
    if (ownershipType.present) {
      map['ownership_type'] = Variable<String>(ownershipType.value);
    }
    if (valuationMode.present) {
      map['valuation_mode'] = Variable<String>(valuationMode.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (originalPriceText.present) {
      map['original_price_text'] = Variable<String>(originalPriceText.value);
    }
    if (totalInterestText.present) {
      map['total_interest_text'] = Variable<String>(totalInterestText.value);
    }
    if (totalPayableText.present) {
      map['total_payable_text'] = Variable<String>(totalPayableText.value);
    }
    if (paidAmountText.present) {
      map['paid_amount_text'] = Variable<String>(paidAmountText.value);
    }
    if (remainingAmountText.present) {
      map['remaining_amount_text'] = Variable<String>(
        remainingAmountText.value,
      );
    }
    if (installmentPlanJson.present) {
      map['installment_plan_json'] = Variable<String>(
        installmentPlanJson.value,
      );
    }
    if (valuationDate.present) {
      map['valuation_date'] = Variable<String>(valuationDate.value);
    }
    if (marketValueText.present) {
      map['market_value_text'] = Variable<String>(marketValueText.value);
    }
    if (marketValueDate.present) {
      map['market_value_date'] = Variable<String>(marketValueDate.value);
    }
    if (valuationSource.present) {
      map['valuation_source'] = Variable<String>(valuationSource.value);
    }
    if (loanBalanceText.present) {
      map['loan_balance_text'] = Variable<String>(loanBalanceText.value);
    }
    if (loanAsOfDate.present) {
      map['loan_as_of_date'] = Variable<String>(loanAsOfDate.value);
    }
    if (paidAmountToDateText.present) {
      map['paid_amount_to_date_text'] = Variable<String>(
        paidAmountToDateText.value,
      );
    }
    if (ownershipSharePctText.present) {
      map['ownership_share_pct_text'] = Variable<String>(
        ownershipSharePctText.value,
      );
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (inflationRateText.present) {
      map['inflation_rate_text'] = Variable<String>(inflationRateText.value);
    }
    if (estimatedCurrentValueText.present) {
      map['estimated_current_value_text'] = Variable<String>(
        estimatedCurrentValueText.value,
      );
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (noZakat.present) {
      map['no_zakat'] = Variable<bool>(noZakat.value);
    }
    if (yearlyGrowthRateText.present) {
      map['yearly_growth_rate_text'] = Variable<String>(
        yearlyGrowthRateText.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvestmentsCompanion(')
          ..write('id: $id, ')
          ..write('investmentType: $investmentType, ')
          ..write('assetSubtype: $assetSubtype, ')
          ..write('ownershipType: $ownershipType, ')
          ..write('valuationMode: $valuationMode, ')
          ..write('currency: $currency, ')
          ..write('originalPriceText: $originalPriceText, ')
          ..write('totalInterestText: $totalInterestText, ')
          ..write('totalPayableText: $totalPayableText, ')
          ..write('paidAmountText: $paidAmountText, ')
          ..write('remainingAmountText: $remainingAmountText, ')
          ..write('installmentPlanJson: $installmentPlanJson, ')
          ..write('valuationDate: $valuationDate, ')
          ..write('marketValueText: $marketValueText, ')
          ..write('marketValueDate: $marketValueDate, ')
          ..write('valuationSource: $valuationSource, ')
          ..write('loanBalanceText: $loanBalanceText, ')
          ..write('loanAsOfDate: $loanAsOfDate, ')
          ..write('paidAmountToDateText: $paidAmountToDateText, ')
          ..write('ownershipSharePctText: $ownershipSharePctText, ')
          ..write('country: $country, ')
          ..write('location: $location, ')
          ..write('inflationRateText: $inflationRateText, ')
          ..write('estimatedCurrentValueText: $estimatedCurrentValueText, ')
          ..write('description: $description, ')
          ..write('noZakat: $noZakat, ')
          ..write('yearlyGrowthRateText: $yearlyGrowthRateText, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingTransactionsTable extends PendingTransactions
    with TableInfo<$PendingTransactionsTable, PendingTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdentifierMeta = const VerificationMeta(
    'sourceIdentifier',
  );
  @override
  late final GeneratedColumn<String> sourceIdentifier = GeneratedColumn<String>(
    'source_identifier',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawMessageMeta = const VerificationMeta(
    'rawMessage',
  );
  @override
  late final GeneratedColumn<String> rawMessage = GeneratedColumn<String>(
    'raw_message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewedAtMeta = const VerificationMeta(
    'reviewedAt',
  );
  @override
  late final GeneratedColumn<String> reviewedAt = GeneratedColumn<String>(
    'reviewed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _suggestedTypeMeta = const VerificationMeta(
    'suggestedType',
  );
  @override
  late final GeneratedColumn<String> suggestedType = GeneratedColumn<String>(
    'suggested_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _suggestedAmountTextMeta =
      const VerificationMeta('suggestedAmountText');
  @override
  late final GeneratedColumn<String> suggestedAmountText =
      GeneratedColumn<String>(
        'suggested_amount_text',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _suggestedCurrencyMeta = const VerificationMeta(
    'suggestedCurrency',
  );
  @override
  late final GeneratedColumn<String> suggestedCurrency =
      GeneratedColumn<String>(
        'suggested_currency',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _suggestedDescriptionMeta =
      const VerificationMeta('suggestedDescription');
  @override
  late final GeneratedColumn<String> suggestedDescription =
      GeneratedColumn<String>(
        'suggested_description',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _merchantNameMeta = const VerificationMeta(
    'merchantName',
  );
  @override
  late final GeneratedColumn<String> merchantName = GeneratedColumn<String>(
    'merchant_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _suggestedCategoryMeta = const VerificationMeta(
    'suggestedCategory',
  );
  @override
  late final GeneratedColumn<String> suggestedCategory =
      GeneratedColumn<String>(
        'suggested_category',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _confidenceTextMeta = const VerificationMeta(
    'confidenceText',
  );
  @override
  late final GeneratedColumn<String> confidenceText = GeneratedColumn<String>(
    'confidence_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _approvalSourceMeta = const VerificationMeta(
    'approvalSource',
  );
  @override
  late final GeneratedColumn<String> approvalSource = GeneratedColumn<String>(
    'approval_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _merchantRuleUsedMeta = const VerificationMeta(
    'merchantRuleUsed',
  );
  @override
  late final GeneratedColumn<String> merchantRuleUsed = GeneratedColumn<String>(
    'merchant_rule_used',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _merchantRuleSourceMeta =
      const VerificationMeta('merchantRuleSource');
  @override
  late final GeneratedColumn<String> merchantRuleSource =
      GeneratedColumn<String>(
        'merchant_rule_source',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _ignoreReasonMeta = const VerificationMeta(
    'ignoreReason',
  );
  @override
  late final GeneratedColumn<String> ignoreReason = GeneratedColumn<String>(
    'ignore_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parserVersionMeta = const VerificationMeta(
    'parserVersion',
  );
  @override
  late final GeneratedColumn<String> parserVersion = GeneratedColumn<String>(
    'parser_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detectedBankMeta = const VerificationMeta(
    'detectedBank',
  );
  @override
  late final GeneratedColumn<String> detectedBank = GeneratedColumn<String>(
    'detected_bank',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requiresReviewMeta = const VerificationMeta(
    'requiresReview',
  );
  @override
  late final GeneratedColumn<bool> requiresReview = GeneratedColumn<bool>(
    'requires_review',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_review" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
    'is_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _linkedTransactionIdMeta =
      const VerificationMeta('linkedTransactionId');
  @override
  late final GeneratedColumn<String> linkedTransactionId =
      GeneratedColumn<String>(
        'linked_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    source,
    sourceIdentifier,
    rawMessage,
    createdAt,
    reviewedAt,
    suggestedType,
    suggestedAmountText,
    suggestedCurrency,
    suggestedDescription,
    merchantName,
    suggestedCategory,
    confidenceText,
    status,
    approvalSource,
    merchantRuleUsed,
    merchantRuleSource,
    ignoreReason,
    parserVersion,
    detectedBank,
    requiresReview,
    isRead,
    linkedTransactionId,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('source_identifier')) {
      context.handle(
        _sourceIdentifierMeta,
        sourceIdentifier.isAcceptableOrUnknown(
          data['source_identifier']!,
          _sourceIdentifierMeta,
        ),
      );
    }
    if (data.containsKey('raw_message')) {
      context.handle(
        _rawMessageMeta,
        rawMessage.isAcceptableOrUnknown(data['raw_message']!, _rawMessageMeta),
      );
    } else if (isInserting) {
      context.missing(_rawMessageMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
        _reviewedAtMeta,
        reviewedAt.isAcceptableOrUnknown(data['reviewed_at']!, _reviewedAtMeta),
      );
    }
    if (data.containsKey('suggested_type')) {
      context.handle(
        _suggestedTypeMeta,
        suggestedType.isAcceptableOrUnknown(
          data['suggested_type']!,
          _suggestedTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_suggestedTypeMeta);
    }
    if (data.containsKey('suggested_amount_text')) {
      context.handle(
        _suggestedAmountTextMeta,
        suggestedAmountText.isAcceptableOrUnknown(
          data['suggested_amount_text']!,
          _suggestedAmountTextMeta,
        ),
      );
    }
    if (data.containsKey('suggested_currency')) {
      context.handle(
        _suggestedCurrencyMeta,
        suggestedCurrency.isAcceptableOrUnknown(
          data['suggested_currency']!,
          _suggestedCurrencyMeta,
        ),
      );
    }
    if (data.containsKey('suggested_description')) {
      context.handle(
        _suggestedDescriptionMeta,
        suggestedDescription.isAcceptableOrUnknown(
          data['suggested_description']!,
          _suggestedDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('merchant_name')) {
      context.handle(
        _merchantNameMeta,
        merchantName.isAcceptableOrUnknown(
          data['merchant_name']!,
          _merchantNameMeta,
        ),
      );
    }
    if (data.containsKey('suggested_category')) {
      context.handle(
        _suggestedCategoryMeta,
        suggestedCategory.isAcceptableOrUnknown(
          data['suggested_category']!,
          _suggestedCategoryMeta,
        ),
      );
    }
    if (data.containsKey('confidence_text')) {
      context.handle(
        _confidenceTextMeta,
        confidenceText.isAcceptableOrUnknown(
          data['confidence_text']!,
          _confidenceTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_confidenceTextMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('approval_source')) {
      context.handle(
        _approvalSourceMeta,
        approvalSource.isAcceptableOrUnknown(
          data['approval_source']!,
          _approvalSourceMeta,
        ),
      );
    }
    if (data.containsKey('merchant_rule_used')) {
      context.handle(
        _merchantRuleUsedMeta,
        merchantRuleUsed.isAcceptableOrUnknown(
          data['merchant_rule_used']!,
          _merchantRuleUsedMeta,
        ),
      );
    }
    if (data.containsKey('merchant_rule_source')) {
      context.handle(
        _merchantRuleSourceMeta,
        merchantRuleSource.isAcceptableOrUnknown(
          data['merchant_rule_source']!,
          _merchantRuleSourceMeta,
        ),
      );
    }
    if (data.containsKey('ignore_reason')) {
      context.handle(
        _ignoreReasonMeta,
        ignoreReason.isAcceptableOrUnknown(
          data['ignore_reason']!,
          _ignoreReasonMeta,
        ),
      );
    }
    if (data.containsKey('parser_version')) {
      context.handle(
        _parserVersionMeta,
        parserVersion.isAcceptableOrUnknown(
          data['parser_version']!,
          _parserVersionMeta,
        ),
      );
    }
    if (data.containsKey('detected_bank')) {
      context.handle(
        _detectedBankMeta,
        detectedBank.isAcceptableOrUnknown(
          data['detected_bank']!,
          _detectedBankMeta,
        ),
      );
    }
    if (data.containsKey('requires_review')) {
      context.handle(
        _requiresReviewMeta,
        requiresReview.isAcceptableOrUnknown(
          data['requires_review']!,
          _requiresReviewMeta,
        ),
      );
    }
    if (data.containsKey('is_read')) {
      context.handle(
        _isReadMeta,
        isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta),
      );
    }
    if (data.containsKey('linked_transaction_id')) {
      context.handle(
        _linkedTransactionIdMeta,
        linkedTransactionId.isAcceptableOrUnknown(
          data['linked_transaction_id']!,
          _linkedTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sourceIdentifier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_identifier'],
      ),
      rawMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_message'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      reviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reviewed_at'],
      ),
      suggestedType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_type'],
      )!,
      suggestedAmountText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_amount_text'],
      ),
      suggestedCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_currency'],
      ),
      suggestedDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_description'],
      ),
      merchantName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_name'],
      ),
      suggestedCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_category'],
      ),
      confidenceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confidence_text'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      approvalSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approval_source'],
      ),
      merchantRuleUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_rule_used'],
      ),
      merchantRuleSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_rule_source'],
      ),
      ignoreReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ignore_reason'],
      ),
      parserVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parser_version'],
      ),
      detectedBank: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detected_bank'],
      ),
      requiresReview: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_review'],
      )!,
      isRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_read'],
      )!,
      linkedTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_transaction_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PendingTransactionsTable createAlias(String alias) {
    return $PendingTransactionsTable(attachedDatabase, alias);
  }
}

class PendingTransaction extends DataClass
    implements Insertable<PendingTransaction> {
  final String id;
  final String source;
  final String? sourceIdentifier;
  final String rawMessage;
  final String createdAt;
  final String? reviewedAt;
  final String suggestedType;
  final String? suggestedAmountText;
  final String? suggestedCurrency;
  final String? suggestedDescription;
  final String? merchantName;
  final String? suggestedCategory;
  final String confidenceText;
  final String status;
  final String? approvalSource;
  final String? merchantRuleUsed;
  final String? merchantRuleSource;
  final String? ignoreReason;
  final String? parserVersion;
  final String? detectedBank;
  final bool requiresReview;
  final bool isRead;
  final String? linkedTransactionId;
  final String updatedAt;
  final String? deletedAt;
  const PendingTransaction({
    required this.id,
    required this.source,
    this.sourceIdentifier,
    required this.rawMessage,
    required this.createdAt,
    this.reviewedAt,
    required this.suggestedType,
    this.suggestedAmountText,
    this.suggestedCurrency,
    this.suggestedDescription,
    this.merchantName,
    this.suggestedCategory,
    required this.confidenceText,
    required this.status,
    this.approvalSource,
    this.merchantRuleUsed,
    this.merchantRuleSource,
    this.ignoreReason,
    this.parserVersion,
    this.detectedBank,
    required this.requiresReview,
    required this.isRead,
    this.linkedTransactionId,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || sourceIdentifier != null) {
      map['source_identifier'] = Variable<String>(sourceIdentifier);
    }
    map['raw_message'] = Variable<String>(rawMessage);
    map['created_at'] = Variable<String>(createdAt);
    if (!nullToAbsent || reviewedAt != null) {
      map['reviewed_at'] = Variable<String>(reviewedAt);
    }
    map['suggested_type'] = Variable<String>(suggestedType);
    if (!nullToAbsent || suggestedAmountText != null) {
      map['suggested_amount_text'] = Variable<String>(suggestedAmountText);
    }
    if (!nullToAbsent || suggestedCurrency != null) {
      map['suggested_currency'] = Variable<String>(suggestedCurrency);
    }
    if (!nullToAbsent || suggestedDescription != null) {
      map['suggested_description'] = Variable<String>(suggestedDescription);
    }
    if (!nullToAbsent || merchantName != null) {
      map['merchant_name'] = Variable<String>(merchantName);
    }
    if (!nullToAbsent || suggestedCategory != null) {
      map['suggested_category'] = Variable<String>(suggestedCategory);
    }
    map['confidence_text'] = Variable<String>(confidenceText);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || approvalSource != null) {
      map['approval_source'] = Variable<String>(approvalSource);
    }
    if (!nullToAbsent || merchantRuleUsed != null) {
      map['merchant_rule_used'] = Variable<String>(merchantRuleUsed);
    }
    if (!nullToAbsent || merchantRuleSource != null) {
      map['merchant_rule_source'] = Variable<String>(merchantRuleSource);
    }
    if (!nullToAbsent || ignoreReason != null) {
      map['ignore_reason'] = Variable<String>(ignoreReason);
    }
    if (!nullToAbsent || parserVersion != null) {
      map['parser_version'] = Variable<String>(parserVersion);
    }
    if (!nullToAbsent || detectedBank != null) {
      map['detected_bank'] = Variable<String>(detectedBank);
    }
    map['requires_review'] = Variable<bool>(requiresReview);
    map['is_read'] = Variable<bool>(isRead);
    if (!nullToAbsent || linkedTransactionId != null) {
      map['linked_transaction_id'] = Variable<String>(linkedTransactionId);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  PendingTransactionsCompanion toCompanion(bool nullToAbsent) {
    return PendingTransactionsCompanion(
      id: Value(id),
      source: Value(source),
      sourceIdentifier: sourceIdentifier == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceIdentifier),
      rawMessage: Value(rawMessage),
      createdAt: Value(createdAt),
      reviewedAt: reviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewedAt),
      suggestedType: Value(suggestedType),
      suggestedAmountText: suggestedAmountText == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedAmountText),
      suggestedCurrency: suggestedCurrency == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedCurrency),
      suggestedDescription: suggestedDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedDescription),
      merchantName: merchantName == null && nullToAbsent
          ? const Value.absent()
          : Value(merchantName),
      suggestedCategory: suggestedCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedCategory),
      confidenceText: Value(confidenceText),
      status: Value(status),
      approvalSource: approvalSource == null && nullToAbsent
          ? const Value.absent()
          : Value(approvalSource),
      merchantRuleUsed: merchantRuleUsed == null && nullToAbsent
          ? const Value.absent()
          : Value(merchantRuleUsed),
      merchantRuleSource: merchantRuleSource == null && nullToAbsent
          ? const Value.absent()
          : Value(merchantRuleSource),
      ignoreReason: ignoreReason == null && nullToAbsent
          ? const Value.absent()
          : Value(ignoreReason),
      parserVersion: parserVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(parserVersion),
      detectedBank: detectedBank == null && nullToAbsent
          ? const Value.absent()
          : Value(detectedBank),
      requiresReview: Value(requiresReview),
      isRead: Value(isRead),
      linkedTransactionId: linkedTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedTransactionId),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PendingTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingTransaction(
      id: serializer.fromJson<String>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      sourceIdentifier: serializer.fromJson<String?>(json['sourceIdentifier']),
      rawMessage: serializer.fromJson<String>(json['rawMessage']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      reviewedAt: serializer.fromJson<String?>(json['reviewedAt']),
      suggestedType: serializer.fromJson<String>(json['suggestedType']),
      suggestedAmountText: serializer.fromJson<String?>(
        json['suggestedAmountText'],
      ),
      suggestedCurrency: serializer.fromJson<String?>(
        json['suggestedCurrency'],
      ),
      suggestedDescription: serializer.fromJson<String?>(
        json['suggestedDescription'],
      ),
      merchantName: serializer.fromJson<String?>(json['merchantName']),
      suggestedCategory: serializer.fromJson<String?>(
        json['suggestedCategory'],
      ),
      confidenceText: serializer.fromJson<String>(json['confidenceText']),
      status: serializer.fromJson<String>(json['status']),
      approvalSource: serializer.fromJson<String?>(json['approvalSource']),
      merchantRuleUsed: serializer.fromJson<String?>(json['merchantRuleUsed']),
      merchantRuleSource: serializer.fromJson<String?>(
        json['merchantRuleSource'],
      ),
      ignoreReason: serializer.fromJson<String?>(json['ignoreReason']),
      parserVersion: serializer.fromJson<String?>(json['parserVersion']),
      detectedBank: serializer.fromJson<String?>(json['detectedBank']),
      requiresReview: serializer.fromJson<bool>(json['requiresReview']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      linkedTransactionId: serializer.fromJson<String?>(
        json['linkedTransactionId'],
      ),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'source': serializer.toJson<String>(source),
      'sourceIdentifier': serializer.toJson<String?>(sourceIdentifier),
      'rawMessage': serializer.toJson<String>(rawMessage),
      'createdAt': serializer.toJson<String>(createdAt),
      'reviewedAt': serializer.toJson<String?>(reviewedAt),
      'suggestedType': serializer.toJson<String>(suggestedType),
      'suggestedAmountText': serializer.toJson<String?>(suggestedAmountText),
      'suggestedCurrency': serializer.toJson<String?>(suggestedCurrency),
      'suggestedDescription': serializer.toJson<String?>(suggestedDescription),
      'merchantName': serializer.toJson<String?>(merchantName),
      'suggestedCategory': serializer.toJson<String?>(suggestedCategory),
      'confidenceText': serializer.toJson<String>(confidenceText),
      'status': serializer.toJson<String>(status),
      'approvalSource': serializer.toJson<String?>(approvalSource),
      'merchantRuleUsed': serializer.toJson<String?>(merchantRuleUsed),
      'merchantRuleSource': serializer.toJson<String?>(merchantRuleSource),
      'ignoreReason': serializer.toJson<String?>(ignoreReason),
      'parserVersion': serializer.toJson<String?>(parserVersion),
      'detectedBank': serializer.toJson<String?>(detectedBank),
      'requiresReview': serializer.toJson<bool>(requiresReview),
      'isRead': serializer.toJson<bool>(isRead),
      'linkedTransactionId': serializer.toJson<String?>(linkedTransactionId),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  PendingTransaction copyWith({
    String? id,
    String? source,
    Value<String?> sourceIdentifier = const Value.absent(),
    String? rawMessage,
    String? createdAt,
    Value<String?> reviewedAt = const Value.absent(),
    String? suggestedType,
    Value<String?> suggestedAmountText = const Value.absent(),
    Value<String?> suggestedCurrency = const Value.absent(),
    Value<String?> suggestedDescription = const Value.absent(),
    Value<String?> merchantName = const Value.absent(),
    Value<String?> suggestedCategory = const Value.absent(),
    String? confidenceText,
    String? status,
    Value<String?> approvalSource = const Value.absent(),
    Value<String?> merchantRuleUsed = const Value.absent(),
    Value<String?> merchantRuleSource = const Value.absent(),
    Value<String?> ignoreReason = const Value.absent(),
    Value<String?> parserVersion = const Value.absent(),
    Value<String?> detectedBank = const Value.absent(),
    bool? requiresReview,
    bool? isRead,
    Value<String?> linkedTransactionId = const Value.absent(),
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
  }) => PendingTransaction(
    id: id ?? this.id,
    source: source ?? this.source,
    sourceIdentifier: sourceIdentifier.present
        ? sourceIdentifier.value
        : this.sourceIdentifier,
    rawMessage: rawMessage ?? this.rawMessage,
    createdAt: createdAt ?? this.createdAt,
    reviewedAt: reviewedAt.present ? reviewedAt.value : this.reviewedAt,
    suggestedType: suggestedType ?? this.suggestedType,
    suggestedAmountText: suggestedAmountText.present
        ? suggestedAmountText.value
        : this.suggestedAmountText,
    suggestedCurrency: suggestedCurrency.present
        ? suggestedCurrency.value
        : this.suggestedCurrency,
    suggestedDescription: suggestedDescription.present
        ? suggestedDescription.value
        : this.suggestedDescription,
    merchantName: merchantName.present ? merchantName.value : this.merchantName,
    suggestedCategory: suggestedCategory.present
        ? suggestedCategory.value
        : this.suggestedCategory,
    confidenceText: confidenceText ?? this.confidenceText,
    status: status ?? this.status,
    approvalSource: approvalSource.present
        ? approvalSource.value
        : this.approvalSource,
    merchantRuleUsed: merchantRuleUsed.present
        ? merchantRuleUsed.value
        : this.merchantRuleUsed,
    merchantRuleSource: merchantRuleSource.present
        ? merchantRuleSource.value
        : this.merchantRuleSource,
    ignoreReason: ignoreReason.present ? ignoreReason.value : this.ignoreReason,
    parserVersion: parserVersion.present
        ? parserVersion.value
        : this.parserVersion,
    detectedBank: detectedBank.present ? detectedBank.value : this.detectedBank,
    requiresReview: requiresReview ?? this.requiresReview,
    isRead: isRead ?? this.isRead,
    linkedTransactionId: linkedTransactionId.present
        ? linkedTransactionId.value
        : this.linkedTransactionId,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PendingTransaction copyWithCompanion(PendingTransactionsCompanion data) {
    return PendingTransaction(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      sourceIdentifier: data.sourceIdentifier.present
          ? data.sourceIdentifier.value
          : this.sourceIdentifier,
      rawMessage: data.rawMessage.present
          ? data.rawMessage.value
          : this.rawMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      reviewedAt: data.reviewedAt.present
          ? data.reviewedAt.value
          : this.reviewedAt,
      suggestedType: data.suggestedType.present
          ? data.suggestedType.value
          : this.suggestedType,
      suggestedAmountText: data.suggestedAmountText.present
          ? data.suggestedAmountText.value
          : this.suggestedAmountText,
      suggestedCurrency: data.suggestedCurrency.present
          ? data.suggestedCurrency.value
          : this.suggestedCurrency,
      suggestedDescription: data.suggestedDescription.present
          ? data.suggestedDescription.value
          : this.suggestedDescription,
      merchantName: data.merchantName.present
          ? data.merchantName.value
          : this.merchantName,
      suggestedCategory: data.suggestedCategory.present
          ? data.suggestedCategory.value
          : this.suggestedCategory,
      confidenceText: data.confidenceText.present
          ? data.confidenceText.value
          : this.confidenceText,
      status: data.status.present ? data.status.value : this.status,
      approvalSource: data.approvalSource.present
          ? data.approvalSource.value
          : this.approvalSource,
      merchantRuleUsed: data.merchantRuleUsed.present
          ? data.merchantRuleUsed.value
          : this.merchantRuleUsed,
      merchantRuleSource: data.merchantRuleSource.present
          ? data.merchantRuleSource.value
          : this.merchantRuleSource,
      ignoreReason: data.ignoreReason.present
          ? data.ignoreReason.value
          : this.ignoreReason,
      parserVersion: data.parserVersion.present
          ? data.parserVersion.value
          : this.parserVersion,
      detectedBank: data.detectedBank.present
          ? data.detectedBank.value
          : this.detectedBank,
      requiresReview: data.requiresReview.present
          ? data.requiresReview.value
          : this.requiresReview,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      linkedTransactionId: data.linkedTransactionId.present
          ? data.linkedTransactionId.value
          : this.linkedTransactionId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingTransaction(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('sourceIdentifier: $sourceIdentifier, ')
          ..write('rawMessage: $rawMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('suggestedType: $suggestedType, ')
          ..write('suggestedAmountText: $suggestedAmountText, ')
          ..write('suggestedCurrency: $suggestedCurrency, ')
          ..write('suggestedDescription: $suggestedDescription, ')
          ..write('merchantName: $merchantName, ')
          ..write('suggestedCategory: $suggestedCategory, ')
          ..write('confidenceText: $confidenceText, ')
          ..write('status: $status, ')
          ..write('approvalSource: $approvalSource, ')
          ..write('merchantRuleUsed: $merchantRuleUsed, ')
          ..write('merchantRuleSource: $merchantRuleSource, ')
          ..write('ignoreReason: $ignoreReason, ')
          ..write('parserVersion: $parserVersion, ')
          ..write('detectedBank: $detectedBank, ')
          ..write('requiresReview: $requiresReview, ')
          ..write('isRead: $isRead, ')
          ..write('linkedTransactionId: $linkedTransactionId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    source,
    sourceIdentifier,
    rawMessage,
    createdAt,
    reviewedAt,
    suggestedType,
    suggestedAmountText,
    suggestedCurrency,
    suggestedDescription,
    merchantName,
    suggestedCategory,
    confidenceText,
    status,
    approvalSource,
    merchantRuleUsed,
    merchantRuleSource,
    ignoreReason,
    parserVersion,
    detectedBank,
    requiresReview,
    isRead,
    linkedTransactionId,
    updatedAt,
    deletedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingTransaction &&
          other.id == this.id &&
          other.source == this.source &&
          other.sourceIdentifier == this.sourceIdentifier &&
          other.rawMessage == this.rawMessage &&
          other.createdAt == this.createdAt &&
          other.reviewedAt == this.reviewedAt &&
          other.suggestedType == this.suggestedType &&
          other.suggestedAmountText == this.suggestedAmountText &&
          other.suggestedCurrency == this.suggestedCurrency &&
          other.suggestedDescription == this.suggestedDescription &&
          other.merchantName == this.merchantName &&
          other.suggestedCategory == this.suggestedCategory &&
          other.confidenceText == this.confidenceText &&
          other.status == this.status &&
          other.approvalSource == this.approvalSource &&
          other.merchantRuleUsed == this.merchantRuleUsed &&
          other.merchantRuleSource == this.merchantRuleSource &&
          other.ignoreReason == this.ignoreReason &&
          other.parserVersion == this.parserVersion &&
          other.detectedBank == this.detectedBank &&
          other.requiresReview == this.requiresReview &&
          other.isRead == this.isRead &&
          other.linkedTransactionId == this.linkedTransactionId &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class PendingTransactionsCompanion extends UpdateCompanion<PendingTransaction> {
  final Value<String> id;
  final Value<String> source;
  final Value<String?> sourceIdentifier;
  final Value<String> rawMessage;
  final Value<String> createdAt;
  final Value<String?> reviewedAt;
  final Value<String> suggestedType;
  final Value<String?> suggestedAmountText;
  final Value<String?> suggestedCurrency;
  final Value<String?> suggestedDescription;
  final Value<String?> merchantName;
  final Value<String?> suggestedCategory;
  final Value<String> confidenceText;
  final Value<String> status;
  final Value<String?> approvalSource;
  final Value<String?> merchantRuleUsed;
  final Value<String?> merchantRuleSource;
  final Value<String?> ignoreReason;
  final Value<String?> parserVersion;
  final Value<String?> detectedBank;
  final Value<bool> requiresReview;
  final Value<bool> isRead;
  final Value<String?> linkedTransactionId;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const PendingTransactionsCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceIdentifier = const Value.absent(),
    this.rawMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    this.suggestedType = const Value.absent(),
    this.suggestedAmountText = const Value.absent(),
    this.suggestedCurrency = const Value.absent(),
    this.suggestedDescription = const Value.absent(),
    this.merchantName = const Value.absent(),
    this.suggestedCategory = const Value.absent(),
    this.confidenceText = const Value.absent(),
    this.status = const Value.absent(),
    this.approvalSource = const Value.absent(),
    this.merchantRuleUsed = const Value.absent(),
    this.merchantRuleSource = const Value.absent(),
    this.ignoreReason = const Value.absent(),
    this.parserVersion = const Value.absent(),
    this.detectedBank = const Value.absent(),
    this.requiresReview = const Value.absent(),
    this.isRead = const Value.absent(),
    this.linkedTransactionId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingTransactionsCompanion.insert({
    required String id,
    required String source,
    this.sourceIdentifier = const Value.absent(),
    required String rawMessage,
    required String createdAt,
    this.reviewedAt = const Value.absent(),
    required String suggestedType,
    this.suggestedAmountText = const Value.absent(),
    this.suggestedCurrency = const Value.absent(),
    this.suggestedDescription = const Value.absent(),
    this.merchantName = const Value.absent(),
    this.suggestedCategory = const Value.absent(),
    required String confidenceText,
    required String status,
    this.approvalSource = const Value.absent(),
    this.merchantRuleUsed = const Value.absent(),
    this.merchantRuleSource = const Value.absent(),
    this.ignoreReason = const Value.absent(),
    this.parserVersion = const Value.absent(),
    this.detectedBank = const Value.absent(),
    this.requiresReview = const Value.absent(),
    this.isRead = const Value.absent(),
    this.linkedTransactionId = const Value.absent(),
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       source = Value(source),
       rawMessage = Value(rawMessage),
       createdAt = Value(createdAt),
       suggestedType = Value(suggestedType),
       confidenceText = Value(confidenceText),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<PendingTransaction> custom({
    Expression<String>? id,
    Expression<String>? source,
    Expression<String>? sourceIdentifier,
    Expression<String>? rawMessage,
    Expression<String>? createdAt,
    Expression<String>? reviewedAt,
    Expression<String>? suggestedType,
    Expression<String>? suggestedAmountText,
    Expression<String>? suggestedCurrency,
    Expression<String>? suggestedDescription,
    Expression<String>? merchantName,
    Expression<String>? suggestedCategory,
    Expression<String>? confidenceText,
    Expression<String>? status,
    Expression<String>? approvalSource,
    Expression<String>? merchantRuleUsed,
    Expression<String>? merchantRuleSource,
    Expression<String>? ignoreReason,
    Expression<String>? parserVersion,
    Expression<String>? detectedBank,
    Expression<bool>? requiresReview,
    Expression<bool>? isRead,
    Expression<String>? linkedTransactionId,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (sourceIdentifier != null) 'source_identifier': sourceIdentifier,
      if (rawMessage != null) 'raw_message': rawMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (suggestedType != null) 'suggested_type': suggestedType,
      if (suggestedAmountText != null)
        'suggested_amount_text': suggestedAmountText,
      if (suggestedCurrency != null) 'suggested_currency': suggestedCurrency,
      if (suggestedDescription != null)
        'suggested_description': suggestedDescription,
      if (merchantName != null) 'merchant_name': merchantName,
      if (suggestedCategory != null) 'suggested_category': suggestedCategory,
      if (confidenceText != null) 'confidence_text': confidenceText,
      if (status != null) 'status': status,
      if (approvalSource != null) 'approval_source': approvalSource,
      if (merchantRuleUsed != null) 'merchant_rule_used': merchantRuleUsed,
      if (merchantRuleSource != null)
        'merchant_rule_source': merchantRuleSource,
      if (ignoreReason != null) 'ignore_reason': ignoreReason,
      if (parserVersion != null) 'parser_version': parserVersion,
      if (detectedBank != null) 'detected_bank': detectedBank,
      if (requiresReview != null) 'requires_review': requiresReview,
      if (isRead != null) 'is_read': isRead,
      if (linkedTransactionId != null)
        'linked_transaction_id': linkedTransactionId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingTransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? source,
    Value<String?>? sourceIdentifier,
    Value<String>? rawMessage,
    Value<String>? createdAt,
    Value<String?>? reviewedAt,
    Value<String>? suggestedType,
    Value<String?>? suggestedAmountText,
    Value<String?>? suggestedCurrency,
    Value<String?>? suggestedDescription,
    Value<String?>? merchantName,
    Value<String?>? suggestedCategory,
    Value<String>? confidenceText,
    Value<String>? status,
    Value<String?>? approvalSource,
    Value<String?>? merchantRuleUsed,
    Value<String?>? merchantRuleSource,
    Value<String?>? ignoreReason,
    Value<String?>? parserVersion,
    Value<String?>? detectedBank,
    Value<bool>? requiresReview,
    Value<bool>? isRead,
    Value<String?>? linkedTransactionId,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return PendingTransactionsCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      sourceIdentifier: sourceIdentifier ?? this.sourceIdentifier,
      rawMessage: rawMessage ?? this.rawMessage,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      suggestedType: suggestedType ?? this.suggestedType,
      suggestedAmountText: suggestedAmountText ?? this.suggestedAmountText,
      suggestedCurrency: suggestedCurrency ?? this.suggestedCurrency,
      suggestedDescription: suggestedDescription ?? this.suggestedDescription,
      merchantName: merchantName ?? this.merchantName,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      confidenceText: confidenceText ?? this.confidenceText,
      status: status ?? this.status,
      approvalSource: approvalSource ?? this.approvalSource,
      merchantRuleUsed: merchantRuleUsed ?? this.merchantRuleUsed,
      merchantRuleSource: merchantRuleSource ?? this.merchantRuleSource,
      ignoreReason: ignoreReason ?? this.ignoreReason,
      parserVersion: parserVersion ?? this.parserVersion,
      detectedBank: detectedBank ?? this.detectedBank,
      requiresReview: requiresReview ?? this.requiresReview,
      isRead: isRead ?? this.isRead,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceIdentifier.present) {
      map['source_identifier'] = Variable<String>(sourceIdentifier.value);
    }
    if (rawMessage.present) {
      map['raw_message'] = Variable<String>(rawMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<String>(reviewedAt.value);
    }
    if (suggestedType.present) {
      map['suggested_type'] = Variable<String>(suggestedType.value);
    }
    if (suggestedAmountText.present) {
      map['suggested_amount_text'] = Variable<String>(
        suggestedAmountText.value,
      );
    }
    if (suggestedCurrency.present) {
      map['suggested_currency'] = Variable<String>(suggestedCurrency.value);
    }
    if (suggestedDescription.present) {
      map['suggested_description'] = Variable<String>(
        suggestedDescription.value,
      );
    }
    if (merchantName.present) {
      map['merchant_name'] = Variable<String>(merchantName.value);
    }
    if (suggestedCategory.present) {
      map['suggested_category'] = Variable<String>(suggestedCategory.value);
    }
    if (confidenceText.present) {
      map['confidence_text'] = Variable<String>(confidenceText.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (approvalSource.present) {
      map['approval_source'] = Variable<String>(approvalSource.value);
    }
    if (merchantRuleUsed.present) {
      map['merchant_rule_used'] = Variable<String>(merchantRuleUsed.value);
    }
    if (merchantRuleSource.present) {
      map['merchant_rule_source'] = Variable<String>(merchantRuleSource.value);
    }
    if (ignoreReason.present) {
      map['ignore_reason'] = Variable<String>(ignoreReason.value);
    }
    if (parserVersion.present) {
      map['parser_version'] = Variable<String>(parserVersion.value);
    }
    if (detectedBank.present) {
      map['detected_bank'] = Variable<String>(detectedBank.value);
    }
    if (requiresReview.present) {
      map['requires_review'] = Variable<bool>(requiresReview.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (linkedTransactionId.present) {
      map['linked_transaction_id'] = Variable<String>(
        linkedTransactionId.value,
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('sourceIdentifier: $sourceIdentifier, ')
          ..write('rawMessage: $rawMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('suggestedType: $suggestedType, ')
          ..write('suggestedAmountText: $suggestedAmountText, ')
          ..write('suggestedCurrency: $suggestedCurrency, ')
          ..write('suggestedDescription: $suggestedDescription, ')
          ..write('merchantName: $merchantName, ')
          ..write('suggestedCategory: $suggestedCategory, ')
          ..write('confidenceText: $confidenceText, ')
          ..write('status: $status, ')
          ..write('approvalSource: $approvalSource, ')
          ..write('merchantRuleUsed: $merchantRuleUsed, ')
          ..write('merchantRuleSource: $merchantRuleSource, ')
          ..write('ignoreReason: $ignoreReason, ')
          ..write('parserVersion: $parserVersion, ')
          ..write('detectedBank: $detectedBank, ')
          ..write('requiresReview: $requiresReview, ')
          ..write('isRead: $isRead, ')
          ..write('linkedTransactionId: $linkedTransactionId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecurringTransactionsTable extends RecurringTransactions
    with TableInfo<$RecurringTransactionsTable, RecurringTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountTextMeta = const VerificationMeta(
    'amountText',
  );
  @override
  late final GeneratedColumn<String> amountText = GeneratedColumn<String>(
    'amount_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayOfMonthMeta = const VerificationMeta(
    'dayOfMonth',
  );
  @override
  late final GeneratedColumn<int> dayOfMonth = GeneratedColumn<int>(
    'day_of_month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastProcessedMeta = const VerificationMeta(
    'lastProcessed',
  );
  @override
  late final GeneratedColumn<String> lastProcessed = GeneratedColumn<String>(
    'last_processed',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _skipMonthMeta = const VerificationMeta(
    'skipMonth',
  );
  @override
  late final GeneratedColumn<String> skipMonth = GeneratedColumn<String>(
    'skip_month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _autoAddMeta = const VerificationMeta(
    'autoAdd',
  );
  @override
  late final GeneratedColumn<bool> autoAdd = GeneratedColumn<bool>(
    'auto_add',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_add" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _reminderEnabledMeta = const VerificationMeta(
    'reminderEnabled',
  );
  @override
  late final GeneratedColumn<bool> reminderEnabled = GeneratedColumn<bool>(
    'reminder_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminder_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reminderDayOffsetMeta = const VerificationMeta(
    'reminderDayOffset',
  );
  @override
  late final GeneratedColumn<int> reminderDayOffset = GeneratedColumn<int>(
    'reminder_day_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reminderTimeMeta = const VerificationMeta(
    'reminderTime',
  );
  @override
  late final GeneratedColumn<String> reminderTime = GeneratedColumn<String>(
    'reminder_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('09:00'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    amountText,
    currency,
    category,
    description,
    dayOfMonth,
    frequency,
    lastProcessed,
    enabled,
    skipMonth,
    createdAt,
    updatedAt,
    deletedAt,
    autoAdd,
    reminderEnabled,
    reminderDayOffset,
    reminderTime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecurringTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount_text')) {
      context.handle(
        _amountTextMeta,
        amountText.isAcceptableOrUnknown(data['amount_text']!, _amountTextMeta),
      );
    } else if (isInserting) {
      context.missing(_amountTextMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('day_of_month')) {
      context.handle(
        _dayOfMonthMeta,
        dayOfMonth.isAcceptableOrUnknown(
          data['day_of_month']!,
          _dayOfMonthMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dayOfMonthMeta);
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
    } else if (isInserting) {
      context.missing(_frequencyMeta);
    }
    if (data.containsKey('last_processed')) {
      context.handle(
        _lastProcessedMeta,
        lastProcessed.isAcceptableOrUnknown(
          data['last_processed']!,
          _lastProcessedMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    } else if (isInserting) {
      context.missing(_enabledMeta);
    }
    if (data.containsKey('skip_month')) {
      context.handle(
        _skipMonthMeta,
        skipMonth.isAcceptableOrUnknown(data['skip_month']!, _skipMonthMeta),
      );
    } else if (isInserting) {
      context.missing(_skipMonthMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('auto_add')) {
      context.handle(
        _autoAddMeta,
        autoAdd.isAcceptableOrUnknown(data['auto_add']!, _autoAddMeta),
      );
    }
    if (data.containsKey('reminder_enabled')) {
      context.handle(
        _reminderEnabledMeta,
        reminderEnabled.isAcceptableOrUnknown(
          data['reminder_enabled']!,
          _reminderEnabledMeta,
        ),
      );
    }
    if (data.containsKey('reminder_day_offset')) {
      context.handle(
        _reminderDayOffsetMeta,
        reminderDayOffset.isAcceptableOrUnknown(
          data['reminder_day_offset']!,
          _reminderDayOffsetMeta,
        ),
      );
    }
    if (data.containsKey('reminder_time')) {
      context.handle(
        _reminderTimeMeta,
        reminderTime.isAcceptableOrUnknown(
          data['reminder_time']!,
          _reminderTimeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amountText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount_text'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      dayOfMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_month'],
      )!,
      frequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency'],
      )!,
      lastProcessed: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_processed'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      skipMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skip_month'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      autoAdd: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_add'],
      )!,
      reminderEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reminder_enabled'],
      )!,
      reminderDayOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_day_offset'],
      )!,
      reminderTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_time'],
      )!,
    );
  }

  @override
  $RecurringTransactionsTable createAlias(String alias) {
    return $RecurringTransactionsTable(attachedDatabase, alias);
  }
}

class RecurringTransaction extends DataClass
    implements Insertable<RecurringTransaction> {
  final String id;
  final String name;
  final String type;
  final String amountText;
  final String currency;
  final String category;
  final String description;
  final int dayOfMonth;
  final String frequency;
  final String? lastProcessed;
  final bool enabled;
  final String skipMonth;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final bool autoAdd;
  final bool reminderEnabled;
  final int reminderDayOffset;
  final String reminderTime;
  const RecurringTransaction({
    required this.id,
    required this.name,
    required this.type,
    required this.amountText,
    required this.currency,
    required this.category,
    required this.description,
    required this.dayOfMonth,
    required this.frequency,
    this.lastProcessed,
    required this.enabled,
    required this.skipMonth,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.autoAdd,
    required this.reminderEnabled,
    required this.reminderDayOffset,
    required this.reminderTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['amount_text'] = Variable<String>(amountText);
    map['currency'] = Variable<String>(currency);
    map['category'] = Variable<String>(category);
    map['description'] = Variable<String>(description);
    map['day_of_month'] = Variable<int>(dayOfMonth);
    map['frequency'] = Variable<String>(frequency);
    if (!nullToAbsent || lastProcessed != null) {
      map['last_processed'] = Variable<String>(lastProcessed);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['skip_month'] = Variable<String>(skipMonth);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['auto_add'] = Variable<bool>(autoAdd);
    map['reminder_enabled'] = Variable<bool>(reminderEnabled);
    map['reminder_day_offset'] = Variable<int>(reminderDayOffset);
    map['reminder_time'] = Variable<String>(reminderTime);
    return map;
  }

  RecurringTransactionsCompanion toCompanion(bool nullToAbsent) {
    return RecurringTransactionsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      amountText: Value(amountText),
      currency: Value(currency),
      category: Value(category),
      description: Value(description),
      dayOfMonth: Value(dayOfMonth),
      frequency: Value(frequency),
      lastProcessed: lastProcessed == null && nullToAbsent
          ? const Value.absent()
          : Value(lastProcessed),
      enabled: Value(enabled),
      skipMonth: Value(skipMonth),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      autoAdd: Value(autoAdd),
      reminderEnabled: Value(reminderEnabled),
      reminderDayOffset: Value(reminderDayOffset),
      reminderTime: Value(reminderTime),
    );
  }

  factory RecurringTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringTransaction(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      amountText: serializer.fromJson<String>(json['amountText']),
      currency: serializer.fromJson<String>(json['currency']),
      category: serializer.fromJson<String>(json['category']),
      description: serializer.fromJson<String>(json['description']),
      dayOfMonth: serializer.fromJson<int>(json['dayOfMonth']),
      frequency: serializer.fromJson<String>(json['frequency']),
      lastProcessed: serializer.fromJson<String?>(json['lastProcessed']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      skipMonth: serializer.fromJson<String>(json['skipMonth']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      autoAdd: serializer.fromJson<bool>(json['autoAdd']),
      reminderEnabled: serializer.fromJson<bool>(json['reminderEnabled']),
      reminderDayOffset: serializer.fromJson<int>(json['reminderDayOffset']),
      reminderTime: serializer.fromJson<String>(json['reminderTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'amountText': serializer.toJson<String>(amountText),
      'currency': serializer.toJson<String>(currency),
      'category': serializer.toJson<String>(category),
      'description': serializer.toJson<String>(description),
      'dayOfMonth': serializer.toJson<int>(dayOfMonth),
      'frequency': serializer.toJson<String>(frequency),
      'lastProcessed': serializer.toJson<String?>(lastProcessed),
      'enabled': serializer.toJson<bool>(enabled),
      'skipMonth': serializer.toJson<String>(skipMonth),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'autoAdd': serializer.toJson<bool>(autoAdd),
      'reminderEnabled': serializer.toJson<bool>(reminderEnabled),
      'reminderDayOffset': serializer.toJson<int>(reminderDayOffset),
      'reminderTime': serializer.toJson<String>(reminderTime),
    };
  }

  RecurringTransaction copyWith({
    String? id,
    String? name,
    String? type,
    String? amountText,
    String? currency,
    String? category,
    String? description,
    int? dayOfMonth,
    String? frequency,
    Value<String?> lastProcessed = const Value.absent(),
    bool? enabled,
    String? skipMonth,
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    bool? autoAdd,
    bool? reminderEnabled,
    int? reminderDayOffset,
    String? reminderTime,
  }) => RecurringTransaction(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    amountText: amountText ?? this.amountText,
    currency: currency ?? this.currency,
    category: category ?? this.category,
    description: description ?? this.description,
    dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    frequency: frequency ?? this.frequency,
    lastProcessed: lastProcessed.present
        ? lastProcessed.value
        : this.lastProcessed,
    enabled: enabled ?? this.enabled,
    skipMonth: skipMonth ?? this.skipMonth,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    autoAdd: autoAdd ?? this.autoAdd,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderDayOffset: reminderDayOffset ?? this.reminderDayOffset,
    reminderTime: reminderTime ?? this.reminderTime,
  );
  RecurringTransaction copyWithCompanion(RecurringTransactionsCompanion data) {
    return RecurringTransaction(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      amountText: data.amountText.present
          ? data.amountText.value
          : this.amountText,
      currency: data.currency.present ? data.currency.value : this.currency,
      category: data.category.present ? data.category.value : this.category,
      description: data.description.present
          ? data.description.value
          : this.description,
      dayOfMonth: data.dayOfMonth.present
          ? data.dayOfMonth.value
          : this.dayOfMonth,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      lastProcessed: data.lastProcessed.present
          ? data.lastProcessed.value
          : this.lastProcessed,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      skipMonth: data.skipMonth.present ? data.skipMonth.value : this.skipMonth,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      autoAdd: data.autoAdd.present ? data.autoAdd.value : this.autoAdd,
      reminderEnabled: data.reminderEnabled.present
          ? data.reminderEnabled.value
          : this.reminderEnabled,
      reminderDayOffset: data.reminderDayOffset.present
          ? data.reminderDayOffset.value
          : this.reminderDayOffset,
      reminderTime: data.reminderTime.present
          ? data.reminderTime.value
          : this.reminderTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringTransaction(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('amountText: $amountText, ')
          ..write('currency: $currency, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('frequency: $frequency, ')
          ..write('lastProcessed: $lastProcessed, ')
          ..write('enabled: $enabled, ')
          ..write('skipMonth: $skipMonth, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('autoAdd: $autoAdd, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderDayOffset: $reminderDayOffset, ')
          ..write('reminderTime: $reminderTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    amountText,
    currency,
    category,
    description,
    dayOfMonth,
    frequency,
    lastProcessed,
    enabled,
    skipMonth,
    createdAt,
    updatedAt,
    deletedAt,
    autoAdd,
    reminderEnabled,
    reminderDayOffset,
    reminderTime,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringTransaction &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.amountText == this.amountText &&
          other.currency == this.currency &&
          other.category == this.category &&
          other.description == this.description &&
          other.dayOfMonth == this.dayOfMonth &&
          other.frequency == this.frequency &&
          other.lastProcessed == this.lastProcessed &&
          other.enabled == this.enabled &&
          other.skipMonth == this.skipMonth &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.autoAdd == this.autoAdd &&
          other.reminderEnabled == this.reminderEnabled &&
          other.reminderDayOffset == this.reminderDayOffset &&
          other.reminderTime == this.reminderTime);
}

class RecurringTransactionsCompanion
    extends UpdateCompanion<RecurringTransaction> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> amountText;
  final Value<String> currency;
  final Value<String> category;
  final Value<String> description;
  final Value<int> dayOfMonth;
  final Value<String> frequency;
  final Value<String?> lastProcessed;
  final Value<bool> enabled;
  final Value<String> skipMonth;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<bool> autoAdd;
  final Value<bool> reminderEnabled;
  final Value<int> reminderDayOffset;
  final Value<String> reminderTime;
  final Value<int> rowid;
  const RecurringTransactionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.amountText = const Value.absent(),
    this.currency = const Value.absent(),
    this.category = const Value.absent(),
    this.description = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.frequency = const Value.absent(),
    this.lastProcessed = const Value.absent(),
    this.enabled = const Value.absent(),
    this.skipMonth = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.autoAdd = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderDayOffset = const Value.absent(),
    this.reminderTime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecurringTransactionsCompanion.insert({
    required String id,
    required String name,
    required String type,
    required String amountText,
    required String currency,
    required String category,
    required String description,
    required int dayOfMonth,
    required String frequency,
    this.lastProcessed = const Value.absent(),
    required bool enabled,
    required String skipMonth,
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    this.autoAdd = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderDayOffset = const Value.absent(),
    this.reminderTime = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type),
       amountText = Value(amountText),
       currency = Value(currency),
       category = Value(category),
       description = Value(description),
       dayOfMonth = Value(dayOfMonth),
       frequency = Value(frequency),
       enabled = Value(enabled),
       skipMonth = Value(skipMonth),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<RecurringTransaction> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? amountText,
    Expression<String>? currency,
    Expression<String>? category,
    Expression<String>? description,
    Expression<int>? dayOfMonth,
    Expression<String>? frequency,
    Expression<String>? lastProcessed,
    Expression<bool>? enabled,
    Expression<String>? skipMonth,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<bool>? autoAdd,
    Expression<bool>? reminderEnabled,
    Expression<int>? reminderDayOffset,
    Expression<String>? reminderTime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (amountText != null) 'amount_text': amountText,
      if (currency != null) 'currency': currency,
      if (category != null) 'category': category,
      if (description != null) 'description': description,
      if (dayOfMonth != null) 'day_of_month': dayOfMonth,
      if (frequency != null) 'frequency': frequency,
      if (lastProcessed != null) 'last_processed': lastProcessed,
      if (enabled != null) 'enabled': enabled,
      if (skipMonth != null) 'skip_month': skipMonth,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (autoAdd != null) 'auto_add': autoAdd,
      if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
      if (reminderDayOffset != null) 'reminder_day_offset': reminderDayOffset,
      if (reminderTime != null) 'reminder_time': reminderTime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecurringTransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String>? amountText,
    Value<String>? currency,
    Value<String>? category,
    Value<String>? description,
    Value<int>? dayOfMonth,
    Value<String>? frequency,
    Value<String?>? lastProcessed,
    Value<bool>? enabled,
    Value<String>? skipMonth,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<bool>? autoAdd,
    Value<bool>? reminderEnabled,
    Value<int>? reminderDayOffset,
    Value<String>? reminderTime,
    Value<int>? rowid,
  }) {
    return RecurringTransactionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amountText: amountText ?? this.amountText,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      description: description ?? this.description,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      frequency: frequency ?? this.frequency,
      lastProcessed: lastProcessed ?? this.lastProcessed,
      enabled: enabled ?? this.enabled,
      skipMonth: skipMonth ?? this.skipMonth,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      autoAdd: autoAdd ?? this.autoAdd,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDayOffset: reminderDayOffset ?? this.reminderDayOffset,
      reminderTime: reminderTime ?? this.reminderTime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amountText.present) {
      map['amount_text'] = Variable<String>(amountText.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (dayOfMonth.present) {
      map['day_of_month'] = Variable<int>(dayOfMonth.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (lastProcessed.present) {
      map['last_processed'] = Variable<String>(lastProcessed.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (skipMonth.present) {
      map['skip_month'] = Variable<String>(skipMonth.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (autoAdd.present) {
      map['auto_add'] = Variable<bool>(autoAdd.value);
    }
    if (reminderEnabled.present) {
      map['reminder_enabled'] = Variable<bool>(reminderEnabled.value);
    }
    if (reminderDayOffset.present) {
      map['reminder_day_offset'] = Variable<int>(reminderDayOffset.value);
    }
    if (reminderTime.present) {
      map['reminder_time'] = Variable<String>(reminderTime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('amountText: $amountText, ')
          ..write('currency: $currency, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('frequency: $frequency, ')
          ..write('lastProcessed: $lastProcessed, ')
          ..write('enabled: $enabled, ')
          ..write('skipMonth: $skipMonth, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('autoAdd: $autoAdd, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderDayOffset: $reminderDayOffset, ')
          ..write('reminderTime: $reminderTime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, valueJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String valueJson;
  final String updatedAt;
  const AppSetting({
    required this.key,
    required this.valueJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value_json'] = Variable<String>(valueJson);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      valueJson: Value(valueJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'valueJson': serializer.toJson<String>(valueJson),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  AppSetting copyWith({String? key, String? valueJson, String? updatedAt}) =>
      AppSetting(
        key: key ?? this.key,
        valueJson: valueJson ?? this.valueJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, valueJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.valueJson == this.valueJson &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> valueJson;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String valueJson,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       valueJson = Value(valueJson),
       updatedAt = Value(updatedAt);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? valueJson,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (valueJson != null) 'value_json': valueJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? valueJson,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      valueJson: valueJson ?? this.valueJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FinancialPlansTable extends FinancialPlans
    with TableInfo<$FinancialPlansTable, FinancialPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FinancialPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectionCurrencyMeta =
      const VerificationMeta('projectionCurrency');
  @override
  late final GeneratedColumn<String> projectionCurrency =
      GeneratedColumn<String>(
        'projection_currency',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _startingBalanceTextMeta =
      const VerificationMeta('startingBalanceText');
  @override
  late final GeneratedColumn<String> startingBalanceText =
      GeneratedColumn<String>(
        'starting_balance_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _startingBalanceDateMeta =
      const VerificationMeta('startingBalanceDate');
  @override
  late final GeneratedColumn<String> startingBalanceDate =
      GeneratedColumn<String>(
        'starting_balance_date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _startingBalanceModeMeta =
      const VerificationMeta('startingBalanceMode');
  @override
  late final GeneratedColumn<String> startingBalanceMode =
      GeneratedColumn<String>(
        'starting_balance_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _snapshotWealthCurrencyMeta =
      const VerificationMeta('snapshotWealthCurrency');
  @override
  late final GeneratedColumn<String> snapshotWealthCurrency =
      GeneratedColumn<String>(
        'snapshot_wealth_currency',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _startingAssetBreakdownJsonMeta =
      const VerificationMeta('startingAssetBreakdownJson');
  @override
  late final GeneratedColumn<String> startingAssetBreakdownJson =
      GeneratedColumn<String>(
        'starting_asset_breakdown_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _monthlyIncomeTextMeta = const VerificationMeta(
    'monthlyIncomeText',
  );
  @override
  late final GeneratedColumn<String> monthlyIncomeText =
      GeneratedColumn<String>(
        'monthly_income_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _monthlyExpensesTextMeta =
      const VerificationMeta('monthlyExpensesText');
  @override
  late final GeneratedColumn<String> monthlyExpensesText =
      GeneratedColumn<String>(
        'monthly_expenses_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _includeInstallmentsMeta =
      const VerificationMeta('includeInstallments');
  @override
  late final GeneratedColumn<bool> includeInstallments = GeneratedColumn<bool>(
    'include_installments',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("include_installments" IN (0, 1))',
    ),
  );
  static const VerificationMeta _includeZakatMeta = const VerificationMeta(
    'includeZakat',
  );
  @override
  late final GeneratedColumn<bool> includeZakat = GeneratedColumn<bool>(
    'include_zakat',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("include_zakat" IN (0, 1))',
    ),
  );
  static const VerificationMeta _durationYearsMeta = const VerificationMeta(
    'durationYears',
  );
  @override
  late final GeneratedColumn<int> durationYears = GeneratedColumn<int>(
    'duration_years',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
  );
  static const VerificationMeta _startingAssetsTextMeta =
      const VerificationMeta('startingAssetsText');
  @override
  late final GeneratedColumn<String> startingAssetsText =
      GeneratedColumn<String>(
        'starting_assets_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _startingLiabilitiesTextMeta =
      const VerificationMeta('startingLiabilitiesText');
  @override
  late final GeneratedColumn<String> startingLiabilitiesText =
      GeneratedColumn<String>(
        'starting_liabilities_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _startingNetWorthTextMeta =
      const VerificationMeta('startingNetWorthText');
  @override
  late final GeneratedColumn<String> startingNetWorthText =
      GeneratedColumn<String>(
        'starting_net_worth_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _startingNisabSnapshotTextMeta =
      const VerificationMeta('startingNisabSnapshotText');
  @override
  late final GeneratedColumn<String> startingNisabSnapshotText =
      GeneratedColumn<String>(
        'starting_nisab_snapshot_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _startingGoldPriceSnapshotTextMeta =
      const VerificationMeta('startingGoldPriceSnapshotText');
  @override
  late final GeneratedColumn<String> startingGoldPriceSnapshotText =
      GeneratedColumn<String>(
        'starting_gold_price_snapshot_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _startingFxSnapshotJsonMeta =
      const VerificationMeta('startingFxSnapshotJson');
  @override
  late final GeneratedColumn<String> startingFxSnapshotJson =
      GeneratedColumn<String>(
        'starting_fx_snapshot_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    startDate,
    projectionCurrency,
    startingBalanceText,
    startingBalanceDate,
    startingBalanceMode,
    snapshotWealthCurrency,
    startingAssetBreakdownJson,
    monthlyIncomeText,
    monthlyExpensesText,
    includeInstallments,
    includeZakat,
    durationYears,
    createdAt,
    isActive,
    startingAssetsText,
    startingLiabilitiesText,
    startingNetWorthText,
    startingNisabSnapshotText,
    startingGoldPriceSnapshotText,
    startingFxSnapshotJson,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'financial_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<FinancialPlan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('projection_currency')) {
      context.handle(
        _projectionCurrencyMeta,
        projectionCurrency.isAcceptableOrUnknown(
          data['projection_currency']!,
          _projectionCurrencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_projectionCurrencyMeta);
    }
    if (data.containsKey('starting_balance_text')) {
      context.handle(
        _startingBalanceTextMeta,
        startingBalanceText.isAcceptableOrUnknown(
          data['starting_balance_text']!,
          _startingBalanceTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startingBalanceTextMeta);
    }
    if (data.containsKey('starting_balance_date')) {
      context.handle(
        _startingBalanceDateMeta,
        startingBalanceDate.isAcceptableOrUnknown(
          data['starting_balance_date']!,
          _startingBalanceDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startingBalanceDateMeta);
    }
    if (data.containsKey('starting_balance_mode')) {
      context.handle(
        _startingBalanceModeMeta,
        startingBalanceMode.isAcceptableOrUnknown(
          data['starting_balance_mode']!,
          _startingBalanceModeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startingBalanceModeMeta);
    }
    if (data.containsKey('snapshot_wealth_currency')) {
      context.handle(
        _snapshotWealthCurrencyMeta,
        snapshotWealthCurrency.isAcceptableOrUnknown(
          data['snapshot_wealth_currency']!,
          _snapshotWealthCurrencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotWealthCurrencyMeta);
    }
    if (data.containsKey('starting_asset_breakdown_json')) {
      context.handle(
        _startingAssetBreakdownJsonMeta,
        startingAssetBreakdownJson.isAcceptableOrUnknown(
          data['starting_asset_breakdown_json']!,
          _startingAssetBreakdownJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startingAssetBreakdownJsonMeta);
    }
    if (data.containsKey('monthly_income_text')) {
      context.handle(
        _monthlyIncomeTextMeta,
        monthlyIncomeText.isAcceptableOrUnknown(
          data['monthly_income_text']!,
          _monthlyIncomeTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_monthlyIncomeTextMeta);
    }
    if (data.containsKey('monthly_expenses_text')) {
      context.handle(
        _monthlyExpensesTextMeta,
        monthlyExpensesText.isAcceptableOrUnknown(
          data['monthly_expenses_text']!,
          _monthlyExpensesTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_monthlyExpensesTextMeta);
    }
    if (data.containsKey('include_installments')) {
      context.handle(
        _includeInstallmentsMeta,
        includeInstallments.isAcceptableOrUnknown(
          data['include_installments']!,
          _includeInstallmentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_includeInstallmentsMeta);
    }
    if (data.containsKey('include_zakat')) {
      context.handle(
        _includeZakatMeta,
        includeZakat.isAcceptableOrUnknown(
          data['include_zakat']!,
          _includeZakatMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_includeZakatMeta);
    }
    if (data.containsKey('duration_years')) {
      context.handle(
        _durationYearsMeta,
        durationYears.isAcceptableOrUnknown(
          data['duration_years']!,
          _durationYearsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationYearsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    } else if (isInserting) {
      context.missing(_isActiveMeta);
    }
    if (data.containsKey('starting_assets_text')) {
      context.handle(
        _startingAssetsTextMeta,
        startingAssetsText.isAcceptableOrUnknown(
          data['starting_assets_text']!,
          _startingAssetsTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startingAssetsTextMeta);
    }
    if (data.containsKey('starting_liabilities_text')) {
      context.handle(
        _startingLiabilitiesTextMeta,
        startingLiabilitiesText.isAcceptableOrUnknown(
          data['starting_liabilities_text']!,
          _startingLiabilitiesTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startingLiabilitiesTextMeta);
    }
    if (data.containsKey('starting_net_worth_text')) {
      context.handle(
        _startingNetWorthTextMeta,
        startingNetWorthText.isAcceptableOrUnknown(
          data['starting_net_worth_text']!,
          _startingNetWorthTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startingNetWorthTextMeta);
    }
    if (data.containsKey('starting_nisab_snapshot_text')) {
      context.handle(
        _startingNisabSnapshotTextMeta,
        startingNisabSnapshotText.isAcceptableOrUnknown(
          data['starting_nisab_snapshot_text']!,
          _startingNisabSnapshotTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startingNisabSnapshotTextMeta);
    }
    if (data.containsKey('starting_gold_price_snapshot_text')) {
      context.handle(
        _startingGoldPriceSnapshotTextMeta,
        startingGoldPriceSnapshotText.isAcceptableOrUnknown(
          data['starting_gold_price_snapshot_text']!,
          _startingGoldPriceSnapshotTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startingGoldPriceSnapshotTextMeta);
    }
    if (data.containsKey('starting_fx_snapshot_json')) {
      context.handle(
        _startingFxSnapshotJsonMeta,
        startingFxSnapshotJson.isAcceptableOrUnknown(
          data['starting_fx_snapshot_json']!,
          _startingFxSnapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startingFxSnapshotJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FinancialPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FinancialPlan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      projectionCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}projection_currency'],
      )!,
      startingBalanceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}starting_balance_text'],
      )!,
      startingBalanceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}starting_balance_date'],
      )!,
      startingBalanceMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}starting_balance_mode'],
      )!,
      snapshotWealthCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_wealth_currency'],
      )!,
      startingAssetBreakdownJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}starting_asset_breakdown_json'],
      )!,
      monthlyIncomeText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}monthly_income_text'],
      )!,
      monthlyExpensesText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}monthly_expenses_text'],
      )!,
      includeInstallments: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}include_installments'],
      )!,
      includeZakat: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}include_zakat'],
      )!,
      durationYears: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_years'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      startingAssetsText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}starting_assets_text'],
      )!,
      startingLiabilitiesText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}starting_liabilities_text'],
      )!,
      startingNetWorthText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}starting_net_worth_text'],
      )!,
      startingNisabSnapshotText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}starting_nisab_snapshot_text'],
      )!,
      startingGoldPriceSnapshotText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}starting_gold_price_snapshot_text'],
      )!,
      startingFxSnapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}starting_fx_snapshot_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $FinancialPlansTable createAlias(String alias) {
    return $FinancialPlansTable(attachedDatabase, alias);
  }
}

class FinancialPlan extends DataClass implements Insertable<FinancialPlan> {
  final String id;
  final String name;
  final String startDate;
  final String projectionCurrency;
  final String startingBalanceText;
  final String startingBalanceDate;
  final String startingBalanceMode;
  final String snapshotWealthCurrency;
  final String startingAssetBreakdownJson;
  final String monthlyIncomeText;
  final String monthlyExpensesText;
  final bool includeInstallments;
  final bool includeZakat;
  final int durationYears;
  final String createdAt;
  final bool isActive;
  final String startingAssetsText;
  final String startingLiabilitiesText;
  final String startingNetWorthText;
  final String startingNisabSnapshotText;
  final String startingGoldPriceSnapshotText;
  final String startingFxSnapshotJson;
  final String updatedAt;
  final String? deletedAt;
  const FinancialPlan({
    required this.id,
    required this.name,
    required this.startDate,
    required this.projectionCurrency,
    required this.startingBalanceText,
    required this.startingBalanceDate,
    required this.startingBalanceMode,
    required this.snapshotWealthCurrency,
    required this.startingAssetBreakdownJson,
    required this.monthlyIncomeText,
    required this.monthlyExpensesText,
    required this.includeInstallments,
    required this.includeZakat,
    required this.durationYears,
    required this.createdAt,
    required this.isActive,
    required this.startingAssetsText,
    required this.startingLiabilitiesText,
    required this.startingNetWorthText,
    required this.startingNisabSnapshotText,
    required this.startingGoldPriceSnapshotText,
    required this.startingFxSnapshotJson,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['start_date'] = Variable<String>(startDate);
    map['projection_currency'] = Variable<String>(projectionCurrency);
    map['starting_balance_text'] = Variable<String>(startingBalanceText);
    map['starting_balance_date'] = Variable<String>(startingBalanceDate);
    map['starting_balance_mode'] = Variable<String>(startingBalanceMode);
    map['snapshot_wealth_currency'] = Variable<String>(snapshotWealthCurrency);
    map['starting_asset_breakdown_json'] = Variable<String>(
      startingAssetBreakdownJson,
    );
    map['monthly_income_text'] = Variable<String>(monthlyIncomeText);
    map['monthly_expenses_text'] = Variable<String>(monthlyExpensesText);
    map['include_installments'] = Variable<bool>(includeInstallments);
    map['include_zakat'] = Variable<bool>(includeZakat);
    map['duration_years'] = Variable<int>(durationYears);
    map['created_at'] = Variable<String>(createdAt);
    map['is_active'] = Variable<bool>(isActive);
    map['starting_assets_text'] = Variable<String>(startingAssetsText);
    map['starting_liabilities_text'] = Variable<String>(
      startingLiabilitiesText,
    );
    map['starting_net_worth_text'] = Variable<String>(startingNetWorthText);
    map['starting_nisab_snapshot_text'] = Variable<String>(
      startingNisabSnapshotText,
    );
    map['starting_gold_price_snapshot_text'] = Variable<String>(
      startingGoldPriceSnapshotText,
    );
    map['starting_fx_snapshot_json'] = Variable<String>(startingFxSnapshotJson);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  FinancialPlansCompanion toCompanion(bool nullToAbsent) {
    return FinancialPlansCompanion(
      id: Value(id),
      name: Value(name),
      startDate: Value(startDate),
      projectionCurrency: Value(projectionCurrency),
      startingBalanceText: Value(startingBalanceText),
      startingBalanceDate: Value(startingBalanceDate),
      startingBalanceMode: Value(startingBalanceMode),
      snapshotWealthCurrency: Value(snapshotWealthCurrency),
      startingAssetBreakdownJson: Value(startingAssetBreakdownJson),
      monthlyIncomeText: Value(monthlyIncomeText),
      monthlyExpensesText: Value(monthlyExpensesText),
      includeInstallments: Value(includeInstallments),
      includeZakat: Value(includeZakat),
      durationYears: Value(durationYears),
      createdAt: Value(createdAt),
      isActive: Value(isActive),
      startingAssetsText: Value(startingAssetsText),
      startingLiabilitiesText: Value(startingLiabilitiesText),
      startingNetWorthText: Value(startingNetWorthText),
      startingNisabSnapshotText: Value(startingNisabSnapshotText),
      startingGoldPriceSnapshotText: Value(startingGoldPriceSnapshotText),
      startingFxSnapshotJson: Value(startingFxSnapshotJson),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory FinancialPlan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FinancialPlan(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      startDate: serializer.fromJson<String>(json['startDate']),
      projectionCurrency: serializer.fromJson<String>(
        json['projectionCurrency'],
      ),
      startingBalanceText: serializer.fromJson<String>(
        json['startingBalanceText'],
      ),
      startingBalanceDate: serializer.fromJson<String>(
        json['startingBalanceDate'],
      ),
      startingBalanceMode: serializer.fromJson<String>(
        json['startingBalanceMode'],
      ),
      snapshotWealthCurrency: serializer.fromJson<String>(
        json['snapshotWealthCurrency'],
      ),
      startingAssetBreakdownJson: serializer.fromJson<String>(
        json['startingAssetBreakdownJson'],
      ),
      monthlyIncomeText: serializer.fromJson<String>(json['monthlyIncomeText']),
      monthlyExpensesText: serializer.fromJson<String>(
        json['monthlyExpensesText'],
      ),
      includeInstallments: serializer.fromJson<bool>(
        json['includeInstallments'],
      ),
      includeZakat: serializer.fromJson<bool>(json['includeZakat']),
      durationYears: serializer.fromJson<int>(json['durationYears']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      startingAssetsText: serializer.fromJson<String>(
        json['startingAssetsText'],
      ),
      startingLiabilitiesText: serializer.fromJson<String>(
        json['startingLiabilitiesText'],
      ),
      startingNetWorthText: serializer.fromJson<String>(
        json['startingNetWorthText'],
      ),
      startingNisabSnapshotText: serializer.fromJson<String>(
        json['startingNisabSnapshotText'],
      ),
      startingGoldPriceSnapshotText: serializer.fromJson<String>(
        json['startingGoldPriceSnapshotText'],
      ),
      startingFxSnapshotJson: serializer.fromJson<String>(
        json['startingFxSnapshotJson'],
      ),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'startDate': serializer.toJson<String>(startDate),
      'projectionCurrency': serializer.toJson<String>(projectionCurrency),
      'startingBalanceText': serializer.toJson<String>(startingBalanceText),
      'startingBalanceDate': serializer.toJson<String>(startingBalanceDate),
      'startingBalanceMode': serializer.toJson<String>(startingBalanceMode),
      'snapshotWealthCurrency': serializer.toJson<String>(
        snapshotWealthCurrency,
      ),
      'startingAssetBreakdownJson': serializer.toJson<String>(
        startingAssetBreakdownJson,
      ),
      'monthlyIncomeText': serializer.toJson<String>(monthlyIncomeText),
      'monthlyExpensesText': serializer.toJson<String>(monthlyExpensesText),
      'includeInstallments': serializer.toJson<bool>(includeInstallments),
      'includeZakat': serializer.toJson<bool>(includeZakat),
      'durationYears': serializer.toJson<int>(durationYears),
      'createdAt': serializer.toJson<String>(createdAt),
      'isActive': serializer.toJson<bool>(isActive),
      'startingAssetsText': serializer.toJson<String>(startingAssetsText),
      'startingLiabilitiesText': serializer.toJson<String>(
        startingLiabilitiesText,
      ),
      'startingNetWorthText': serializer.toJson<String>(startingNetWorthText),
      'startingNisabSnapshotText': serializer.toJson<String>(
        startingNisabSnapshotText,
      ),
      'startingGoldPriceSnapshotText': serializer.toJson<String>(
        startingGoldPriceSnapshotText,
      ),
      'startingFxSnapshotJson': serializer.toJson<String>(
        startingFxSnapshotJson,
      ),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  FinancialPlan copyWith({
    String? id,
    String? name,
    String? startDate,
    String? projectionCurrency,
    String? startingBalanceText,
    String? startingBalanceDate,
    String? startingBalanceMode,
    String? snapshotWealthCurrency,
    String? startingAssetBreakdownJson,
    String? monthlyIncomeText,
    String? monthlyExpensesText,
    bool? includeInstallments,
    bool? includeZakat,
    int? durationYears,
    String? createdAt,
    bool? isActive,
    String? startingAssetsText,
    String? startingLiabilitiesText,
    String? startingNetWorthText,
    String? startingNisabSnapshotText,
    String? startingGoldPriceSnapshotText,
    String? startingFxSnapshotJson,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
  }) => FinancialPlan(
    id: id ?? this.id,
    name: name ?? this.name,
    startDate: startDate ?? this.startDate,
    projectionCurrency: projectionCurrency ?? this.projectionCurrency,
    startingBalanceText: startingBalanceText ?? this.startingBalanceText,
    startingBalanceDate: startingBalanceDate ?? this.startingBalanceDate,
    startingBalanceMode: startingBalanceMode ?? this.startingBalanceMode,
    snapshotWealthCurrency:
        snapshotWealthCurrency ?? this.snapshotWealthCurrency,
    startingAssetBreakdownJson:
        startingAssetBreakdownJson ?? this.startingAssetBreakdownJson,
    monthlyIncomeText: monthlyIncomeText ?? this.monthlyIncomeText,
    monthlyExpensesText: monthlyExpensesText ?? this.monthlyExpensesText,
    includeInstallments: includeInstallments ?? this.includeInstallments,
    includeZakat: includeZakat ?? this.includeZakat,
    durationYears: durationYears ?? this.durationYears,
    createdAt: createdAt ?? this.createdAt,
    isActive: isActive ?? this.isActive,
    startingAssetsText: startingAssetsText ?? this.startingAssetsText,
    startingLiabilitiesText:
        startingLiabilitiesText ?? this.startingLiabilitiesText,
    startingNetWorthText: startingNetWorthText ?? this.startingNetWorthText,
    startingNisabSnapshotText:
        startingNisabSnapshotText ?? this.startingNisabSnapshotText,
    startingGoldPriceSnapshotText:
        startingGoldPriceSnapshotText ?? this.startingGoldPriceSnapshotText,
    startingFxSnapshotJson:
        startingFxSnapshotJson ?? this.startingFxSnapshotJson,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  FinancialPlan copyWithCompanion(FinancialPlansCompanion data) {
    return FinancialPlan(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      projectionCurrency: data.projectionCurrency.present
          ? data.projectionCurrency.value
          : this.projectionCurrency,
      startingBalanceText: data.startingBalanceText.present
          ? data.startingBalanceText.value
          : this.startingBalanceText,
      startingBalanceDate: data.startingBalanceDate.present
          ? data.startingBalanceDate.value
          : this.startingBalanceDate,
      startingBalanceMode: data.startingBalanceMode.present
          ? data.startingBalanceMode.value
          : this.startingBalanceMode,
      snapshotWealthCurrency: data.snapshotWealthCurrency.present
          ? data.snapshotWealthCurrency.value
          : this.snapshotWealthCurrency,
      startingAssetBreakdownJson: data.startingAssetBreakdownJson.present
          ? data.startingAssetBreakdownJson.value
          : this.startingAssetBreakdownJson,
      monthlyIncomeText: data.monthlyIncomeText.present
          ? data.monthlyIncomeText.value
          : this.monthlyIncomeText,
      monthlyExpensesText: data.monthlyExpensesText.present
          ? data.monthlyExpensesText.value
          : this.monthlyExpensesText,
      includeInstallments: data.includeInstallments.present
          ? data.includeInstallments.value
          : this.includeInstallments,
      includeZakat: data.includeZakat.present
          ? data.includeZakat.value
          : this.includeZakat,
      durationYears: data.durationYears.present
          ? data.durationYears.value
          : this.durationYears,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      startingAssetsText: data.startingAssetsText.present
          ? data.startingAssetsText.value
          : this.startingAssetsText,
      startingLiabilitiesText: data.startingLiabilitiesText.present
          ? data.startingLiabilitiesText.value
          : this.startingLiabilitiesText,
      startingNetWorthText: data.startingNetWorthText.present
          ? data.startingNetWorthText.value
          : this.startingNetWorthText,
      startingNisabSnapshotText: data.startingNisabSnapshotText.present
          ? data.startingNisabSnapshotText.value
          : this.startingNisabSnapshotText,
      startingGoldPriceSnapshotText: data.startingGoldPriceSnapshotText.present
          ? data.startingGoldPriceSnapshotText.value
          : this.startingGoldPriceSnapshotText,
      startingFxSnapshotJson: data.startingFxSnapshotJson.present
          ? data.startingFxSnapshotJson.value
          : this.startingFxSnapshotJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FinancialPlan(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('startDate: $startDate, ')
          ..write('projectionCurrency: $projectionCurrency, ')
          ..write('startingBalanceText: $startingBalanceText, ')
          ..write('startingBalanceDate: $startingBalanceDate, ')
          ..write('startingBalanceMode: $startingBalanceMode, ')
          ..write('snapshotWealthCurrency: $snapshotWealthCurrency, ')
          ..write('startingAssetBreakdownJson: $startingAssetBreakdownJson, ')
          ..write('monthlyIncomeText: $monthlyIncomeText, ')
          ..write('monthlyExpensesText: $monthlyExpensesText, ')
          ..write('includeInstallments: $includeInstallments, ')
          ..write('includeZakat: $includeZakat, ')
          ..write('durationYears: $durationYears, ')
          ..write('createdAt: $createdAt, ')
          ..write('isActive: $isActive, ')
          ..write('startingAssetsText: $startingAssetsText, ')
          ..write('startingLiabilitiesText: $startingLiabilitiesText, ')
          ..write('startingNetWorthText: $startingNetWorthText, ')
          ..write('startingNisabSnapshotText: $startingNisabSnapshotText, ')
          ..write(
            'startingGoldPriceSnapshotText: $startingGoldPriceSnapshotText, ',
          )
          ..write('startingFxSnapshotJson: $startingFxSnapshotJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    startDate,
    projectionCurrency,
    startingBalanceText,
    startingBalanceDate,
    startingBalanceMode,
    snapshotWealthCurrency,
    startingAssetBreakdownJson,
    monthlyIncomeText,
    monthlyExpensesText,
    includeInstallments,
    includeZakat,
    durationYears,
    createdAt,
    isActive,
    startingAssetsText,
    startingLiabilitiesText,
    startingNetWorthText,
    startingNisabSnapshotText,
    startingGoldPriceSnapshotText,
    startingFxSnapshotJson,
    updatedAt,
    deletedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FinancialPlan &&
          other.id == this.id &&
          other.name == this.name &&
          other.startDate == this.startDate &&
          other.projectionCurrency == this.projectionCurrency &&
          other.startingBalanceText == this.startingBalanceText &&
          other.startingBalanceDate == this.startingBalanceDate &&
          other.startingBalanceMode == this.startingBalanceMode &&
          other.snapshotWealthCurrency == this.snapshotWealthCurrency &&
          other.startingAssetBreakdownJson == this.startingAssetBreakdownJson &&
          other.monthlyIncomeText == this.monthlyIncomeText &&
          other.monthlyExpensesText == this.monthlyExpensesText &&
          other.includeInstallments == this.includeInstallments &&
          other.includeZakat == this.includeZakat &&
          other.durationYears == this.durationYears &&
          other.createdAt == this.createdAt &&
          other.isActive == this.isActive &&
          other.startingAssetsText == this.startingAssetsText &&
          other.startingLiabilitiesText == this.startingLiabilitiesText &&
          other.startingNetWorthText == this.startingNetWorthText &&
          other.startingNisabSnapshotText == this.startingNisabSnapshotText &&
          other.startingGoldPriceSnapshotText ==
              this.startingGoldPriceSnapshotText &&
          other.startingFxSnapshotJson == this.startingFxSnapshotJson &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class FinancialPlansCompanion extends UpdateCompanion<FinancialPlan> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> startDate;
  final Value<String> projectionCurrency;
  final Value<String> startingBalanceText;
  final Value<String> startingBalanceDate;
  final Value<String> startingBalanceMode;
  final Value<String> snapshotWealthCurrency;
  final Value<String> startingAssetBreakdownJson;
  final Value<String> monthlyIncomeText;
  final Value<String> monthlyExpensesText;
  final Value<bool> includeInstallments;
  final Value<bool> includeZakat;
  final Value<int> durationYears;
  final Value<String> createdAt;
  final Value<bool> isActive;
  final Value<String> startingAssetsText;
  final Value<String> startingLiabilitiesText;
  final Value<String> startingNetWorthText;
  final Value<String> startingNisabSnapshotText;
  final Value<String> startingGoldPriceSnapshotText;
  final Value<String> startingFxSnapshotJson;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const FinancialPlansCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.startDate = const Value.absent(),
    this.projectionCurrency = const Value.absent(),
    this.startingBalanceText = const Value.absent(),
    this.startingBalanceDate = const Value.absent(),
    this.startingBalanceMode = const Value.absent(),
    this.snapshotWealthCurrency = const Value.absent(),
    this.startingAssetBreakdownJson = const Value.absent(),
    this.monthlyIncomeText = const Value.absent(),
    this.monthlyExpensesText = const Value.absent(),
    this.includeInstallments = const Value.absent(),
    this.includeZakat = const Value.absent(),
    this.durationYears = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isActive = const Value.absent(),
    this.startingAssetsText = const Value.absent(),
    this.startingLiabilitiesText = const Value.absent(),
    this.startingNetWorthText = const Value.absent(),
    this.startingNisabSnapshotText = const Value.absent(),
    this.startingGoldPriceSnapshotText = const Value.absent(),
    this.startingFxSnapshotJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FinancialPlansCompanion.insert({
    required String id,
    required String name,
    required String startDate,
    required String projectionCurrency,
    required String startingBalanceText,
    required String startingBalanceDate,
    required String startingBalanceMode,
    required String snapshotWealthCurrency,
    required String startingAssetBreakdownJson,
    required String monthlyIncomeText,
    required String monthlyExpensesText,
    required bool includeInstallments,
    required bool includeZakat,
    required int durationYears,
    required String createdAt,
    required bool isActive,
    required String startingAssetsText,
    required String startingLiabilitiesText,
    required String startingNetWorthText,
    required String startingNisabSnapshotText,
    required String startingGoldPriceSnapshotText,
    required String startingFxSnapshotJson,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       startDate = Value(startDate),
       projectionCurrency = Value(projectionCurrency),
       startingBalanceText = Value(startingBalanceText),
       startingBalanceDate = Value(startingBalanceDate),
       startingBalanceMode = Value(startingBalanceMode),
       snapshotWealthCurrency = Value(snapshotWealthCurrency),
       startingAssetBreakdownJson = Value(startingAssetBreakdownJson),
       monthlyIncomeText = Value(monthlyIncomeText),
       monthlyExpensesText = Value(monthlyExpensesText),
       includeInstallments = Value(includeInstallments),
       includeZakat = Value(includeZakat),
       durationYears = Value(durationYears),
       createdAt = Value(createdAt),
       isActive = Value(isActive),
       startingAssetsText = Value(startingAssetsText),
       startingLiabilitiesText = Value(startingLiabilitiesText),
       startingNetWorthText = Value(startingNetWorthText),
       startingNisabSnapshotText = Value(startingNisabSnapshotText),
       startingGoldPriceSnapshotText = Value(startingGoldPriceSnapshotText),
       startingFxSnapshotJson = Value(startingFxSnapshotJson),
       updatedAt = Value(updatedAt);
  static Insertable<FinancialPlan> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? startDate,
    Expression<String>? projectionCurrency,
    Expression<String>? startingBalanceText,
    Expression<String>? startingBalanceDate,
    Expression<String>? startingBalanceMode,
    Expression<String>? snapshotWealthCurrency,
    Expression<String>? startingAssetBreakdownJson,
    Expression<String>? monthlyIncomeText,
    Expression<String>? monthlyExpensesText,
    Expression<bool>? includeInstallments,
    Expression<bool>? includeZakat,
    Expression<int>? durationYears,
    Expression<String>? createdAt,
    Expression<bool>? isActive,
    Expression<String>? startingAssetsText,
    Expression<String>? startingLiabilitiesText,
    Expression<String>? startingNetWorthText,
    Expression<String>? startingNisabSnapshotText,
    Expression<String>? startingGoldPriceSnapshotText,
    Expression<String>? startingFxSnapshotJson,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (startDate != null) 'start_date': startDate,
      if (projectionCurrency != null) 'projection_currency': projectionCurrency,
      if (startingBalanceText != null)
        'starting_balance_text': startingBalanceText,
      if (startingBalanceDate != null)
        'starting_balance_date': startingBalanceDate,
      if (startingBalanceMode != null)
        'starting_balance_mode': startingBalanceMode,
      if (snapshotWealthCurrency != null)
        'snapshot_wealth_currency': snapshotWealthCurrency,
      if (startingAssetBreakdownJson != null)
        'starting_asset_breakdown_json': startingAssetBreakdownJson,
      if (monthlyIncomeText != null) 'monthly_income_text': monthlyIncomeText,
      if (monthlyExpensesText != null)
        'monthly_expenses_text': monthlyExpensesText,
      if (includeInstallments != null)
        'include_installments': includeInstallments,
      if (includeZakat != null) 'include_zakat': includeZakat,
      if (durationYears != null) 'duration_years': durationYears,
      if (createdAt != null) 'created_at': createdAt,
      if (isActive != null) 'is_active': isActive,
      if (startingAssetsText != null)
        'starting_assets_text': startingAssetsText,
      if (startingLiabilitiesText != null)
        'starting_liabilities_text': startingLiabilitiesText,
      if (startingNetWorthText != null)
        'starting_net_worth_text': startingNetWorthText,
      if (startingNisabSnapshotText != null)
        'starting_nisab_snapshot_text': startingNisabSnapshotText,
      if (startingGoldPriceSnapshotText != null)
        'starting_gold_price_snapshot_text': startingGoldPriceSnapshotText,
      if (startingFxSnapshotJson != null)
        'starting_fx_snapshot_json': startingFxSnapshotJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FinancialPlansCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? startDate,
    Value<String>? projectionCurrency,
    Value<String>? startingBalanceText,
    Value<String>? startingBalanceDate,
    Value<String>? startingBalanceMode,
    Value<String>? snapshotWealthCurrency,
    Value<String>? startingAssetBreakdownJson,
    Value<String>? monthlyIncomeText,
    Value<String>? monthlyExpensesText,
    Value<bool>? includeInstallments,
    Value<bool>? includeZakat,
    Value<int>? durationYears,
    Value<String>? createdAt,
    Value<bool>? isActive,
    Value<String>? startingAssetsText,
    Value<String>? startingLiabilitiesText,
    Value<String>? startingNetWorthText,
    Value<String>? startingNisabSnapshotText,
    Value<String>? startingGoldPriceSnapshotText,
    Value<String>? startingFxSnapshotJson,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return FinancialPlansCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      projectionCurrency: projectionCurrency ?? this.projectionCurrency,
      startingBalanceText: startingBalanceText ?? this.startingBalanceText,
      startingBalanceDate: startingBalanceDate ?? this.startingBalanceDate,
      startingBalanceMode: startingBalanceMode ?? this.startingBalanceMode,
      snapshotWealthCurrency:
          snapshotWealthCurrency ?? this.snapshotWealthCurrency,
      startingAssetBreakdownJson:
          startingAssetBreakdownJson ?? this.startingAssetBreakdownJson,
      monthlyIncomeText: monthlyIncomeText ?? this.monthlyIncomeText,
      monthlyExpensesText: monthlyExpensesText ?? this.monthlyExpensesText,
      includeInstallments: includeInstallments ?? this.includeInstallments,
      includeZakat: includeZakat ?? this.includeZakat,
      durationYears: durationYears ?? this.durationYears,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      startingAssetsText: startingAssetsText ?? this.startingAssetsText,
      startingLiabilitiesText:
          startingLiabilitiesText ?? this.startingLiabilitiesText,
      startingNetWorthText: startingNetWorthText ?? this.startingNetWorthText,
      startingNisabSnapshotText:
          startingNisabSnapshotText ?? this.startingNisabSnapshotText,
      startingGoldPriceSnapshotText:
          startingGoldPriceSnapshotText ?? this.startingGoldPriceSnapshotText,
      startingFxSnapshotJson:
          startingFxSnapshotJson ?? this.startingFxSnapshotJson,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (projectionCurrency.present) {
      map['projection_currency'] = Variable<String>(projectionCurrency.value);
    }
    if (startingBalanceText.present) {
      map['starting_balance_text'] = Variable<String>(
        startingBalanceText.value,
      );
    }
    if (startingBalanceDate.present) {
      map['starting_balance_date'] = Variable<String>(
        startingBalanceDate.value,
      );
    }
    if (startingBalanceMode.present) {
      map['starting_balance_mode'] = Variable<String>(
        startingBalanceMode.value,
      );
    }
    if (snapshotWealthCurrency.present) {
      map['snapshot_wealth_currency'] = Variable<String>(
        snapshotWealthCurrency.value,
      );
    }
    if (startingAssetBreakdownJson.present) {
      map['starting_asset_breakdown_json'] = Variable<String>(
        startingAssetBreakdownJson.value,
      );
    }
    if (monthlyIncomeText.present) {
      map['monthly_income_text'] = Variable<String>(monthlyIncomeText.value);
    }
    if (monthlyExpensesText.present) {
      map['monthly_expenses_text'] = Variable<String>(
        monthlyExpensesText.value,
      );
    }
    if (includeInstallments.present) {
      map['include_installments'] = Variable<bool>(includeInstallments.value);
    }
    if (includeZakat.present) {
      map['include_zakat'] = Variable<bool>(includeZakat.value);
    }
    if (durationYears.present) {
      map['duration_years'] = Variable<int>(durationYears.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (startingAssetsText.present) {
      map['starting_assets_text'] = Variable<String>(startingAssetsText.value);
    }
    if (startingLiabilitiesText.present) {
      map['starting_liabilities_text'] = Variable<String>(
        startingLiabilitiesText.value,
      );
    }
    if (startingNetWorthText.present) {
      map['starting_net_worth_text'] = Variable<String>(
        startingNetWorthText.value,
      );
    }
    if (startingNisabSnapshotText.present) {
      map['starting_nisab_snapshot_text'] = Variable<String>(
        startingNisabSnapshotText.value,
      );
    }
    if (startingGoldPriceSnapshotText.present) {
      map['starting_gold_price_snapshot_text'] = Variable<String>(
        startingGoldPriceSnapshotText.value,
      );
    }
    if (startingFxSnapshotJson.present) {
      map['starting_fx_snapshot_json'] = Variable<String>(
        startingFxSnapshotJson.value,
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FinancialPlansCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('startDate: $startDate, ')
          ..write('projectionCurrency: $projectionCurrency, ')
          ..write('startingBalanceText: $startingBalanceText, ')
          ..write('startingBalanceDate: $startingBalanceDate, ')
          ..write('startingBalanceMode: $startingBalanceMode, ')
          ..write('snapshotWealthCurrency: $snapshotWealthCurrency, ')
          ..write('startingAssetBreakdownJson: $startingAssetBreakdownJson, ')
          ..write('monthlyIncomeText: $monthlyIncomeText, ')
          ..write('monthlyExpensesText: $monthlyExpensesText, ')
          ..write('includeInstallments: $includeInstallments, ')
          ..write('includeZakat: $includeZakat, ')
          ..write('durationYears: $durationYears, ')
          ..write('createdAt: $createdAt, ')
          ..write('isActive: $isActive, ')
          ..write('startingAssetsText: $startingAssetsText, ')
          ..write('startingLiabilitiesText: $startingLiabilitiesText, ')
          ..write('startingNetWorthText: $startingNetWorthText, ')
          ..write('startingNisabSnapshotText: $startingNisabSnapshotText, ')
          ..write(
            'startingGoldPriceSnapshotText: $startingGoldPriceSnapshotText, ',
          )
          ..write('startingFxSnapshotJson: $startingFxSnapshotJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MerchantRulesTable extends MerchantRules
    with TableInfo<$MerchantRulesTable, MerchantRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MerchantRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _merchantNameMeta = const VerificationMeta(
    'merchantName',
  );
  @override
  late final GeneratedColumn<String> merchantName = GeneratedColumn<String>(
    'merchant_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _defaultTypeMeta = const VerificationMeta(
    'defaultType',
  );
  @override
  late final GeneratedColumn<String> defaultType = GeneratedColumn<String>(
    'default_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _autoApproveMeta = const VerificationMeta(
    'autoApprove',
  );
  @override
  late final GeneratedColumn<bool> autoApprove = GeneratedColumn<bool>(
    'auto_approve',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_approve" IN (0, 1))',
    ),
  );
  static const VerificationMeta _usageCountMeta = const VerificationMeta(
    'usageCount',
  );
  @override
  late final GeneratedColumn<int> usageCount = GeneratedColumn<int>(
    'usage_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceTextMeta = const VerificationMeta(
    'confidenceText',
  );
  @override
  late final GeneratedColumn<String> confidenceText = GeneratedColumn<String>(
    'confidence_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUsedMeta = const VerificationMeta(
    'lastUsed',
  );
  @override
  late final GeneratedColumn<String> lastUsed = GeneratedColumn<String>(
    'last_used',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aliasesJsonMeta = const VerificationMeta(
    'aliasesJson',
  );
  @override
  late final GeneratedColumn<String> aliasesJson = GeneratedColumn<String>(
    'aliases_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _isBuiltinOverrideMeta = const VerificationMeta(
    'isBuiltinOverride',
  );
  @override
  late final GeneratedColumn<bool> isBuiltinOverride = GeneratedColumn<bool>(
    'is_builtin_override',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_builtin_override" IN (0, 1))',
    ),
  );
  static const VerificationMeta _builtinKeyMeta = const VerificationMeta(
    'builtinKey',
  );
  @override
  late final GeneratedColumn<String> builtinKey = GeneratedColumn<String>(
    'builtin_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    merchantName,
    categoryId,
    defaultType,
    autoApprove,
    usageCount,
    confidenceText,
    lastUsed,
    source,
    aliasesJson,
    enabled,
    isBuiltinOverride,
    builtinKey,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'merchant_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<MerchantRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('merchant_name')) {
      context.handle(
        _merchantNameMeta,
        merchantName.isAcceptableOrUnknown(
          data['merchant_name']!,
          _merchantNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_merchantNameMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('default_type')) {
      context.handle(
        _defaultTypeMeta,
        defaultType.isAcceptableOrUnknown(
          data['default_type']!,
          _defaultTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_defaultTypeMeta);
    }
    if (data.containsKey('auto_approve')) {
      context.handle(
        _autoApproveMeta,
        autoApprove.isAcceptableOrUnknown(
          data['auto_approve']!,
          _autoApproveMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_autoApproveMeta);
    }
    if (data.containsKey('usage_count')) {
      context.handle(
        _usageCountMeta,
        usageCount.isAcceptableOrUnknown(data['usage_count']!, _usageCountMeta),
      );
    } else if (isInserting) {
      context.missing(_usageCountMeta);
    }
    if (data.containsKey('confidence_text')) {
      context.handle(
        _confidenceTextMeta,
        confidenceText.isAcceptableOrUnknown(
          data['confidence_text']!,
          _confidenceTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_confidenceTextMeta);
    }
    if (data.containsKey('last_used')) {
      context.handle(
        _lastUsedMeta,
        lastUsed.isAcceptableOrUnknown(data['last_used']!, _lastUsedMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('aliases_json')) {
      context.handle(
        _aliasesJsonMeta,
        aliasesJson.isAcceptableOrUnknown(
          data['aliases_json']!,
          _aliasesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_aliasesJsonMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    } else if (isInserting) {
      context.missing(_enabledMeta);
    }
    if (data.containsKey('is_builtin_override')) {
      context.handle(
        _isBuiltinOverrideMeta,
        isBuiltinOverride.isAcceptableOrUnknown(
          data['is_builtin_override']!,
          _isBuiltinOverrideMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_isBuiltinOverrideMeta);
    }
    if (data.containsKey('builtin_key')) {
      context.handle(
        _builtinKeyMeta,
        builtinKey.isAcceptableOrUnknown(data['builtin_key']!, _builtinKeyMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MerchantRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MerchantRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      merchantName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_name'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      defaultType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_type'],
      )!,
      autoApprove: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_approve'],
      )!,
      usageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}usage_count'],
      )!,
      confidenceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confidence_text'],
      )!,
      lastUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_used'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      aliasesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aliases_json'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      isBuiltinOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_builtin_override'],
      )!,
      builtinKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}builtin_key'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $MerchantRulesTable createAlias(String alias) {
    return $MerchantRulesTable(attachedDatabase, alias);
  }
}

class MerchantRule extends DataClass implements Insertable<MerchantRule> {
  final String id;
  final String merchantName;
  final String categoryId;
  final String defaultType;
  final bool autoApprove;
  final int usageCount;
  final String confidenceText;
  final String? lastUsed;
  final String source;
  final String aliasesJson;
  final bool enabled;
  final bool isBuiltinOverride;
  final String? builtinKey;
  final String updatedAt;
  final String? deletedAt;
  const MerchantRule({
    required this.id,
    required this.merchantName,
    required this.categoryId,
    required this.defaultType,
    required this.autoApprove,
    required this.usageCount,
    required this.confidenceText,
    this.lastUsed,
    required this.source,
    required this.aliasesJson,
    required this.enabled,
    required this.isBuiltinOverride,
    this.builtinKey,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['merchant_name'] = Variable<String>(merchantName);
    map['category_id'] = Variable<String>(categoryId);
    map['default_type'] = Variable<String>(defaultType);
    map['auto_approve'] = Variable<bool>(autoApprove);
    map['usage_count'] = Variable<int>(usageCount);
    map['confidence_text'] = Variable<String>(confidenceText);
    if (!nullToAbsent || lastUsed != null) {
      map['last_used'] = Variable<String>(lastUsed);
    }
    map['source'] = Variable<String>(source);
    map['aliases_json'] = Variable<String>(aliasesJson);
    map['enabled'] = Variable<bool>(enabled);
    map['is_builtin_override'] = Variable<bool>(isBuiltinOverride);
    if (!nullToAbsent || builtinKey != null) {
      map['builtin_key'] = Variable<String>(builtinKey);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  MerchantRulesCompanion toCompanion(bool nullToAbsent) {
    return MerchantRulesCompanion(
      id: Value(id),
      merchantName: Value(merchantName),
      categoryId: Value(categoryId),
      defaultType: Value(defaultType),
      autoApprove: Value(autoApprove),
      usageCount: Value(usageCount),
      confidenceText: Value(confidenceText),
      lastUsed: lastUsed == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsed),
      source: Value(source),
      aliasesJson: Value(aliasesJson),
      enabled: Value(enabled),
      isBuiltinOverride: Value(isBuiltinOverride),
      builtinKey: builtinKey == null && nullToAbsent
          ? const Value.absent()
          : Value(builtinKey),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory MerchantRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MerchantRule(
      id: serializer.fromJson<String>(json['id']),
      merchantName: serializer.fromJson<String>(json['merchantName']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      defaultType: serializer.fromJson<String>(json['defaultType']),
      autoApprove: serializer.fromJson<bool>(json['autoApprove']),
      usageCount: serializer.fromJson<int>(json['usageCount']),
      confidenceText: serializer.fromJson<String>(json['confidenceText']),
      lastUsed: serializer.fromJson<String?>(json['lastUsed']),
      source: serializer.fromJson<String>(json['source']),
      aliasesJson: serializer.fromJson<String>(json['aliasesJson']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      isBuiltinOverride: serializer.fromJson<bool>(json['isBuiltinOverride']),
      builtinKey: serializer.fromJson<String?>(json['builtinKey']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'merchantName': serializer.toJson<String>(merchantName),
      'categoryId': serializer.toJson<String>(categoryId),
      'defaultType': serializer.toJson<String>(defaultType),
      'autoApprove': serializer.toJson<bool>(autoApprove),
      'usageCount': serializer.toJson<int>(usageCount),
      'confidenceText': serializer.toJson<String>(confidenceText),
      'lastUsed': serializer.toJson<String?>(lastUsed),
      'source': serializer.toJson<String>(source),
      'aliasesJson': serializer.toJson<String>(aliasesJson),
      'enabled': serializer.toJson<bool>(enabled),
      'isBuiltinOverride': serializer.toJson<bool>(isBuiltinOverride),
      'builtinKey': serializer.toJson<String?>(builtinKey),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  MerchantRule copyWith({
    String? id,
    String? merchantName,
    String? categoryId,
    String? defaultType,
    bool? autoApprove,
    int? usageCount,
    String? confidenceText,
    Value<String?> lastUsed = const Value.absent(),
    String? source,
    String? aliasesJson,
    bool? enabled,
    bool? isBuiltinOverride,
    Value<String?> builtinKey = const Value.absent(),
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
  }) => MerchantRule(
    id: id ?? this.id,
    merchantName: merchantName ?? this.merchantName,
    categoryId: categoryId ?? this.categoryId,
    defaultType: defaultType ?? this.defaultType,
    autoApprove: autoApprove ?? this.autoApprove,
    usageCount: usageCount ?? this.usageCount,
    confidenceText: confidenceText ?? this.confidenceText,
    lastUsed: lastUsed.present ? lastUsed.value : this.lastUsed,
    source: source ?? this.source,
    aliasesJson: aliasesJson ?? this.aliasesJson,
    enabled: enabled ?? this.enabled,
    isBuiltinOverride: isBuiltinOverride ?? this.isBuiltinOverride,
    builtinKey: builtinKey.present ? builtinKey.value : this.builtinKey,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  MerchantRule copyWithCompanion(MerchantRulesCompanion data) {
    return MerchantRule(
      id: data.id.present ? data.id.value : this.id,
      merchantName: data.merchantName.present
          ? data.merchantName.value
          : this.merchantName,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      defaultType: data.defaultType.present
          ? data.defaultType.value
          : this.defaultType,
      autoApprove: data.autoApprove.present
          ? data.autoApprove.value
          : this.autoApprove,
      usageCount: data.usageCount.present
          ? data.usageCount.value
          : this.usageCount,
      confidenceText: data.confidenceText.present
          ? data.confidenceText.value
          : this.confidenceText,
      lastUsed: data.lastUsed.present ? data.lastUsed.value : this.lastUsed,
      source: data.source.present ? data.source.value : this.source,
      aliasesJson: data.aliasesJson.present
          ? data.aliasesJson.value
          : this.aliasesJson,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      isBuiltinOverride: data.isBuiltinOverride.present
          ? data.isBuiltinOverride.value
          : this.isBuiltinOverride,
      builtinKey: data.builtinKey.present
          ? data.builtinKey.value
          : this.builtinKey,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MerchantRule(')
          ..write('id: $id, ')
          ..write('merchantName: $merchantName, ')
          ..write('categoryId: $categoryId, ')
          ..write('defaultType: $defaultType, ')
          ..write('autoApprove: $autoApprove, ')
          ..write('usageCount: $usageCount, ')
          ..write('confidenceText: $confidenceText, ')
          ..write('lastUsed: $lastUsed, ')
          ..write('source: $source, ')
          ..write('aliasesJson: $aliasesJson, ')
          ..write('enabled: $enabled, ')
          ..write('isBuiltinOverride: $isBuiltinOverride, ')
          ..write('builtinKey: $builtinKey, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    merchantName,
    categoryId,
    defaultType,
    autoApprove,
    usageCount,
    confidenceText,
    lastUsed,
    source,
    aliasesJson,
    enabled,
    isBuiltinOverride,
    builtinKey,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MerchantRule &&
          other.id == this.id &&
          other.merchantName == this.merchantName &&
          other.categoryId == this.categoryId &&
          other.defaultType == this.defaultType &&
          other.autoApprove == this.autoApprove &&
          other.usageCount == this.usageCount &&
          other.confidenceText == this.confidenceText &&
          other.lastUsed == this.lastUsed &&
          other.source == this.source &&
          other.aliasesJson == this.aliasesJson &&
          other.enabled == this.enabled &&
          other.isBuiltinOverride == this.isBuiltinOverride &&
          other.builtinKey == this.builtinKey &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class MerchantRulesCompanion extends UpdateCompanion<MerchantRule> {
  final Value<String> id;
  final Value<String> merchantName;
  final Value<String> categoryId;
  final Value<String> defaultType;
  final Value<bool> autoApprove;
  final Value<int> usageCount;
  final Value<String> confidenceText;
  final Value<String?> lastUsed;
  final Value<String> source;
  final Value<String> aliasesJson;
  final Value<bool> enabled;
  final Value<bool> isBuiltinOverride;
  final Value<String?> builtinKey;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const MerchantRulesCompanion({
    this.id = const Value.absent(),
    this.merchantName = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.defaultType = const Value.absent(),
    this.autoApprove = const Value.absent(),
    this.usageCount = const Value.absent(),
    this.confidenceText = const Value.absent(),
    this.lastUsed = const Value.absent(),
    this.source = const Value.absent(),
    this.aliasesJson = const Value.absent(),
    this.enabled = const Value.absent(),
    this.isBuiltinOverride = const Value.absent(),
    this.builtinKey = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MerchantRulesCompanion.insert({
    required String id,
    required String merchantName,
    required String categoryId,
    required String defaultType,
    required bool autoApprove,
    required int usageCount,
    required String confidenceText,
    this.lastUsed = const Value.absent(),
    required String source,
    required String aliasesJson,
    required bool enabled,
    required bool isBuiltinOverride,
    this.builtinKey = const Value.absent(),
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       merchantName = Value(merchantName),
       categoryId = Value(categoryId),
       defaultType = Value(defaultType),
       autoApprove = Value(autoApprove),
       usageCount = Value(usageCount),
       confidenceText = Value(confidenceText),
       source = Value(source),
       aliasesJson = Value(aliasesJson),
       enabled = Value(enabled),
       isBuiltinOverride = Value(isBuiltinOverride),
       updatedAt = Value(updatedAt);
  static Insertable<MerchantRule> custom({
    Expression<String>? id,
    Expression<String>? merchantName,
    Expression<String>? categoryId,
    Expression<String>? defaultType,
    Expression<bool>? autoApprove,
    Expression<int>? usageCount,
    Expression<String>? confidenceText,
    Expression<String>? lastUsed,
    Expression<String>? source,
    Expression<String>? aliasesJson,
    Expression<bool>? enabled,
    Expression<bool>? isBuiltinOverride,
    Expression<String>? builtinKey,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (merchantName != null) 'merchant_name': merchantName,
      if (categoryId != null) 'category_id': categoryId,
      if (defaultType != null) 'default_type': defaultType,
      if (autoApprove != null) 'auto_approve': autoApprove,
      if (usageCount != null) 'usage_count': usageCount,
      if (confidenceText != null) 'confidence_text': confidenceText,
      if (lastUsed != null) 'last_used': lastUsed,
      if (source != null) 'source': source,
      if (aliasesJson != null) 'aliases_json': aliasesJson,
      if (enabled != null) 'enabled': enabled,
      if (isBuiltinOverride != null) 'is_builtin_override': isBuiltinOverride,
      if (builtinKey != null) 'builtin_key': builtinKey,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MerchantRulesCompanion copyWith({
    Value<String>? id,
    Value<String>? merchantName,
    Value<String>? categoryId,
    Value<String>? defaultType,
    Value<bool>? autoApprove,
    Value<int>? usageCount,
    Value<String>? confidenceText,
    Value<String?>? lastUsed,
    Value<String>? source,
    Value<String>? aliasesJson,
    Value<bool>? enabled,
    Value<bool>? isBuiltinOverride,
    Value<String?>? builtinKey,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return MerchantRulesCompanion(
      id: id ?? this.id,
      merchantName: merchantName ?? this.merchantName,
      categoryId: categoryId ?? this.categoryId,
      defaultType: defaultType ?? this.defaultType,
      autoApprove: autoApprove ?? this.autoApprove,
      usageCount: usageCount ?? this.usageCount,
      confidenceText: confidenceText ?? this.confidenceText,
      lastUsed: lastUsed ?? this.lastUsed,
      source: source ?? this.source,
      aliasesJson: aliasesJson ?? this.aliasesJson,
      enabled: enabled ?? this.enabled,
      isBuiltinOverride: isBuiltinOverride ?? this.isBuiltinOverride,
      builtinKey: builtinKey ?? this.builtinKey,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (merchantName.present) {
      map['merchant_name'] = Variable<String>(merchantName.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (defaultType.present) {
      map['default_type'] = Variable<String>(defaultType.value);
    }
    if (autoApprove.present) {
      map['auto_approve'] = Variable<bool>(autoApprove.value);
    }
    if (usageCount.present) {
      map['usage_count'] = Variable<int>(usageCount.value);
    }
    if (confidenceText.present) {
      map['confidence_text'] = Variable<String>(confidenceText.value);
    }
    if (lastUsed.present) {
      map['last_used'] = Variable<String>(lastUsed.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (aliasesJson.present) {
      map['aliases_json'] = Variable<String>(aliasesJson.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (isBuiltinOverride.present) {
      map['is_builtin_override'] = Variable<bool>(isBuiltinOverride.value);
    }
    if (builtinKey.present) {
      map['builtin_key'] = Variable<String>(builtinKey.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MerchantRulesCompanion(')
          ..write('id: $id, ')
          ..write('merchantName: $merchantName, ')
          ..write('categoryId: $categoryId, ')
          ..write('defaultType: $defaultType, ')
          ..write('autoApprove: $autoApprove, ')
          ..write('usageCount: $usageCount, ')
          ..write('confidenceText: $confidenceText, ')
          ..write('lastUsed: $lastUsed, ')
          ..write('source: $source, ')
          ..write('aliasesJson: $aliasesJson, ')
          ..write('enabled: $enabled, ')
          ..write('isBuiltinOverride: $isBuiltinOverride, ')
          ..write('builtinKey: $builtinKey, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MerchantConfirmationsTable extends MerchantConfirmations
    with TableInfo<$MerchantConfirmationsTable, MerchantConfirmation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MerchantConfirmationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _merchantNameMeta = const VerificationMeta(
    'merchantName',
  );
  @override
  late final GeneratedColumn<String> merchantName = GeneratedColumn<String>(
    'merchant_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confirmationsMeta = const VerificationMeta(
    'confirmations',
  );
  @override
  late final GeneratedColumn<int> confirmations = GeneratedColumn<int>(
    'confirmations',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctionsMeta = const VerificationMeta(
    'corrections',
  );
  @override
  late final GeneratedColumn<int> corrections = GeneratedColumn<int>(
    'corrections',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    merchantName,
    categoryId,
    confirmations,
    corrections,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'merchant_confirmations';
  @override
  VerificationContext validateIntegrity(
    Insertable<MerchantConfirmation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('merchant_name')) {
      context.handle(
        _merchantNameMeta,
        merchantName.isAcceptableOrUnknown(
          data['merchant_name']!,
          _merchantNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_merchantNameMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('confirmations')) {
      context.handle(
        _confirmationsMeta,
        confirmations.isAcceptableOrUnknown(
          data['confirmations']!,
          _confirmationsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_confirmationsMeta);
    }
    if (data.containsKey('corrections')) {
      context.handle(
        _correctionsMeta,
        corrections.isAcceptableOrUnknown(
          data['corrections']!,
          _correctionsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_correctionsMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MerchantConfirmation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MerchantConfirmation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      merchantName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_name'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      confirmations: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confirmations'],
      )!,
      corrections: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}corrections'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $MerchantConfirmationsTable createAlias(String alias) {
    return $MerchantConfirmationsTable(attachedDatabase, alias);
  }
}

class MerchantConfirmation extends DataClass
    implements Insertable<MerchantConfirmation> {
  final String id;
  final String merchantName;
  final String categoryId;
  final int confirmations;
  final int corrections;
  final String updatedAt;
  final String? deletedAt;
  const MerchantConfirmation({
    required this.id,
    required this.merchantName,
    required this.categoryId,
    required this.confirmations,
    required this.corrections,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['merchant_name'] = Variable<String>(merchantName);
    map['category_id'] = Variable<String>(categoryId);
    map['confirmations'] = Variable<int>(confirmations);
    map['corrections'] = Variable<int>(corrections);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  MerchantConfirmationsCompanion toCompanion(bool nullToAbsent) {
    return MerchantConfirmationsCompanion(
      id: Value(id),
      merchantName: Value(merchantName),
      categoryId: Value(categoryId),
      confirmations: Value(confirmations),
      corrections: Value(corrections),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory MerchantConfirmation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MerchantConfirmation(
      id: serializer.fromJson<String>(json['id']),
      merchantName: serializer.fromJson<String>(json['merchantName']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      confirmations: serializer.fromJson<int>(json['confirmations']),
      corrections: serializer.fromJson<int>(json['corrections']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'merchantName': serializer.toJson<String>(merchantName),
      'categoryId': serializer.toJson<String>(categoryId),
      'confirmations': serializer.toJson<int>(confirmations),
      'corrections': serializer.toJson<int>(corrections),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  MerchantConfirmation copyWith({
    String? id,
    String? merchantName,
    String? categoryId,
    int? confirmations,
    int? corrections,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
  }) => MerchantConfirmation(
    id: id ?? this.id,
    merchantName: merchantName ?? this.merchantName,
    categoryId: categoryId ?? this.categoryId,
    confirmations: confirmations ?? this.confirmations,
    corrections: corrections ?? this.corrections,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  MerchantConfirmation copyWithCompanion(MerchantConfirmationsCompanion data) {
    return MerchantConfirmation(
      id: data.id.present ? data.id.value : this.id,
      merchantName: data.merchantName.present
          ? data.merchantName.value
          : this.merchantName,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      confirmations: data.confirmations.present
          ? data.confirmations.value
          : this.confirmations,
      corrections: data.corrections.present
          ? data.corrections.value
          : this.corrections,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MerchantConfirmation(')
          ..write('id: $id, ')
          ..write('merchantName: $merchantName, ')
          ..write('categoryId: $categoryId, ')
          ..write('confirmations: $confirmations, ')
          ..write('corrections: $corrections, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    merchantName,
    categoryId,
    confirmations,
    corrections,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MerchantConfirmation &&
          other.id == this.id &&
          other.merchantName == this.merchantName &&
          other.categoryId == this.categoryId &&
          other.confirmations == this.confirmations &&
          other.corrections == this.corrections &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class MerchantConfirmationsCompanion
    extends UpdateCompanion<MerchantConfirmation> {
  final Value<String> id;
  final Value<String> merchantName;
  final Value<String> categoryId;
  final Value<int> confirmations;
  final Value<int> corrections;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const MerchantConfirmationsCompanion({
    this.id = const Value.absent(),
    this.merchantName = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.confirmations = const Value.absent(),
    this.corrections = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MerchantConfirmationsCompanion.insert({
    required String id,
    required String merchantName,
    required String categoryId,
    required int confirmations,
    required int corrections,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       merchantName = Value(merchantName),
       categoryId = Value(categoryId),
       confirmations = Value(confirmations),
       corrections = Value(corrections),
       updatedAt = Value(updatedAt);
  static Insertable<MerchantConfirmation> custom({
    Expression<String>? id,
    Expression<String>? merchantName,
    Expression<String>? categoryId,
    Expression<int>? confirmations,
    Expression<int>? corrections,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (merchantName != null) 'merchant_name': merchantName,
      if (categoryId != null) 'category_id': categoryId,
      if (confirmations != null) 'confirmations': confirmations,
      if (corrections != null) 'corrections': corrections,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MerchantConfirmationsCompanion copyWith({
    Value<String>? id,
    Value<String>? merchantName,
    Value<String>? categoryId,
    Value<int>? confirmations,
    Value<int>? corrections,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return MerchantConfirmationsCompanion(
      id: id ?? this.id,
      merchantName: merchantName ?? this.merchantName,
      categoryId: categoryId ?? this.categoryId,
      confirmations: confirmations ?? this.confirmations,
      corrections: corrections ?? this.corrections,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (merchantName.present) {
      map['merchant_name'] = Variable<String>(merchantName.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (confirmations.present) {
      map['confirmations'] = Variable<int>(confirmations.value);
    }
    if (corrections.present) {
      map['corrections'] = Variable<int>(corrections.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MerchantConfirmationsCompanion(')
          ..write('id: $id, ')
          ..write('merchantName: $merchantName, ')
          ..write('categoryId: $categoryId, ')
          ..write('confirmations: $confirmations, ')
          ..write('corrections: $corrections, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CorrectionFeedbacksTable extends CorrectionFeedbacks
    with TableInfo<$CorrectionFeedbacksTable, CorrectionFeedback> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CorrectionFeedbacksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldNameMeta = const VerificationMeta(
    'fieldName',
  );
  @override
  late final GeneratedColumn<String> fieldName = GeneratedColumn<String>(
    'field_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalValueMeta = const VerificationMeta(
    'originalValue',
  );
  @override
  late final GeneratedColumn<String> originalValue = GeneratedColumn<String>(
    'original_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctedValueMeta = const VerificationMeta(
    'correctedValue',
  );
  @override
  late final GeneratedColumn<String> correctedValue = GeneratedColumn<String>(
    'corrected_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fieldName,
    originalValue,
    correctedValue,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'correction_feedbacks';
  @override
  VerificationContext validateIntegrity(
    Insertable<CorrectionFeedback> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('field_name')) {
      context.handle(
        _fieldNameMeta,
        fieldName.isAcceptableOrUnknown(data['field_name']!, _fieldNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldNameMeta);
    }
    if (data.containsKey('original_value')) {
      context.handle(
        _originalValueMeta,
        originalValue.isAcceptableOrUnknown(
          data['original_value']!,
          _originalValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalValueMeta);
    }
    if (data.containsKey('corrected_value')) {
      context.handle(
        _correctedValueMeta,
        correctedValue.isAcceptableOrUnknown(
          data['corrected_value']!,
          _correctedValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_correctedValueMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CorrectionFeedback map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CorrectionFeedback(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fieldName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_name'],
      )!,
      originalValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_value'],
      )!,
      correctedValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}corrected_value'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CorrectionFeedbacksTable createAlias(String alias) {
    return $CorrectionFeedbacksTable(attachedDatabase, alias);
  }
}

class CorrectionFeedback extends DataClass
    implements Insertable<CorrectionFeedback> {
  final String id;
  final String fieldName;
  final String originalValue;
  final String correctedValue;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  const CorrectionFeedback({
    required this.id,
    required this.fieldName,
    required this.originalValue,
    required this.correctedValue,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['field_name'] = Variable<String>(fieldName);
    map['original_value'] = Variable<String>(originalValue);
    map['corrected_value'] = Variable<String>(correctedValue);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  CorrectionFeedbacksCompanion toCompanion(bool nullToAbsent) {
    return CorrectionFeedbacksCompanion(
      id: Value(id),
      fieldName: Value(fieldName),
      originalValue: Value(originalValue),
      correctedValue: Value(correctedValue),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory CorrectionFeedback.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CorrectionFeedback(
      id: serializer.fromJson<String>(json['id']),
      fieldName: serializer.fromJson<String>(json['fieldName']),
      originalValue: serializer.fromJson<String>(json['originalValue']),
      correctedValue: serializer.fromJson<String>(json['correctedValue']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fieldName': serializer.toJson<String>(fieldName),
      'originalValue': serializer.toJson<String>(originalValue),
      'correctedValue': serializer.toJson<String>(correctedValue),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  CorrectionFeedback copyWith({
    String? id,
    String? fieldName,
    String? originalValue,
    String? correctedValue,
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
  }) => CorrectionFeedback(
    id: id ?? this.id,
    fieldName: fieldName ?? this.fieldName,
    originalValue: originalValue ?? this.originalValue,
    correctedValue: correctedValue ?? this.correctedValue,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  CorrectionFeedback copyWithCompanion(CorrectionFeedbacksCompanion data) {
    return CorrectionFeedback(
      id: data.id.present ? data.id.value : this.id,
      fieldName: data.fieldName.present ? data.fieldName.value : this.fieldName,
      originalValue: data.originalValue.present
          ? data.originalValue.value
          : this.originalValue,
      correctedValue: data.correctedValue.present
          ? data.correctedValue.value
          : this.correctedValue,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CorrectionFeedback(')
          ..write('id: $id, ')
          ..write('fieldName: $fieldName, ')
          ..write('originalValue: $originalValue, ')
          ..write('correctedValue: $correctedValue, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fieldName,
    originalValue,
    correctedValue,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CorrectionFeedback &&
          other.id == this.id &&
          other.fieldName == this.fieldName &&
          other.originalValue == this.originalValue &&
          other.correctedValue == this.correctedValue &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CorrectionFeedbacksCompanion extends UpdateCompanion<CorrectionFeedback> {
  final Value<String> id;
  final Value<String> fieldName;
  final Value<String> originalValue;
  final Value<String> correctedValue;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const CorrectionFeedbacksCompanion({
    this.id = const Value.absent(),
    this.fieldName = const Value.absent(),
    this.originalValue = const Value.absent(),
    this.correctedValue = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CorrectionFeedbacksCompanion.insert({
    required String id,
    required String fieldName,
    required String originalValue,
    required String correctedValue,
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fieldName = Value(fieldName),
       originalValue = Value(originalValue),
       correctedValue = Value(correctedValue),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CorrectionFeedback> custom({
    Expression<String>? id,
    Expression<String>? fieldName,
    Expression<String>? originalValue,
    Expression<String>? correctedValue,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fieldName != null) 'field_name': fieldName,
      if (originalValue != null) 'original_value': originalValue,
      if (correctedValue != null) 'corrected_value': correctedValue,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CorrectionFeedbacksCompanion copyWith({
    Value<String>? id,
    Value<String>? fieldName,
    Value<String>? originalValue,
    Value<String>? correctedValue,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CorrectionFeedbacksCompanion(
      id: id ?? this.id,
      fieldName: fieldName ?? this.fieldName,
      originalValue: originalValue ?? this.originalValue,
      correctedValue: correctedValue ?? this.correctedValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fieldName.present) {
      map['field_name'] = Variable<String>(fieldName.value);
    }
    if (originalValue.present) {
      map['original_value'] = Variable<String>(originalValue.value);
    }
    if (correctedValue.present) {
      map['corrected_value'] = Variable<String>(correctedValue.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CorrectionFeedbacksCompanion(')
          ..write('id: $id, ')
          ..write('fieldName: $fieldName, ')
          ..write('originalValue: $originalValue, ')
          ..write('correctedValue: $correctedValue, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetadataTable extends SyncMetadata
    with TableInfo<$SyncMetadataTable, SyncMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetadataData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncMetadataTable createAlias(String alias) {
    return $SyncMetadataTable(attachedDatabase, alias);
  }
}

class SyncMetadataData extends DataClass
    implements Insertable<SyncMetadataData> {
  final String key;
  final String value;
  const SyncMetadataData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return SyncMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory SyncMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncMetadataData copyWith({String? key, String? value}) =>
      SyncMetadataData(key: key ?? this.key, value: value ?? this.value);
  SyncMetadataData copyWithCompanion(SyncMetadataCompanion data) {
    return SyncMetadataData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetadataData &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncMetadataCompanion extends UpdateCompanion<SyncMetadataData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncMetadataData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _collectionNameMeta = const VerificationMeta(
    'collectionName',
  );
  @override
  late final GeneratedColumn<String> collectionName = GeneratedColumn<String>(
    'collection_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _availableAtMeta = const VerificationMeta(
    'availableAt',
  );
  @override
  late final GeneratedColumn<String> availableAt = GeneratedColumn<String>(
    'available_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dedupeKeyMeta = const VerificationMeta(
    'dedupeKey',
  );
  @override
  late final GeneratedColumn<String> dedupeKey = GeneratedColumn<String>(
    'dedupe_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    collectionName,
    recordId,
    operation,
    payloadJson,
    createdAt,
    availableAt,
    attemptCount,
    lastError,
    dedupeKey,
    priority,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('collection_name')) {
      context.handle(
        _collectionNameMeta,
        collectionName.isAcceptableOrUnknown(
          data['collection_name']!,
          _collectionNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionNameMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('available_at')) {
      context.handle(
        _availableAtMeta,
        availableAt.isAcceptableOrUnknown(
          data['available_at']!,
          _availableAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_availableAtMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('dedupe_key')) {
      context.handle(
        _dedupeKeyMeta,
        dedupeKey.isAcceptableOrUnknown(data['dedupe_key']!, _dedupeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dedupeKeyMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      collectionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_name'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      availableAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}available_at'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      dedupeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupe_key'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final int id;
  final String collectionName;
  final String recordId;
  final String operation;
  final String? payloadJson;
  final String createdAt;
  final String availableAt;
  final int attemptCount;
  final String? lastError;
  final String dedupeKey;
  final int priority;
  final String? deviceId;
  const SyncQueueData({
    required this.id,
    required this.collectionName,
    required this.recordId,
    required this.operation,
    this.payloadJson,
    required this.createdAt,
    required this.availableAt,
    required this.attemptCount,
    this.lastError,
    required this.dedupeKey,
    required this.priority,
    this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['collection_name'] = Variable<String>(collectionName);
    map['record_id'] = Variable<String>(recordId);
    map['operation'] = Variable<String>(operation);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['available_at'] = Variable<String>(availableAt);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['dedupe_key'] = Variable<String>(dedupeKey);
    map['priority'] = Variable<int>(priority);
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      collectionName: Value(collectionName),
      recordId: Value(recordId),
      operation: Value(operation),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      createdAt: Value(createdAt),
      availableAt: Value(availableAt),
      attemptCount: Value(attemptCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      dedupeKey: Value(dedupeKey),
      priority: Value(priority),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
    );
  }

  factory SyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      collectionName: serializer.fromJson<String>(json['collectionName']),
      recordId: serializer.fromJson<String>(json['recordId']),
      operation: serializer.fromJson<String>(json['operation']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      availableAt: serializer.fromJson<String>(json['availableAt']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      dedupeKey: serializer.fromJson<String>(json['dedupeKey']),
      priority: serializer.fromJson<int>(json['priority']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'collectionName': serializer.toJson<String>(collectionName),
      'recordId': serializer.toJson<String>(recordId),
      'operation': serializer.toJson<String>(operation),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'createdAt': serializer.toJson<String>(createdAt),
      'availableAt': serializer.toJson<String>(availableAt),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastError': serializer.toJson<String?>(lastError),
      'dedupeKey': serializer.toJson<String>(dedupeKey),
      'priority': serializer.toJson<int>(priority),
      'deviceId': serializer.toJson<String?>(deviceId),
    };
  }

  SyncQueueData copyWith({
    int? id,
    String? collectionName,
    String? recordId,
    String? operation,
    Value<String?> payloadJson = const Value.absent(),
    String? createdAt,
    String? availableAt,
    int? attemptCount,
    Value<String?> lastError = const Value.absent(),
    String? dedupeKey,
    int? priority,
    Value<String?> deviceId = const Value.absent(),
  }) => SyncQueueData(
    id: id ?? this.id,
    collectionName: collectionName ?? this.collectionName,
    recordId: recordId ?? this.recordId,
    operation: operation ?? this.operation,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
    availableAt: availableAt ?? this.availableAt,
    attemptCount: attemptCount ?? this.attemptCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    dedupeKey: dedupeKey ?? this.dedupeKey,
    priority: priority ?? this.priority,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
  );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      collectionName: data.collectionName.present
          ? data.collectionName.value
          : this.collectionName,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      availableAt: data.availableAt.present
          ? data.availableAt.value
          : this.availableAt,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      dedupeKey: data.dedupeKey.present ? data.dedupeKey.value : this.dedupeKey,
      priority: data.priority.present ? data.priority.value : this.priority,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('id: $id, ')
          ..write('collectionName: $collectionName, ')
          ..write('recordId: $recordId, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('availableAt: $availableAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('priority: $priority, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    collectionName,
    recordId,
    operation,
    payloadJson,
    createdAt,
    availableAt,
    attemptCount,
    lastError,
    dedupeKey,
    priority,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.id == this.id &&
          other.collectionName == this.collectionName &&
          other.recordId == this.recordId &&
          other.operation == this.operation &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt &&
          other.availableAt == this.availableAt &&
          other.attemptCount == this.attemptCount &&
          other.lastError == this.lastError &&
          other.dedupeKey == this.dedupeKey &&
          other.priority == this.priority &&
          other.deviceId == this.deviceId);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<int> id;
  final Value<String> collectionName;
  final Value<String> recordId;
  final Value<String> operation;
  final Value<String?> payloadJson;
  final Value<String> createdAt;
  final Value<String> availableAt;
  final Value<int> attemptCount;
  final Value<String?> lastError;
  final Value<String> dedupeKey;
  final Value<int> priority;
  final Value<String?> deviceId;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.collectionName = const Value.absent(),
    this.recordId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.availableAt = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.priority = const Value.absent(),
    this.deviceId = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String collectionName,
    required String recordId,
    required String operation,
    this.payloadJson = const Value.absent(),
    required String createdAt,
    required String availableAt,
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    required String dedupeKey,
    this.priority = const Value.absent(),
    this.deviceId = const Value.absent(),
  }) : collectionName = Value(collectionName),
       recordId = Value(recordId),
       operation = Value(operation),
       createdAt = Value(createdAt),
       availableAt = Value(availableAt),
       dedupeKey = Value(dedupeKey);
  static Insertable<SyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? collectionName,
    Expression<String>? recordId,
    Expression<String>? operation,
    Expression<String>? payloadJson,
    Expression<String>? createdAt,
    Expression<String>? availableAt,
    Expression<int>? attemptCount,
    Expression<String>? lastError,
    Expression<String>? dedupeKey,
    Expression<int>? priority,
    Expression<String>? deviceId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (collectionName != null) 'collection_name': collectionName,
      if (recordId != null) 'record_id': recordId,
      if (operation != null) 'operation': operation,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (availableAt != null) 'available_at': availableAt,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastError != null) 'last_error': lastError,
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
      if (priority != null) 'priority': priority,
      if (deviceId != null) 'device_id': deviceId,
    });
  }

  SyncQueueCompanion copyWith({
    Value<int>? id,
    Value<String>? collectionName,
    Value<String>? recordId,
    Value<String>? operation,
    Value<String?>? payloadJson,
    Value<String>? createdAt,
    Value<String>? availableAt,
    Value<int>? attemptCount,
    Value<String?>? lastError,
    Value<String>? dedupeKey,
    Value<int>? priority,
    Value<String?>? deviceId,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      collectionName: collectionName ?? this.collectionName,
      recordId: recordId ?? this.recordId,
      operation: operation ?? this.operation,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      availableAt: availableAt ?? this.availableAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      priority: priority ?? this.priority,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (collectionName.present) {
      map['collection_name'] = Variable<String>(collectionName.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (availableAt.present) {
      map['available_at'] = Variable<String>(availableAt.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (dedupeKey.present) {
      map['dedupe_key'] = Variable<String>(dedupeKey.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('collectionName: $collectionName, ')
          ..write('recordId: $recordId, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('availableAt: $availableAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('priority: $priority, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }
}

class $MigrationStateTable extends MigrationState
    with TableInfo<$MigrationStateTable, MigrationStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MigrationStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'migration_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<MigrationStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MigrationStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MigrationStateData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MigrationStateTable createAlias(String alias) {
    return $MigrationStateTable(attachedDatabase, alias);
  }
}

class MigrationStateData extends DataClass
    implements Insertable<MigrationStateData> {
  final String key;
  final String value;
  const MigrationStateData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MigrationStateCompanion toCompanion(bool nullToAbsent) {
    return MigrationStateCompanion(key: Value(key), value: Value(value));
  }

  factory MigrationStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MigrationStateData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MigrationStateData copyWith({String? key, String? value}) =>
      MigrationStateData(key: key ?? this.key, value: value ?? this.value);
  MigrationStateData copyWithCompanion(MigrationStateCompanion data) {
    return MigrationStateData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MigrationStateData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MigrationStateData &&
          other.key == this.key &&
          other.value == this.value);
}

class MigrationStateCompanion extends UpdateCompanion<MigrationStateData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MigrationStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MigrationStateCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MigrationStateData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MigrationStateCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MigrationStateCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MigrationStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $SavingsTable savings = $SavingsTable(this);
  late final $InvestmentsTable investments = $InvestmentsTable(this);
  late final $PendingTransactionsTable pendingTransactions =
      $PendingTransactionsTable(this);
  late final $RecurringTransactionsTable recurringTransactions =
      $RecurringTransactionsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $FinancialPlansTable financialPlans = $FinancialPlansTable(this);
  late final $MerchantRulesTable merchantRules = $MerchantRulesTable(this);
  late final $MerchantConfirmationsTable merchantConfirmations =
      $MerchantConfirmationsTable(this);
  late final $CorrectionFeedbacksTable correctionFeedbacks =
      $CorrectionFeedbacksTable(this);
  late final $SyncMetadataTable syncMetadata = $SyncMetadataTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $MigrationStateTable migrationState = $MigrationStateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    transactions,
    savings,
    investments,
    pendingTransactions,
    recurringTransactions,
    appSettings,
    financialPlans,
    merchantRules,
    merchantConfirmations,
    correctionFeedbacks,
    syncMetadata,
    syncQueue,
    migrationState,
  ];
}

typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      required String id,
      required String type,
      required String date,
      required String amountText,
      required String currency,
      required String category,
      required String description,
      required String createdAt,
      Value<bool> rolledOver,
      Value<String?> rolledAmountText,
      Value<String?> sourceIncomeId,
      Value<String?> exchangePairId,
      Value<String?> exchangeSourceIncomeId,
      Value<String?> remainingAmountText,
      Value<String?> activityType,
      Value<String?> costBasisText,
      Value<String?> saleValueText,
      Value<String?> realizedGainText,
      Value<String?> realizedGainLossCurrency,
      Value<String?> metalQuantityText,
      required String updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> date,
      Value<String> amountText,
      Value<String> currency,
      Value<String> category,
      Value<String> description,
      Value<String> createdAt,
      Value<bool> rolledOver,
      Value<String?> rolledAmountText,
      Value<String?> sourceIncomeId,
      Value<String?> exchangePairId,
      Value<String?> exchangeSourceIncomeId,
      Value<String?> remainingAmountText,
      Value<String?> activityType,
      Value<String?> costBasisText,
      Value<String?> saleValueText,
      Value<String?> realizedGainText,
      Value<String?> realizedGainLossCurrency,
      Value<String?> metalQuantityText,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amountText => $composableBuilder(
    column: $table.amountText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get rolledOver => $composableBuilder(
    column: $table.rolledOver,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rolledAmountText => $composableBuilder(
    column: $table.rolledAmountText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceIncomeId => $composableBuilder(
    column: $table.sourceIncomeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exchangePairId => $composableBuilder(
    column: $table.exchangePairId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exchangeSourceIncomeId => $composableBuilder(
    column: $table.exchangeSourceIncomeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remainingAmountText => $composableBuilder(
    column: $table.remainingAmountText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get costBasisText => $composableBuilder(
    column: $table.costBasisText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get saleValueText => $composableBuilder(
    column: $table.saleValueText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get realizedGainText => $composableBuilder(
    column: $table.realizedGainText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get realizedGainLossCurrency => $composableBuilder(
    column: $table.realizedGainLossCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metalQuantityText => $composableBuilder(
    column: $table.metalQuantityText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amountText => $composableBuilder(
    column: $table.amountText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get rolledOver => $composableBuilder(
    column: $table.rolledOver,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rolledAmountText => $composableBuilder(
    column: $table.rolledAmountText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceIncomeId => $composableBuilder(
    column: $table.sourceIncomeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exchangePairId => $composableBuilder(
    column: $table.exchangePairId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exchangeSourceIncomeId => $composableBuilder(
    column: $table.exchangeSourceIncomeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remainingAmountText => $composableBuilder(
    column: $table.remainingAmountText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get costBasisText => $composableBuilder(
    column: $table.costBasisText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get saleValueText => $composableBuilder(
    column: $table.saleValueText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get realizedGainText => $composableBuilder(
    column: $table.realizedGainText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get realizedGainLossCurrency => $composableBuilder(
    column: $table.realizedGainLossCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metalQuantityText => $composableBuilder(
    column: $table.metalQuantityText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get amountText => $composableBuilder(
    column: $table.amountText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get rolledOver => $composableBuilder(
    column: $table.rolledOver,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rolledAmountText => $composableBuilder(
    column: $table.rolledAmountText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceIncomeId => $composableBuilder(
    column: $table.sourceIncomeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exchangePairId => $composableBuilder(
    column: $table.exchangePairId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exchangeSourceIncomeId => $composableBuilder(
    column: $table.exchangeSourceIncomeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remainingAmountText => $composableBuilder(
    column: $table.remainingAmountText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get costBasisText => $composableBuilder(
    column: $table.costBasisText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get saleValueText => $composableBuilder(
    column: $table.saleValueText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get realizedGainText => $composableBuilder(
    column: $table.realizedGainText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get realizedGainLossCurrency => $composableBuilder(
    column: $table.realizedGainLossCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metalQuantityText => $composableBuilder(
    column: $table.metalQuantityText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          Transaction,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (
            Transaction,
            BaseReferences<_$AppDatabase, $TransactionsTable, Transaction>,
          ),
          Transaction,
          PrefetchHooks Function()
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> amountText = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<bool> rolledOver = const Value.absent(),
                Value<String?> rolledAmountText = const Value.absent(),
                Value<String?> sourceIncomeId = const Value.absent(),
                Value<String?> exchangePairId = const Value.absent(),
                Value<String?> exchangeSourceIncomeId = const Value.absent(),
                Value<String?> remainingAmountText = const Value.absent(),
                Value<String?> activityType = const Value.absent(),
                Value<String?> costBasisText = const Value.absent(),
                Value<String?> saleValueText = const Value.absent(),
                Value<String?> realizedGainText = const Value.absent(),
                Value<String?> realizedGainLossCurrency = const Value.absent(),
                Value<String?> metalQuantityText = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                type: type,
                date: date,
                amountText: amountText,
                currency: currency,
                category: category,
                description: description,
                createdAt: createdAt,
                rolledOver: rolledOver,
                rolledAmountText: rolledAmountText,
                sourceIncomeId: sourceIncomeId,
                exchangePairId: exchangePairId,
                exchangeSourceIncomeId: exchangeSourceIncomeId,
                remainingAmountText: remainingAmountText,
                activityType: activityType,
                costBasisText: costBasisText,
                saleValueText: saleValueText,
                realizedGainText: realizedGainText,
                realizedGainLossCurrency: realizedGainLossCurrency,
                metalQuantityText: metalQuantityText,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String date,
                required String amountText,
                required String currency,
                required String category,
                required String description,
                required String createdAt,
                Value<bool> rolledOver = const Value.absent(),
                Value<String?> rolledAmountText = const Value.absent(),
                Value<String?> sourceIncomeId = const Value.absent(),
                Value<String?> exchangePairId = const Value.absent(),
                Value<String?> exchangeSourceIncomeId = const Value.absent(),
                Value<String?> remainingAmountText = const Value.absent(),
                Value<String?> activityType = const Value.absent(),
                Value<String?> costBasisText = const Value.absent(),
                Value<String?> saleValueText = const Value.absent(),
                Value<String?> realizedGainText = const Value.absent(),
                Value<String?> realizedGainLossCurrency = const Value.absent(),
                Value<String?> metalQuantityText = const Value.absent(),
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                type: type,
                date: date,
                amountText: amountText,
                currency: currency,
                category: category,
                description: description,
                createdAt: createdAt,
                rolledOver: rolledOver,
                rolledAmountText: rolledAmountText,
                sourceIncomeId: sourceIncomeId,
                exchangePairId: exchangePairId,
                exchangeSourceIncomeId: exchangeSourceIncomeId,
                remainingAmountText: remainingAmountText,
                activityType: activityType,
                costBasisText: costBasisText,
                saleValueText: saleValueText,
                realizedGainText: realizedGainText,
                realizedGainLossCurrency: realizedGainLossCurrency,
                metalQuantityText: metalQuantityText,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      Transaction,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (
        Transaction,
        BaseReferences<_$AppDatabase, $TransactionsTable, Transaction>,
      ),
      Transaction,
      PrefetchHooks Function()
    >;
typedef $$SavingsTableCreateCompanionBuilder =
    SavingsCompanion Function({
      required String id,
      required String assetType,
      required String dateAcquired,
      required String amountText,
      required String remainingAmountText,
      required String unit,
      required String description,
      Value<String?> linkedCashEntryId,
      required String purchaseCurrency,
      required String purchaseAmountText,
      required String createdAt,
      Value<String?> sourceIncomeId,
      Value<String?> exchangeSourceSavingId,
      Value<String?> exchangeSourceIncomeId,
      Value<bool?> internalTransfer,
      Value<String?> internalTransferType,
      required String fundingAllocationsJson,
      Value<String?> transferActivityId,
      required String updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$SavingsTableUpdateCompanionBuilder =
    SavingsCompanion Function({
      Value<String> id,
      Value<String> assetType,
      Value<String> dateAcquired,
      Value<String> amountText,
      Value<String> remainingAmountText,
      Value<String> unit,
      Value<String> description,
      Value<String?> linkedCashEntryId,
      Value<String> purchaseCurrency,
      Value<String> purchaseAmountText,
      Value<String> createdAt,
      Value<String?> sourceIncomeId,
      Value<String?> exchangeSourceSavingId,
      Value<String?> exchangeSourceIncomeId,
      Value<bool?> internalTransfer,
      Value<String?> internalTransferType,
      Value<String> fundingAllocationsJson,
      Value<String?> transferActivityId,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$SavingsTableFilterComposer
    extends Composer<_$AppDatabase, $SavingsTable> {
  $$SavingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetType => $composableBuilder(
    column: $table.assetType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateAcquired => $composableBuilder(
    column: $table.dateAcquired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amountText => $composableBuilder(
    column: $table.amountText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remainingAmountText => $composableBuilder(
    column: $table.remainingAmountText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedCashEntryId => $composableBuilder(
    column: $table.linkedCashEntryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get purchaseCurrency => $composableBuilder(
    column: $table.purchaseCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get purchaseAmountText => $composableBuilder(
    column: $table.purchaseAmountText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceIncomeId => $composableBuilder(
    column: $table.sourceIncomeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exchangeSourceSavingId => $composableBuilder(
    column: $table.exchangeSourceSavingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exchangeSourceIncomeId => $composableBuilder(
    column: $table.exchangeSourceIncomeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get internalTransfer => $composableBuilder(
    column: $table.internalTransfer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get internalTransferType => $composableBuilder(
    column: $table.internalTransferType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fundingAllocationsJson => $composableBuilder(
    column: $table.fundingAllocationsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transferActivityId => $composableBuilder(
    column: $table.transferActivityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SavingsTable> {
  $$SavingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetType => $composableBuilder(
    column: $table.assetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateAcquired => $composableBuilder(
    column: $table.dateAcquired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amountText => $composableBuilder(
    column: $table.amountText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remainingAmountText => $composableBuilder(
    column: $table.remainingAmountText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedCashEntryId => $composableBuilder(
    column: $table.linkedCashEntryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purchaseCurrency => $composableBuilder(
    column: $table.purchaseCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purchaseAmountText => $composableBuilder(
    column: $table.purchaseAmountText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceIncomeId => $composableBuilder(
    column: $table.sourceIncomeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exchangeSourceSavingId => $composableBuilder(
    column: $table.exchangeSourceSavingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exchangeSourceIncomeId => $composableBuilder(
    column: $table.exchangeSourceIncomeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get internalTransfer => $composableBuilder(
    column: $table.internalTransfer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get internalTransferType => $composableBuilder(
    column: $table.internalTransferType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fundingAllocationsJson => $composableBuilder(
    column: $table.fundingAllocationsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transferActivityId => $composableBuilder(
    column: $table.transferActivityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavingsTable> {
  $$SavingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get assetType =>
      $composableBuilder(column: $table.assetType, builder: (column) => column);

  GeneratedColumn<String> get dateAcquired => $composableBuilder(
    column: $table.dateAcquired,
    builder: (column) => column,
  );

  GeneratedColumn<String> get amountText => $composableBuilder(
    column: $table.amountText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remainingAmountText => $composableBuilder(
    column: $table.remainingAmountText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkedCashEntryId => $composableBuilder(
    column: $table.linkedCashEntryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get purchaseCurrency => $composableBuilder(
    column: $table.purchaseCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get purchaseAmountText => $composableBuilder(
    column: $table.purchaseAmountText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get sourceIncomeId => $composableBuilder(
    column: $table.sourceIncomeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exchangeSourceSavingId => $composableBuilder(
    column: $table.exchangeSourceSavingId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exchangeSourceIncomeId => $composableBuilder(
    column: $table.exchangeSourceIncomeId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get internalTransfer => $composableBuilder(
    column: $table.internalTransfer,
    builder: (column) => column,
  );

  GeneratedColumn<String> get internalTransferType => $composableBuilder(
    column: $table.internalTransferType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fundingAllocationsJson => $composableBuilder(
    column: $table.fundingAllocationsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transferActivityId => $composableBuilder(
    column: $table.transferActivityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$SavingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavingsTable,
          Saving,
          $$SavingsTableFilterComposer,
          $$SavingsTableOrderingComposer,
          $$SavingsTableAnnotationComposer,
          $$SavingsTableCreateCompanionBuilder,
          $$SavingsTableUpdateCompanionBuilder,
          (Saving, BaseReferences<_$AppDatabase, $SavingsTable, Saving>),
          Saving,
          PrefetchHooks Function()
        > {
  $$SavingsTableTableManager(_$AppDatabase db, $SavingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> assetType = const Value.absent(),
                Value<String> dateAcquired = const Value.absent(),
                Value<String> amountText = const Value.absent(),
                Value<String> remainingAmountText = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> linkedCashEntryId = const Value.absent(),
                Value<String> purchaseCurrency = const Value.absent(),
                Value<String> purchaseAmountText = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String?> sourceIncomeId = const Value.absent(),
                Value<String?> exchangeSourceSavingId = const Value.absent(),
                Value<String?> exchangeSourceIncomeId = const Value.absent(),
                Value<bool?> internalTransfer = const Value.absent(),
                Value<String?> internalTransferType = const Value.absent(),
                Value<String> fundingAllocationsJson = const Value.absent(),
                Value<String?> transferActivityId = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavingsCompanion(
                id: id,
                assetType: assetType,
                dateAcquired: dateAcquired,
                amountText: amountText,
                remainingAmountText: remainingAmountText,
                unit: unit,
                description: description,
                linkedCashEntryId: linkedCashEntryId,
                purchaseCurrency: purchaseCurrency,
                purchaseAmountText: purchaseAmountText,
                createdAt: createdAt,
                sourceIncomeId: sourceIncomeId,
                exchangeSourceSavingId: exchangeSourceSavingId,
                exchangeSourceIncomeId: exchangeSourceIncomeId,
                internalTransfer: internalTransfer,
                internalTransferType: internalTransferType,
                fundingAllocationsJson: fundingAllocationsJson,
                transferActivityId: transferActivityId,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String assetType,
                required String dateAcquired,
                required String amountText,
                required String remainingAmountText,
                required String unit,
                required String description,
                Value<String?> linkedCashEntryId = const Value.absent(),
                required String purchaseCurrency,
                required String purchaseAmountText,
                required String createdAt,
                Value<String?> sourceIncomeId = const Value.absent(),
                Value<String?> exchangeSourceSavingId = const Value.absent(),
                Value<String?> exchangeSourceIncomeId = const Value.absent(),
                Value<bool?> internalTransfer = const Value.absent(),
                Value<String?> internalTransferType = const Value.absent(),
                required String fundingAllocationsJson,
                Value<String?> transferActivityId = const Value.absent(),
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavingsCompanion.insert(
                id: id,
                assetType: assetType,
                dateAcquired: dateAcquired,
                amountText: amountText,
                remainingAmountText: remainingAmountText,
                unit: unit,
                description: description,
                linkedCashEntryId: linkedCashEntryId,
                purchaseCurrency: purchaseCurrency,
                purchaseAmountText: purchaseAmountText,
                createdAt: createdAt,
                sourceIncomeId: sourceIncomeId,
                exchangeSourceSavingId: exchangeSourceSavingId,
                exchangeSourceIncomeId: exchangeSourceIncomeId,
                internalTransfer: internalTransfer,
                internalTransferType: internalTransferType,
                fundingAllocationsJson: fundingAllocationsJson,
                transferActivityId: transferActivityId,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavingsTable,
      Saving,
      $$SavingsTableFilterComposer,
      $$SavingsTableOrderingComposer,
      $$SavingsTableAnnotationComposer,
      $$SavingsTableCreateCompanionBuilder,
      $$SavingsTableUpdateCompanionBuilder,
      (Saving, BaseReferences<_$AppDatabase, $SavingsTable, Saving>),
      Saving,
      PrefetchHooks Function()
    >;
typedef $$InvestmentsTableCreateCompanionBuilder =
    InvestmentsCompanion Function({
      required String id,
      required String investmentType,
      required String assetSubtype,
      required String ownershipType,
      required String valuationMode,
      required String currency,
      required String originalPriceText,
      required String totalInterestText,
      required String totalPayableText,
      required String paidAmountText,
      required String remainingAmountText,
      required String installmentPlanJson,
      required String valuationDate,
      required String marketValueText,
      required String marketValueDate,
      required String valuationSource,
      required String loanBalanceText,
      required String loanAsOfDate,
      required String paidAmountToDateText,
      required String ownershipSharePctText,
      required String country,
      required String location,
      required String inflationRateText,
      required String estimatedCurrentValueText,
      required String description,
      Value<bool> noZakat,
      Value<String?> yearlyGrowthRateText,
      required String createdAt,
      required String updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$InvestmentsTableUpdateCompanionBuilder =
    InvestmentsCompanion Function({
      Value<String> id,
      Value<String> investmentType,
      Value<String> assetSubtype,
      Value<String> ownershipType,
      Value<String> valuationMode,
      Value<String> currency,
      Value<String> originalPriceText,
      Value<String> totalInterestText,
      Value<String> totalPayableText,
      Value<String> paidAmountText,
      Value<String> remainingAmountText,
      Value<String> installmentPlanJson,
      Value<String> valuationDate,
      Value<String> marketValueText,
      Value<String> marketValueDate,
      Value<String> valuationSource,
      Value<String> loanBalanceText,
      Value<String> loanAsOfDate,
      Value<String> paidAmountToDateText,
      Value<String> ownershipSharePctText,
      Value<String> country,
      Value<String> location,
      Value<String> inflationRateText,
      Value<String> estimatedCurrentValueText,
      Value<String> description,
      Value<bool> noZakat,
      Value<String?> yearlyGrowthRateText,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$InvestmentsTableFilterComposer
    extends Composer<_$AppDatabase, $InvestmentsTable> {
  $$InvestmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get investmentType => $composableBuilder(
    column: $table.investmentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetSubtype => $composableBuilder(
    column: $table.assetSubtype,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownershipType => $composableBuilder(
    column: $table.ownershipType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valuationMode => $composableBuilder(
    column: $table.valuationMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalPriceText => $composableBuilder(
    column: $table.originalPriceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get totalInterestText => $composableBuilder(
    column: $table.totalInterestText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get totalPayableText => $composableBuilder(
    column: $table.totalPayableText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paidAmountText => $composableBuilder(
    column: $table.paidAmountText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remainingAmountText => $composableBuilder(
    column: $table.remainingAmountText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get installmentPlanJson => $composableBuilder(
    column: $table.installmentPlanJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valuationDate => $composableBuilder(
    column: $table.valuationDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get marketValueText => $composableBuilder(
    column: $table.marketValueText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get marketValueDate => $composableBuilder(
    column: $table.marketValueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valuationSource => $composableBuilder(
    column: $table.valuationSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loanBalanceText => $composableBuilder(
    column: $table.loanBalanceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loanAsOfDate => $composableBuilder(
    column: $table.loanAsOfDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paidAmountToDateText => $composableBuilder(
    column: $table.paidAmountToDateText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownershipSharePctText => $composableBuilder(
    column: $table.ownershipSharePctText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inflationRateText => $composableBuilder(
    column: $table.inflationRateText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estimatedCurrentValueText => $composableBuilder(
    column: $table.estimatedCurrentValueText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get noZakat => $composableBuilder(
    column: $table.noZakat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get yearlyGrowthRateText => $composableBuilder(
    column: $table.yearlyGrowthRateText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InvestmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $InvestmentsTable> {
  $$InvestmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get investmentType => $composableBuilder(
    column: $table.investmentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetSubtype => $composableBuilder(
    column: $table.assetSubtype,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownershipType => $composableBuilder(
    column: $table.ownershipType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valuationMode => $composableBuilder(
    column: $table.valuationMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalPriceText => $composableBuilder(
    column: $table.originalPriceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get totalInterestText => $composableBuilder(
    column: $table.totalInterestText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get totalPayableText => $composableBuilder(
    column: $table.totalPayableText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paidAmountText => $composableBuilder(
    column: $table.paidAmountText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remainingAmountText => $composableBuilder(
    column: $table.remainingAmountText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get installmentPlanJson => $composableBuilder(
    column: $table.installmentPlanJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valuationDate => $composableBuilder(
    column: $table.valuationDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get marketValueText => $composableBuilder(
    column: $table.marketValueText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get marketValueDate => $composableBuilder(
    column: $table.marketValueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valuationSource => $composableBuilder(
    column: $table.valuationSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loanBalanceText => $composableBuilder(
    column: $table.loanBalanceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loanAsOfDate => $composableBuilder(
    column: $table.loanAsOfDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paidAmountToDateText => $composableBuilder(
    column: $table.paidAmountToDateText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownershipSharePctText => $composableBuilder(
    column: $table.ownershipSharePctText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inflationRateText => $composableBuilder(
    column: $table.inflationRateText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estimatedCurrentValueText => $composableBuilder(
    column: $table.estimatedCurrentValueText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get noZakat => $composableBuilder(
    column: $table.noZakat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get yearlyGrowthRateText => $composableBuilder(
    column: $table.yearlyGrowthRateText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InvestmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InvestmentsTable> {
  $$InvestmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get investmentType => $composableBuilder(
    column: $table.investmentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assetSubtype => $composableBuilder(
    column: $table.assetSubtype,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownershipType => $composableBuilder(
    column: $table.ownershipType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get valuationMode => $composableBuilder(
    column: $table.valuationMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get originalPriceText => $composableBuilder(
    column: $table.originalPriceText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get totalInterestText => $composableBuilder(
    column: $table.totalInterestText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get totalPayableText => $composableBuilder(
    column: $table.totalPayableText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paidAmountText => $composableBuilder(
    column: $table.paidAmountText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remainingAmountText => $composableBuilder(
    column: $table.remainingAmountText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get installmentPlanJson => $composableBuilder(
    column: $table.installmentPlanJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get valuationDate => $composableBuilder(
    column: $table.valuationDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get marketValueText => $composableBuilder(
    column: $table.marketValueText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get marketValueDate => $composableBuilder(
    column: $table.marketValueDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get valuationSource => $composableBuilder(
    column: $table.valuationSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get loanBalanceText => $composableBuilder(
    column: $table.loanBalanceText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get loanAsOfDate => $composableBuilder(
    column: $table.loanAsOfDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paidAmountToDateText => $composableBuilder(
    column: $table.paidAmountToDateText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownershipSharePctText => $composableBuilder(
    column: $table.ownershipSharePctText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get inflationRateText => $composableBuilder(
    column: $table.inflationRateText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get estimatedCurrentValueText => $composableBuilder(
    column: $table.estimatedCurrentValueText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get noZakat =>
      $composableBuilder(column: $table.noZakat, builder: (column) => column);

  GeneratedColumn<String> get yearlyGrowthRateText => $composableBuilder(
    column: $table.yearlyGrowthRateText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$InvestmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InvestmentsTable,
          Investment,
          $$InvestmentsTableFilterComposer,
          $$InvestmentsTableOrderingComposer,
          $$InvestmentsTableAnnotationComposer,
          $$InvestmentsTableCreateCompanionBuilder,
          $$InvestmentsTableUpdateCompanionBuilder,
          (
            Investment,
            BaseReferences<_$AppDatabase, $InvestmentsTable, Investment>,
          ),
          Investment,
          PrefetchHooks Function()
        > {
  $$InvestmentsTableTableManager(_$AppDatabase db, $InvestmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvestmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InvestmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InvestmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> investmentType = const Value.absent(),
                Value<String> assetSubtype = const Value.absent(),
                Value<String> ownershipType = const Value.absent(),
                Value<String> valuationMode = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> originalPriceText = const Value.absent(),
                Value<String> totalInterestText = const Value.absent(),
                Value<String> totalPayableText = const Value.absent(),
                Value<String> paidAmountText = const Value.absent(),
                Value<String> remainingAmountText = const Value.absent(),
                Value<String> installmentPlanJson = const Value.absent(),
                Value<String> valuationDate = const Value.absent(),
                Value<String> marketValueText = const Value.absent(),
                Value<String> marketValueDate = const Value.absent(),
                Value<String> valuationSource = const Value.absent(),
                Value<String> loanBalanceText = const Value.absent(),
                Value<String> loanAsOfDate = const Value.absent(),
                Value<String> paidAmountToDateText = const Value.absent(),
                Value<String> ownershipSharePctText = const Value.absent(),
                Value<String> country = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String> inflationRateText = const Value.absent(),
                Value<String> estimatedCurrentValueText = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<bool> noZakat = const Value.absent(),
                Value<String?> yearlyGrowthRateText = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvestmentsCompanion(
                id: id,
                investmentType: investmentType,
                assetSubtype: assetSubtype,
                ownershipType: ownershipType,
                valuationMode: valuationMode,
                currency: currency,
                originalPriceText: originalPriceText,
                totalInterestText: totalInterestText,
                totalPayableText: totalPayableText,
                paidAmountText: paidAmountText,
                remainingAmountText: remainingAmountText,
                installmentPlanJson: installmentPlanJson,
                valuationDate: valuationDate,
                marketValueText: marketValueText,
                marketValueDate: marketValueDate,
                valuationSource: valuationSource,
                loanBalanceText: loanBalanceText,
                loanAsOfDate: loanAsOfDate,
                paidAmountToDateText: paidAmountToDateText,
                ownershipSharePctText: ownershipSharePctText,
                country: country,
                location: location,
                inflationRateText: inflationRateText,
                estimatedCurrentValueText: estimatedCurrentValueText,
                description: description,
                noZakat: noZakat,
                yearlyGrowthRateText: yearlyGrowthRateText,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String investmentType,
                required String assetSubtype,
                required String ownershipType,
                required String valuationMode,
                required String currency,
                required String originalPriceText,
                required String totalInterestText,
                required String totalPayableText,
                required String paidAmountText,
                required String remainingAmountText,
                required String installmentPlanJson,
                required String valuationDate,
                required String marketValueText,
                required String marketValueDate,
                required String valuationSource,
                required String loanBalanceText,
                required String loanAsOfDate,
                required String paidAmountToDateText,
                required String ownershipSharePctText,
                required String country,
                required String location,
                required String inflationRateText,
                required String estimatedCurrentValueText,
                required String description,
                Value<bool> noZakat = const Value.absent(),
                Value<String?> yearlyGrowthRateText = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvestmentsCompanion.insert(
                id: id,
                investmentType: investmentType,
                assetSubtype: assetSubtype,
                ownershipType: ownershipType,
                valuationMode: valuationMode,
                currency: currency,
                originalPriceText: originalPriceText,
                totalInterestText: totalInterestText,
                totalPayableText: totalPayableText,
                paidAmountText: paidAmountText,
                remainingAmountText: remainingAmountText,
                installmentPlanJson: installmentPlanJson,
                valuationDate: valuationDate,
                marketValueText: marketValueText,
                marketValueDate: marketValueDate,
                valuationSource: valuationSource,
                loanBalanceText: loanBalanceText,
                loanAsOfDate: loanAsOfDate,
                paidAmountToDateText: paidAmountToDateText,
                ownershipSharePctText: ownershipSharePctText,
                country: country,
                location: location,
                inflationRateText: inflationRateText,
                estimatedCurrentValueText: estimatedCurrentValueText,
                description: description,
                noZakat: noZakat,
                yearlyGrowthRateText: yearlyGrowthRateText,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InvestmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InvestmentsTable,
      Investment,
      $$InvestmentsTableFilterComposer,
      $$InvestmentsTableOrderingComposer,
      $$InvestmentsTableAnnotationComposer,
      $$InvestmentsTableCreateCompanionBuilder,
      $$InvestmentsTableUpdateCompanionBuilder,
      (
        Investment,
        BaseReferences<_$AppDatabase, $InvestmentsTable, Investment>,
      ),
      Investment,
      PrefetchHooks Function()
    >;
typedef $$PendingTransactionsTableCreateCompanionBuilder =
    PendingTransactionsCompanion Function({
      required String id,
      required String source,
      Value<String?> sourceIdentifier,
      required String rawMessage,
      required String createdAt,
      Value<String?> reviewedAt,
      required String suggestedType,
      Value<String?> suggestedAmountText,
      Value<String?> suggestedCurrency,
      Value<String?> suggestedDescription,
      Value<String?> merchantName,
      Value<String?> suggestedCategory,
      required String confidenceText,
      required String status,
      Value<String?> approvalSource,
      Value<String?> merchantRuleUsed,
      Value<String?> merchantRuleSource,
      Value<String?> ignoreReason,
      Value<String?> parserVersion,
      Value<String?> detectedBank,
      Value<bool> requiresReview,
      Value<bool> isRead,
      Value<String?> linkedTransactionId,
      required String updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$PendingTransactionsTableUpdateCompanionBuilder =
    PendingTransactionsCompanion Function({
      Value<String> id,
      Value<String> source,
      Value<String?> sourceIdentifier,
      Value<String> rawMessage,
      Value<String> createdAt,
      Value<String?> reviewedAt,
      Value<String> suggestedType,
      Value<String?> suggestedAmountText,
      Value<String?> suggestedCurrency,
      Value<String?> suggestedDescription,
      Value<String?> merchantName,
      Value<String?> suggestedCategory,
      Value<String> confidenceText,
      Value<String> status,
      Value<String?> approvalSource,
      Value<String?> merchantRuleUsed,
      Value<String?> merchantRuleSource,
      Value<String?> ignoreReason,
      Value<String?> parserVersion,
      Value<String?> detectedBank,
      Value<bool> requiresReview,
      Value<bool> isRead,
      Value<String?> linkedTransactionId,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$PendingTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingTransactionsTable> {
  $$PendingTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceIdentifier => $composableBuilder(
    column: $table.sourceIdentifier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawMessage => $composableBuilder(
    column: $table.rawMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedType => $composableBuilder(
    column: $table.suggestedType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedAmountText => $composableBuilder(
    column: $table.suggestedAmountText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedCurrency => $composableBuilder(
    column: $table.suggestedCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedDescription => $composableBuilder(
    column: $table.suggestedDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchantName => $composableBuilder(
    column: $table.merchantName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedCategory => $composableBuilder(
    column: $table.suggestedCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confidenceText => $composableBuilder(
    column: $table.confidenceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get approvalSource => $composableBuilder(
    column: $table.approvalSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchantRuleUsed => $composableBuilder(
    column: $table.merchantRuleUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchantRuleSource => $composableBuilder(
    column: $table.merchantRuleSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ignoreReason => $composableBuilder(
    column: $table.ignoreReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parserVersion => $composableBuilder(
    column: $table.parserVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detectedBank => $composableBuilder(
    column: $table.detectedBank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresReview => $composableBuilder(
    column: $table.requiresReview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedTransactionId => $composableBuilder(
    column: $table.linkedTransactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingTransactionsTable> {
  $$PendingTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceIdentifier => $composableBuilder(
    column: $table.sourceIdentifier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawMessage => $composableBuilder(
    column: $table.rawMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedType => $composableBuilder(
    column: $table.suggestedType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedAmountText => $composableBuilder(
    column: $table.suggestedAmountText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedCurrency => $composableBuilder(
    column: $table.suggestedCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedDescription => $composableBuilder(
    column: $table.suggestedDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchantName => $composableBuilder(
    column: $table.merchantName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedCategory => $composableBuilder(
    column: $table.suggestedCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confidenceText => $composableBuilder(
    column: $table.confidenceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get approvalSource => $composableBuilder(
    column: $table.approvalSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchantRuleUsed => $composableBuilder(
    column: $table.merchantRuleUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchantRuleSource => $composableBuilder(
    column: $table.merchantRuleSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ignoreReason => $composableBuilder(
    column: $table.ignoreReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parserVersion => $composableBuilder(
    column: $table.parserVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detectedBank => $composableBuilder(
    column: $table.detectedBank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresReview => $composableBuilder(
    column: $table.requiresReview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedTransactionId => $composableBuilder(
    column: $table.linkedTransactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingTransactionsTable> {
  $$PendingTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceIdentifier => $composableBuilder(
    column: $table.sourceIdentifier,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawMessage => $composableBuilder(
    column: $table.rawMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedType => $composableBuilder(
    column: $table.suggestedType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedAmountText => $composableBuilder(
    column: $table.suggestedAmountText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedCurrency => $composableBuilder(
    column: $table.suggestedCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedDescription => $composableBuilder(
    column: $table.suggestedDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get merchantName => $composableBuilder(
    column: $table.merchantName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedCategory => $composableBuilder(
    column: $table.suggestedCategory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confidenceText => $composableBuilder(
    column: $table.confidenceText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get approvalSource => $composableBuilder(
    column: $table.approvalSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get merchantRuleUsed => $composableBuilder(
    column: $table.merchantRuleUsed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get merchantRuleSource => $composableBuilder(
    column: $table.merchantRuleSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ignoreReason => $composableBuilder(
    column: $table.ignoreReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parserVersion => $composableBuilder(
    column: $table.parserVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detectedBank => $composableBuilder(
    column: $table.detectedBank,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get requiresReview => $composableBuilder(
    column: $table.requiresReview,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<String> get linkedTransactionId => $composableBuilder(
    column: $table.linkedTransactionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$PendingTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingTransactionsTable,
          PendingTransaction,
          $$PendingTransactionsTableFilterComposer,
          $$PendingTransactionsTableOrderingComposer,
          $$PendingTransactionsTableAnnotationComposer,
          $$PendingTransactionsTableCreateCompanionBuilder,
          $$PendingTransactionsTableUpdateCompanionBuilder,
          (
            PendingTransaction,
            BaseReferences<
              _$AppDatabase,
              $PendingTransactionsTable,
              PendingTransaction
            >,
          ),
          PendingTransaction,
          PrefetchHooks Function()
        > {
  $$PendingTransactionsTableTableManager(
    _$AppDatabase db,
    $PendingTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingTransactionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PendingTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> sourceIdentifier = const Value.absent(),
                Value<String> rawMessage = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String?> reviewedAt = const Value.absent(),
                Value<String> suggestedType = const Value.absent(),
                Value<String?> suggestedAmountText = const Value.absent(),
                Value<String?> suggestedCurrency = const Value.absent(),
                Value<String?> suggestedDescription = const Value.absent(),
                Value<String?> merchantName = const Value.absent(),
                Value<String?> suggestedCategory = const Value.absent(),
                Value<String> confidenceText = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> approvalSource = const Value.absent(),
                Value<String?> merchantRuleUsed = const Value.absent(),
                Value<String?> merchantRuleSource = const Value.absent(),
                Value<String?> ignoreReason = const Value.absent(),
                Value<String?> parserVersion = const Value.absent(),
                Value<String?> detectedBank = const Value.absent(),
                Value<bool> requiresReview = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<String?> linkedTransactionId = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingTransactionsCompanion(
                id: id,
                source: source,
                sourceIdentifier: sourceIdentifier,
                rawMessage: rawMessage,
                createdAt: createdAt,
                reviewedAt: reviewedAt,
                suggestedType: suggestedType,
                suggestedAmountText: suggestedAmountText,
                suggestedCurrency: suggestedCurrency,
                suggestedDescription: suggestedDescription,
                merchantName: merchantName,
                suggestedCategory: suggestedCategory,
                confidenceText: confidenceText,
                status: status,
                approvalSource: approvalSource,
                merchantRuleUsed: merchantRuleUsed,
                merchantRuleSource: merchantRuleSource,
                ignoreReason: ignoreReason,
                parserVersion: parserVersion,
                detectedBank: detectedBank,
                requiresReview: requiresReview,
                isRead: isRead,
                linkedTransactionId: linkedTransactionId,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String source,
                Value<String?> sourceIdentifier = const Value.absent(),
                required String rawMessage,
                required String createdAt,
                Value<String?> reviewedAt = const Value.absent(),
                required String suggestedType,
                Value<String?> suggestedAmountText = const Value.absent(),
                Value<String?> suggestedCurrency = const Value.absent(),
                Value<String?> suggestedDescription = const Value.absent(),
                Value<String?> merchantName = const Value.absent(),
                Value<String?> suggestedCategory = const Value.absent(),
                required String confidenceText,
                required String status,
                Value<String?> approvalSource = const Value.absent(),
                Value<String?> merchantRuleUsed = const Value.absent(),
                Value<String?> merchantRuleSource = const Value.absent(),
                Value<String?> ignoreReason = const Value.absent(),
                Value<String?> parserVersion = const Value.absent(),
                Value<String?> detectedBank = const Value.absent(),
                Value<bool> requiresReview = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<String?> linkedTransactionId = const Value.absent(),
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingTransactionsCompanion.insert(
                id: id,
                source: source,
                sourceIdentifier: sourceIdentifier,
                rawMessage: rawMessage,
                createdAt: createdAt,
                reviewedAt: reviewedAt,
                suggestedType: suggestedType,
                suggestedAmountText: suggestedAmountText,
                suggestedCurrency: suggestedCurrency,
                suggestedDescription: suggestedDescription,
                merchantName: merchantName,
                suggestedCategory: suggestedCategory,
                confidenceText: confidenceText,
                status: status,
                approvalSource: approvalSource,
                merchantRuleUsed: merchantRuleUsed,
                merchantRuleSource: merchantRuleSource,
                ignoreReason: ignoreReason,
                parserVersion: parserVersion,
                detectedBank: detectedBank,
                requiresReview: requiresReview,
                isRead: isRead,
                linkedTransactionId: linkedTransactionId,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingTransactionsTable,
      PendingTransaction,
      $$PendingTransactionsTableFilterComposer,
      $$PendingTransactionsTableOrderingComposer,
      $$PendingTransactionsTableAnnotationComposer,
      $$PendingTransactionsTableCreateCompanionBuilder,
      $$PendingTransactionsTableUpdateCompanionBuilder,
      (
        PendingTransaction,
        BaseReferences<
          _$AppDatabase,
          $PendingTransactionsTable,
          PendingTransaction
        >,
      ),
      PendingTransaction,
      PrefetchHooks Function()
    >;
typedef $$RecurringTransactionsTableCreateCompanionBuilder =
    RecurringTransactionsCompanion Function({
      required String id,
      required String name,
      required String type,
      required String amountText,
      required String currency,
      required String category,
      required String description,
      required int dayOfMonth,
      required String frequency,
      Value<String?> lastProcessed,
      required bool enabled,
      required String skipMonth,
      required String createdAt,
      required String updatedAt,
      Value<String?> deletedAt,
      Value<bool> autoAdd,
      Value<bool> reminderEnabled,
      Value<int> reminderDayOffset,
      Value<String> reminderTime,
      Value<int> rowid,
    });
typedef $$RecurringTransactionsTableUpdateCompanionBuilder =
    RecurringTransactionsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> type,
      Value<String> amountText,
      Value<String> currency,
      Value<String> category,
      Value<String> description,
      Value<int> dayOfMonth,
      Value<String> frequency,
      Value<String?> lastProcessed,
      Value<bool> enabled,
      Value<String> skipMonth,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<bool> autoAdd,
      Value<bool> reminderEnabled,
      Value<int> reminderDayOffset,
      Value<String> reminderTime,
      Value<int> rowid,
    });

class $$RecurringTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $RecurringTransactionsTable> {
  $$RecurringTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amountText => $composableBuilder(
    column: $table.amountText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastProcessed => $composableBuilder(
    column: $table.lastProcessed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skipMonth => $composableBuilder(
    column: $table.skipMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoAdd => $composableBuilder(
    column: $table.autoAdd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderDayOffset => $composableBuilder(
    column: $table.reminderDayOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecurringTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecurringTransactionsTable> {
  $$RecurringTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amountText => $composableBuilder(
    column: $table.amountText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastProcessed => $composableBuilder(
    column: $table.lastProcessed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skipMonth => $composableBuilder(
    column: $table.skipMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoAdd => $composableBuilder(
    column: $table.autoAdd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderDayOffset => $composableBuilder(
    column: $table.reminderDayOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecurringTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecurringTransactionsTable> {
  $$RecurringTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get amountText => $composableBuilder(
    column: $table.amountText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<String> get lastProcessed => $composableBuilder(
    column: $table.lastProcessed,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get skipMonth =>
      $composableBuilder(column: $table.skipMonth, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get autoAdd =>
      $composableBuilder(column: $table.autoAdd, builder: (column) => column);

  GeneratedColumn<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderDayOffset => $composableBuilder(
    column: $table.reminderDayOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => column,
  );
}

class $$RecurringTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecurringTransactionsTable,
          RecurringTransaction,
          $$RecurringTransactionsTableFilterComposer,
          $$RecurringTransactionsTableOrderingComposer,
          $$RecurringTransactionsTableAnnotationComposer,
          $$RecurringTransactionsTableCreateCompanionBuilder,
          $$RecurringTransactionsTableUpdateCompanionBuilder,
          (
            RecurringTransaction,
            BaseReferences<
              _$AppDatabase,
              $RecurringTransactionsTable,
              RecurringTransaction
            >,
          ),
          RecurringTransaction,
          PrefetchHooks Function()
        > {
  $$RecurringTransactionsTableTableManager(
    _$AppDatabase db,
    $RecurringTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringTransactionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$RecurringTransactionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RecurringTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> amountText = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> dayOfMonth = const Value.absent(),
                Value<String> frequency = const Value.absent(),
                Value<String?> lastProcessed = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> skipMonth = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<bool> autoAdd = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<int> reminderDayOffset = const Value.absent(),
                Value<String> reminderTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurringTransactionsCompanion(
                id: id,
                name: name,
                type: type,
                amountText: amountText,
                currency: currency,
                category: category,
                description: description,
                dayOfMonth: dayOfMonth,
                frequency: frequency,
                lastProcessed: lastProcessed,
                enabled: enabled,
                skipMonth: skipMonth,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                autoAdd: autoAdd,
                reminderEnabled: reminderEnabled,
                reminderDayOffset: reminderDayOffset,
                reminderTime: reminderTime,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String type,
                required String amountText,
                required String currency,
                required String category,
                required String description,
                required int dayOfMonth,
                required String frequency,
                Value<String?> lastProcessed = const Value.absent(),
                required bool enabled,
                required String skipMonth,
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<bool> autoAdd = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<int> reminderDayOffset = const Value.absent(),
                Value<String> reminderTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurringTransactionsCompanion.insert(
                id: id,
                name: name,
                type: type,
                amountText: amountText,
                currency: currency,
                category: category,
                description: description,
                dayOfMonth: dayOfMonth,
                frequency: frequency,
                lastProcessed: lastProcessed,
                enabled: enabled,
                skipMonth: skipMonth,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                autoAdd: autoAdd,
                reminderEnabled: reminderEnabled,
                reminderDayOffset: reminderDayOffset,
                reminderTime: reminderTime,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecurringTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecurringTransactionsTable,
      RecurringTransaction,
      $$RecurringTransactionsTableFilterComposer,
      $$RecurringTransactionsTableOrderingComposer,
      $$RecurringTransactionsTableAnnotationComposer,
      $$RecurringTransactionsTableCreateCompanionBuilder,
      $$RecurringTransactionsTableUpdateCompanionBuilder,
      (
        RecurringTransaction,
        BaseReferences<
          _$AppDatabase,
          $RecurringTransactionsTable,
          RecurringTransaction
        >,
      ),
      RecurringTransaction,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String valueJson,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> valueJson,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String valueJson,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$FinancialPlansTableCreateCompanionBuilder =
    FinancialPlansCompanion Function({
      required String id,
      required String name,
      required String startDate,
      required String projectionCurrency,
      required String startingBalanceText,
      required String startingBalanceDate,
      required String startingBalanceMode,
      required String snapshotWealthCurrency,
      required String startingAssetBreakdownJson,
      required String monthlyIncomeText,
      required String monthlyExpensesText,
      required bool includeInstallments,
      required bool includeZakat,
      required int durationYears,
      required String createdAt,
      required bool isActive,
      required String startingAssetsText,
      required String startingLiabilitiesText,
      required String startingNetWorthText,
      required String startingNisabSnapshotText,
      required String startingGoldPriceSnapshotText,
      required String startingFxSnapshotJson,
      required String updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$FinancialPlansTableUpdateCompanionBuilder =
    FinancialPlansCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> startDate,
      Value<String> projectionCurrency,
      Value<String> startingBalanceText,
      Value<String> startingBalanceDate,
      Value<String> startingBalanceMode,
      Value<String> snapshotWealthCurrency,
      Value<String> startingAssetBreakdownJson,
      Value<String> monthlyIncomeText,
      Value<String> monthlyExpensesText,
      Value<bool> includeInstallments,
      Value<bool> includeZakat,
      Value<int> durationYears,
      Value<String> createdAt,
      Value<bool> isActive,
      Value<String> startingAssetsText,
      Value<String> startingLiabilitiesText,
      Value<String> startingNetWorthText,
      Value<String> startingNisabSnapshotText,
      Value<String> startingGoldPriceSnapshotText,
      Value<String> startingFxSnapshotJson,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$FinancialPlansTableFilterComposer
    extends Composer<_$AppDatabase, $FinancialPlansTable> {
  $$FinancialPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectionCurrency => $composableBuilder(
    column: $table.projectionCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startingBalanceText => $composableBuilder(
    column: $table.startingBalanceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startingBalanceDate => $composableBuilder(
    column: $table.startingBalanceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startingBalanceMode => $composableBuilder(
    column: $table.startingBalanceMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotWealthCurrency => $composableBuilder(
    column: $table.snapshotWealthCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startingAssetBreakdownJson => $composableBuilder(
    column: $table.startingAssetBreakdownJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get monthlyIncomeText => $composableBuilder(
    column: $table.monthlyIncomeText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get monthlyExpensesText => $composableBuilder(
    column: $table.monthlyExpensesText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includeInstallments => $composableBuilder(
    column: $table.includeInstallments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includeZakat => $composableBuilder(
    column: $table.includeZakat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationYears => $composableBuilder(
    column: $table.durationYears,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startingAssetsText => $composableBuilder(
    column: $table.startingAssetsText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startingLiabilitiesText => $composableBuilder(
    column: $table.startingLiabilitiesText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startingNetWorthText => $composableBuilder(
    column: $table.startingNetWorthText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startingNisabSnapshotText => $composableBuilder(
    column: $table.startingNisabSnapshotText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startingGoldPriceSnapshotText => $composableBuilder(
    column: $table.startingGoldPriceSnapshotText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startingFxSnapshotJson => $composableBuilder(
    column: $table.startingFxSnapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FinancialPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $FinancialPlansTable> {
  $$FinancialPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectionCurrency => $composableBuilder(
    column: $table.projectionCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startingBalanceText => $composableBuilder(
    column: $table.startingBalanceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startingBalanceDate => $composableBuilder(
    column: $table.startingBalanceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startingBalanceMode => $composableBuilder(
    column: $table.startingBalanceMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotWealthCurrency => $composableBuilder(
    column: $table.snapshotWealthCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startingAssetBreakdownJson => $composableBuilder(
    column: $table.startingAssetBreakdownJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get monthlyIncomeText => $composableBuilder(
    column: $table.monthlyIncomeText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get monthlyExpensesText => $composableBuilder(
    column: $table.monthlyExpensesText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includeInstallments => $composableBuilder(
    column: $table.includeInstallments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includeZakat => $composableBuilder(
    column: $table.includeZakat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationYears => $composableBuilder(
    column: $table.durationYears,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startingAssetsText => $composableBuilder(
    column: $table.startingAssetsText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startingLiabilitiesText => $composableBuilder(
    column: $table.startingLiabilitiesText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startingNetWorthText => $composableBuilder(
    column: $table.startingNetWorthText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startingNisabSnapshotText => $composableBuilder(
    column: $table.startingNisabSnapshotText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startingGoldPriceSnapshotText =>
      $composableBuilder(
        column: $table.startingGoldPriceSnapshotText,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get startingFxSnapshotJson => $composableBuilder(
    column: $table.startingFxSnapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FinancialPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $FinancialPlansTable> {
  $$FinancialPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get projectionCurrency => $composableBuilder(
    column: $table.projectionCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startingBalanceText => $composableBuilder(
    column: $table.startingBalanceText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startingBalanceDate => $composableBuilder(
    column: $table.startingBalanceDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startingBalanceMode => $composableBuilder(
    column: $table.startingBalanceMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapshotWealthCurrency => $composableBuilder(
    column: $table.snapshotWealthCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startingAssetBreakdownJson => $composableBuilder(
    column: $table.startingAssetBreakdownJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get monthlyIncomeText => $composableBuilder(
    column: $table.monthlyIncomeText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get monthlyExpensesText => $composableBuilder(
    column: $table.monthlyExpensesText,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get includeInstallments => $composableBuilder(
    column: $table.includeInstallments,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get includeZakat => $composableBuilder(
    column: $table.includeZakat,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationYears => $composableBuilder(
    column: $table.durationYears,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get startingAssetsText => $composableBuilder(
    column: $table.startingAssetsText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startingLiabilitiesText => $composableBuilder(
    column: $table.startingLiabilitiesText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startingNetWorthText => $composableBuilder(
    column: $table.startingNetWorthText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startingNisabSnapshotText => $composableBuilder(
    column: $table.startingNisabSnapshotText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startingGoldPriceSnapshotText =>
      $composableBuilder(
        column: $table.startingGoldPriceSnapshotText,
        builder: (column) => column,
      );

  GeneratedColumn<String> get startingFxSnapshotJson => $composableBuilder(
    column: $table.startingFxSnapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$FinancialPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FinancialPlansTable,
          FinancialPlan,
          $$FinancialPlansTableFilterComposer,
          $$FinancialPlansTableOrderingComposer,
          $$FinancialPlansTableAnnotationComposer,
          $$FinancialPlansTableCreateCompanionBuilder,
          $$FinancialPlansTableUpdateCompanionBuilder,
          (
            FinancialPlan,
            BaseReferences<_$AppDatabase, $FinancialPlansTable, FinancialPlan>,
          ),
          FinancialPlan,
          PrefetchHooks Function()
        > {
  $$FinancialPlansTableTableManager(
    _$AppDatabase db,
    $FinancialPlansTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FinancialPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FinancialPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FinancialPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<String> projectionCurrency = const Value.absent(),
                Value<String> startingBalanceText = const Value.absent(),
                Value<String> startingBalanceDate = const Value.absent(),
                Value<String> startingBalanceMode = const Value.absent(),
                Value<String> snapshotWealthCurrency = const Value.absent(),
                Value<String> startingAssetBreakdownJson = const Value.absent(),
                Value<String> monthlyIncomeText = const Value.absent(),
                Value<String> monthlyExpensesText = const Value.absent(),
                Value<bool> includeInstallments = const Value.absent(),
                Value<bool> includeZakat = const Value.absent(),
                Value<int> durationYears = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> startingAssetsText = const Value.absent(),
                Value<String> startingLiabilitiesText = const Value.absent(),
                Value<String> startingNetWorthText = const Value.absent(),
                Value<String> startingNisabSnapshotText = const Value.absent(),
                Value<String> startingGoldPriceSnapshotText =
                    const Value.absent(),
                Value<String> startingFxSnapshotJson = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FinancialPlansCompanion(
                id: id,
                name: name,
                startDate: startDate,
                projectionCurrency: projectionCurrency,
                startingBalanceText: startingBalanceText,
                startingBalanceDate: startingBalanceDate,
                startingBalanceMode: startingBalanceMode,
                snapshotWealthCurrency: snapshotWealthCurrency,
                startingAssetBreakdownJson: startingAssetBreakdownJson,
                monthlyIncomeText: monthlyIncomeText,
                monthlyExpensesText: monthlyExpensesText,
                includeInstallments: includeInstallments,
                includeZakat: includeZakat,
                durationYears: durationYears,
                createdAt: createdAt,
                isActive: isActive,
                startingAssetsText: startingAssetsText,
                startingLiabilitiesText: startingLiabilitiesText,
                startingNetWorthText: startingNetWorthText,
                startingNisabSnapshotText: startingNisabSnapshotText,
                startingGoldPriceSnapshotText: startingGoldPriceSnapshotText,
                startingFxSnapshotJson: startingFxSnapshotJson,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String startDate,
                required String projectionCurrency,
                required String startingBalanceText,
                required String startingBalanceDate,
                required String startingBalanceMode,
                required String snapshotWealthCurrency,
                required String startingAssetBreakdownJson,
                required String monthlyIncomeText,
                required String monthlyExpensesText,
                required bool includeInstallments,
                required bool includeZakat,
                required int durationYears,
                required String createdAt,
                required bool isActive,
                required String startingAssetsText,
                required String startingLiabilitiesText,
                required String startingNetWorthText,
                required String startingNisabSnapshotText,
                required String startingGoldPriceSnapshotText,
                required String startingFxSnapshotJson,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FinancialPlansCompanion.insert(
                id: id,
                name: name,
                startDate: startDate,
                projectionCurrency: projectionCurrency,
                startingBalanceText: startingBalanceText,
                startingBalanceDate: startingBalanceDate,
                startingBalanceMode: startingBalanceMode,
                snapshotWealthCurrency: snapshotWealthCurrency,
                startingAssetBreakdownJson: startingAssetBreakdownJson,
                monthlyIncomeText: monthlyIncomeText,
                monthlyExpensesText: monthlyExpensesText,
                includeInstallments: includeInstallments,
                includeZakat: includeZakat,
                durationYears: durationYears,
                createdAt: createdAt,
                isActive: isActive,
                startingAssetsText: startingAssetsText,
                startingLiabilitiesText: startingLiabilitiesText,
                startingNetWorthText: startingNetWorthText,
                startingNisabSnapshotText: startingNisabSnapshotText,
                startingGoldPriceSnapshotText: startingGoldPriceSnapshotText,
                startingFxSnapshotJson: startingFxSnapshotJson,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FinancialPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FinancialPlansTable,
      FinancialPlan,
      $$FinancialPlansTableFilterComposer,
      $$FinancialPlansTableOrderingComposer,
      $$FinancialPlansTableAnnotationComposer,
      $$FinancialPlansTableCreateCompanionBuilder,
      $$FinancialPlansTableUpdateCompanionBuilder,
      (
        FinancialPlan,
        BaseReferences<_$AppDatabase, $FinancialPlansTable, FinancialPlan>,
      ),
      FinancialPlan,
      PrefetchHooks Function()
    >;
typedef $$MerchantRulesTableCreateCompanionBuilder =
    MerchantRulesCompanion Function({
      required String id,
      required String merchantName,
      required String categoryId,
      required String defaultType,
      required bool autoApprove,
      required int usageCount,
      required String confidenceText,
      Value<String?> lastUsed,
      required String source,
      required String aliasesJson,
      required bool enabled,
      required bool isBuiltinOverride,
      Value<String?> builtinKey,
      required String updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$MerchantRulesTableUpdateCompanionBuilder =
    MerchantRulesCompanion Function({
      Value<String> id,
      Value<String> merchantName,
      Value<String> categoryId,
      Value<String> defaultType,
      Value<bool> autoApprove,
      Value<int> usageCount,
      Value<String> confidenceText,
      Value<String?> lastUsed,
      Value<String> source,
      Value<String> aliasesJson,
      Value<bool> enabled,
      Value<bool> isBuiltinOverride,
      Value<String?> builtinKey,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$MerchantRulesTableFilterComposer
    extends Composer<_$AppDatabase, $MerchantRulesTable> {
  $$MerchantRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchantName => $composableBuilder(
    column: $table.merchantName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultType => $composableBuilder(
    column: $table.defaultType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoApprove => $composableBuilder(
    column: $table.autoApprove,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usageCount => $composableBuilder(
    column: $table.usageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confidenceText => $composableBuilder(
    column: $table.confidenceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastUsed => $composableBuilder(
    column: $table.lastUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltinOverride => $composableBuilder(
    column: $table.isBuiltinOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get builtinKey => $composableBuilder(
    column: $table.builtinKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MerchantRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $MerchantRulesTable> {
  $$MerchantRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchantName => $composableBuilder(
    column: $table.merchantName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultType => $composableBuilder(
    column: $table.defaultType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoApprove => $composableBuilder(
    column: $table.autoApprove,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usageCount => $composableBuilder(
    column: $table.usageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confidenceText => $composableBuilder(
    column: $table.confidenceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastUsed => $composableBuilder(
    column: $table.lastUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltinOverride => $composableBuilder(
    column: $table.isBuiltinOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get builtinKey => $composableBuilder(
    column: $table.builtinKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MerchantRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MerchantRulesTable> {
  $$MerchantRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get merchantName => $composableBuilder(
    column: $table.merchantName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultType => $composableBuilder(
    column: $table.defaultType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoApprove => $composableBuilder(
    column: $table.autoApprove,
    builder: (column) => column,
  );

  GeneratedColumn<int> get usageCount => $composableBuilder(
    column: $table.usageCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confidenceText => $composableBuilder(
    column: $table.confidenceText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastUsed =>
      $composableBuilder(column: $table.lastUsed, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get isBuiltinOverride => $composableBuilder(
    column: $table.isBuiltinOverride,
    builder: (column) => column,
  );

  GeneratedColumn<String> get builtinKey => $composableBuilder(
    column: $table.builtinKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$MerchantRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MerchantRulesTable,
          MerchantRule,
          $$MerchantRulesTableFilterComposer,
          $$MerchantRulesTableOrderingComposer,
          $$MerchantRulesTableAnnotationComposer,
          $$MerchantRulesTableCreateCompanionBuilder,
          $$MerchantRulesTableUpdateCompanionBuilder,
          (
            MerchantRule,
            BaseReferences<_$AppDatabase, $MerchantRulesTable, MerchantRule>,
          ),
          MerchantRule,
          PrefetchHooks Function()
        > {
  $$MerchantRulesTableTableManager(_$AppDatabase db, $MerchantRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MerchantRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MerchantRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MerchantRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> merchantName = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> defaultType = const Value.absent(),
                Value<bool> autoApprove = const Value.absent(),
                Value<int> usageCount = const Value.absent(),
                Value<String> confidenceText = const Value.absent(),
                Value<String?> lastUsed = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> aliasesJson = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> isBuiltinOverride = const Value.absent(),
                Value<String?> builtinKey = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MerchantRulesCompanion(
                id: id,
                merchantName: merchantName,
                categoryId: categoryId,
                defaultType: defaultType,
                autoApprove: autoApprove,
                usageCount: usageCount,
                confidenceText: confidenceText,
                lastUsed: lastUsed,
                source: source,
                aliasesJson: aliasesJson,
                enabled: enabled,
                isBuiltinOverride: isBuiltinOverride,
                builtinKey: builtinKey,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String merchantName,
                required String categoryId,
                required String defaultType,
                required bool autoApprove,
                required int usageCount,
                required String confidenceText,
                Value<String?> lastUsed = const Value.absent(),
                required String source,
                required String aliasesJson,
                required bool enabled,
                required bool isBuiltinOverride,
                Value<String?> builtinKey = const Value.absent(),
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MerchantRulesCompanion.insert(
                id: id,
                merchantName: merchantName,
                categoryId: categoryId,
                defaultType: defaultType,
                autoApprove: autoApprove,
                usageCount: usageCount,
                confidenceText: confidenceText,
                lastUsed: lastUsed,
                source: source,
                aliasesJson: aliasesJson,
                enabled: enabled,
                isBuiltinOverride: isBuiltinOverride,
                builtinKey: builtinKey,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MerchantRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MerchantRulesTable,
      MerchantRule,
      $$MerchantRulesTableFilterComposer,
      $$MerchantRulesTableOrderingComposer,
      $$MerchantRulesTableAnnotationComposer,
      $$MerchantRulesTableCreateCompanionBuilder,
      $$MerchantRulesTableUpdateCompanionBuilder,
      (
        MerchantRule,
        BaseReferences<_$AppDatabase, $MerchantRulesTable, MerchantRule>,
      ),
      MerchantRule,
      PrefetchHooks Function()
    >;
typedef $$MerchantConfirmationsTableCreateCompanionBuilder =
    MerchantConfirmationsCompanion Function({
      required String id,
      required String merchantName,
      required String categoryId,
      required int confirmations,
      required int corrections,
      required String updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$MerchantConfirmationsTableUpdateCompanionBuilder =
    MerchantConfirmationsCompanion Function({
      Value<String> id,
      Value<String> merchantName,
      Value<String> categoryId,
      Value<int> confirmations,
      Value<int> corrections,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$MerchantConfirmationsTableFilterComposer
    extends Composer<_$AppDatabase, $MerchantConfirmationsTable> {
  $$MerchantConfirmationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchantName => $composableBuilder(
    column: $table.merchantName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get confirmations => $composableBuilder(
    column: $table.confirmations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get corrections => $composableBuilder(
    column: $table.corrections,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MerchantConfirmationsTableOrderingComposer
    extends Composer<_$AppDatabase, $MerchantConfirmationsTable> {
  $$MerchantConfirmationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchantName => $composableBuilder(
    column: $table.merchantName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confirmations => $composableBuilder(
    column: $table.confirmations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get corrections => $composableBuilder(
    column: $table.corrections,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MerchantConfirmationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MerchantConfirmationsTable> {
  $$MerchantConfirmationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get merchantName => $composableBuilder(
    column: $table.merchantName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get confirmations => $composableBuilder(
    column: $table.confirmations,
    builder: (column) => column,
  );

  GeneratedColumn<int> get corrections => $composableBuilder(
    column: $table.corrections,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$MerchantConfirmationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MerchantConfirmationsTable,
          MerchantConfirmation,
          $$MerchantConfirmationsTableFilterComposer,
          $$MerchantConfirmationsTableOrderingComposer,
          $$MerchantConfirmationsTableAnnotationComposer,
          $$MerchantConfirmationsTableCreateCompanionBuilder,
          $$MerchantConfirmationsTableUpdateCompanionBuilder,
          (
            MerchantConfirmation,
            BaseReferences<
              _$AppDatabase,
              $MerchantConfirmationsTable,
              MerchantConfirmation
            >,
          ),
          MerchantConfirmation,
          PrefetchHooks Function()
        > {
  $$MerchantConfirmationsTableTableManager(
    _$AppDatabase db,
    $MerchantConfirmationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MerchantConfirmationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MerchantConfirmationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MerchantConfirmationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> merchantName = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<int> confirmations = const Value.absent(),
                Value<int> corrections = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MerchantConfirmationsCompanion(
                id: id,
                merchantName: merchantName,
                categoryId: categoryId,
                confirmations: confirmations,
                corrections: corrections,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String merchantName,
                required String categoryId,
                required int confirmations,
                required int corrections,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MerchantConfirmationsCompanion.insert(
                id: id,
                merchantName: merchantName,
                categoryId: categoryId,
                confirmations: confirmations,
                corrections: corrections,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MerchantConfirmationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MerchantConfirmationsTable,
      MerchantConfirmation,
      $$MerchantConfirmationsTableFilterComposer,
      $$MerchantConfirmationsTableOrderingComposer,
      $$MerchantConfirmationsTableAnnotationComposer,
      $$MerchantConfirmationsTableCreateCompanionBuilder,
      $$MerchantConfirmationsTableUpdateCompanionBuilder,
      (
        MerchantConfirmation,
        BaseReferences<
          _$AppDatabase,
          $MerchantConfirmationsTable,
          MerchantConfirmation
        >,
      ),
      MerchantConfirmation,
      PrefetchHooks Function()
    >;
typedef $$CorrectionFeedbacksTableCreateCompanionBuilder =
    CorrectionFeedbacksCompanion Function({
      required String id,
      required String fieldName,
      required String originalValue,
      required String correctedValue,
      required String createdAt,
      required String updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$CorrectionFeedbacksTableUpdateCompanionBuilder =
    CorrectionFeedbacksCompanion Function({
      Value<String> id,
      Value<String> fieldName,
      Value<String> originalValue,
      Value<String> correctedValue,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$CorrectionFeedbacksTableFilterComposer
    extends Composer<_$AppDatabase, $CorrectionFeedbacksTable> {
  $$CorrectionFeedbacksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldName => $composableBuilder(
    column: $table.fieldName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalValue => $composableBuilder(
    column: $table.originalValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get correctedValue => $composableBuilder(
    column: $table.correctedValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CorrectionFeedbacksTableOrderingComposer
    extends Composer<_$AppDatabase, $CorrectionFeedbacksTable> {
  $$CorrectionFeedbacksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldName => $composableBuilder(
    column: $table.fieldName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalValue => $composableBuilder(
    column: $table.originalValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get correctedValue => $composableBuilder(
    column: $table.correctedValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CorrectionFeedbacksTableAnnotationComposer
    extends Composer<_$AppDatabase, $CorrectionFeedbacksTable> {
  $$CorrectionFeedbacksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fieldName =>
      $composableBuilder(column: $table.fieldName, builder: (column) => column);

  GeneratedColumn<String> get originalValue => $composableBuilder(
    column: $table.originalValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get correctedValue => $composableBuilder(
    column: $table.correctedValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CorrectionFeedbacksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CorrectionFeedbacksTable,
          CorrectionFeedback,
          $$CorrectionFeedbacksTableFilterComposer,
          $$CorrectionFeedbacksTableOrderingComposer,
          $$CorrectionFeedbacksTableAnnotationComposer,
          $$CorrectionFeedbacksTableCreateCompanionBuilder,
          $$CorrectionFeedbacksTableUpdateCompanionBuilder,
          (
            CorrectionFeedback,
            BaseReferences<
              _$AppDatabase,
              $CorrectionFeedbacksTable,
              CorrectionFeedback
            >,
          ),
          CorrectionFeedback,
          PrefetchHooks Function()
        > {
  $$CorrectionFeedbacksTableTableManager(
    _$AppDatabase db,
    $CorrectionFeedbacksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CorrectionFeedbacksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CorrectionFeedbacksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CorrectionFeedbacksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> fieldName = const Value.absent(),
                Value<String> originalValue = const Value.absent(),
                Value<String> correctedValue = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CorrectionFeedbacksCompanion(
                id: id,
                fieldName: fieldName,
                originalValue: originalValue,
                correctedValue: correctedValue,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String fieldName,
                required String originalValue,
                required String correctedValue,
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CorrectionFeedbacksCompanion.insert(
                id: id,
                fieldName: fieldName,
                originalValue: originalValue,
                correctedValue: correctedValue,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CorrectionFeedbacksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CorrectionFeedbacksTable,
      CorrectionFeedback,
      $$CorrectionFeedbacksTableFilterComposer,
      $$CorrectionFeedbacksTableOrderingComposer,
      $$CorrectionFeedbacksTableAnnotationComposer,
      $$CorrectionFeedbacksTableCreateCompanionBuilder,
      $$CorrectionFeedbacksTableUpdateCompanionBuilder,
      (
        CorrectionFeedback,
        BaseReferences<
          _$AppDatabase,
          $CorrectionFeedbacksTable,
          CorrectionFeedback
        >,
      ),
      CorrectionFeedback,
      PrefetchHooks Function()
    >;
typedef $$SyncMetadataTableCreateCompanionBuilder =
    SyncMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncMetadataTableUpdateCompanionBuilder =
    SyncMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetadataTable,
          SyncMetadataData,
          $$SyncMetadataTableFilterComposer,
          $$SyncMetadataTableOrderingComposer,
          $$SyncMetadataTableAnnotationComposer,
          $$SyncMetadataTableCreateCompanionBuilder,
          $$SyncMetadataTableUpdateCompanionBuilder,
          (
            SyncMetadataData,
            BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>,
          ),
          SyncMetadataData,
          PrefetchHooks Function()
        > {
  $$SyncMetadataTableTableManager(_$AppDatabase db, $SyncMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetadataTable,
      SyncMetadataData,
      $$SyncMetadataTableFilterComposer,
      $$SyncMetadataTableOrderingComposer,
      $$SyncMetadataTableAnnotationComposer,
      $$SyncMetadataTableCreateCompanionBuilder,
      $$SyncMetadataTableUpdateCompanionBuilder,
      (
        SyncMetadataData,
        BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>,
      ),
      SyncMetadataData,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      required String collectionName,
      required String recordId,
      required String operation,
      Value<String?> payloadJson,
      required String createdAt,
      required String availableAt,
      Value<int> attemptCount,
      Value<String?> lastError,
      required String dedupeKey,
      Value<int> priority,
      Value<String?> deviceId,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      Value<String> collectionName,
      Value<String> recordId,
      Value<String> operation,
      Value<String?> payloadJson,
      Value<String> createdAt,
      Value<String> availableAt,
      Value<int> attemptCount,
      Value<String?> lastError,
      Value<String> dedupeKey,
      Value<int> priority,
      Value<String?> deviceId,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionName => $composableBuilder(
    column: $table.collectionName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionName => $composableBuilder(
    column: $table.collectionName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get collectionName => $composableBuilder(
    column: $table.collectionName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get dedupeKey =>
      $composableBuilder(column: $table.dedupeKey, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueData,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueData,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
          ),
          SyncQueueData,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> collectionName = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> availableAt = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String> dedupeKey = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                collectionName: collectionName,
                recordId: recordId,
                operation: operation,
                payloadJson: payloadJson,
                createdAt: createdAt,
                availableAt: availableAt,
                attemptCount: attemptCount,
                lastError: lastError,
                dedupeKey: dedupeKey,
                priority: priority,
                deviceId: deviceId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String collectionName,
                required String recordId,
                required String operation,
                Value<String?> payloadJson = const Value.absent(),
                required String createdAt,
                required String availableAt,
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required String dedupeKey,
                Value<int> priority = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                collectionName: collectionName,
                recordId: recordId,
                operation: operation,
                payloadJson: payloadJson,
                createdAt: createdAt,
                availableAt: availableAt,
                attemptCount: attemptCount,
                lastError: lastError,
                dedupeKey: dedupeKey,
                priority: priority,
                deviceId: deviceId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueData,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueData,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
      ),
      SyncQueueData,
      PrefetchHooks Function()
    >;
typedef $$MigrationStateTableCreateCompanionBuilder =
    MigrationStateCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$MigrationStateTableUpdateCompanionBuilder =
    MigrationStateCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$MigrationStateTableFilterComposer
    extends Composer<_$AppDatabase, $MigrationStateTable> {
  $$MigrationStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MigrationStateTableOrderingComposer
    extends Composer<_$AppDatabase, $MigrationStateTable> {
  $$MigrationStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MigrationStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $MigrationStateTable> {
  $$MigrationStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MigrationStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MigrationStateTable,
          MigrationStateData,
          $$MigrationStateTableFilterComposer,
          $$MigrationStateTableOrderingComposer,
          $$MigrationStateTableAnnotationComposer,
          $$MigrationStateTableCreateCompanionBuilder,
          $$MigrationStateTableUpdateCompanionBuilder,
          (
            MigrationStateData,
            BaseReferences<
              _$AppDatabase,
              $MigrationStateTable,
              MigrationStateData
            >,
          ),
          MigrationStateData,
          PrefetchHooks Function()
        > {
  $$MigrationStateTableTableManager(
    _$AppDatabase db,
    $MigrationStateTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MigrationStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MigrationStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MigrationStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  MigrationStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => MigrationStateCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MigrationStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MigrationStateTable,
      MigrationStateData,
      $$MigrationStateTableFilterComposer,
      $$MigrationStateTableOrderingComposer,
      $$MigrationStateTableAnnotationComposer,
      $$MigrationStateTableCreateCompanionBuilder,
      $$MigrationStateTableUpdateCompanionBuilder,
      (
        MigrationStateData,
        BaseReferences<_$AppDatabase, $MigrationStateTable, MigrationStateData>,
      ),
      MigrationStateData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$SavingsTableTableManager get savings =>
      $$SavingsTableTableManager(_db, _db.savings);
  $$InvestmentsTableTableManager get investments =>
      $$InvestmentsTableTableManager(_db, _db.investments);
  $$PendingTransactionsTableTableManager get pendingTransactions =>
      $$PendingTransactionsTableTableManager(_db, _db.pendingTransactions);
  $$RecurringTransactionsTableTableManager get recurringTransactions =>
      $$RecurringTransactionsTableTableManager(_db, _db.recurringTransactions);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$FinancialPlansTableTableManager get financialPlans =>
      $$FinancialPlansTableTableManager(_db, _db.financialPlans);
  $$MerchantRulesTableTableManager get merchantRules =>
      $$MerchantRulesTableTableManager(_db, _db.merchantRules);
  $$MerchantConfirmationsTableTableManager get merchantConfirmations =>
      $$MerchantConfirmationsTableTableManager(_db, _db.merchantConfirmations);
  $$CorrectionFeedbacksTableTableManager get correctionFeedbacks =>
      $$CorrectionFeedbacksTableTableManager(_db, _db.correctionFeedbacks);
  $$SyncMetadataTableTableManager get syncMetadata =>
      $$SyncMetadataTableTableManager(_db, _db.syncMetadata);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$MigrationStateTableTableManager get migrationState =>
      $$MigrationStateTableTableManager(_db, _db.migrationState);
}
