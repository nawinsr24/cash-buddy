// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openingMinorMeta = const VerificationMeta(
    'openingMinor',
  );
  @override
  late final GeneratedColumn<int> openingMinor = GeneratedColumn<int>(
    'opening_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _last4Meta = const VerificationMeta('last4');
  @override
  late final GeneratedColumn<String> last4 = GeneratedColumn<String>(
    'last4',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
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
    kind,
    colorValue,
    openingMinor,
    last4,
    sortOrder,
    archived,
    hlc,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
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
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('opening_minor')) {
      context.handle(
        _openingMinorMeta,
        openingMinor.isAcceptableOrUnknown(
          data['opening_minor']!,
          _openingMinorMeta,
        ),
      );
    }
    if (data.containsKey('last4')) {
      context.handle(
        _last4Meta,
        last4.isAcceptableOrUnknown(data['last4']!, _last4Meta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
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
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      openingMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opening_minor'],
      )!,
      last4: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last4'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final String id;
  final String name;
  final String kind;
  final int colorValue;
  final int openingMinor;
  final String? last4;
  final int sortOrder;
  final bool archived;
  final String hlc;
  final String? deletedAt;
  const Account({
    required this.id,
    required this.name,
    required this.kind,
    required this.colorValue,
    required this.openingMinor,
    this.last4,
    required this.sortOrder,
    required this.archived,
    required this.hlc,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    map['color_value'] = Variable<int>(colorValue);
    map['opening_minor'] = Variable<int>(openingMinor);
    if (!nullToAbsent || last4 != null) {
      map['last4'] = Variable<String>(last4);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['archived'] = Variable<bool>(archived);
    map['hlc'] = Variable<String>(hlc);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      colorValue: Value(colorValue),
      openingMinor: Value(openingMinor),
      last4: last4 == null && nullToAbsent
          ? const Value.absent()
          : Value(last4),
      sortOrder: Value(sortOrder),
      archived: Value(archived),
      hlc: Value(hlc),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      openingMinor: serializer.fromJson<int>(json['openingMinor']),
      last4: serializer.fromJson<String?>(json['last4']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      archived: serializer.fromJson<bool>(json['archived']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'colorValue': serializer.toJson<int>(colorValue),
      'openingMinor': serializer.toJson<int>(openingMinor),
      'last4': serializer.toJson<String?>(last4),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'archived': serializer.toJson<bool>(archived),
      'hlc': serializer.toJson<String>(hlc),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Account copyWith({
    String? id,
    String? name,
    String? kind,
    int? colorValue,
    int? openingMinor,
    Value<String?> last4 = const Value.absent(),
    int? sortOrder,
    bool? archived,
    String? hlc,
    Value<String?> deletedAt = const Value.absent(),
  }) => Account(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    colorValue: colorValue ?? this.colorValue,
    openingMinor: openingMinor ?? this.openingMinor,
    last4: last4.present ? last4.value : this.last4,
    sortOrder: sortOrder ?? this.sortOrder,
    archived: archived ?? this.archived,
    hlc: hlc ?? this.hlc,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      openingMinor: data.openingMinor.present
          ? data.openingMinor.value
          : this.openingMinor,
      last4: data.last4.present ? data.last4.value : this.last4,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      archived: data.archived.present ? data.archived.value : this.archived,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('colorValue: $colorValue, ')
          ..write('openingMinor: $openingMinor, ')
          ..write('last4: $last4, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived, ')
          ..write('hlc: $hlc, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    colorValue,
    openingMinor,
    last4,
    sortOrder,
    archived,
    hlc,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.colorValue == this.colorValue &&
          other.openingMinor == this.openingMinor &&
          other.last4 == this.last4 &&
          other.sortOrder == this.sortOrder &&
          other.archived == this.archived &&
          other.hlc == this.hlc &&
          other.deletedAt == this.deletedAt);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> kind;
  final Value<int> colorValue;
  final Value<int> openingMinor;
  final Value<String?> last4;
  final Value<int> sortOrder;
  final Value<bool> archived;
  final Value<String> hlc;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.openingMinor = const Value.absent(),
    this.last4 = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archived = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required String name,
    required String kind,
    required int colorValue,
    this.openingMinor = const Value.absent(),
    this.last4 = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archived = const Value.absent(),
    required String hlc,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       kind = Value(kind),
       colorValue = Value(colorValue),
       hlc = Value(hlc);
  static Insertable<Account> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<int>? colorValue,
    Expression<int>? openingMinor,
    Expression<String>? last4,
    Expression<int>? sortOrder,
    Expression<bool>? archived,
    Expression<String>? hlc,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (colorValue != null) 'color_value': colorValue,
      if (openingMinor != null) 'opening_minor': openingMinor,
      if (last4 != null) 'last4': last4,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (archived != null) 'archived': archived,
      if (hlc != null) 'hlc': hlc,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? kind,
    Value<int>? colorValue,
    Value<int>? openingMinor,
    Value<String?>? last4,
    Value<int>? sortOrder,
    Value<bool>? archived,
    Value<String>? hlc,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      colorValue: colorValue ?? this.colorValue,
      openingMinor: openingMinor ?? this.openingMinor,
      last4: last4 ?? this.last4,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
      hlc: hlc ?? this.hlc,
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
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (openingMinor.present) {
      map['opening_minor'] = Variable<int>(openingMinor.value);
    }
    if (last4.present) {
      map['last4'] = Variable<String>(last4.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
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
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('colorValue: $colorValue, ')
          ..write('openingMinor: $openingMinor, ')
          ..write('last4: $last4, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived, ')
          ..write('hlc: $hlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconKeyMeta = const VerificationMeta(
    'iconKey',
  );
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
    'icon_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('category'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
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
    kind,
    parentId,
    colorValue,
    iconKey,
    sortOrder,
    archived,
    hlc,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
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
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('icon_key')) {
      context.handle(
        _iconKeyMeta,
        iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
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
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      iconKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_key'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String name;
  final String kind;
  final String? parentId;
  final int colorValue;
  final String iconKey;
  final int sortOrder;
  final bool archived;
  final String hlc;
  final String? deletedAt;
  const Category({
    required this.id,
    required this.name,
    required this.kind,
    this.parentId,
    required this.colorValue,
    required this.iconKey,
    required this.sortOrder,
    required this.archived,
    required this.hlc,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['color_value'] = Variable<int>(colorValue);
    map['icon_key'] = Variable<String>(iconKey);
    map['sort_order'] = Variable<int>(sortOrder);
    map['archived'] = Variable<bool>(archived);
    map['hlc'] = Variable<String>(hlc);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      colorValue: Value(colorValue),
      iconKey: Value(iconKey),
      sortOrder: Value(sortOrder),
      archived: Value(archived),
      hlc: Value(hlc),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      iconKey: serializer.fromJson<String>(json['iconKey']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      archived: serializer.fromJson<bool>(json['archived']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'parentId': serializer.toJson<String?>(parentId),
      'colorValue': serializer.toJson<int>(colorValue),
      'iconKey': serializer.toJson<String>(iconKey),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'archived': serializer.toJson<bool>(archived),
      'hlc': serializer.toJson<String>(hlc),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? kind,
    Value<String?> parentId = const Value.absent(),
    int? colorValue,
    String? iconKey,
    int? sortOrder,
    bool? archived,
    String? hlc,
    Value<String?> deletedAt = const Value.absent(),
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    parentId: parentId.present ? parentId.value : this.parentId,
    colorValue: colorValue ?? this.colorValue,
    iconKey: iconKey ?? this.iconKey,
    sortOrder: sortOrder ?? this.sortOrder,
    archived: archived ?? this.archived,
    hlc: hlc ?? this.hlc,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      archived: data.archived.present ? data.archived.value : this.archived,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('parentId: $parentId, ')
          ..write('colorValue: $colorValue, ')
          ..write('iconKey: $iconKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived, ')
          ..write('hlc: $hlc, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    parentId,
    colorValue,
    iconKey,
    sortOrder,
    archived,
    hlc,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.parentId == this.parentId &&
          other.colorValue == this.colorValue &&
          other.iconKey == this.iconKey &&
          other.sortOrder == this.sortOrder &&
          other.archived == this.archived &&
          other.hlc == this.hlc &&
          other.deletedAt == this.deletedAt);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> kind;
  final Value<String?> parentId;
  final Value<int> colorValue;
  final Value<String> iconKey;
  final Value<int> sortOrder;
  final Value<bool> archived;
  final Value<String> hlc;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.parentId = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archived = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String name,
    required String kind,
    this.parentId = const Value.absent(),
    required int colorValue,
    this.iconKey = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archived = const Value.absent(),
    required String hlc,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       kind = Value(kind),
       colorValue = Value(colorValue),
       hlc = Value(hlc);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? parentId,
    Expression<int>? colorValue,
    Expression<String>? iconKey,
    Expression<int>? sortOrder,
    Expression<bool>? archived,
    Expression<String>? hlc,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (parentId != null) 'parent_id': parentId,
      if (colorValue != null) 'color_value': colorValue,
      if (iconKey != null) 'icon_key': iconKey,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (archived != null) 'archived': archived,
      if (hlc != null) 'hlc': hlc,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? kind,
    Value<String?>? parentId,
    Value<int>? colorValue,
    Value<String>? iconKey,
    Value<int>? sortOrder,
    Value<bool>? archived,
    Value<String>? hlc,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      parentId: parentId ?? this.parentId,
      colorValue: colorValue ?? this.colorValue,
      iconKey: iconKey ?? this.iconKey,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
      hlc: hlc ?? this.hlc,
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
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
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
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('parentId: $parentId, ')
          ..write('colorValue: $colorValue, ')
          ..write('iconKey: $iconKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived, ')
          ..write('hlc: $hlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

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
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toAccountIdMeta = const VerificationMeta(
    'toAccountId',
  );
  @override
  late final GeneratedColumn<String> toAccountId = GeneratedColumn<String>(
    'to_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _merchantMeta = const VerificationMeta(
    'merchant',
  );
  @override
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
    'merchant',
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
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _sourceRefMeta = const VerificationMeta(
    'sourceRef',
  );
  @override
  late final GeneratedColumn<String> sourceRef = GeneratedColumn<String>(
    'source_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
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
    amountMinor,
    accountId,
    toAccountId,
    categoryId,
    paymentMethod,
    date,
    note,
    merchant,
    source,
    sourceRef,
    hlc,
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
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('to_account_id')) {
      context.handle(
        _toAccountIdMeta,
        toAccountId.isAcceptableOrUnknown(
          data['to_account_id']!,
          _toAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('merchant')) {
      context.handle(
        _merchantMeta,
        merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('source_ref')) {
      context.handle(
        _sourceRefMeta,
        sourceRef.isAcceptableOrUnknown(data['source_ref']!, _sourceRefMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
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
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      toAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_account_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      merchant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sourceRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_ref'],
      ),
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
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
  final int amountMinor;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? paymentMethod;
  final String date;
  final String note;
  final String? merchant;
  final String source;
  final String? sourceRef;
  final String hlc;
  final String? deletedAt;
  const Transaction({
    required this.id,
    required this.type,
    required this.amountMinor,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.paymentMethod,
    required this.date,
    required this.note,
    this.merchant,
    required this.source,
    this.sourceRef,
    required this.hlc,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || toAccountId != null) {
      map['to_account_id'] = Variable<String>(toAccountId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || paymentMethod != null) {
      map['payment_method'] = Variable<String>(paymentMethod);
    }
    map['date'] = Variable<String>(date);
    map['note'] = Variable<String>(note);
    if (!nullToAbsent || merchant != null) {
      map['merchant'] = Variable<String>(merchant);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || sourceRef != null) {
      map['source_ref'] = Variable<String>(sourceRef);
    }
    map['hlc'] = Variable<String>(hlc);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      type: Value(type),
      amountMinor: Value(amountMinor),
      accountId: Value(accountId),
      toAccountId: toAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(toAccountId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      paymentMethod: paymentMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentMethod),
      date: Value(date),
      note: Value(note),
      merchant: merchant == null && nullToAbsent
          ? const Value.absent()
          : Value(merchant),
      source: Value(source),
      sourceRef: sourceRef == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRef),
      hlc: Value(hlc),
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
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      accountId: serializer.fromJson<String>(json['accountId']),
      toAccountId: serializer.fromJson<String?>(json['toAccountId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      paymentMethod: serializer.fromJson<String?>(json['paymentMethod']),
      date: serializer.fromJson<String>(json['date']),
      note: serializer.fromJson<String>(json['note']),
      merchant: serializer.fromJson<String?>(json['merchant']),
      source: serializer.fromJson<String>(json['source']),
      sourceRef: serializer.fromJson<String?>(json['sourceRef']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'accountId': serializer.toJson<String>(accountId),
      'toAccountId': serializer.toJson<String?>(toAccountId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'paymentMethod': serializer.toJson<String?>(paymentMethod),
      'date': serializer.toJson<String>(date),
      'note': serializer.toJson<String>(note),
      'merchant': serializer.toJson<String?>(merchant),
      'source': serializer.toJson<String>(source),
      'sourceRef': serializer.toJson<String?>(sourceRef),
      'hlc': serializer.toJson<String>(hlc),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Transaction copyWith({
    String? id,
    String? type,
    int? amountMinor,
    String? accountId,
    Value<String?> toAccountId = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<String?> paymentMethod = const Value.absent(),
    String? date,
    String? note,
    Value<String?> merchant = const Value.absent(),
    String? source,
    Value<String?> sourceRef = const Value.absent(),
    String? hlc,
    Value<String?> deletedAt = const Value.absent(),
  }) => Transaction(
    id: id ?? this.id,
    type: type ?? this.type,
    amountMinor: amountMinor ?? this.amountMinor,
    accountId: accountId ?? this.accountId,
    toAccountId: toAccountId.present ? toAccountId.value : this.toAccountId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    paymentMethod: paymentMethod.present
        ? paymentMethod.value
        : this.paymentMethod,
    date: date ?? this.date,
    note: note ?? this.note,
    merchant: merchant.present ? merchant.value : this.merchant,
    source: source ?? this.source,
    sourceRef: sourceRef.present ? sourceRef.value : this.sourceRef,
    hlc: hlc ?? this.hlc,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      toAccountId: data.toAccountId.present
          ? data.toAccountId.value
          : this.toAccountId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      date: data.date.present ? data.date.value : this.date,
      note: data.note.present ? data.note.value : this.note,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      source: data.source.present ? data.source.value : this.source,
      sourceRef: data.sourceRef.present ? data.sourceRef.value : this.sourceRef,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('merchant: $merchant, ')
          ..write('source: $source, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('hlc: $hlc, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    amountMinor,
    accountId,
    toAccountId,
    categoryId,
    paymentMethod,
    date,
    note,
    merchant,
    source,
    sourceRef,
    hlc,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.type == this.type &&
          other.amountMinor == this.amountMinor &&
          other.accountId == this.accountId &&
          other.toAccountId == this.toAccountId &&
          other.categoryId == this.categoryId &&
          other.paymentMethod == this.paymentMethod &&
          other.date == this.date &&
          other.note == this.note &&
          other.merchant == this.merchant &&
          other.source == this.source &&
          other.sourceRef == this.sourceRef &&
          other.hlc == this.hlc &&
          other.deletedAt == this.deletedAt);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<String> id;
  final Value<String> type;
  final Value<int> amountMinor;
  final Value<String> accountId;
  final Value<String?> toAccountId;
  final Value<String?> categoryId;
  final Value<String?> paymentMethod;
  final Value<String> date;
  final Value<String> note;
  final Value<String?> merchant;
  final Value<String> source;
  final Value<String?> sourceRef;
  final Value<String> hlc;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.date = const Value.absent(),
    this.note = const Value.absent(),
    this.merchant = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceRef = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    required String type,
    required int amountMinor,
    required String accountId,
    this.toAccountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    required String date,
    this.note = const Value.absent(),
    this.merchant = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceRef = const Value.absent(),
    required String hlc,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       amountMinor = Value(amountMinor),
       accountId = Value(accountId),
       date = Value(date),
       hlc = Value(hlc);
  static Insertable<Transaction> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<int>? amountMinor,
    Expression<String>? accountId,
    Expression<String>? toAccountId,
    Expression<String>? categoryId,
    Expression<String>? paymentMethod,
    Expression<String>? date,
    Expression<String>? note,
    Expression<String>? merchant,
    Expression<String>? source,
    Expression<String>? sourceRef,
    Expression<String>? hlc,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (accountId != null) 'account_id': accountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (categoryId != null) 'category_id': categoryId,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (date != null) 'date': date,
      if (note != null) 'note': note,
      if (merchant != null) 'merchant': merchant,
      if (source != null) 'source': source,
      if (sourceRef != null) 'source_ref': sourceRef,
      if (hlc != null) 'hlc': hlc,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<int>? amountMinor,
    Value<String>? accountId,
    Value<String?>? toAccountId,
    Value<String?>? categoryId,
    Value<String?>? paymentMethod,
    Value<String>? date,
    Value<String>? note,
    Value<String?>? merchant,
    Value<String>? source,
    Value<String?>? sourceRef,
    Value<String>? hlc,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      amountMinor: amountMinor ?? this.amountMinor,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      categoryId: categoryId ?? this.categoryId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
      note: note ?? this.note,
      merchant: merchant ?? this.merchant,
      source: source ?? this.source,
      sourceRef: sourceRef ?? this.sourceRef,
      hlc: hlc ?? this.hlc,
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
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (toAccountId.present) {
      map['to_account_id'] = Variable<String>(toAccountId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceRef.present) {
      map['source_ref'] = Variable<String>(sourceRef.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
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
          ..write('amountMinor: $amountMinor, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('merchant: $merchant, ')
          ..write('source: $source, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('hlc: $hlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DebtsTable extends Debts with TableInfo<$DebtsTable, Debt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DebtsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _counterpartyMeta = const VerificationMeta(
    'counterparty',
  );
  @override
  late final GeneratedColumn<String> counterparty = GeneratedColumn<String>(
    'counterparty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _principalMinorMeta = const VerificationMeta(
    'principalMinor',
  );
  @override
  late final GeneratedColumn<int> principalMinor = GeneratedColumn<int>(
    'principal_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _issuedOnMeta = const VerificationMeta(
    'issuedOn',
  );
  @override
  late final GeneratedColumn<String> issuedOn = GeneratedColumn<String>(
    'issued_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueOnMeta = const VerificationMeta('dueOn');
  @override
  late final GeneratedColumn<String> dueOn = GeneratedColumn<String>(
    'due_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _interestEnabledMeta = const VerificationMeta(
    'interestEnabled',
  );
  @override
  late final GeneratedColumn<bool> interestEnabled = GeneratedColumn<bool>(
    'interest_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("interest_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _interestTypeMeta = const VerificationMeta(
    'interestType',
  );
  @override
  late final GeneratedColumn<String> interestType = GeneratedColumn<String>(
    'interest_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('simple'),
  );
  static const VerificationMeta _rateBpsMeta = const VerificationMeta(
    'rateBps',
  );
  @override
  late final GeneratedColumn<int> rateBps = GeneratedColumn<int>(
    'rate_bps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ratePeriodMeta = const VerificationMeta(
    'ratePeriod',
  );
  @override
  late final GeneratedColumn<String> ratePeriod = GeneratedColumn<String>(
    'rate_period',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('monthly'),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
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
    direction,
    counterparty,
    principalMinor,
    issuedOn,
    dueOn,
    interestEnabled,
    interestType,
    rateBps,
    ratePeriod,
    accountId,
    note,
    hlc,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'debts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Debt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('counterparty')) {
      context.handle(
        _counterpartyMeta,
        counterparty.isAcceptableOrUnknown(
          data['counterparty']!,
          _counterpartyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_counterpartyMeta);
    }
    if (data.containsKey('principal_minor')) {
      context.handle(
        _principalMinorMeta,
        principalMinor.isAcceptableOrUnknown(
          data['principal_minor']!,
          _principalMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_principalMinorMeta);
    }
    if (data.containsKey('issued_on')) {
      context.handle(
        _issuedOnMeta,
        issuedOn.isAcceptableOrUnknown(data['issued_on']!, _issuedOnMeta),
      );
    } else if (isInserting) {
      context.missing(_issuedOnMeta);
    }
    if (data.containsKey('due_on')) {
      context.handle(
        _dueOnMeta,
        dueOn.isAcceptableOrUnknown(data['due_on']!, _dueOnMeta),
      );
    }
    if (data.containsKey('interest_enabled')) {
      context.handle(
        _interestEnabledMeta,
        interestEnabled.isAcceptableOrUnknown(
          data['interest_enabled']!,
          _interestEnabledMeta,
        ),
      );
    }
    if (data.containsKey('interest_type')) {
      context.handle(
        _interestTypeMeta,
        interestType.isAcceptableOrUnknown(
          data['interest_type']!,
          _interestTypeMeta,
        ),
      );
    }
    if (data.containsKey('rate_bps')) {
      context.handle(
        _rateBpsMeta,
        rateBps.isAcceptableOrUnknown(data['rate_bps']!, _rateBpsMeta),
      );
    }
    if (data.containsKey('rate_period')) {
      context.handle(
        _ratePeriodMeta,
        ratePeriod.isAcceptableOrUnknown(data['rate_period']!, _ratePeriodMeta),
      );
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
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
  Debt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Debt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      counterparty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counterparty'],
      )!,
      principalMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}principal_minor'],
      )!,
      issuedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issued_on'],
      )!,
      dueOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_on'],
      ),
      interestEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}interest_enabled'],
      )!,
      interestType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}interest_type'],
      )!,
      rateBps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_bps'],
      )!,
      ratePeriod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rate_period'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $DebtsTable createAlias(String alias) {
    return $DebtsTable(attachedDatabase, alias);
  }
}

class Debt extends DataClass implements Insertable<Debt> {
  final String id;
  final String direction;
  final String counterparty;
  final int principalMinor;
  final String issuedOn;
  final String? dueOn;
  final bool interestEnabled;
  final String interestType;
  final int rateBps;
  final String ratePeriod;
  final String accountId;
  final String note;
  final String hlc;
  final String? deletedAt;
  const Debt({
    required this.id,
    required this.direction,
    required this.counterparty,
    required this.principalMinor,
    required this.issuedOn,
    this.dueOn,
    required this.interestEnabled,
    required this.interestType,
    required this.rateBps,
    required this.ratePeriod,
    required this.accountId,
    required this.note,
    required this.hlc,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['direction'] = Variable<String>(direction);
    map['counterparty'] = Variable<String>(counterparty);
    map['principal_minor'] = Variable<int>(principalMinor);
    map['issued_on'] = Variable<String>(issuedOn);
    if (!nullToAbsent || dueOn != null) {
      map['due_on'] = Variable<String>(dueOn);
    }
    map['interest_enabled'] = Variable<bool>(interestEnabled);
    map['interest_type'] = Variable<String>(interestType);
    map['rate_bps'] = Variable<int>(rateBps);
    map['rate_period'] = Variable<String>(ratePeriod);
    map['account_id'] = Variable<String>(accountId);
    map['note'] = Variable<String>(note);
    map['hlc'] = Variable<String>(hlc);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  DebtsCompanion toCompanion(bool nullToAbsent) {
    return DebtsCompanion(
      id: Value(id),
      direction: Value(direction),
      counterparty: Value(counterparty),
      principalMinor: Value(principalMinor),
      issuedOn: Value(issuedOn),
      dueOn: dueOn == null && nullToAbsent
          ? const Value.absent()
          : Value(dueOn),
      interestEnabled: Value(interestEnabled),
      interestType: Value(interestType),
      rateBps: Value(rateBps),
      ratePeriod: Value(ratePeriod),
      accountId: Value(accountId),
      note: Value(note),
      hlc: Value(hlc),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Debt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Debt(
      id: serializer.fromJson<String>(json['id']),
      direction: serializer.fromJson<String>(json['direction']),
      counterparty: serializer.fromJson<String>(json['counterparty']),
      principalMinor: serializer.fromJson<int>(json['principalMinor']),
      issuedOn: serializer.fromJson<String>(json['issuedOn']),
      dueOn: serializer.fromJson<String?>(json['dueOn']),
      interestEnabled: serializer.fromJson<bool>(json['interestEnabled']),
      interestType: serializer.fromJson<String>(json['interestType']),
      rateBps: serializer.fromJson<int>(json['rateBps']),
      ratePeriod: serializer.fromJson<String>(json['ratePeriod']),
      accountId: serializer.fromJson<String>(json['accountId']),
      note: serializer.fromJson<String>(json['note']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'direction': serializer.toJson<String>(direction),
      'counterparty': serializer.toJson<String>(counterparty),
      'principalMinor': serializer.toJson<int>(principalMinor),
      'issuedOn': serializer.toJson<String>(issuedOn),
      'dueOn': serializer.toJson<String?>(dueOn),
      'interestEnabled': serializer.toJson<bool>(interestEnabled),
      'interestType': serializer.toJson<String>(interestType),
      'rateBps': serializer.toJson<int>(rateBps),
      'ratePeriod': serializer.toJson<String>(ratePeriod),
      'accountId': serializer.toJson<String>(accountId),
      'note': serializer.toJson<String>(note),
      'hlc': serializer.toJson<String>(hlc),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Debt copyWith({
    String? id,
    String? direction,
    String? counterparty,
    int? principalMinor,
    String? issuedOn,
    Value<String?> dueOn = const Value.absent(),
    bool? interestEnabled,
    String? interestType,
    int? rateBps,
    String? ratePeriod,
    String? accountId,
    String? note,
    String? hlc,
    Value<String?> deletedAt = const Value.absent(),
  }) => Debt(
    id: id ?? this.id,
    direction: direction ?? this.direction,
    counterparty: counterparty ?? this.counterparty,
    principalMinor: principalMinor ?? this.principalMinor,
    issuedOn: issuedOn ?? this.issuedOn,
    dueOn: dueOn.present ? dueOn.value : this.dueOn,
    interestEnabled: interestEnabled ?? this.interestEnabled,
    interestType: interestType ?? this.interestType,
    rateBps: rateBps ?? this.rateBps,
    ratePeriod: ratePeriod ?? this.ratePeriod,
    accountId: accountId ?? this.accountId,
    note: note ?? this.note,
    hlc: hlc ?? this.hlc,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Debt copyWithCompanion(DebtsCompanion data) {
    return Debt(
      id: data.id.present ? data.id.value : this.id,
      direction: data.direction.present ? data.direction.value : this.direction,
      counterparty: data.counterparty.present
          ? data.counterparty.value
          : this.counterparty,
      principalMinor: data.principalMinor.present
          ? data.principalMinor.value
          : this.principalMinor,
      issuedOn: data.issuedOn.present ? data.issuedOn.value : this.issuedOn,
      dueOn: data.dueOn.present ? data.dueOn.value : this.dueOn,
      interestEnabled: data.interestEnabled.present
          ? data.interestEnabled.value
          : this.interestEnabled,
      interestType: data.interestType.present
          ? data.interestType.value
          : this.interestType,
      rateBps: data.rateBps.present ? data.rateBps.value : this.rateBps,
      ratePeriod: data.ratePeriod.present
          ? data.ratePeriod.value
          : this.ratePeriod,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      note: data.note.present ? data.note.value : this.note,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Debt(')
          ..write('id: $id, ')
          ..write('direction: $direction, ')
          ..write('counterparty: $counterparty, ')
          ..write('principalMinor: $principalMinor, ')
          ..write('issuedOn: $issuedOn, ')
          ..write('dueOn: $dueOn, ')
          ..write('interestEnabled: $interestEnabled, ')
          ..write('interestType: $interestType, ')
          ..write('rateBps: $rateBps, ')
          ..write('ratePeriod: $ratePeriod, ')
          ..write('accountId: $accountId, ')
          ..write('note: $note, ')
          ..write('hlc: $hlc, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    direction,
    counterparty,
    principalMinor,
    issuedOn,
    dueOn,
    interestEnabled,
    interestType,
    rateBps,
    ratePeriod,
    accountId,
    note,
    hlc,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Debt &&
          other.id == this.id &&
          other.direction == this.direction &&
          other.counterparty == this.counterparty &&
          other.principalMinor == this.principalMinor &&
          other.issuedOn == this.issuedOn &&
          other.dueOn == this.dueOn &&
          other.interestEnabled == this.interestEnabled &&
          other.interestType == this.interestType &&
          other.rateBps == this.rateBps &&
          other.ratePeriod == this.ratePeriod &&
          other.accountId == this.accountId &&
          other.note == this.note &&
          other.hlc == this.hlc &&
          other.deletedAt == this.deletedAt);
}

class DebtsCompanion extends UpdateCompanion<Debt> {
  final Value<String> id;
  final Value<String> direction;
  final Value<String> counterparty;
  final Value<int> principalMinor;
  final Value<String> issuedOn;
  final Value<String?> dueOn;
  final Value<bool> interestEnabled;
  final Value<String> interestType;
  final Value<int> rateBps;
  final Value<String> ratePeriod;
  final Value<String> accountId;
  final Value<String> note;
  final Value<String> hlc;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const DebtsCompanion({
    this.id = const Value.absent(),
    this.direction = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.principalMinor = const Value.absent(),
    this.issuedOn = const Value.absent(),
    this.dueOn = const Value.absent(),
    this.interestEnabled = const Value.absent(),
    this.interestType = const Value.absent(),
    this.rateBps = const Value.absent(),
    this.ratePeriod = const Value.absent(),
    this.accountId = const Value.absent(),
    this.note = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DebtsCompanion.insert({
    required String id,
    required String direction,
    required String counterparty,
    required int principalMinor,
    required String issuedOn,
    this.dueOn = const Value.absent(),
    this.interestEnabled = const Value.absent(),
    this.interestType = const Value.absent(),
    this.rateBps = const Value.absent(),
    this.ratePeriod = const Value.absent(),
    required String accountId,
    this.note = const Value.absent(),
    required String hlc,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       direction = Value(direction),
       counterparty = Value(counterparty),
       principalMinor = Value(principalMinor),
       issuedOn = Value(issuedOn),
       accountId = Value(accountId),
       hlc = Value(hlc);
  static Insertable<Debt> custom({
    Expression<String>? id,
    Expression<String>? direction,
    Expression<String>? counterparty,
    Expression<int>? principalMinor,
    Expression<String>? issuedOn,
    Expression<String>? dueOn,
    Expression<bool>? interestEnabled,
    Expression<String>? interestType,
    Expression<int>? rateBps,
    Expression<String>? ratePeriod,
    Expression<String>? accountId,
    Expression<String>? note,
    Expression<String>? hlc,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (direction != null) 'direction': direction,
      if (counterparty != null) 'counterparty': counterparty,
      if (principalMinor != null) 'principal_minor': principalMinor,
      if (issuedOn != null) 'issued_on': issuedOn,
      if (dueOn != null) 'due_on': dueOn,
      if (interestEnabled != null) 'interest_enabled': interestEnabled,
      if (interestType != null) 'interest_type': interestType,
      if (rateBps != null) 'rate_bps': rateBps,
      if (ratePeriod != null) 'rate_period': ratePeriod,
      if (accountId != null) 'account_id': accountId,
      if (note != null) 'note': note,
      if (hlc != null) 'hlc': hlc,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DebtsCompanion copyWith({
    Value<String>? id,
    Value<String>? direction,
    Value<String>? counterparty,
    Value<int>? principalMinor,
    Value<String>? issuedOn,
    Value<String?>? dueOn,
    Value<bool>? interestEnabled,
    Value<String>? interestType,
    Value<int>? rateBps,
    Value<String>? ratePeriod,
    Value<String>? accountId,
    Value<String>? note,
    Value<String>? hlc,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return DebtsCompanion(
      id: id ?? this.id,
      direction: direction ?? this.direction,
      counterparty: counterparty ?? this.counterparty,
      principalMinor: principalMinor ?? this.principalMinor,
      issuedOn: issuedOn ?? this.issuedOn,
      dueOn: dueOn ?? this.dueOn,
      interestEnabled: interestEnabled ?? this.interestEnabled,
      interestType: interestType ?? this.interestType,
      rateBps: rateBps ?? this.rateBps,
      ratePeriod: ratePeriod ?? this.ratePeriod,
      accountId: accountId ?? this.accountId,
      note: note ?? this.note,
      hlc: hlc ?? this.hlc,
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
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (counterparty.present) {
      map['counterparty'] = Variable<String>(counterparty.value);
    }
    if (principalMinor.present) {
      map['principal_minor'] = Variable<int>(principalMinor.value);
    }
    if (issuedOn.present) {
      map['issued_on'] = Variable<String>(issuedOn.value);
    }
    if (dueOn.present) {
      map['due_on'] = Variable<String>(dueOn.value);
    }
    if (interestEnabled.present) {
      map['interest_enabled'] = Variable<bool>(interestEnabled.value);
    }
    if (interestType.present) {
      map['interest_type'] = Variable<String>(interestType.value);
    }
    if (rateBps.present) {
      map['rate_bps'] = Variable<int>(rateBps.value);
    }
    if (ratePeriod.present) {
      map['rate_period'] = Variable<String>(ratePeriod.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
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
    return (StringBuffer('DebtsCompanion(')
          ..write('id: $id, ')
          ..write('direction: $direction, ')
          ..write('counterparty: $counterparty, ')
          ..write('principalMinor: $principalMinor, ')
          ..write('issuedOn: $issuedOn, ')
          ..write('dueOn: $dueOn, ')
          ..write('interestEnabled: $interestEnabled, ')
          ..write('interestType: $interestType, ')
          ..write('rateBps: $rateBps, ')
          ..write('ratePeriod: $ratePeriod, ')
          ..write('accountId: $accountId, ')
          ..write('note: $note, ')
          ..write('hlc: $hlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DebtEventsTable extends DebtEvents
    with TableInfo<$DebtEventsTable, DebtEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DebtEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _debtIdMeta = const VerificationMeta('debtId');
  @override
  late final GeneratedColumn<String> debtId = GeneratedColumn<String>(
    'debt_id',
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
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _principalPartMeta = const VerificationMeta(
    'principalPart',
  );
  @override
  late final GeneratedColumn<int> principalPart = GeneratedColumn<int>(
    'principal_part',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _interestPartMeta = const VerificationMeta(
    'interestPart',
  );
  @override
  late final GeneratedColumn<int> interestPart = GeneratedColumn<int>(
    'interest_part',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _periodKeyMeta = const VerificationMeta(
    'periodKey',
  );
  @override
  late final GeneratedColumn<int> periodKey = GeneratedColumn<int>(
    'period_key',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
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
    debtId,
    type,
    amountMinor,
    date,
    principalPart,
    interestPart,
    periodKey,
    note,
    hlc,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'debt_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<DebtEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('debt_id')) {
      context.handle(
        _debtIdMeta,
        debtId.isAcceptableOrUnknown(data['debt_id']!, _debtIdMeta),
      );
    } else if (isInserting) {
      context.missing(_debtIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('principal_part')) {
      context.handle(
        _principalPartMeta,
        principalPart.isAcceptableOrUnknown(
          data['principal_part']!,
          _principalPartMeta,
        ),
      );
    }
    if (data.containsKey('interest_part')) {
      context.handle(
        _interestPartMeta,
        interestPart.isAcceptableOrUnknown(
          data['interest_part']!,
          _interestPartMeta,
        ),
      );
    }
    if (data.containsKey('period_key')) {
      context.handle(
        _periodKeyMeta,
        periodKey.isAcceptableOrUnknown(data['period_key']!, _periodKeyMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
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
  DebtEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DebtEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      debtId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}debt_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      principalPart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}principal_part'],
      )!,
      interestPart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interest_part'],
      )!,
      periodKey: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}period_key'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $DebtEventsTable createAlias(String alias) {
    return $DebtEventsTable(attachedDatabase, alias);
  }
}

class DebtEvent extends DataClass implements Insertable<DebtEvent> {
  final String id;
  final String debtId;
  final String type;
  final int amountMinor;
  final String date;
  final int principalPart;
  final int interestPart;
  final int? periodKey;
  final String note;
  final String hlc;
  final String? deletedAt;
  const DebtEvent({
    required this.id,
    required this.debtId,
    required this.type,
    required this.amountMinor,
    required this.date,
    required this.principalPart,
    required this.interestPart,
    this.periodKey,
    required this.note,
    required this.hlc,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['debt_id'] = Variable<String>(debtId);
    map['type'] = Variable<String>(type);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['date'] = Variable<String>(date);
    map['principal_part'] = Variable<int>(principalPart);
    map['interest_part'] = Variable<int>(interestPart);
    if (!nullToAbsent || periodKey != null) {
      map['period_key'] = Variable<int>(periodKey);
    }
    map['note'] = Variable<String>(note);
    map['hlc'] = Variable<String>(hlc);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  DebtEventsCompanion toCompanion(bool nullToAbsent) {
    return DebtEventsCompanion(
      id: Value(id),
      debtId: Value(debtId),
      type: Value(type),
      amountMinor: Value(amountMinor),
      date: Value(date),
      principalPart: Value(principalPart),
      interestPart: Value(interestPart),
      periodKey: periodKey == null && nullToAbsent
          ? const Value.absent()
          : Value(periodKey),
      note: Value(note),
      hlc: Value(hlc),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory DebtEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DebtEvent(
      id: serializer.fromJson<String>(json['id']),
      debtId: serializer.fromJson<String>(json['debtId']),
      type: serializer.fromJson<String>(json['type']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      date: serializer.fromJson<String>(json['date']),
      principalPart: serializer.fromJson<int>(json['principalPart']),
      interestPart: serializer.fromJson<int>(json['interestPart']),
      periodKey: serializer.fromJson<int?>(json['periodKey']),
      note: serializer.fromJson<String>(json['note']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'debtId': serializer.toJson<String>(debtId),
      'type': serializer.toJson<String>(type),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'date': serializer.toJson<String>(date),
      'principalPart': serializer.toJson<int>(principalPart),
      'interestPart': serializer.toJson<int>(interestPart),
      'periodKey': serializer.toJson<int?>(periodKey),
      'note': serializer.toJson<String>(note),
      'hlc': serializer.toJson<String>(hlc),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  DebtEvent copyWith({
    String? id,
    String? debtId,
    String? type,
    int? amountMinor,
    String? date,
    int? principalPart,
    int? interestPart,
    Value<int?> periodKey = const Value.absent(),
    String? note,
    String? hlc,
    Value<String?> deletedAt = const Value.absent(),
  }) => DebtEvent(
    id: id ?? this.id,
    debtId: debtId ?? this.debtId,
    type: type ?? this.type,
    amountMinor: amountMinor ?? this.amountMinor,
    date: date ?? this.date,
    principalPart: principalPart ?? this.principalPart,
    interestPart: interestPart ?? this.interestPart,
    periodKey: periodKey.present ? periodKey.value : this.periodKey,
    note: note ?? this.note,
    hlc: hlc ?? this.hlc,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  DebtEvent copyWithCompanion(DebtEventsCompanion data) {
    return DebtEvent(
      id: data.id.present ? data.id.value : this.id,
      debtId: data.debtId.present ? data.debtId.value : this.debtId,
      type: data.type.present ? data.type.value : this.type,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      date: data.date.present ? data.date.value : this.date,
      principalPart: data.principalPart.present
          ? data.principalPart.value
          : this.principalPart,
      interestPart: data.interestPart.present
          ? data.interestPart.value
          : this.interestPart,
      periodKey: data.periodKey.present ? data.periodKey.value : this.periodKey,
      note: data.note.present ? data.note.value : this.note,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DebtEvent(')
          ..write('id: $id, ')
          ..write('debtId: $debtId, ')
          ..write('type: $type, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('date: $date, ')
          ..write('principalPart: $principalPart, ')
          ..write('interestPart: $interestPart, ')
          ..write('periodKey: $periodKey, ')
          ..write('note: $note, ')
          ..write('hlc: $hlc, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    debtId,
    type,
    amountMinor,
    date,
    principalPart,
    interestPart,
    periodKey,
    note,
    hlc,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DebtEvent &&
          other.id == this.id &&
          other.debtId == this.debtId &&
          other.type == this.type &&
          other.amountMinor == this.amountMinor &&
          other.date == this.date &&
          other.principalPart == this.principalPart &&
          other.interestPart == this.interestPart &&
          other.periodKey == this.periodKey &&
          other.note == this.note &&
          other.hlc == this.hlc &&
          other.deletedAt == this.deletedAt);
}

class DebtEventsCompanion extends UpdateCompanion<DebtEvent> {
  final Value<String> id;
  final Value<String> debtId;
  final Value<String> type;
  final Value<int> amountMinor;
  final Value<String> date;
  final Value<int> principalPart;
  final Value<int> interestPart;
  final Value<int?> periodKey;
  final Value<String> note;
  final Value<String> hlc;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const DebtEventsCompanion({
    this.id = const Value.absent(),
    this.debtId = const Value.absent(),
    this.type = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.date = const Value.absent(),
    this.principalPart = const Value.absent(),
    this.interestPart = const Value.absent(),
    this.periodKey = const Value.absent(),
    this.note = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DebtEventsCompanion.insert({
    required String id,
    required String debtId,
    required String type,
    required int amountMinor,
    required String date,
    this.principalPart = const Value.absent(),
    this.interestPart = const Value.absent(),
    this.periodKey = const Value.absent(),
    this.note = const Value.absent(),
    required String hlc,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       debtId = Value(debtId),
       type = Value(type),
       amountMinor = Value(amountMinor),
       date = Value(date),
       hlc = Value(hlc);
  static Insertable<DebtEvent> custom({
    Expression<String>? id,
    Expression<String>? debtId,
    Expression<String>? type,
    Expression<int>? amountMinor,
    Expression<String>? date,
    Expression<int>? principalPart,
    Expression<int>? interestPart,
    Expression<int>? periodKey,
    Expression<String>? note,
    Expression<String>? hlc,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (debtId != null) 'debt_id': debtId,
      if (type != null) 'type': type,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (date != null) 'date': date,
      if (principalPart != null) 'principal_part': principalPart,
      if (interestPart != null) 'interest_part': interestPart,
      if (periodKey != null) 'period_key': periodKey,
      if (note != null) 'note': note,
      if (hlc != null) 'hlc': hlc,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DebtEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? debtId,
    Value<String>? type,
    Value<int>? amountMinor,
    Value<String>? date,
    Value<int>? principalPart,
    Value<int>? interestPart,
    Value<int?>? periodKey,
    Value<String>? note,
    Value<String>? hlc,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return DebtEventsCompanion(
      id: id ?? this.id,
      debtId: debtId ?? this.debtId,
      type: type ?? this.type,
      amountMinor: amountMinor ?? this.amountMinor,
      date: date ?? this.date,
      principalPart: principalPart ?? this.principalPart,
      interestPart: interestPart ?? this.interestPart,
      periodKey: periodKey ?? this.periodKey,
      note: note ?? this.note,
      hlc: hlc ?? this.hlc,
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
    if (debtId.present) {
      map['debt_id'] = Variable<String>(debtId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (principalPart.present) {
      map['principal_part'] = Variable<int>(principalPart.value);
    }
    if (interestPart.present) {
      map['interest_part'] = Variable<int>(interestPart.value);
    }
    if (periodKey.present) {
      map['period_key'] = Variable<int>(periodKey.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
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
    return (StringBuffer('DebtEventsCompanion(')
          ..write('id: $id, ')
          ..write('debtId: $debtId, ')
          ..write('type: $type, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('date: $date, ')
          ..write('principalPart: $principalPart, ')
          ..write('interestPart: $interestPart, ')
          ..write('periodKey: $periodKey, ')
          ..write('note: $note, ')
          ..write('hlc: $hlc, ')
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
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
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
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expectedGrowthBpsMeta = const VerificationMeta(
    'expectedGrowthBps',
  );
  @override
  late final GeneratedColumn<int> expectedGrowthBps = GeneratedColumn<int>(
    'expected_growth_bps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentValueMinorMeta = const VerificationMeta(
    'currentValueMinor',
  );
  @override
  late final GeneratedColumn<int> currentValueMinor = GeneratedColumn<int>(
    'current_value_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueUpdatedOnMeta = const VerificationMeta(
    'valueUpdatedOn',
  );
  @override
  late final GeneratedColumn<String> valueUpdatedOn = GeneratedColumn<String>(
    'value_updated_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitsMeta = const VerificationMeta('units');
  @override
  late final GeneratedColumn<double> units = GeneratedColumn<double>(
    'units',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _buyPriceMinorMeta = const VerificationMeta(
    'buyPriceMinor',
  );
  @override
  late final GeneratedColumn<int> buyPriceMinor = GeneratedColumn<int>(
    'buy_price_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sipMinorMeta = const VerificationMeta(
    'sipMinor',
  );
  @override
  late final GeneratedColumn<int> sipMinor = GeneratedColumn<int>(
    'sip_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chitValueMinorMeta = const VerificationMeta(
    'chitValueMinor',
  );
  @override
  late final GeneratedColumn<int> chitValueMinor = GeneratedColumn<int>(
    'chit_value_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tenureMonthsMeta = const VerificationMeta(
    'tenureMonths',
  );
  @override
  late final GeneratedColumn<int> tenureMonths = GeneratedColumn<int>(
    'tenure_months',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _membersMeta = const VerificationMeta(
    'members',
  );
  @override
  late final GeneratedColumn<int> members = GeneratedColumn<int>(
    'members',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monthlyMinorMeta = const VerificationMeta(
    'monthlyMinor',
  );
  @override
  late final GeneratedColumn<int> monthlyMinor = GeneratedColumn<int>(
    'monthly_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commissionBpsMeta = const VerificationMeta(
    'commissionBps',
  );
  @override
  late final GeneratedColumn<int> commissionBps = GeneratedColumn<int>(
    'commission_bps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _organiserMeta = const VerificationMeta(
    'organiser',
  );
  @override
  late final GeneratedColumn<String> organiser = GeneratedColumn<String>(
    'organiser',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
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
    kind,
    name,
    accountId,
    startDate,
    expectedGrowthBps,
    currentValueMinor,
    valueUpdatedOn,
    units,
    buyPriceMinor,
    sipMinor,
    chitValueMinor,
    tenureMonths,
    members,
    monthlyMinor,
    commissionBps,
    organiser,
    note,
    hlc,
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
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('expected_growth_bps')) {
      context.handle(
        _expectedGrowthBpsMeta,
        expectedGrowthBps.isAcceptableOrUnknown(
          data['expected_growth_bps']!,
          _expectedGrowthBpsMeta,
        ),
      );
    }
    if (data.containsKey('current_value_minor')) {
      context.handle(
        _currentValueMinorMeta,
        currentValueMinor.isAcceptableOrUnknown(
          data['current_value_minor']!,
          _currentValueMinorMeta,
        ),
      );
    }
    if (data.containsKey('value_updated_on')) {
      context.handle(
        _valueUpdatedOnMeta,
        valueUpdatedOn.isAcceptableOrUnknown(
          data['value_updated_on']!,
          _valueUpdatedOnMeta,
        ),
      );
    }
    if (data.containsKey('units')) {
      context.handle(
        _unitsMeta,
        units.isAcceptableOrUnknown(data['units']!, _unitsMeta),
      );
    }
    if (data.containsKey('buy_price_minor')) {
      context.handle(
        _buyPriceMinorMeta,
        buyPriceMinor.isAcceptableOrUnknown(
          data['buy_price_minor']!,
          _buyPriceMinorMeta,
        ),
      );
    }
    if (data.containsKey('sip_minor')) {
      context.handle(
        _sipMinorMeta,
        sipMinor.isAcceptableOrUnknown(data['sip_minor']!, _sipMinorMeta),
      );
    }
    if (data.containsKey('chit_value_minor')) {
      context.handle(
        _chitValueMinorMeta,
        chitValueMinor.isAcceptableOrUnknown(
          data['chit_value_minor']!,
          _chitValueMinorMeta,
        ),
      );
    }
    if (data.containsKey('tenure_months')) {
      context.handle(
        _tenureMonthsMeta,
        tenureMonths.isAcceptableOrUnknown(
          data['tenure_months']!,
          _tenureMonthsMeta,
        ),
      );
    }
    if (data.containsKey('members')) {
      context.handle(
        _membersMeta,
        members.isAcceptableOrUnknown(data['members']!, _membersMeta),
      );
    }
    if (data.containsKey('monthly_minor')) {
      context.handle(
        _monthlyMinorMeta,
        monthlyMinor.isAcceptableOrUnknown(
          data['monthly_minor']!,
          _monthlyMinorMeta,
        ),
      );
    }
    if (data.containsKey('commission_bps')) {
      context.handle(
        _commissionBpsMeta,
        commissionBps.isAcceptableOrUnknown(
          data['commission_bps']!,
          _commissionBpsMeta,
        ),
      );
    }
    if (data.containsKey('organiser')) {
      context.handle(
        _organiserMeta,
        organiser.isAcceptableOrUnknown(data['organiser']!, _organiserMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
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
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      ),
      expectedGrowthBps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_growth_bps'],
      ),
      currentValueMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_value_minor'],
      ),
      valueUpdatedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_updated_on'],
      ),
      units: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}units'],
      ),
      buyPriceMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}buy_price_minor'],
      ),
      sipMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sip_minor'],
      ),
      chitValueMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chit_value_minor'],
      ),
      tenureMonths: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tenure_months'],
      ),
      members: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}members'],
      ),
      monthlyMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}monthly_minor'],
      ),
      commissionBps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}commission_bps'],
      ),
      organiser: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organiser'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
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
  final String kind;
  final String name;
  final String? accountId;
  final String? startDate;
  final int? expectedGrowthBps;
  final int? currentValueMinor;
  final String? valueUpdatedOn;
  final double? units;
  final int? buyPriceMinor;
  final int? sipMinor;
  final int? chitValueMinor;
  final int? tenureMonths;
  final int? members;
  final int? monthlyMinor;
  final int? commissionBps;
  final String? organiser;
  final String note;
  final String hlc;
  final String? deletedAt;
  const Investment({
    required this.id,
    required this.kind,
    required this.name,
    this.accountId,
    this.startDate,
    this.expectedGrowthBps,
    this.currentValueMinor,
    this.valueUpdatedOn,
    this.units,
    this.buyPriceMinor,
    this.sipMinor,
    this.chitValueMinor,
    this.tenureMonths,
    this.members,
    this.monthlyMinor,
    this.commissionBps,
    this.organiser,
    required this.note,
    required this.hlc,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<String>(startDate);
    }
    if (!nullToAbsent || expectedGrowthBps != null) {
      map['expected_growth_bps'] = Variable<int>(expectedGrowthBps);
    }
    if (!nullToAbsent || currentValueMinor != null) {
      map['current_value_minor'] = Variable<int>(currentValueMinor);
    }
    if (!nullToAbsent || valueUpdatedOn != null) {
      map['value_updated_on'] = Variable<String>(valueUpdatedOn);
    }
    if (!nullToAbsent || units != null) {
      map['units'] = Variable<double>(units);
    }
    if (!nullToAbsent || buyPriceMinor != null) {
      map['buy_price_minor'] = Variable<int>(buyPriceMinor);
    }
    if (!nullToAbsent || sipMinor != null) {
      map['sip_minor'] = Variable<int>(sipMinor);
    }
    if (!nullToAbsent || chitValueMinor != null) {
      map['chit_value_minor'] = Variable<int>(chitValueMinor);
    }
    if (!nullToAbsent || tenureMonths != null) {
      map['tenure_months'] = Variable<int>(tenureMonths);
    }
    if (!nullToAbsent || members != null) {
      map['members'] = Variable<int>(members);
    }
    if (!nullToAbsent || monthlyMinor != null) {
      map['monthly_minor'] = Variable<int>(monthlyMinor);
    }
    if (!nullToAbsent || commissionBps != null) {
      map['commission_bps'] = Variable<int>(commissionBps);
    }
    if (!nullToAbsent || organiser != null) {
      map['organiser'] = Variable<String>(organiser);
    }
    map['note'] = Variable<String>(note);
    map['hlc'] = Variable<String>(hlc);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  InvestmentsCompanion toCompanion(bool nullToAbsent) {
    return InvestmentsCompanion(
      id: Value(id),
      kind: Value(kind),
      name: Value(name),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      expectedGrowthBps: expectedGrowthBps == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedGrowthBps),
      currentValueMinor: currentValueMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(currentValueMinor),
      valueUpdatedOn: valueUpdatedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(valueUpdatedOn),
      units: units == null && nullToAbsent
          ? const Value.absent()
          : Value(units),
      buyPriceMinor: buyPriceMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(buyPriceMinor),
      sipMinor: sipMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(sipMinor),
      chitValueMinor: chitValueMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(chitValueMinor),
      tenureMonths: tenureMonths == null && nullToAbsent
          ? const Value.absent()
          : Value(tenureMonths),
      members: members == null && nullToAbsent
          ? const Value.absent()
          : Value(members),
      monthlyMinor: monthlyMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(monthlyMinor),
      commissionBps: commissionBps == null && nullToAbsent
          ? const Value.absent()
          : Value(commissionBps),
      organiser: organiser == null && nullToAbsent
          ? const Value.absent()
          : Value(organiser),
      note: Value(note),
      hlc: Value(hlc),
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
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      startDate: serializer.fromJson<String?>(json['startDate']),
      expectedGrowthBps: serializer.fromJson<int?>(json['expectedGrowthBps']),
      currentValueMinor: serializer.fromJson<int?>(json['currentValueMinor']),
      valueUpdatedOn: serializer.fromJson<String?>(json['valueUpdatedOn']),
      units: serializer.fromJson<double?>(json['units']),
      buyPriceMinor: serializer.fromJson<int?>(json['buyPriceMinor']),
      sipMinor: serializer.fromJson<int?>(json['sipMinor']),
      chitValueMinor: serializer.fromJson<int?>(json['chitValueMinor']),
      tenureMonths: serializer.fromJson<int?>(json['tenureMonths']),
      members: serializer.fromJson<int?>(json['members']),
      monthlyMinor: serializer.fromJson<int?>(json['monthlyMinor']),
      commissionBps: serializer.fromJson<int?>(json['commissionBps']),
      organiser: serializer.fromJson<String?>(json['organiser']),
      note: serializer.fromJson<String>(json['note']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'accountId': serializer.toJson<String?>(accountId),
      'startDate': serializer.toJson<String?>(startDate),
      'expectedGrowthBps': serializer.toJson<int?>(expectedGrowthBps),
      'currentValueMinor': serializer.toJson<int?>(currentValueMinor),
      'valueUpdatedOn': serializer.toJson<String?>(valueUpdatedOn),
      'units': serializer.toJson<double?>(units),
      'buyPriceMinor': serializer.toJson<int?>(buyPriceMinor),
      'sipMinor': serializer.toJson<int?>(sipMinor),
      'chitValueMinor': serializer.toJson<int?>(chitValueMinor),
      'tenureMonths': serializer.toJson<int?>(tenureMonths),
      'members': serializer.toJson<int?>(members),
      'monthlyMinor': serializer.toJson<int?>(monthlyMinor),
      'commissionBps': serializer.toJson<int?>(commissionBps),
      'organiser': serializer.toJson<String?>(organiser),
      'note': serializer.toJson<String>(note),
      'hlc': serializer.toJson<String>(hlc),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Investment copyWith({
    String? id,
    String? kind,
    String? name,
    Value<String?> accountId = const Value.absent(),
    Value<String?> startDate = const Value.absent(),
    Value<int?> expectedGrowthBps = const Value.absent(),
    Value<int?> currentValueMinor = const Value.absent(),
    Value<String?> valueUpdatedOn = const Value.absent(),
    Value<double?> units = const Value.absent(),
    Value<int?> buyPriceMinor = const Value.absent(),
    Value<int?> sipMinor = const Value.absent(),
    Value<int?> chitValueMinor = const Value.absent(),
    Value<int?> tenureMonths = const Value.absent(),
    Value<int?> members = const Value.absent(),
    Value<int?> monthlyMinor = const Value.absent(),
    Value<int?> commissionBps = const Value.absent(),
    Value<String?> organiser = const Value.absent(),
    String? note,
    String? hlc,
    Value<String?> deletedAt = const Value.absent(),
  }) => Investment(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    accountId: accountId.present ? accountId.value : this.accountId,
    startDate: startDate.present ? startDate.value : this.startDate,
    expectedGrowthBps: expectedGrowthBps.present
        ? expectedGrowthBps.value
        : this.expectedGrowthBps,
    currentValueMinor: currentValueMinor.present
        ? currentValueMinor.value
        : this.currentValueMinor,
    valueUpdatedOn: valueUpdatedOn.present
        ? valueUpdatedOn.value
        : this.valueUpdatedOn,
    units: units.present ? units.value : this.units,
    buyPriceMinor: buyPriceMinor.present
        ? buyPriceMinor.value
        : this.buyPriceMinor,
    sipMinor: sipMinor.present ? sipMinor.value : this.sipMinor,
    chitValueMinor: chitValueMinor.present
        ? chitValueMinor.value
        : this.chitValueMinor,
    tenureMonths: tenureMonths.present ? tenureMonths.value : this.tenureMonths,
    members: members.present ? members.value : this.members,
    monthlyMinor: monthlyMinor.present ? monthlyMinor.value : this.monthlyMinor,
    commissionBps: commissionBps.present
        ? commissionBps.value
        : this.commissionBps,
    organiser: organiser.present ? organiser.value : this.organiser,
    note: note ?? this.note,
    hlc: hlc ?? this.hlc,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Investment copyWithCompanion(InvestmentsCompanion data) {
    return Investment(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      expectedGrowthBps: data.expectedGrowthBps.present
          ? data.expectedGrowthBps.value
          : this.expectedGrowthBps,
      currentValueMinor: data.currentValueMinor.present
          ? data.currentValueMinor.value
          : this.currentValueMinor,
      valueUpdatedOn: data.valueUpdatedOn.present
          ? data.valueUpdatedOn.value
          : this.valueUpdatedOn,
      units: data.units.present ? data.units.value : this.units,
      buyPriceMinor: data.buyPriceMinor.present
          ? data.buyPriceMinor.value
          : this.buyPriceMinor,
      sipMinor: data.sipMinor.present ? data.sipMinor.value : this.sipMinor,
      chitValueMinor: data.chitValueMinor.present
          ? data.chitValueMinor.value
          : this.chitValueMinor,
      tenureMonths: data.tenureMonths.present
          ? data.tenureMonths.value
          : this.tenureMonths,
      members: data.members.present ? data.members.value : this.members,
      monthlyMinor: data.monthlyMinor.present
          ? data.monthlyMinor.value
          : this.monthlyMinor,
      commissionBps: data.commissionBps.present
          ? data.commissionBps.value
          : this.commissionBps,
      organiser: data.organiser.present ? data.organiser.value : this.organiser,
      note: data.note.present ? data.note.value : this.note,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Investment(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('accountId: $accountId, ')
          ..write('startDate: $startDate, ')
          ..write('expectedGrowthBps: $expectedGrowthBps, ')
          ..write('currentValueMinor: $currentValueMinor, ')
          ..write('valueUpdatedOn: $valueUpdatedOn, ')
          ..write('units: $units, ')
          ..write('buyPriceMinor: $buyPriceMinor, ')
          ..write('sipMinor: $sipMinor, ')
          ..write('chitValueMinor: $chitValueMinor, ')
          ..write('tenureMonths: $tenureMonths, ')
          ..write('members: $members, ')
          ..write('monthlyMinor: $monthlyMinor, ')
          ..write('commissionBps: $commissionBps, ')
          ..write('organiser: $organiser, ')
          ..write('note: $note, ')
          ..write('hlc: $hlc, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    name,
    accountId,
    startDate,
    expectedGrowthBps,
    currentValueMinor,
    valueUpdatedOn,
    units,
    buyPriceMinor,
    sipMinor,
    chitValueMinor,
    tenureMonths,
    members,
    monthlyMinor,
    commissionBps,
    organiser,
    note,
    hlc,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Investment &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.accountId == this.accountId &&
          other.startDate == this.startDate &&
          other.expectedGrowthBps == this.expectedGrowthBps &&
          other.currentValueMinor == this.currentValueMinor &&
          other.valueUpdatedOn == this.valueUpdatedOn &&
          other.units == this.units &&
          other.buyPriceMinor == this.buyPriceMinor &&
          other.sipMinor == this.sipMinor &&
          other.chitValueMinor == this.chitValueMinor &&
          other.tenureMonths == this.tenureMonths &&
          other.members == this.members &&
          other.monthlyMinor == this.monthlyMinor &&
          other.commissionBps == this.commissionBps &&
          other.organiser == this.organiser &&
          other.note == this.note &&
          other.hlc == this.hlc &&
          other.deletedAt == this.deletedAt);
}

class InvestmentsCompanion extends UpdateCompanion<Investment> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> name;
  final Value<String?> accountId;
  final Value<String?> startDate;
  final Value<int?> expectedGrowthBps;
  final Value<int?> currentValueMinor;
  final Value<String?> valueUpdatedOn;
  final Value<double?> units;
  final Value<int?> buyPriceMinor;
  final Value<int?> sipMinor;
  final Value<int?> chitValueMinor;
  final Value<int?> tenureMonths;
  final Value<int?> members;
  final Value<int?> monthlyMinor;
  final Value<int?> commissionBps;
  final Value<String?> organiser;
  final Value<String> note;
  final Value<String> hlc;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const InvestmentsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.accountId = const Value.absent(),
    this.startDate = const Value.absent(),
    this.expectedGrowthBps = const Value.absent(),
    this.currentValueMinor = const Value.absent(),
    this.valueUpdatedOn = const Value.absent(),
    this.units = const Value.absent(),
    this.buyPriceMinor = const Value.absent(),
    this.sipMinor = const Value.absent(),
    this.chitValueMinor = const Value.absent(),
    this.tenureMonths = const Value.absent(),
    this.members = const Value.absent(),
    this.monthlyMinor = const Value.absent(),
    this.commissionBps = const Value.absent(),
    this.organiser = const Value.absent(),
    this.note = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InvestmentsCompanion.insert({
    required String id,
    required String kind,
    required String name,
    this.accountId = const Value.absent(),
    this.startDate = const Value.absent(),
    this.expectedGrowthBps = const Value.absent(),
    this.currentValueMinor = const Value.absent(),
    this.valueUpdatedOn = const Value.absent(),
    this.units = const Value.absent(),
    this.buyPriceMinor = const Value.absent(),
    this.sipMinor = const Value.absent(),
    this.chitValueMinor = const Value.absent(),
    this.tenureMonths = const Value.absent(),
    this.members = const Value.absent(),
    this.monthlyMinor = const Value.absent(),
    this.commissionBps = const Value.absent(),
    this.organiser = const Value.absent(),
    this.note = const Value.absent(),
    required String hlc,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       name = Value(name),
       hlc = Value(hlc);
  static Insertable<Investment> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? accountId,
    Expression<String>? startDate,
    Expression<int>? expectedGrowthBps,
    Expression<int>? currentValueMinor,
    Expression<String>? valueUpdatedOn,
    Expression<double>? units,
    Expression<int>? buyPriceMinor,
    Expression<int>? sipMinor,
    Expression<int>? chitValueMinor,
    Expression<int>? tenureMonths,
    Expression<int>? members,
    Expression<int>? monthlyMinor,
    Expression<int>? commissionBps,
    Expression<String>? organiser,
    Expression<String>? note,
    Expression<String>? hlc,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (accountId != null) 'account_id': accountId,
      if (startDate != null) 'start_date': startDate,
      if (expectedGrowthBps != null) 'expected_growth_bps': expectedGrowthBps,
      if (currentValueMinor != null) 'current_value_minor': currentValueMinor,
      if (valueUpdatedOn != null) 'value_updated_on': valueUpdatedOn,
      if (units != null) 'units': units,
      if (buyPriceMinor != null) 'buy_price_minor': buyPriceMinor,
      if (sipMinor != null) 'sip_minor': sipMinor,
      if (chitValueMinor != null) 'chit_value_minor': chitValueMinor,
      if (tenureMonths != null) 'tenure_months': tenureMonths,
      if (members != null) 'members': members,
      if (monthlyMinor != null) 'monthly_minor': monthlyMinor,
      if (commissionBps != null) 'commission_bps': commissionBps,
      if (organiser != null) 'organiser': organiser,
      if (note != null) 'note': note,
      if (hlc != null) 'hlc': hlc,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InvestmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? name,
    Value<String?>? accountId,
    Value<String?>? startDate,
    Value<int?>? expectedGrowthBps,
    Value<int?>? currentValueMinor,
    Value<String?>? valueUpdatedOn,
    Value<double?>? units,
    Value<int?>? buyPriceMinor,
    Value<int?>? sipMinor,
    Value<int?>? chitValueMinor,
    Value<int?>? tenureMonths,
    Value<int?>? members,
    Value<int?>? monthlyMinor,
    Value<int?>? commissionBps,
    Value<String?>? organiser,
    Value<String>? note,
    Value<String>? hlc,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return InvestmentsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      accountId: accountId ?? this.accountId,
      startDate: startDate ?? this.startDate,
      expectedGrowthBps: expectedGrowthBps ?? this.expectedGrowthBps,
      currentValueMinor: currentValueMinor ?? this.currentValueMinor,
      valueUpdatedOn: valueUpdatedOn ?? this.valueUpdatedOn,
      units: units ?? this.units,
      buyPriceMinor: buyPriceMinor ?? this.buyPriceMinor,
      sipMinor: sipMinor ?? this.sipMinor,
      chitValueMinor: chitValueMinor ?? this.chitValueMinor,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      members: members ?? this.members,
      monthlyMinor: monthlyMinor ?? this.monthlyMinor,
      commissionBps: commissionBps ?? this.commissionBps,
      organiser: organiser ?? this.organiser,
      note: note ?? this.note,
      hlc: hlc ?? this.hlc,
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
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (expectedGrowthBps.present) {
      map['expected_growth_bps'] = Variable<int>(expectedGrowthBps.value);
    }
    if (currentValueMinor.present) {
      map['current_value_minor'] = Variable<int>(currentValueMinor.value);
    }
    if (valueUpdatedOn.present) {
      map['value_updated_on'] = Variable<String>(valueUpdatedOn.value);
    }
    if (units.present) {
      map['units'] = Variable<double>(units.value);
    }
    if (buyPriceMinor.present) {
      map['buy_price_minor'] = Variable<int>(buyPriceMinor.value);
    }
    if (sipMinor.present) {
      map['sip_minor'] = Variable<int>(sipMinor.value);
    }
    if (chitValueMinor.present) {
      map['chit_value_minor'] = Variable<int>(chitValueMinor.value);
    }
    if (tenureMonths.present) {
      map['tenure_months'] = Variable<int>(tenureMonths.value);
    }
    if (members.present) {
      map['members'] = Variable<int>(members.value);
    }
    if (monthlyMinor.present) {
      map['monthly_minor'] = Variable<int>(monthlyMinor.value);
    }
    if (commissionBps.present) {
      map['commission_bps'] = Variable<int>(commissionBps.value);
    }
    if (organiser.present) {
      map['organiser'] = Variable<String>(organiser.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
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
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('accountId: $accountId, ')
          ..write('startDate: $startDate, ')
          ..write('expectedGrowthBps: $expectedGrowthBps, ')
          ..write('currentValueMinor: $currentValueMinor, ')
          ..write('valueUpdatedOn: $valueUpdatedOn, ')
          ..write('units: $units, ')
          ..write('buyPriceMinor: $buyPriceMinor, ')
          ..write('sipMinor: $sipMinor, ')
          ..write('chitValueMinor: $chitValueMinor, ')
          ..write('tenureMonths: $tenureMonths, ')
          ..write('members: $members, ')
          ..write('monthlyMinor: $monthlyMinor, ')
          ..write('commissionBps: $commissionBps, ')
          ..write('organiser: $organiser, ')
          ..write('note: $note, ')
          ..write('hlc: $hlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InvestmentEntriesTable extends InvestmentEntries
    with TableInfo<$InvestmentEntriesTable, InvestmentEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvestmentEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _investmentIdMeta = const VerificationMeta(
    'investmentId',
  );
  @override
  late final GeneratedColumn<String> investmentId = GeneratedColumn<String>(
    'investment_id',
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
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _periodKeyMeta = const VerificationMeta(
    'periodKey',
  );
  @override
  late final GeneratedColumn<int> periodKey = GeneratedColumn<int>(
    'period_key',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _postToBalanceMeta = const VerificationMeta(
    'postToBalance',
  );
  @override
  late final GeneratedColumn<bool> postToBalance = GeneratedColumn<bool>(
    'post_to_balance',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("post_to_balance" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
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
    investmentId,
    type,
    amountMinor,
    date,
    periodKey,
    postToBalance,
    note,
    hlc,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'investment_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<InvestmentEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('investment_id')) {
      context.handle(
        _investmentIdMeta,
        investmentId.isAcceptableOrUnknown(
          data['investment_id']!,
          _investmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_investmentIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('period_key')) {
      context.handle(
        _periodKeyMeta,
        periodKey.isAcceptableOrUnknown(data['period_key']!, _periodKeyMeta),
      );
    }
    if (data.containsKey('post_to_balance')) {
      context.handle(
        _postToBalanceMeta,
        postToBalance.isAcceptableOrUnknown(
          data['post_to_balance']!,
          _postToBalanceMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
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
  InvestmentEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InvestmentEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      investmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}investment_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      periodKey: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}period_key'],
      ),
      postToBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}post_to_balance'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $InvestmentEntriesTable createAlias(String alias) {
    return $InvestmentEntriesTable(attachedDatabase, alias);
  }
}

class InvestmentEntry extends DataClass implements Insertable<InvestmentEntry> {
  final String id;
  final String investmentId;
  final String type;
  final int amountMinor;
  final String date;
  final int? periodKey;
  final bool postToBalance;
  final String note;
  final String hlc;
  final String? deletedAt;
  const InvestmentEntry({
    required this.id,
    required this.investmentId,
    required this.type,
    required this.amountMinor,
    required this.date,
    this.periodKey,
    required this.postToBalance,
    required this.note,
    required this.hlc,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['investment_id'] = Variable<String>(investmentId);
    map['type'] = Variable<String>(type);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['date'] = Variable<String>(date);
    if (!nullToAbsent || periodKey != null) {
      map['period_key'] = Variable<int>(periodKey);
    }
    map['post_to_balance'] = Variable<bool>(postToBalance);
    map['note'] = Variable<String>(note);
    map['hlc'] = Variable<String>(hlc);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  InvestmentEntriesCompanion toCompanion(bool nullToAbsent) {
    return InvestmentEntriesCompanion(
      id: Value(id),
      investmentId: Value(investmentId),
      type: Value(type),
      amountMinor: Value(amountMinor),
      date: Value(date),
      periodKey: periodKey == null && nullToAbsent
          ? const Value.absent()
          : Value(periodKey),
      postToBalance: Value(postToBalance),
      note: Value(note),
      hlc: Value(hlc),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory InvestmentEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InvestmentEntry(
      id: serializer.fromJson<String>(json['id']),
      investmentId: serializer.fromJson<String>(json['investmentId']),
      type: serializer.fromJson<String>(json['type']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      date: serializer.fromJson<String>(json['date']),
      periodKey: serializer.fromJson<int?>(json['periodKey']),
      postToBalance: serializer.fromJson<bool>(json['postToBalance']),
      note: serializer.fromJson<String>(json['note']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'investmentId': serializer.toJson<String>(investmentId),
      'type': serializer.toJson<String>(type),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'date': serializer.toJson<String>(date),
      'periodKey': serializer.toJson<int?>(periodKey),
      'postToBalance': serializer.toJson<bool>(postToBalance),
      'note': serializer.toJson<String>(note),
      'hlc': serializer.toJson<String>(hlc),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  InvestmentEntry copyWith({
    String? id,
    String? investmentId,
    String? type,
    int? amountMinor,
    String? date,
    Value<int?> periodKey = const Value.absent(),
    bool? postToBalance,
    String? note,
    String? hlc,
    Value<String?> deletedAt = const Value.absent(),
  }) => InvestmentEntry(
    id: id ?? this.id,
    investmentId: investmentId ?? this.investmentId,
    type: type ?? this.type,
    amountMinor: amountMinor ?? this.amountMinor,
    date: date ?? this.date,
    periodKey: periodKey.present ? periodKey.value : this.periodKey,
    postToBalance: postToBalance ?? this.postToBalance,
    note: note ?? this.note,
    hlc: hlc ?? this.hlc,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  InvestmentEntry copyWithCompanion(InvestmentEntriesCompanion data) {
    return InvestmentEntry(
      id: data.id.present ? data.id.value : this.id,
      investmentId: data.investmentId.present
          ? data.investmentId.value
          : this.investmentId,
      type: data.type.present ? data.type.value : this.type,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      date: data.date.present ? data.date.value : this.date,
      periodKey: data.periodKey.present ? data.periodKey.value : this.periodKey,
      postToBalance: data.postToBalance.present
          ? data.postToBalance.value
          : this.postToBalance,
      note: data.note.present ? data.note.value : this.note,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InvestmentEntry(')
          ..write('id: $id, ')
          ..write('investmentId: $investmentId, ')
          ..write('type: $type, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('date: $date, ')
          ..write('periodKey: $periodKey, ')
          ..write('postToBalance: $postToBalance, ')
          ..write('note: $note, ')
          ..write('hlc: $hlc, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    investmentId,
    type,
    amountMinor,
    date,
    periodKey,
    postToBalance,
    note,
    hlc,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvestmentEntry &&
          other.id == this.id &&
          other.investmentId == this.investmentId &&
          other.type == this.type &&
          other.amountMinor == this.amountMinor &&
          other.date == this.date &&
          other.periodKey == this.periodKey &&
          other.postToBalance == this.postToBalance &&
          other.note == this.note &&
          other.hlc == this.hlc &&
          other.deletedAt == this.deletedAt);
}

class InvestmentEntriesCompanion extends UpdateCompanion<InvestmentEntry> {
  final Value<String> id;
  final Value<String> investmentId;
  final Value<String> type;
  final Value<int> amountMinor;
  final Value<String> date;
  final Value<int?> periodKey;
  final Value<bool> postToBalance;
  final Value<String> note;
  final Value<String> hlc;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const InvestmentEntriesCompanion({
    this.id = const Value.absent(),
    this.investmentId = const Value.absent(),
    this.type = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.date = const Value.absent(),
    this.periodKey = const Value.absent(),
    this.postToBalance = const Value.absent(),
    this.note = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InvestmentEntriesCompanion.insert({
    required String id,
    required String investmentId,
    required String type,
    required int amountMinor,
    required String date,
    this.periodKey = const Value.absent(),
    this.postToBalance = const Value.absent(),
    this.note = const Value.absent(),
    required String hlc,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       investmentId = Value(investmentId),
       type = Value(type),
       amountMinor = Value(amountMinor),
       date = Value(date),
       hlc = Value(hlc);
  static Insertable<InvestmentEntry> custom({
    Expression<String>? id,
    Expression<String>? investmentId,
    Expression<String>? type,
    Expression<int>? amountMinor,
    Expression<String>? date,
    Expression<int>? periodKey,
    Expression<bool>? postToBalance,
    Expression<String>? note,
    Expression<String>? hlc,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (investmentId != null) 'investment_id': investmentId,
      if (type != null) 'type': type,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (date != null) 'date': date,
      if (periodKey != null) 'period_key': periodKey,
      if (postToBalance != null) 'post_to_balance': postToBalance,
      if (note != null) 'note': note,
      if (hlc != null) 'hlc': hlc,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InvestmentEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? investmentId,
    Value<String>? type,
    Value<int>? amountMinor,
    Value<String>? date,
    Value<int?>? periodKey,
    Value<bool>? postToBalance,
    Value<String>? note,
    Value<String>? hlc,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return InvestmentEntriesCompanion(
      id: id ?? this.id,
      investmentId: investmentId ?? this.investmentId,
      type: type ?? this.type,
      amountMinor: amountMinor ?? this.amountMinor,
      date: date ?? this.date,
      periodKey: periodKey ?? this.periodKey,
      postToBalance: postToBalance ?? this.postToBalance,
      note: note ?? this.note,
      hlc: hlc ?? this.hlc,
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
    if (investmentId.present) {
      map['investment_id'] = Variable<String>(investmentId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (periodKey.present) {
      map['period_key'] = Variable<int>(periodKey.value);
    }
    if (postToBalance.present) {
      map['post_to_balance'] = Variable<bool>(postToBalance.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
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
    return (StringBuffer('InvestmentEntriesCompanion(')
          ..write('id: $id, ')
          ..write('investmentId: $investmentId, ')
          ..write('type: $type, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('date: $date, ')
          ..write('periodKey: $periodKey, ')
          ..write('postToBalance: $postToBalance, ')
          ..write('note: $note, ')
          ..write('hlc: $hlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SmsInboxTable extends SmsInbox
    with TableInfo<$SmsInboxTable, SmsInboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SmsInboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _semanticKeyMeta = const VerificationMeta(
    'semanticKey',
  );
  @override
  late final GeneratedColumn<String> semanticKey = GeneratedColumn<String>(
    'semantic_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderMeta = const VerificationMeta('sender');
  @override
  late final GeneratedColumn<String> sender = GeneratedColumn<String>(
    'sender',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _merchantMeta = const VerificationMeta(
    'merchant',
  );
  @override
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
    'merchant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accountRefMeta = const VerificationMeta(
    'accountRef',
  );
  @override
  late final GeneratedColumn<String> accountRef = GeneratedColumn<String>(
    'account_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceMeta = const VerificationMeta(
    'reference',
  );
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
    'reference',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fingerprint,
    semanticKey,
    sender,
    body,
    direction,
    amountMinor,
    date,
    merchant,
    accountRef,
    reference,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sms_inbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SmsInboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('semantic_key')) {
      context.handle(
        _semanticKeyMeta,
        semanticKey.isAcceptableOrUnknown(
          data['semantic_key']!,
          _semanticKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_semanticKeyMeta);
    }
    if (data.containsKey('sender')) {
      context.handle(
        _senderMeta,
        sender.isAcceptableOrUnknown(data['sender']!, _senderMeta),
      );
    } else if (isInserting) {
      context.missing(_senderMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('merchant')) {
      context.handle(
        _merchantMeta,
        merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta),
      );
    }
    if (data.containsKey('account_ref')) {
      context.handle(
        _accountRefMeta,
        accountRef.isAcceptableOrUnknown(data['account_ref']!, _accountRefMeta),
      );
    }
    if (data.containsKey('reference')) {
      context.handle(
        _referenceMeta,
        reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SmsInboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SmsInboxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      )!,
      semanticKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semantic_key'],
      )!,
      sender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      merchant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant'],
      ),
      accountRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_ref'],
      ),
      reference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $SmsInboxTable createAlias(String alias) {
    return $SmsInboxTable(attachedDatabase, alias);
  }
}

class SmsInboxData extends DataClass implements Insertable<SmsInboxData> {
  final String id;
  final String fingerprint;
  final String semanticKey;
  final String sender;
  final String body;
  final String direction;
  final int amountMinor;
  final String date;
  final String? merchant;
  final String? accountRef;
  final String? reference;
  final String status;
  const SmsInboxData({
    required this.id,
    required this.fingerprint,
    required this.semanticKey,
    required this.sender,
    required this.body,
    required this.direction,
    required this.amountMinor,
    required this.date,
    this.merchant,
    this.accountRef,
    this.reference,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['fingerprint'] = Variable<String>(fingerprint);
    map['semantic_key'] = Variable<String>(semanticKey);
    map['sender'] = Variable<String>(sender);
    map['body'] = Variable<String>(body);
    map['direction'] = Variable<String>(direction);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['date'] = Variable<String>(date);
    if (!nullToAbsent || merchant != null) {
      map['merchant'] = Variable<String>(merchant);
    }
    if (!nullToAbsent || accountRef != null) {
      map['account_ref'] = Variable<String>(accountRef);
    }
    if (!nullToAbsent || reference != null) {
      map['reference'] = Variable<String>(reference);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  SmsInboxCompanion toCompanion(bool nullToAbsent) {
    return SmsInboxCompanion(
      id: Value(id),
      fingerprint: Value(fingerprint),
      semanticKey: Value(semanticKey),
      sender: Value(sender),
      body: Value(body),
      direction: Value(direction),
      amountMinor: Value(amountMinor),
      date: Value(date),
      merchant: merchant == null && nullToAbsent
          ? const Value.absent()
          : Value(merchant),
      accountRef: accountRef == null && nullToAbsent
          ? const Value.absent()
          : Value(accountRef),
      reference: reference == null && nullToAbsent
          ? const Value.absent()
          : Value(reference),
      status: Value(status),
    );
  }

  factory SmsInboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SmsInboxData(
      id: serializer.fromJson<String>(json['id']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      semanticKey: serializer.fromJson<String>(json['semanticKey']),
      sender: serializer.fromJson<String>(json['sender']),
      body: serializer.fromJson<String>(json['body']),
      direction: serializer.fromJson<String>(json['direction']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      date: serializer.fromJson<String>(json['date']),
      merchant: serializer.fromJson<String?>(json['merchant']),
      accountRef: serializer.fromJson<String?>(json['accountRef']),
      reference: serializer.fromJson<String?>(json['reference']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'semanticKey': serializer.toJson<String>(semanticKey),
      'sender': serializer.toJson<String>(sender),
      'body': serializer.toJson<String>(body),
      'direction': serializer.toJson<String>(direction),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'date': serializer.toJson<String>(date),
      'merchant': serializer.toJson<String?>(merchant),
      'accountRef': serializer.toJson<String?>(accountRef),
      'reference': serializer.toJson<String?>(reference),
      'status': serializer.toJson<String>(status),
    };
  }

  SmsInboxData copyWith({
    String? id,
    String? fingerprint,
    String? semanticKey,
    String? sender,
    String? body,
    String? direction,
    int? amountMinor,
    String? date,
    Value<String?> merchant = const Value.absent(),
    Value<String?> accountRef = const Value.absent(),
    Value<String?> reference = const Value.absent(),
    String? status,
  }) => SmsInboxData(
    id: id ?? this.id,
    fingerprint: fingerprint ?? this.fingerprint,
    semanticKey: semanticKey ?? this.semanticKey,
    sender: sender ?? this.sender,
    body: body ?? this.body,
    direction: direction ?? this.direction,
    amountMinor: amountMinor ?? this.amountMinor,
    date: date ?? this.date,
    merchant: merchant.present ? merchant.value : this.merchant,
    accountRef: accountRef.present ? accountRef.value : this.accountRef,
    reference: reference.present ? reference.value : this.reference,
    status: status ?? this.status,
  );
  SmsInboxData copyWithCompanion(SmsInboxCompanion data) {
    return SmsInboxData(
      id: data.id.present ? data.id.value : this.id,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      semanticKey: data.semanticKey.present
          ? data.semanticKey.value
          : this.semanticKey,
      sender: data.sender.present ? data.sender.value : this.sender,
      body: data.body.present ? data.body.value : this.body,
      direction: data.direction.present ? data.direction.value : this.direction,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      date: data.date.present ? data.date.value : this.date,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      accountRef: data.accountRef.present
          ? data.accountRef.value
          : this.accountRef,
      reference: data.reference.present ? data.reference.value : this.reference,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SmsInboxData(')
          ..write('id: $id, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('semanticKey: $semanticKey, ')
          ..write('sender: $sender, ')
          ..write('body: $body, ')
          ..write('direction: $direction, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('date: $date, ')
          ..write('merchant: $merchant, ')
          ..write('accountRef: $accountRef, ')
          ..write('reference: $reference, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fingerprint,
    semanticKey,
    sender,
    body,
    direction,
    amountMinor,
    date,
    merchant,
    accountRef,
    reference,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SmsInboxData &&
          other.id == this.id &&
          other.fingerprint == this.fingerprint &&
          other.semanticKey == this.semanticKey &&
          other.sender == this.sender &&
          other.body == this.body &&
          other.direction == this.direction &&
          other.amountMinor == this.amountMinor &&
          other.date == this.date &&
          other.merchant == this.merchant &&
          other.accountRef == this.accountRef &&
          other.reference == this.reference &&
          other.status == this.status);
}

class SmsInboxCompanion extends UpdateCompanion<SmsInboxData> {
  final Value<String> id;
  final Value<String> fingerprint;
  final Value<String> semanticKey;
  final Value<String> sender;
  final Value<String> body;
  final Value<String> direction;
  final Value<int> amountMinor;
  final Value<String> date;
  final Value<String?> merchant;
  final Value<String?> accountRef;
  final Value<String?> reference;
  final Value<String> status;
  final Value<int> rowid;
  const SmsInboxCompanion({
    this.id = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.semanticKey = const Value.absent(),
    this.sender = const Value.absent(),
    this.body = const Value.absent(),
    this.direction = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.date = const Value.absent(),
    this.merchant = const Value.absent(),
    this.accountRef = const Value.absent(),
    this.reference = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SmsInboxCompanion.insert({
    required String id,
    required String fingerprint,
    required String semanticKey,
    required String sender,
    required String body,
    required String direction,
    required int amountMinor,
    required String date,
    this.merchant = const Value.absent(),
    this.accountRef = const Value.absent(),
    this.reference = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fingerprint = Value(fingerprint),
       semanticKey = Value(semanticKey),
       sender = Value(sender),
       body = Value(body),
       direction = Value(direction),
       amountMinor = Value(amountMinor),
       date = Value(date);
  static Insertable<SmsInboxData> custom({
    Expression<String>? id,
    Expression<String>? fingerprint,
    Expression<String>? semanticKey,
    Expression<String>? sender,
    Expression<String>? body,
    Expression<String>? direction,
    Expression<int>? amountMinor,
    Expression<String>? date,
    Expression<String>? merchant,
    Expression<String>? accountRef,
    Expression<String>? reference,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (semanticKey != null) 'semantic_key': semanticKey,
      if (sender != null) 'sender': sender,
      if (body != null) 'body': body,
      if (direction != null) 'direction': direction,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (date != null) 'date': date,
      if (merchant != null) 'merchant': merchant,
      if (accountRef != null) 'account_ref': accountRef,
      if (reference != null) 'reference': reference,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SmsInboxCompanion copyWith({
    Value<String>? id,
    Value<String>? fingerprint,
    Value<String>? semanticKey,
    Value<String>? sender,
    Value<String>? body,
    Value<String>? direction,
    Value<int>? amountMinor,
    Value<String>? date,
    Value<String?>? merchant,
    Value<String?>? accountRef,
    Value<String?>? reference,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return SmsInboxCompanion(
      id: id ?? this.id,
      fingerprint: fingerprint ?? this.fingerprint,
      semanticKey: semanticKey ?? this.semanticKey,
      sender: sender ?? this.sender,
      body: body ?? this.body,
      direction: direction ?? this.direction,
      amountMinor: amountMinor ?? this.amountMinor,
      date: date ?? this.date,
      merchant: merchant ?? this.merchant,
      accountRef: accountRef ?? this.accountRef,
      reference: reference ?? this.reference,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (semanticKey.present) {
      map['semantic_key'] = Variable<String>(semanticKey.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (accountRef.present) {
      map['account_ref'] = Variable<String>(accountRef.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SmsInboxCompanion(')
          ..write('id: $id, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('semanticKey: $semanticKey, ')
          ..write('sender: $sender, ')
          ..write('body: $body, ')
          ..write('direction: $direction, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('date: $date, ')
          ..write('merchant: $merchant, ')
          ..write('accountRef: $accountRef, ')
          ..write('reference: $reference, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
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
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
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
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
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

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
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
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
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

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
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
    return (StringBuffer('SettingsCompanion(')
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
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $DebtsTable debts = $DebtsTable(this);
  late final $DebtEventsTable debtEvents = $DebtEventsTable(this);
  late final $InvestmentsTable investments = $InvestmentsTable(this);
  late final $InvestmentEntriesTable investmentEntries =
      $InvestmentEntriesTable(this);
  late final $SmsInboxTable smsInbox = $SmsInboxTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index txnDate = Index(
    'txn_date',
    'CREATE INDEX txn_date ON transactions (date)',
  );
  late final Index txnCatDate = Index(
    'txn_cat_date',
    'CREATE INDEX txn_cat_date ON transactions (category_id, date)',
  );
  late final Index txnAccDate = Index(
    'txn_acc_date',
    'CREATE INDEX txn_acc_date ON transactions (account_id, date)',
  );
  late final Index txnSourceRef = Index(
    'txn_source_ref',
    'CREATE INDEX txn_source_ref ON transactions (source_ref)',
  );
  late final Index debtEvDebt = Index(
    'debt_ev_debt',
    'CREATE INDEX debt_ev_debt ON debt_events (debt_id, date)',
  );
  late final Index invEntryInv = Index(
    'inv_entry_inv',
    'CREATE INDEX inv_entry_inv ON investment_entries (investment_id, date)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    categories,
    transactions,
    debts,
    debtEvents,
    investments,
    investmentEntries,
    smsInbox,
    settings,
    txnDate,
    txnCatDate,
    txnAccDate,
    txnSourceRef,
    debtEvDebt,
    invEntryInv,
  ];
}

typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  required String id,
  required String name,
  required String kind,
  required int colorValue,
  Value<int> openingMinor,
  Value<String?> last4,
  Value<int> sortOrder,
  Value<bool> archived,
  required String hlc,
  Value<String?> deletedAt,
  Value<int> rowid,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> kind,
  Value<int> colorValue,
  Value<int> openingMinor,
  Value<String?> last4,
  Value<int> sortOrder,
  Value<bool> archived,
  Value<String> hlc,
  Value<String?> deletedAt,
  Value<int> rowid,
});

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openingMinor => $composableBuilder(
    column: $table.openingMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get last4 => $composableBuilder(
    column: $table.last4,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openingMinor => $composableBuilder(
    column: $table.openingMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get last4 => $composableBuilder(
    column: $table.last4,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
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

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get openingMinor => $composableBuilder(
    column: $table.openingMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get last4 =>
      $composableBuilder(column: $table.last4, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
          Account,
          PrefetchHooks Function()
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<int> openingMinor = const Value.absent(),
                Value<String?> last4 = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                name: name,
                kind: kind,
                colorValue: colorValue,
                openingMinor: openingMinor,
                last4: last4,
                sortOrder: sortOrder,
                archived: archived,
                hlc: hlc,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String kind,
                required int colorValue,
                Value<int> openingMinor = const Value.absent(),
                Value<String?> last4 = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                required String hlc,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                colorValue: colorValue,
                openingMinor: openingMinor,
                last4: last4,
                sortOrder: sortOrder,
                archived: archived,
                hlc: hlc,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AccountsTable, Account>(table),
                  BaseReferences<_$AppDatabase, $AccountsTable, Account>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
      Account,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  required String name,
  required String kind,
  Value<String?> parentId,
  required int colorValue,
  Value<String> iconKey,
  Value<int> sortOrder,
  Value<bool> archived,
  required String hlc,
  Value<String?> deletedAt,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> kind,
  Value<String?> parentId,
  Value<int> colorValue,
  Value<String> iconKey,
  Value<int> sortOrder,
  Value<bool> archived,
  Value<String> hlc,
  Value<String?> deletedAt,
  Value<int> rowid,
});

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
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

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
          Category,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<String> iconKey = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                kind: kind,
                parentId: parentId,
                colorValue: colorValue,
                iconKey: iconKey,
                sortOrder: sortOrder,
                archived: archived,
                hlc: hlc,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String kind,
                Value<String?> parentId = const Value.absent(),
                required int colorValue,
                Value<String> iconKey = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                required String hlc,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                parentId: parentId,
                colorValue: colorValue,
                iconKey: iconKey,
                sortOrder: sortOrder,
                archived: archived,
                hlc: hlc,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, Category>(table),
                  BaseReferences<_$AppDatabase, $CategoriesTable, Category>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
      Category,
      PrefetchHooks Function()
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      required String id,
      required String type,
      required int amountMinor,
      required String accountId,
      Value<String?> toAccountId,
      Value<String?> categoryId,
      Value<String?> paymentMethod,
      required String date,
      Value<String> note,
      Value<String?> merchant,
      Value<String> source,
      Value<String?> sourceRef,
      required String hlc,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<int> amountMinor,
      Value<String> accountId,
      Value<String?> toAccountId,
      Value<String?> categoryId,
      Value<String?> paymentMethod,
      Value<String> date,
      Value<String> note,
      Value<String?> merchant,
      Value<String> source,
      Value<String?> sourceRef,
      Value<String> hlc,
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

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRef => $composableBuilder(
    column: $table.sourceRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
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

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRef => $composableBuilder(
    column: $table.sourceRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
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

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceRef =>
      $composableBuilder(column: $table.sourceRef, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

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
                Value<int> amountMinor = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String?> toAccountId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> paymentMethod = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> merchant = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> sourceRef = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                type: type,
                amountMinor: amountMinor,
                accountId: accountId,
                toAccountId: toAccountId,
                categoryId: categoryId,
                paymentMethod: paymentMethod,
                date: date,
                note: note,
                merchant: merchant,
                source: source,
                sourceRef: sourceRef,
                hlc: hlc,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required int amountMinor,
                required String accountId,
                Value<String?> toAccountId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> paymentMethod = const Value.absent(),
                required String date,
                Value<String> note = const Value.absent(),
                Value<String?> merchant = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> sourceRef = const Value.absent(),
                required String hlc,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                type: type,
                amountMinor: amountMinor,
                accountId: accountId,
                toAccountId: toAccountId,
                categoryId: categoryId,
                paymentMethod: paymentMethod,
                date: date,
                note: note,
                merchant: merchant,
                source: source,
                sourceRef: sourceRef,
                hlc: hlc,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransactionsTable, Transaction>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $TransactionsTable,
                    Transaction
                  >(db, table, e),
                ),
              )
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
typedef $$DebtsTableCreateCompanionBuilder = DebtsCompanion Function({
  required String id,
  required String direction,
  required String counterparty,
  required int principalMinor,
  required String issuedOn,
  Value<String?> dueOn,
  Value<bool> interestEnabled,
  Value<String> interestType,
  Value<int> rateBps,
  Value<String> ratePeriod,
  required String accountId,
  Value<String> note,
  required String hlc,
  Value<String?> deletedAt,
  Value<int> rowid,
});
typedef $$DebtsTableUpdateCompanionBuilder = DebtsCompanion Function({
  Value<String> id,
  Value<String> direction,
  Value<String> counterparty,
  Value<int> principalMinor,
  Value<String> issuedOn,
  Value<String?> dueOn,
  Value<bool> interestEnabled,
  Value<String> interestType,
  Value<int> rateBps,
  Value<String> ratePeriod,
  Value<String> accountId,
  Value<String> note,
  Value<String> hlc,
  Value<String?> deletedAt,
  Value<int> rowid,
});

class $$DebtsTableFilterComposer extends Composer<_$AppDatabase, $DebtsTable> {
  $$DebtsTableFilterComposer({
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

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get principalMinor => $composableBuilder(
    column: $table.principalMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get issuedOn => $composableBuilder(
    column: $table.issuedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueOn => $composableBuilder(
    column: $table.dueOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get interestEnabled => $composableBuilder(
    column: $table.interestEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get interestType => $composableBuilder(
    column: $table.interestType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rateBps => $composableBuilder(
    column: $table.rateBps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ratePeriod => $composableBuilder(
    column: $table.ratePeriod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DebtsTableOrderingComposer
    extends Composer<_$AppDatabase, $DebtsTable> {
  $$DebtsTableOrderingComposer({
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

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get principalMinor => $composableBuilder(
    column: $table.principalMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get issuedOn => $composableBuilder(
    column: $table.issuedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueOn => $composableBuilder(
    column: $table.dueOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get interestEnabled => $composableBuilder(
    column: $table.interestEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interestType => $composableBuilder(
    column: $table.interestType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rateBps => $composableBuilder(
    column: $table.rateBps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ratePeriod => $composableBuilder(
    column: $table.ratePeriod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DebtsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DebtsTable> {
  $$DebtsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => column,
  );

  GeneratedColumn<int> get principalMinor => $composableBuilder(
    column: $table.principalMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get issuedOn =>
      $composableBuilder(column: $table.issuedOn, builder: (column) => column);

  GeneratedColumn<String> get dueOn =>
      $composableBuilder(column: $table.dueOn, builder: (column) => column);

  GeneratedColumn<bool> get interestEnabled => $composableBuilder(
    column: $table.interestEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get interestType => $composableBuilder(
    column: $table.interestType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rateBps =>
      $composableBuilder(column: $table.rateBps, builder: (column) => column);

  GeneratedColumn<String> get ratePeriod => $composableBuilder(
    column: $table.ratePeriod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DebtsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DebtsTable,
          Debt,
          $$DebtsTableFilterComposer,
          $$DebtsTableOrderingComposer,
          $$DebtsTableAnnotationComposer,
          $$DebtsTableCreateCompanionBuilder,
          $$DebtsTableUpdateCompanionBuilder,
          (Debt, BaseReferences<_$AppDatabase, $DebtsTable, Debt>),
          Debt,
          PrefetchHooks Function()
        > {
  $$DebtsTableTableManager(_$AppDatabase db, $DebtsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DebtsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DebtsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DebtsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> counterparty = const Value.absent(),
                Value<int> principalMinor = const Value.absent(),
                Value<String> issuedOn = const Value.absent(),
                Value<String?> dueOn = const Value.absent(),
                Value<bool> interestEnabled = const Value.absent(),
                Value<String> interestType = const Value.absent(),
                Value<int> rateBps = const Value.absent(),
                Value<String> ratePeriod = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DebtsCompanion(
                id: id,
                direction: direction,
                counterparty: counterparty,
                principalMinor: principalMinor,
                issuedOn: issuedOn,
                dueOn: dueOn,
                interestEnabled: interestEnabled,
                interestType: interestType,
                rateBps: rateBps,
                ratePeriod: ratePeriod,
                accountId: accountId,
                note: note,
                hlc: hlc,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String direction,
                required String counterparty,
                required int principalMinor,
                required String issuedOn,
                Value<String?> dueOn = const Value.absent(),
                Value<bool> interestEnabled = const Value.absent(),
                Value<String> interestType = const Value.absent(),
                Value<int> rateBps = const Value.absent(),
                Value<String> ratePeriod = const Value.absent(),
                required String accountId,
                Value<String> note = const Value.absent(),
                required String hlc,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DebtsCompanion.insert(
                id: id,
                direction: direction,
                counterparty: counterparty,
                principalMinor: principalMinor,
                issuedOn: issuedOn,
                dueOn: dueOn,
                interestEnabled: interestEnabled,
                interestType: interestType,
                rateBps: rateBps,
                ratePeriod: ratePeriod,
                accountId: accountId,
                note: note,
                hlc: hlc,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DebtsTable, Debt>(table),
                  BaseReferences<_$AppDatabase, $DebtsTable, Debt>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DebtsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DebtsTable,
      Debt,
      $$DebtsTableFilterComposer,
      $$DebtsTableOrderingComposer,
      $$DebtsTableAnnotationComposer,
      $$DebtsTableCreateCompanionBuilder,
      $$DebtsTableUpdateCompanionBuilder,
      (Debt, BaseReferences<_$AppDatabase, $DebtsTable, Debt>),
      Debt,
      PrefetchHooks Function()
    >;
typedef $$DebtEventsTableCreateCompanionBuilder = DebtEventsCompanion Function({
  required String id,
  required String debtId,
  required String type,
  required int amountMinor,
  required String date,
  Value<int> principalPart,
  Value<int> interestPart,
  Value<int?> periodKey,
  Value<String> note,
  required String hlc,
  Value<String?> deletedAt,
  Value<int> rowid,
});
typedef $$DebtEventsTableUpdateCompanionBuilder = DebtEventsCompanion Function({
  Value<String> id,
  Value<String> debtId,
  Value<String> type,
  Value<int> amountMinor,
  Value<String> date,
  Value<int> principalPart,
  Value<int> interestPart,
  Value<int?> periodKey,
  Value<String> note,
  Value<String> hlc,
  Value<String?> deletedAt,
  Value<int> rowid,
});

class $$DebtEventsTableFilterComposer
    extends Composer<_$AppDatabase, $DebtEventsTable> {
  $$DebtEventsTableFilterComposer({
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

  ColumnFilters<String> get debtId => $composableBuilder(
    column: $table.debtId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get principalPart => $composableBuilder(
    column: $table.principalPart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get interestPart => $composableBuilder(
    column: $table.interestPart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DebtEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $DebtEventsTable> {
  $$DebtEventsTableOrderingComposer({
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

  ColumnOrderings<String> get debtId => $composableBuilder(
    column: $table.debtId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get principalPart => $composableBuilder(
    column: $table.principalPart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get interestPart => $composableBuilder(
    column: $table.interestPart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DebtEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DebtEventsTable> {
  $$DebtEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get debtId =>
      $composableBuilder(column: $table.debtId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get principalPart => $composableBuilder(
    column: $table.principalPart,
    builder: (column) => column,
  );

  GeneratedColumn<int> get interestPart => $composableBuilder(
    column: $table.interestPart,
    builder: (column) => column,
  );

  GeneratedColumn<int> get periodKey =>
      $composableBuilder(column: $table.periodKey, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DebtEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DebtEventsTable,
          DebtEvent,
          $$DebtEventsTableFilterComposer,
          $$DebtEventsTableOrderingComposer,
          $$DebtEventsTableAnnotationComposer,
          $$DebtEventsTableCreateCompanionBuilder,
          $$DebtEventsTableUpdateCompanionBuilder,
          (
            DebtEvent,
            BaseReferences<_$AppDatabase, $DebtEventsTable, DebtEvent>,
          ),
          DebtEvent,
          PrefetchHooks Function()
        > {
  $$DebtEventsTableTableManager(_$AppDatabase db, $DebtEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DebtEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DebtEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DebtEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> debtId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int> principalPart = const Value.absent(),
                Value<int> interestPart = const Value.absent(),
                Value<int?> periodKey = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DebtEventsCompanion(
                id: id,
                debtId: debtId,
                type: type,
                amountMinor: amountMinor,
                date: date,
                principalPart: principalPart,
                interestPart: interestPart,
                periodKey: periodKey,
                note: note,
                hlc: hlc,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String debtId,
                required String type,
                required int amountMinor,
                required String date,
                Value<int> principalPart = const Value.absent(),
                Value<int> interestPart = const Value.absent(),
                Value<int?> periodKey = const Value.absent(),
                Value<String> note = const Value.absent(),
                required String hlc,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DebtEventsCompanion.insert(
                id: id,
                debtId: debtId,
                type: type,
                amountMinor: amountMinor,
                date: date,
                principalPart: principalPart,
                interestPart: interestPart,
                periodKey: periodKey,
                note: note,
                hlc: hlc,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DebtEventsTable, DebtEvent>(table),
                  BaseReferences<_$AppDatabase, $DebtEventsTable, DebtEvent>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DebtEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DebtEventsTable,
      DebtEvent,
      $$DebtEventsTableFilterComposer,
      $$DebtEventsTableOrderingComposer,
      $$DebtEventsTableAnnotationComposer,
      $$DebtEventsTableCreateCompanionBuilder,
      $$DebtEventsTableUpdateCompanionBuilder,
      (DebtEvent, BaseReferences<_$AppDatabase, $DebtEventsTable, DebtEvent>),
      DebtEvent,
      PrefetchHooks Function()
    >;
typedef $$InvestmentsTableCreateCompanionBuilder =
    InvestmentsCompanion Function({
      required String id,
      required String kind,
      required String name,
      Value<String?> accountId,
      Value<String?> startDate,
      Value<int?> expectedGrowthBps,
      Value<int?> currentValueMinor,
      Value<String?> valueUpdatedOn,
      Value<double?> units,
      Value<int?> buyPriceMinor,
      Value<int?> sipMinor,
      Value<int?> chitValueMinor,
      Value<int?> tenureMonths,
      Value<int?> members,
      Value<int?> monthlyMinor,
      Value<int?> commissionBps,
      Value<String?> organiser,
      Value<String> note,
      required String hlc,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$InvestmentsTableUpdateCompanionBuilder =
    InvestmentsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> name,
      Value<String?> accountId,
      Value<String?> startDate,
      Value<int?> expectedGrowthBps,
      Value<int?> currentValueMinor,
      Value<String?> valueUpdatedOn,
      Value<double?> units,
      Value<int?> buyPriceMinor,
      Value<int?> sipMinor,
      Value<int?> chitValueMinor,
      Value<int?> tenureMonths,
      Value<int?> members,
      Value<int?> monthlyMinor,
      Value<int?> commissionBps,
      Value<String?> organiser,
      Value<String> note,
      Value<String> hlc,
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedGrowthBps => $composableBuilder(
    column: $table.expectedGrowthBps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentValueMinor => $composableBuilder(
    column: $table.currentValueMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueUpdatedOn => $composableBuilder(
    column: $table.valueUpdatedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get units => $composableBuilder(
    column: $table.units,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get buyPriceMinor => $composableBuilder(
    column: $table.buyPriceMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sipMinor => $composableBuilder(
    column: $table.sipMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chitValueMinor => $composableBuilder(
    column: $table.chitValueMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tenureMonths => $composableBuilder(
    column: $table.tenureMonths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get members => $composableBuilder(
    column: $table.members,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthlyMinor => $composableBuilder(
    column: $table.monthlyMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get commissionBps => $composableBuilder(
    column: $table.commissionBps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get organiser => $composableBuilder(
    column: $table.organiser,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedGrowthBps => $composableBuilder(
    column: $table.expectedGrowthBps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentValueMinor => $composableBuilder(
    column: $table.currentValueMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueUpdatedOn => $composableBuilder(
    column: $table.valueUpdatedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get units => $composableBuilder(
    column: $table.units,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get buyPriceMinor => $composableBuilder(
    column: $table.buyPriceMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sipMinor => $composableBuilder(
    column: $table.sipMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chitValueMinor => $composableBuilder(
    column: $table.chitValueMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tenureMonths => $composableBuilder(
    column: $table.tenureMonths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get members => $composableBuilder(
    column: $table.members,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthlyMinor => $composableBuilder(
    column: $table.monthlyMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get commissionBps => $composableBuilder(
    column: $table.commissionBps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get organiser => $composableBuilder(
    column: $table.organiser,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
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

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<int> get expectedGrowthBps => $composableBuilder(
    column: $table.expectedGrowthBps,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentValueMinor => $composableBuilder(
    column: $table.currentValueMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get valueUpdatedOn => $composableBuilder(
    column: $table.valueUpdatedOn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get units =>
      $composableBuilder(column: $table.units, builder: (column) => column);

  GeneratedColumn<int> get buyPriceMinor => $composableBuilder(
    column: $table.buyPriceMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sipMinor =>
      $composableBuilder(column: $table.sipMinor, builder: (column) => column);

  GeneratedColumn<int> get chitValueMinor => $composableBuilder(
    column: $table.chitValueMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tenureMonths => $composableBuilder(
    column: $table.tenureMonths,
    builder: (column) => column,
  );

  GeneratedColumn<int> get members =>
      $composableBuilder(column: $table.members, builder: (column) => column);

  GeneratedColumn<int> get monthlyMinor => $composableBuilder(
    column: $table.monthlyMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get commissionBps => $composableBuilder(
    column: $table.commissionBps,
    builder: (column) => column,
  );

  GeneratedColumn<String> get organiser =>
      $composableBuilder(column: $table.organiser, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

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
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String?> startDate = const Value.absent(),
                Value<int?> expectedGrowthBps = const Value.absent(),
                Value<int?> currentValueMinor = const Value.absent(),
                Value<String?> valueUpdatedOn = const Value.absent(),
                Value<double?> units = const Value.absent(),
                Value<int?> buyPriceMinor = const Value.absent(),
                Value<int?> sipMinor = const Value.absent(),
                Value<int?> chitValueMinor = const Value.absent(),
                Value<int?> tenureMonths = const Value.absent(),
                Value<int?> members = const Value.absent(),
                Value<int?> monthlyMinor = const Value.absent(),
                Value<int?> commissionBps = const Value.absent(),
                Value<String?> organiser = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvestmentsCompanion(
                id: id,
                kind: kind,
                name: name,
                accountId: accountId,
                startDate: startDate,
                expectedGrowthBps: expectedGrowthBps,
                currentValueMinor: currentValueMinor,
                valueUpdatedOn: valueUpdatedOn,
                units: units,
                buyPriceMinor: buyPriceMinor,
                sipMinor: sipMinor,
                chitValueMinor: chitValueMinor,
                tenureMonths: tenureMonths,
                members: members,
                monthlyMinor: monthlyMinor,
                commissionBps: commissionBps,
                organiser: organiser,
                note: note,
                hlc: hlc,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String name,
                Value<String?> accountId = const Value.absent(),
                Value<String?> startDate = const Value.absent(),
                Value<int?> expectedGrowthBps = const Value.absent(),
                Value<int?> currentValueMinor = const Value.absent(),
                Value<String?> valueUpdatedOn = const Value.absent(),
                Value<double?> units = const Value.absent(),
                Value<int?> buyPriceMinor = const Value.absent(),
                Value<int?> sipMinor = const Value.absent(),
                Value<int?> chitValueMinor = const Value.absent(),
                Value<int?> tenureMonths = const Value.absent(),
                Value<int?> members = const Value.absent(),
                Value<int?> monthlyMinor = const Value.absent(),
                Value<int?> commissionBps = const Value.absent(),
                Value<String?> organiser = const Value.absent(),
                Value<String> note = const Value.absent(),
                required String hlc,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvestmentsCompanion.insert(
                id: id,
                kind: kind,
                name: name,
                accountId: accountId,
                startDate: startDate,
                expectedGrowthBps: expectedGrowthBps,
                currentValueMinor: currentValueMinor,
                valueUpdatedOn: valueUpdatedOn,
                units: units,
                buyPriceMinor: buyPriceMinor,
                sipMinor: sipMinor,
                chitValueMinor: chitValueMinor,
                tenureMonths: tenureMonths,
                members: members,
                monthlyMinor: monthlyMinor,
                commissionBps: commissionBps,
                organiser: organiser,
                note: note,
                hlc: hlc,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InvestmentsTable, Investment>(table),
                  BaseReferences<_$AppDatabase, $InvestmentsTable, Investment>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
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
typedef $$InvestmentEntriesTableCreateCompanionBuilder =
    InvestmentEntriesCompanion Function({
      required String id,
      required String investmentId,
      required String type,
      required int amountMinor,
      required String date,
      Value<int?> periodKey,
      Value<bool> postToBalance,
      Value<String> note,
      required String hlc,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$InvestmentEntriesTableUpdateCompanionBuilder =
    InvestmentEntriesCompanion Function({
      Value<String> id,
      Value<String> investmentId,
      Value<String> type,
      Value<int> amountMinor,
      Value<String> date,
      Value<int?> periodKey,
      Value<bool> postToBalance,
      Value<String> note,
      Value<String> hlc,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$InvestmentEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $InvestmentEntriesTable> {
  $$InvestmentEntriesTableFilterComposer({
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

  ColumnFilters<String> get investmentId => $composableBuilder(
    column: $table.investmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get postToBalance => $composableBuilder(
    column: $table.postToBalance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InvestmentEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $InvestmentEntriesTable> {
  $$InvestmentEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get investmentId => $composableBuilder(
    column: $table.investmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get postToBalance => $composableBuilder(
    column: $table.postToBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InvestmentEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InvestmentEntriesTable> {
  $$InvestmentEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get investmentId => $composableBuilder(
    column: $table.investmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get periodKey =>
      $composableBuilder(column: $table.periodKey, builder: (column) => column);

  GeneratedColumn<bool> get postToBalance => $composableBuilder(
    column: $table.postToBalance,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$InvestmentEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InvestmentEntriesTable,
          InvestmentEntry,
          $$InvestmentEntriesTableFilterComposer,
          $$InvestmentEntriesTableOrderingComposer,
          $$InvestmentEntriesTableAnnotationComposer,
          $$InvestmentEntriesTableCreateCompanionBuilder,
          $$InvestmentEntriesTableUpdateCompanionBuilder,
          (
            InvestmentEntry,
            BaseReferences<
              _$AppDatabase,
              $InvestmentEntriesTable,
              InvestmentEntry
            >,
          ),
          InvestmentEntry,
          PrefetchHooks Function()
        > {
  $$InvestmentEntriesTableTableManager(
    _$AppDatabase db,
    $InvestmentEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvestmentEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InvestmentEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InvestmentEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> investmentId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int?> periodKey = const Value.absent(),
                Value<bool> postToBalance = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvestmentEntriesCompanion(
                id: id,
                investmentId: investmentId,
                type: type,
                amountMinor: amountMinor,
                date: date,
                periodKey: periodKey,
                postToBalance: postToBalance,
                note: note,
                hlc: hlc,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String investmentId,
                required String type,
                required int amountMinor,
                required String date,
                Value<int?> periodKey = const Value.absent(),
                Value<bool> postToBalance = const Value.absent(),
                Value<String> note = const Value.absent(),
                required String hlc,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvestmentEntriesCompanion.insert(
                id: id,
                investmentId: investmentId,
                type: type,
                amountMinor: amountMinor,
                date: date,
                periodKey: periodKey,
                postToBalance: postToBalance,
                note: note,
                hlc: hlc,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InvestmentEntriesTable, InvestmentEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $InvestmentEntriesTable,
                    InvestmentEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InvestmentEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InvestmentEntriesTable,
      InvestmentEntry,
      $$InvestmentEntriesTableFilterComposer,
      $$InvestmentEntriesTableOrderingComposer,
      $$InvestmentEntriesTableAnnotationComposer,
      $$InvestmentEntriesTableCreateCompanionBuilder,
      $$InvestmentEntriesTableUpdateCompanionBuilder,
      (
        InvestmentEntry,
        BaseReferences<_$AppDatabase, $InvestmentEntriesTable, InvestmentEntry>,
      ),
      InvestmentEntry,
      PrefetchHooks Function()
    >;
typedef $$SmsInboxTableCreateCompanionBuilder = SmsInboxCompanion Function({
  required String id,
  required String fingerprint,
  required String semanticKey,
  required String sender,
  required String body,
  required String direction,
  required int amountMinor,
  required String date,
  Value<String?> merchant,
  Value<String?> accountRef,
  Value<String?> reference,
  Value<String> status,
  Value<int> rowid,
});
typedef $$SmsInboxTableUpdateCompanionBuilder = SmsInboxCompanion Function({
  Value<String> id,
  Value<String> fingerprint,
  Value<String> semanticKey,
  Value<String> sender,
  Value<String> body,
  Value<String> direction,
  Value<int> amountMinor,
  Value<String> date,
  Value<String?> merchant,
  Value<String?> accountRef,
  Value<String?> reference,
  Value<String> status,
  Value<int> rowid,
});

class $$SmsInboxTableFilterComposer
    extends Composer<_$AppDatabase, $SmsInboxTable> {
  $$SmsInboxTableFilterComposer({
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

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semanticKey => $composableBuilder(
    column: $table.semanticKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountRef => $composableBuilder(
    column: $table.accountRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SmsInboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SmsInboxTable> {
  $$SmsInboxTableOrderingComposer({
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

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semanticKey => $composableBuilder(
    column: $table.semanticKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountRef => $composableBuilder(
    column: $table.accountRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SmsInboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SmsInboxTable> {
  $$SmsInboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get semanticKey => $composableBuilder(
    column: $table.semanticKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sender =>
      $composableBuilder(column: $table.sender, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumn<String> get accountRef => $composableBuilder(
    column: $table.accountRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$SmsInboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SmsInboxTable,
          SmsInboxData,
          $$SmsInboxTableFilterComposer,
          $$SmsInboxTableOrderingComposer,
          $$SmsInboxTableAnnotationComposer,
          $$SmsInboxTableCreateCompanionBuilder,
          $$SmsInboxTableUpdateCompanionBuilder,
          (
            SmsInboxData,
            BaseReferences<_$AppDatabase, $SmsInboxTable, SmsInboxData>,
          ),
          SmsInboxData,
          PrefetchHooks Function()
        > {
  $$SmsInboxTableTableManager(_$AppDatabase db, $SmsInboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SmsInboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SmsInboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SmsInboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<String> semanticKey = const Value.absent(),
                Value<String> sender = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String?> merchant = const Value.absent(),
                Value<String?> accountRef = const Value.absent(),
                Value<String?> reference = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SmsInboxCompanion(
                id: id,
                fingerprint: fingerprint,
                semanticKey: semanticKey,
                sender: sender,
                body: body,
                direction: direction,
                amountMinor: amountMinor,
                date: date,
                merchant: merchant,
                accountRef: accountRef,
                reference: reference,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String fingerprint,
                required String semanticKey,
                required String sender,
                required String body,
                required String direction,
                required int amountMinor,
                required String date,
                Value<String?> merchant = const Value.absent(),
                Value<String?> accountRef = const Value.absent(),
                Value<String?> reference = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SmsInboxCompanion.insert(
                id: id,
                fingerprint: fingerprint,
                semanticKey: semanticKey,
                sender: sender,
                body: body,
                direction: direction,
                amountMinor: amountMinor,
                date: date,
                merchant: merchant,
                accountRef: accountRef,
                reference: reference,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SmsInboxTable, SmsInboxData>(table),
                  BaseReferences<_$AppDatabase, $SmsInboxTable, SmsInboxData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SmsInboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SmsInboxTable,
      SmsInboxData,
      $$SmsInboxTableFilterComposer,
      $$SmsInboxTableOrderingComposer,
      $$SmsInboxTableAnnotationComposer,
      $$SmsInboxTableCreateCompanionBuilder,
      $$SmsInboxTableUpdateCompanionBuilder,
      (
        SmsInboxData,
        BaseReferences<_$AppDatabase, $SmsInboxTable, SmsInboxData>,
      ),
      SmsInboxData,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
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

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
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

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
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

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, Setting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$DebtsTableTableManager get debts =>
      $$DebtsTableTableManager(_db, _db.debts);
  $$DebtEventsTableTableManager get debtEvents =>
      $$DebtEventsTableTableManager(_db, _db.debtEvents);
  $$InvestmentsTableTableManager get investments =>
      $$InvestmentsTableTableManager(_db, _db.investments);
  $$InvestmentEntriesTableTableManager get investmentEntries =>
      $$InvestmentEntriesTableTableManager(_db, _db.investmentEntries);
  $$SmsInboxTableTableManager get smsInbox =>
      $$SmsInboxTableTableManager(_db, _db.smsInbox);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
