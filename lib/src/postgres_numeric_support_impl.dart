import 'dart:math';
import 'dart:typed_data';

import 'package:rational/rational.dart';

final BigInt bigInt10 = BigInt.from(10);
final BigInt bigIntM1 = BigInt.from(-1);

final Rational rational10000 = Rational.fromInt(pow(10, 4) as int);

Rational numericBinaryToRational(Uint8List binary) {
  if (binary == null) {
    return null;
  }

  int ndigits = (binary[0] << 8) + binary[1];
  int weight = (binary[2] << 8) + binary[3];
  int sign = (binary[4] << 8) + binary[5];
  int dscale = (binary[6] << 8) + binary[7];

  List<int> digits = [];
  for (int i = 8; i < binary.length; i += 2) {
    digits.add((binary[i] << 8) + binary[i + 1]);
  }

  BigInt numerator = BigInt.zero;

  int d;

  if (weight & (1 << 15) > 0) {
    d = weight - 0xFFFF;
  } else {
    for (d = 0; d <= weight; d++) {
      int dig = (d < ndigits) ? digits[d] : 0;
      bool putit = d > 0;

      int d1 = dig ~/ 1000;
      dig -= d1 * 1000;
      putit |= d1 > 0;
      if (putit) {
        numerator = numerator * BigInt.from(10);
        numerator += BigInt.from(d1);
      }
      d1 = dig ~/ 100;
      dig -= d1 * 100;
      putit |= d1 > 0;
      if (putit) {
        numerator = numerator * BigInt.from(10);
        numerator += BigInt.from(d1);
      }
      d1 = dig ~/ 10;
      dig -= d1 * 10;
      putit |= d1 > 0;
      if (putit) {
        numerator = numerator * BigInt.from(10);
        numerator += BigInt.from(d1);
      }
      numerator = numerator * BigInt.from(10);
      numerator += BigInt.from(dig);
    }
  }

  BigInt denominator = BigInt.zero;

  int numbersInDenominator = 0;

  if (dscale > 0) {
    for (int i = 0; i < dscale; d++, i += 4) {
      int dig = (d >= 0 && d < ndigits) ? digits[d] : 0;
      int d1 = dig ~/ 1000;
      dig -= d1 * 1000;

      denominator *= bigInt10;
      denominator += BigInt.from(d1);

      if (++numbersInDenominator >= dscale) break;

      d1 = dig ~/ 100;
      dig -= d1 * 100;

      denominator *= bigInt10;
      denominator += BigInt.from(d1);

      if (++numbersInDenominator >= dscale) break;

      d1 = dig ~/ 10;
      dig -= d1 * 10;

      denominator *= bigInt10;
      denominator += BigInt.from(d1);

      if (++numbersInDenominator >= dscale) break;

      denominator *= bigInt10;
      denominator += BigInt.from(dig);

      if (++numbersInDenominator >= dscale) break;
    }
  }

  var scaleDenominator = bigInt10.pow(dscale);

  numerator = numerator * scaleDenominator + denominator;

  if (sign == 0x4000) {
    numerator = bigIntM1 * numerator;
  }

  return Rational(numerator, scaleDenominator);
}

Uint8List rationalToNumericBinary(Rational rational, int scale) {
  List<int> digits = [];

  // numerator
  int numerator = rational.abs().toInt();

  int weight = -1;

  if (numerator > 0) {
    do {
      int digit = numerator % 10000;

      int byte0 = (digit & 0xFF00) >> 8;
      int byte1 = digit & 0xFF;

      digits.insert(0, byte1);
      digits.insert(0, byte0);

      numerator = numerator ~/ 10000;

      weight++;
    } while (numerator > 0);
  }

  // denominator
  var rationalDigit = rational.abs();

  bool denominatorAdded = false;

  for (int i = 0; i < scale; i += 4) {
    var rationalDenominator = rationalDigit - Rational(rationalDigit.toBigInt());
    rationalDigit = rationalDenominator * rational10000;

    int digit = rationalDigit.toInt();

    int byte0 = (digit & 0xFF00) >> 8;
    int byte1 = digit & 0xFF;

    bool leadingZero = digit == 0 && !denominatorAdded;
    bool trailingZero = digit == 0 && i >= scale - 4;

    if (!leadingZero && !trailingZero) {
      denominatorAdded = true;
      digits.add(byte0);
      digits.add(byte1);
    }

    if (!denominatorAdded && digit == 0) {
      weight--;
    }
  }

  int digitsNumber = digits.length ~/ 2;

  digits..insert(0, scale)..insert(0, 0);

  digits..insert(0, 0)..insert(0, rational.isNegative ? 0x40 : 0);

  digits..insert(0, weight)..insert(0, weight > 0 ? 0 : -1);

  digits..insert(0, digitsNumber)..insert(0, 0);

  return Uint8List.fromList(digits);
}

