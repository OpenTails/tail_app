import 'dart:core';

import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';

//While json_serialization should support generics, its broken?
//Docs show example which should work but, when used with ValueNotifier, throw a Converter error https://github.com/google/json_serializable.dart/blob/master/example/lib/json_converter_example.dart

class BaseValueNotifierConverter<T> extends JsonConverter<ValueNotifier<T>, T> {
  const BaseValueNotifierConverter();

  @override
  ValueNotifier<T> fromJson(T json) => ValueNotifier<T>(json);

  @override
  T toJson(ValueNotifier<T> object) {
    return object.value;
  }
}

class StringValueNotifierConverter extends BaseValueNotifierConverter<String> {
  @override
  const StringValueNotifierConverter();
}

class BooleanValueNotifierConverter extends BaseValueNotifierConverter<bool> {
  @override
  const BooleanValueNotifierConverter();
}

class DoubleValueNotifierConverter extends BaseValueNotifierConverter<double> {
  @override
  const DoubleValueNotifierConverter();
}

class ListActionValueNotifierConverter extends JsonConverter<ValueNotifier<List<AutoActionCategory>>, List<dynamic>> {
  const ListActionValueNotifierConverter();

  @override
  ValueNotifier<List<AutoActionCategory>> fromJson(List<dynamic> json) {
    return ValueNotifier<List<AutoActionCategory>>(json.map((e) => AutoActionCategory.values[e as int]).toList());
  }

  @override
  List<int> toJson(ValueNotifier<List<AutoActionCategory>> object) {
    return object.value.map((e) => e.index).toList();
  }
}
