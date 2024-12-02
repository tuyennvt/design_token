import 'dart:convert';
import 'dart:io';

import 'package:diacritic/diacritic.dart';

const inputPaths = [
  'assets/json/foundation.json',
  'assets/json/components.json',
];

void main() async {
  final outputFile = File('lib/src/design_tokens.dart');
  outputFile.writeAsString("import 'package:flutter/material.dart';\n\n");

  final inputFiles = inputPaths.map((path) => File(path)).toList();

  for (int i = 0; i < inputFiles.length; i++) {
    final fileContent = await inputFiles[i].readAsString();
    final List<dynamic> json = jsonDecode(fileContent);
    for (int index = 0; index < json.length; index++) {
      final dartCode = _getDartCode(json[index]);
      await outputFile.writeAsString(dartCode, mode: FileMode.append);
    }
  }

  print('Generated');
}

String _getDartCode(Map<String, dynamic> json) {
  final buffer = StringBuffer();
  buffer.writeln();
  _parseToken(json, buffer);
  return buffer.toString();
}

void _parseToken(
  Map<String, dynamic> json,
  StringBuffer buffer, {
  String parentKey = '',
}) {
  json.forEach((jsonKey, jsonValue) {
    final currentKey =
        (parentKey.isEmpty ? jsonKey : '$parentKey$jsonKey').standardize;
    if (!jsonValue.containsKey('type') || !jsonValue.containsKey('value')) {
      _parseToken(jsonValue, buffer, parentKey: currentKey);
    } else {
      final type = jsonValue['type'];
      switch (type) {
        case 'color':
          final colorToken = _getColorToken(
            key: currentKey,
            value: jsonValue['value'],
          );
          buffer.writeln(colorToken);
          break;
        case 'number':
          final numberToken = _getNumberToken(
            key: currentKey,
            value: jsonValue['value'],
          );
          buffer.writeln(numberToken);
          break;
        default:
          print('$type is not supported');
          break;
      }
    }
  });
}

String _getColorToken({
  required String key,
  required String value,
}) {
  final variableName = key.toFirstLowerCase;
  if (value.startsWith('#')) {
    final dartColorValue = 'Color(0xFF${value.substring(1).toUpperCase()})';
    return "const $variableName = $dartColorValue;";
  } else if (value.startsWith('rgba')) {
    final rgbaPattern = RegExp(r'rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)');
    final match = rgbaPattern.firstMatch(value);
    if (match != null) {
      final r = int.parse(match.group(1)!);
      final g = int.parse(match.group(2)!);
      final b = int.parse(match.group(3)!);
      final a = double.parse(match.group(4)!);
      final dartCodeValue = 'Color.fromRGBO($r, $g, $b, $a)';
      return "const $variableName = $dartCodeValue;";
    }
  } else if (value.startsWith('{')) {
    return "const $variableName = ${value.toReferenceName};";
  }
  return '';
}

String _getNumberToken({
  required String key,
  required dynamic value,
}) {
  final variableName = key.toFirstLowerCase;
  if (value is num) {
    return "const $variableName = $value;";
  } else if (value is String && value.startsWith('{')) {
    return "const $variableName = ${value.toReferenceName};";
  }
  return '';
}

extension _StringExt on String {
  String get toReferenceName {
    final name =
        replaceAll('{', '').replaceAll('}', '').standardize.replaceAll('.', '');
    return name.toFirstLowerCase;
  }

  String get toFirstLowerCase {
    return '${this[0].toLowerCase()}${substring(1)}';
  }

  String get standardize {
    return removeDiacritics(
        replaceAll(RegExp(r'\s+'), '').replaceAll('-', '').replaceAll('%', ''));
  }
}
