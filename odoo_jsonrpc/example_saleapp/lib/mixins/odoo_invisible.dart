import 'dart:developer' as dev;

mixin InvisibleConditionMixin {
  Map<String, dynamic> get recordState;

  final _expressionCache = <String, bool>{};
  final _customOperators = <String, bool Function(String?, String)>{};

  void registerCustomOperator(
      String operator, bool Function(String?, String) evaluator) {
    _customOperators[operator] = evaluator;
  }

  void clearExpressionCache() {
    _expressionCache.clear();
  }

  bool parseInvisibleValue(
      dynamic value, {
        bool useCache = true,
        bool requireFieldExistence = false,
      }) {
    dev.log(
      'Parsing invisible value: $value for field: ${value ?? 'unknown'}',
      name: 'InvisibleConditionMixin',
    );
    if (value == null) {
      dev.log(
        'Result for field ${value ?? 'unknown'}: false (value is null)',
        name: 'InvisibleConditionMixin',
      );
      return false;
    }

    if (value is bool) {
      dev.log(
        'Result for field ${value ?? 'unknown'}: $value (boolean)',
        name: 'InvisibleConditionMixin',
      );
      return value;
    }
    if (value is int) {
      final result = value == 1;
      dev.log(
        'Result for field ${value ?? 'unknown'}: $result (int: $value)',
        name: 'InvisibleConditionMixin',
      );
      return result;
    }
    if (value is String) {
      final lowerValue = value.toLowerCase().trim();
      if (lowerValue == 'true' || lowerValue == '1') {
        dev.log(
          'Result for field ${value ?? 'unknown'}: true (string: $value)',
          name: 'InvisibleConditionMixin',
        );
        return true;
      }
      if (lowerValue == 'false' || lowerValue == '0') {
        dev.log(
          'Result for field ${value ?? 'unknown'}: false (string: $value)',
          name: 'InvisibleConditionMixin',
        );
        return false;
      }

      if (useCache && _expressionCache.containsKey(value)) {
        dev.log(
          'Result for field ${value ?? 'unknown'}: ${_expressionCache[value]!} (from cache)',
          name: 'InvisibleConditionMixin',
        );
        return _expressionCache[value]!;
      }

      // Normalize the expression first
      final normalizedExpr = _normalizeExpression(value);
      dev.log(
        'Normalized expression for field ${value ?? 'unknown'}: $normalizedExpr',
        name: 'InvisibleConditionMixin',
      );

      final result = _evaluateInvisibleExpression(
        normalizedExpr,
        requireFieldExistence: requireFieldExistence,
      );
      if (useCache) _expressionCache[value] = result;
      dev.log(
        'Result for field ${value ?? 'unknown'}: $result (evaluated expression: $normalizedExpr)',
        name: 'InvisibleConditionMixin',
      );
      return result;
    }
    if (value is List) {
      final result = _evaluateDomainExpression(
        value,
        requireFieldExistence: requireFieldExistence,
      );
      dev.log(
        'Result for field ${value ?? 'unknown'}: $result (domain expression: $value)',
        name: 'InvisibleConditionMixin',
      );
      return result;
    }

    dev.log(
      'Result for field ${value ?? 'unknown'}: false (unsupported type: ${value.runtimeType})',
      name: 'InvisibleConditionMixin',
    );
    return false;
  }

  String _normalizeExpression(String expression) {
    // Replace text operators with symbol operators for consistency
    String normalized = expression
        .replaceAll(RegExp(r'\s+and\s+', caseSensitive: false), ' & ')
        .replaceAll(RegExp(r'\s+or\s+', caseSensitive: false), ' | ');

    // Handle spaces around operators
    normalized = normalized
        .replaceAll(RegExp(r'\s*==\s*'), '==')
        .replaceAll(RegExp(r'\s*!=\s*'), '!=')
        .replaceAll(RegExp(r'\s*<=\s*'), '<=')
        .replaceAll(RegExp(r'\s*>=\s*'), '>=')
        .replaceAll(RegExp(r'\s*<\s*'), '<')
        .replaceAll(RegExp(r'\s*>\s*'), '>')
        .replaceAll(RegExp(r'\s*=\s*'), '=');

    // Add spaces around logical operators for easier splitting
    normalized = normalized
        .replaceAll('&', ' & ')
        .replaceAll('|', ' | ');

    return normalized;
  }

  bool _evaluateInvisibleExpression(
      String expression, {
        bool requireFieldExistence = false,
      }) {
    dev.log(
      'Evaluating expression: $expression',
      name: 'InvisibleConditionMixin',
    );

    // First, check if there are logical operators at the top level
    if (_containsLogicalOperatorsAtTopLevel(expression)) {
      return _evaluateLogicalExpression(
        expression,
        requireFieldExistence: requireFieldExistence,
      );
    }

    // Handle 'in' and 'not in' operators
    if (_containsInOperator(expression)) {
      return _evaluateInExpression(
        expression,
        requireFieldExistence: requireFieldExistence,
      );
    }

    // Handle 'not' prefix
    if (expression.trim().startsWith('not ')) {
      final fieldName = expression.trim().substring(4).trim();
      final result = !_getFieldBoolValue(
        fieldName,
        requireFieldExistence: requireFieldExistence,
      );
      dev.log(
        'Evaluated not $fieldName: $result',
        name: 'InvisibleConditionMixin',
      );
      return result;
    }

    // Handle comparison operators
    final comparisonResult = _evaluateComparisonExpression(
      expression,
      requireFieldExistence: requireFieldExistence,
    );
    if (comparisonResult != null) {
      return comparisonResult;
    }

    // Handle group_ prefix
    if (expression.trim().startsWith('group_')) {
      final result = _getFieldBoolValue(
        expression.trim(),
        requireFieldExistence: requireFieldExistence,
      );
      dev.log(
        'Evaluated group $expression: $result',
        name: 'InvisibleConditionMixin',
      );
      return result;
    }

    // Handle nested fields
    if (expression.contains('.')) {
      final result = _evaluateNestedField(
        expression,
        requireFieldExistence: requireFieldExistence,
      );
      dev.log(
        'Evaluated nested field $expression: $result',
        name: 'InvisibleConditionMixin',
      );
      return result;
    }

    // Default case - treat as field name
    final result = _getFieldBoolValue(
      expression.trim(),
      requireFieldExistence: requireFieldExistence,
    );
    dev.log(
      'Evaluated field $expression: $result',
      name: 'InvisibleConditionMixin',
    );
    return result;
  }

  bool _containsLogicalOperatorsAtTopLevel(String expression) {
    // Check if the expression contains & or | operators that are not inside quotes or parentheses
    bool inSingleQuote = false;
    bool inDoubleQuote = false;
    int parenthesisLevel = 0;

    for (int i = 0; i < expression.length; i++) {
      final char = expression[i];

      // Handle quotes
      if (char == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
      } else if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
      }

      // Handle parentheses
      if (!inSingleQuote && !inDoubleQuote) {
        if (char == '(') {
          parenthesisLevel++;
        } else if (char == ')') {
          parenthesisLevel--;
        }
      }

      // Check for logical operators at top level
      if (!inSingleQuote && !inDoubleQuote && parenthesisLevel == 0) {
        if ((char == '&' || char == '|') &&
            (i == 0 || expression[i - 1] == ' ') &&
            (i == expression.length - 1 || expression[i + 1] == ' ')) {
          return true;
        }
      }
    }

    return false;
  }

  bool _containsInOperator(String expression) {
    // Check for 'in' or 'not in' operators that are not inside quotes
    final inPattern = RegExp(r'(?<!\w)in(?!\w)');
    final notInPattern = RegExp(r'(?<!\w)not\s+in(?!\w)');

    bool inSingleQuote = false;
    bool inDoubleQuote = false;
    String tempExpr = '';

    // Remove quoted parts for checking
    for (int i = 0; i < expression.length; i++) {
      final char = expression[i];

      if (char == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
        continue;
      } else if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
        continue;
      }

      if (!inSingleQuote && !inDoubleQuote) {
        tempExpr += char;
      }
    }

    return inPattern.hasMatch(tempExpr) || notInPattern.hasMatch(tempExpr);
  }

  bool _evaluateInExpression(
      String expression, {
        bool requireFieldExistence = false,
      }) {
    // Handle 'in' and 'not in' operators
    String operator;
    List<String> parts;

    if (expression.contains(' not in ')) {
      operator = 'not in';
      parts = expression.split(' not in ');
    } else if (expression.contains(' in ')) {
      operator = 'in';
      parts = expression.split(' in ');
    } else {
      dev.log(
        'Invalid in/not in expression: $expression',
        name: 'InvisibleConditionMixin',
      );
      return false;
    }

    if (parts.length != 2) {
      dev.log(
        'Invalid $operator expression format: $expression',
        name: 'InvisibleConditionMixin',
      );
      return false;
    }

    final fieldName = parts[0].trim();
    String listPart = parts[1].trim();

    // Extract list values
    if ((listPart.startsWith('[') && listPart.endsWith(']')) ||
        (listPart.startsWith('(') && listPart.endsWith(')'))) {
      listPart = listPart.substring(1, listPart.length - 1);
      final values = _splitListValues(listPart);
      final fieldValue = _getFieldValue(fieldName);

      if (fieldValue == null) {
        dev.log(
          'Field $fieldName is null',
          name: 'InvisibleConditionMixin',
        );
        return requireFieldExistence ? false : operator == 'not in';
      }

      final fieldValueStr = fieldValue.toString();
      final isInList = values.contains(fieldValueStr);
      final result = operator == 'not in' ? !isInList : isInList;
      dev.log(
        '$fieldName $operator $values: $result',
        name: 'InvisibleConditionMixin',
      );
      return result;
    }

    dev.log(
      'Invalid list format in $operator expression: $expression',
      name: 'InvisibleConditionMixin',
    );
    return false;
  }

  bool? _evaluateComparisonExpression(
      String expression, {
        bool requireFieldExistence = false,
      }) {
    // Handle comparison operators
    const comparisonOperators = ['==', '!=', '<=', '>=', '<', '>', '='];
    String? foundOperator;
    List<String>? parts;

    for (final op in comparisonOperators) {
      if (expression.contains(op)) {
        foundOperator = op;
        parts = expression.split(op);
        break;
      }
    }

    if (foundOperator != null && parts != null) {
      if (parts.length != 2) {
        dev.log(
          'Invalid $foundOperator expression: $expression',
          name: 'InvisibleConditionMixin',
        );
        return false;
      }

      final fieldName = parts[0].trim();
      var expectedValue = parts[1].trim();

      // Remove quotes if present
      if ((expectedValue.startsWith("'") && expectedValue.endsWith("'")) ||
          (expectedValue.startsWith('"') && expectedValue.endsWith('"'))) {
        expectedValue = expectedValue.substring(1, expectedValue.length - 1);
      }

      if (!_fieldExists(fieldName)) {
        dev.log(
          'Field $fieldName not found',
          name: 'InvisibleConditionMixin',
        );
        return requireFieldExistence ? false : foundOperator == '!=';
      }

      final fieldValue = _getFieldValue(fieldName)?.toString();
      final result = _compareValues(
        fieldValue,
        expectedValue,
        foundOperator,
        requireFieldExistence,
      );
      dev.log(
        '$fieldName $foundOperator $expectedValue = $result',
        name: 'InvisibleConditionMixin',
      );
      return result;
    }

    return null;
  }

  bool _fieldExists(String fieldName) {
    if (fieldName.contains('.')) {
      // Check if nested field exists
      final parts = fieldName.split('.');
      dynamic current = recordState;

      for (var part in parts) {
        if (current is Map<String, dynamic>) {
          if (!current.containsKey(part)) {
            return false;
          }
          current = current[part];
        } else if (current is List && int.tryParse(part) != null) {
          final index = int.parse(part);
          if (index < 0 || index >= current.length) {
            return false;
          }
          current = current[index];
        } else {
          return false;
        }
      }

      return true;
    } else {
      return recordState.containsKey(fieldName);
    }
  }

  dynamic _getFieldValue(String fieldName) {
    if (fieldName.contains('.')) {
      return _getNestedFieldValue(fieldName);
    } else {
      return recordState[fieldName];
    }
  }

  bool _evaluateLogicalExpression(
      String expression, {
        bool requireFieldExistence = false,
      }) {
    dev.log(
      'Evaluating logical expression: $expression',
      name: 'InvisibleConditionMixin',
    );

    // Handle parenthesized expressions first
    final parenthesizedRegex = RegExp(r'\([^()]*\)');
    String processedExpr = expression;

    while (parenthesizedRegex.hasMatch(processedExpr)) {
      processedExpr = processedExpr.replaceAllMapped(parenthesizedRegex, (match) {
        final innerExpr = match.group(0)!.substring(1, match.group(0)!.length - 1);
        final result = _evaluateInvisibleExpression(
          innerExpr,
          requireFieldExistence: requireFieldExistence,
        );
        return result.toString();
      });
    }

    // Split by OR operator first
    if (processedExpr.contains(' | ')) {
      final orParts = processedExpr.split(' | ');
      for (final part in orParts) {
        if (_evaluateInvisibleExpression(
          part.trim(),
          requireFieldExistence: requireFieldExistence,
        )) {
          return true;
        }
      }
      return false;
    }

    // Then split by AND operator
    if (processedExpr.contains(' & ')) {
      final andParts = processedExpr.split(' & ');
      for (final part in andParts) {
        if (!_evaluateInvisibleExpression(
          part.trim(),
          requireFieldExistence: requireFieldExistence,
        )) {
          return false;
        }
      }
      return true;
    }

    // If no logical operators found after processing parentheses
    return _evaluateInvisibleExpression(
      processedExpr,
      requireFieldExistence: requireFieldExistence,
    );
  }

  List<String> _splitListValues(String listPart) {
    final result = <String>[];
    final current = StringBuffer();
    bool inQuotes = false;
    String quoteChar = '';

    for (var i = 0; i < listPart.length; i++) {
      final char = listPart[i];

      if (char == '"' || char == "'") {
        if (inQuotes && char == quoteChar) {
          inQuotes = false;
          quoteChar = '';
        } else if (!inQuotes) {
          inQuotes = true;
          quoteChar = char;
        }
        current.write(char);
      } else if (char == ',' && !inQuotes) {
        var value = current.toString().trim();
        if (value.startsWith("'") && value.endsWith("'") ||
            value.startsWith('"') && value.endsWith('"')) {
          value = value.substring(1, value.length - 1);
        }
        if (value.isNotEmpty) result.add(value);
        current.clear();
      } else {
        current.write(char);
      }
    }

    final value = current.toString().trim();
    if (value.isNotEmpty) {
      if (value.startsWith("'") && value.endsWith("'") ||
          value.startsWith('"') && value.endsWith('"')) {
        result.add(value.substring(1, value.length - 1));
      } else {
        result.add(value);
      }
    }

    dev.log(
      'Parsed list: $result',
      name: 'InvisibleConditionMixin',
    );
    return result;
  }

  bool _evaluateDomainExpression(
      List<dynamic> domain, {
        bool requireFieldExistence = false,
      }) {
    if (domain.isEmpty) {
      dev.log(
        'Empty domain, returning true',
        name: 'InvisibleConditionMixin',
      );
      return true;
    }

    if (domain[0] is String && ['&', '|', '!'].contains(domain[0])) {
      final operator = domain[0] as String;
      if (operator == '!') {
        if (domain.length != 2) {
          dev.log(
            'Invalid ! domain: $domain',
            name: 'InvisibleConditionMixin',
          );
          return false;
        }
        return !_evaluateDomainExpression(
          domain[1] as List<dynamic>,
          requireFieldExistence: requireFieldExistence,
        );
      }

      final subDomains = domain.sublist(1);
      if (operator == '&') {
        for (var subDomain in subDomains) {
          if (!_evaluateDomainExpression(
            subDomain as List<dynamic>,
            requireFieldExistence: requireFieldExistence,
          )) {
            return false;
          }
        }
        return true;
      } else if (operator == '|') {
        for (var subDomain in subDomains) {
          if (_evaluateDomainExpression(
            subDomain as List<dynamic>,
            requireFieldExistence: requireFieldExistence,
          )) {
            return true;
          }
        }
        return false;
      }
    }

    if (domain.length == 3) {
      final fieldName = domain[0] as String;
      final operator = domain[1] as String;
      final expectedValue = domain[2];

      final fieldValue = _getFieldValue(fieldName)?.toString();

      if (!_fieldExists(fieldName)) {
        dev.log(
          'Field $fieldName not found',
          name: 'InvisibleConditionMixin',
        );
        return requireFieldExistence
            ? false
            : (operator == '!=' || operator == 'not in');
      }

      if (operator == 'in' || operator == 'not in') {
        final values = expectedValue is List
            ? expectedValue.map((v) => v.toString()).toList()
            : [expectedValue.toString()];
        final isInList = values.contains(fieldValue);
        final result = operator == 'not in' ? !isInList : isInList;
        dev.log(
          '$fieldName $operator $values: $result',
          name: 'InvisibleConditionMixin',
        );
        return result;
      }

      if (operator == 'ilike' || operator == 'not ilike') {
        if (fieldValue == null) {
          return operator == 'not ilike';
        }
        final isLike = fieldValue
            .toLowerCase()
            .contains(expectedValue.toString().toLowerCase());
        final result = operator == 'not ilike' ? !isLike : isLike;
        dev.log(
          '$fieldName $operator $expectedValue: $result',
          name: 'InvisibleConditionMixin',
        );
        return result;
      }

      final result = _compareValues(
        fieldValue,
        expectedValue.toString(),
        operator,
        requireFieldExistence,
      );
      dev.log(
        '$fieldName $operator $expectedValue: $result',
        name: 'InvisibleConditionMixin',
      );
      return result;
    }

    dev.log(
      'Invalid domain: $domain',
      name: 'InvisibleConditionMixin',
    );
    return false;
  }

  bool _compareValues(
      String? fieldValue,
      String expectedValue,
      String operator,
      bool requireFieldExistence,
      ) {
    if (fieldValue == null) {
      return requireFieldExistence
          ? false
          : (operator == '!=' || operator == 'not in');
    }

    if (_customOperators.containsKey(operator)) {
      return _customOperators[operator]!(fieldValue, expectedValue);
    }

    final fieldNum = double.tryParse(fieldValue);
    final expectedNum = double.tryParse(expectedValue);

    if (fieldNum != null && expectedNum != null) {
      switch (operator) {
        case '==':
        case '=':
          return fieldNum == expectedNum;
        case '!=':
          return fieldNum != expectedNum;
        case '<':
          return fieldNum < expectedNum;
        case '>':
          return fieldNum > expectedNum;
        case '<=':
          return fieldNum <= expectedNum;
        case '>=':
          return fieldNum >= expectedNum;
        default:
          dev.log(
            'Unsupported numerical operator: $operator',
            name: 'InvisibleConditionMixin',
          );
          return false;
      }
    }

    switch (operator) {
      case '==':
      case '=':
        return fieldValue == expectedValue;
      case '!=':
        return fieldValue != expectedValue;
      default:
        dev.log(
          'Unsupported string operator: $operator',
          name: 'InvisibleConditionMixin',
        );
        return false;
    }
  }

  bool _getFieldBoolValue(
      String fieldName, {
        bool requireFieldExistence = false,
      }) {
    final value = _getFieldValue(fieldName);
    print("_getFieldBoolValue  : $fieldName $value");
    if (value == null) {
      if (requireFieldExistence && !_fieldExists(fieldName)) {
        return false;
      }
      return false;
    }

    if (value is bool) return value;
    if (value is int) return true;
    if (value is String) {
      final lowerValue = value.toLowerCase();
      return lowerValue == 'true' || lowerValue == '1';
    }
    return false;
  }

  dynamic _getNestedFieldValue(String fieldPath) {
    final parts = fieldPath.split('.');
    dynamic current = recordState;

    for (var part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else if (current is List && int.tryParse(part) != null) {
        final index = int.parse(part);
        if (index >= 0 && index < current.length) {
          current = current[index];
        } else {
          return null;
        }
      } else {
        return null;
      }
    }

    return current;
  }

  bool _evaluateNestedField(
      String expr, {
        bool requireFieldExistence = false,
      }) {
    // Check if it's a comparison expression
    const comparisonOperators = ['==', '!=', '<=', '>=', '<', '>', '='];
    String? foundOperator;
    List<String>? parts;

    for (final op in comparisonOperators) {
      if (expr.contains(op)) {
        foundOperator = op;
        parts = expr.split(op);
        break;
      }
    }

    if (foundOperator != null && parts != null) {
      if (parts.length != 2) {
        dev.log(
          'Invalid nested field expression: $expr',
          name: 'InvisibleConditionMixin',
        );
        return false;
      }

      final fieldPath = parts[0].trim();
      var expectedValue = parts[1].trim();

      if ((expectedValue.startsWith("'") && expectedValue.endsWith("'")) ||
          (expectedValue.startsWith('"') && expectedValue.endsWith('"'))) {
        expectedValue = expectedValue.substring(1, expectedValue.length - 1);
      }

      final fieldValue = _getNestedFieldValue(fieldPath)?.toString();
      if (fieldValue == null && requireFieldExistence) {
        dev.log(
          'Nested field $fieldPath not found',
          name: 'InvisibleConditionMixin',
        );
        return false;
      }
      return _compareValues(
        fieldValue,
        expectedValue,
        foundOperator,
        requireFieldExistence,
      );
    }

    return _getFieldBoolValue(
      expr,
      requireFieldExistence: requireFieldExistence,
    );
  }
}