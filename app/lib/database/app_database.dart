import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// Tables
class Bookings extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get ticketTypeId => text()();
  TextColumn get fromStationId => text().nullable()();
  TextColumn get toStationId => text().nullable()();
  IntColumn get quantity => integer()();
  RealColumn get totalPrice => real()();
  TextColumn get status => text()();
  TextColumn get qrCode => text().nullable()();
  TextColumn get rfidToken => text().nullable()();
  DateTimeColumn get validFrom => dateTime().nullable()();
  DateTimeColumn get validUntil => dateTime().nullable()();
  DateTimeColumn get validatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}

class TicketTypes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  RealColumn get price => real()();
  IntColumn get durationMinutes => integer().nullable()();
  TextColumn get validityType => text()();
  TextColumn get category => text()();
  BoolColumn get isActive => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}

class Stations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get city => text().nullable()();
  TextColumn get country => text()();
  BoolColumn get isActive => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}

class FavoriteTickets extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get ticketTypeId => text()();
  TextColumn get fromStationId => text().nullable()();
  TextColumn get toStationId => text().nullable()();
  IntColumn get quantity => integer()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  
  @override
  Set<Column> get primaryKey => {id};
}

class Wallets extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  RealColumn get balance => real()();
  TextColumn get currency => text()();
  BoolColumn get autoTopupEnabled => boolean()();
  RealColumn get autoTopupLimit => real()();
  RealColumn get autoTopupAmount => real()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}

class WalletTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get walletId => text()();
  TextColumn get type => text()(); // 'credit' or 'debit'
  RealColumn get amount => real()();
  TextColumn get description => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  
  @override
  Set<Column> get primaryKey => {id};
}

class PaymentMethods extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get type => text()(); // 'card', 'paypal', 'apple_pay', 'google_pay', 'wallet'
  TextColumn get cardNumber => text().nullable()(); // Last 4 digits only
  TextColumn get cardHolderName => text().nullable()();
  TextColumn get expiryMonth => text().nullable()();
  TextColumn get expiryYear => text().nullable()();
  TextColumn get brand => text().nullable()(); // Visa, Mastercard, etc.
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get targetTable => text()();
  TextColumn get operation => text()(); // 'insert', 'update', 'delete'
  TextColumn get recordId => text()();
  TextColumn get data => text()(); // JSON string
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  
  @override
  String get tableName => 'sync_queue';
}

@DriftDatabase(tables: [
  Bookings,
  TicketTypes,
  Stations,
  FavoriteTickets,
  Wallets,
  WalletTransactions,
  PaymentMethods,
  SyncQueue,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add PaymentMethods table
          await m.createTable(paymentMethods);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'ticketmania.db'));
    return NativeDatabase(file);
  });
}

