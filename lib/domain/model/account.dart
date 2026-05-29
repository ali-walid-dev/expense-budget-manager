import 'package:flutter/material.dart';

enum AccountType {
  cash,
  bank,
  creditCard,
  wallet,
  vodafoneCash,
  instapay;
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.initialBalance,
    required this.color,
    required this.iconKey,
    required this.archived,
  });

  final int id;
  final String name;
  final AccountType type;
  final String currency;
  final int initialBalance;
  final Color color;
  final String iconKey;
  final bool archived;

  Account copyWith({
    String? name,
    AccountType? type,
    String? currency,
    int? initialBalance,
    Color? color,
    String? iconKey,
    bool? archived,
  }) =>
      Account(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        currency: currency ?? this.currency,
        initialBalance: initialBalance ?? this.initialBalance,
        color: color ?? this.color,
        iconKey: iconKey ?? this.iconKey,
        archived: archived ?? this.archived,
      );
}

class AccountWithBalance {
  const AccountWithBalance({required this.account, required this.balance});
  final Account account;
  final int balance;
}
